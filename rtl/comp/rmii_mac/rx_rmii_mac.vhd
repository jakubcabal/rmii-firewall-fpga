--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RX_RMII_MAC is
    Port (
        -- RMII INPUT INTERFACE
        RMII_CLK    : in  std_logic;
        RMII_RST    : in  std_logic;
        RMII_RXD    : in  std_logic_vector(1 downto 0);
        RMII_CSR_DV : in  std_logic;

        -- USER OUTPUT STREAM INTERFACE
        TX_CLK      : in  std_logic;
        TX_RST      : in  std_logic;
        TX_DATA     : out std_logic_vector(7 downto 0);
        TX_SOP      : out std_logic;
        TX_EOP      : out std_logic;
        TX_VLD      : out std_logic;
        TX_RDY      : in  std_logic;

        -- WISHBONE SLAVE INTERFACE
        WB_CLK      : in  std_logic;
        WB_RST      : in  std_logic;
        WB_CYC      : in  std_logic;
        WB_STB      : in  std_logic;
        WB_WE       : in  std_logic;
        WB_ADDR     : in  std_logic_vector(15 downto 0);
        WB_DIN      : in  std_logic_vector(31 downto 0);
        WB_STALL    : out std_logic;
        WB_ACK      : out std_logic;
        WB_DOUT     : out std_logic_vector(31 downto 0)
    );
end entity;

architecture RTL of RX_RMII_MAC is

    type state is (idle, preamble, sfd, sop, wait4eop);
    signal fsm_pstate : state;
    signal fsm_nstate : state;

    signal cmd_reg   : std_logic_vector(7 downto 0);
    signal cmd_next  : std_logic_vector(7 downto 0);
    signal addr_reg  : std_logic_vector(15 downto 0);
    signal addr_next : std_logic_vector(15 downto 0);
    signal dout_reg  : std_logic_vector(31 downto 0);
    signal dout_next : std_logic_vector(31 downto 0);
    signal din_reg   : std_logic_vector(31 downto 0);

    signal uart_dout     : std_logic_vector(7 downto 0);
    signal uart_dout_vld : std_logic;
    signal uart_din      : std_logic_vector(7 downto 0);
    signal uart_din_vld  : std_logic;
    signal uart_din_rdy  : std_logic;

begin

    -- -------------------------------------------------------------------------
    --  RMII TO BYTE STREAM
    -- -------------------------------------------------------------------------
    
    -- two flipflops as prevent metastability
    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            rmii_rxd_meta    <= RMII_RXD;
            rmii_rxd_reg     <= rmii_rxd_meta;
            rmii_csr_dv_meta <= RMII_CSR_DV;
            rmii_csr_dv_reg  <= rmii_csr_dv_meta;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            rmii_rxd_reg2    <= rmii_rxd_reg;
            rmii_csr_dv_reg2 <= rmii_csr_dv_reg;
            if (rmii_csr_dv_reg = '1') then
                rx_cnt <= rx_cnt + 1;
            else
                rx_cnt <= (others => '0');
            end if;
        end if;
    end process;

    rx_cnt_max <= '1' when (rx_cnt = "11") else '0';

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            data_reg <= rmii_rxd_reg2 & data_reg(7 downto 2);
            last_reg <= rmii_csr_dv_reg2 and not rmii_csr_dv_reg;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                vld_reg <= '0';
            else
                vld_reg <= rx_cnt_max and rmii_csr_dv_reg2;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  FSM
    -- -------------------------------------------------------------------------

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                fsm_pstate <= idle;
            else
                fsm_pstate <= fsm_nstate;
            end if;
        end if;
    end process;

    process (fsm_pstate, vld_reg, data_reg, last_reg)
    begin
        fsm_nstate   <= idle;
        vld_flag     <= '0';
        sop_flag     <= '0';
        eop_flag     <= '0';

        case fsm_pstate is
            when idle =>
                if (vld_reg = '1' and data_reg = X"55") then
                    fsm_nstate <= preamble;
                else
                    fsm_nstate <= idle;
                end if;

            when preamble => -- todo check number of preamble bytes
                if (vld_reg = '1') then
                    if (data_reg = X"D5") then
                        fsm_nstate <= sfd;
                    elsif (data_reg = X"55") then
                        fsm_nstate <= preamble;
                    else
                        fsm_nstate <= idle;
                    end if;
                else
                    fsm_nstate <= preamble;
                end if;

            when sfd => -- start frame delimiter
                if (vld_reg = '1') then
                    fsm_nstate <= sop;
                else
                    fsm_nstate <= sfd;
                end if;

            when sop => -- start of packet (first byte)
                vld_flag <= '1';
                sop_flag <= '1';
                if (vld_reg = '1') then
                    fsm_nstate <= wait4eop;
                else
                    fsm_nstate <= sfd;
                end if;

            when wait4eop => -- wait for end of packet (last byte)
                vld_flag <= '1';
                if (vld_reg = '1' and last_reg = '1') then
                    eop_flag   <= '1';
                    fsm_nstate <= idle;
                else
                    fsm_nstate <= wait4eop;
                end if;

        end case;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            data_reg2 <= data_reg;
            sop_reg2  <= sop_flag;
            eop_reg2  <= eop_flag;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                vld_reg2 <= '0';
            else
                vld_reg2 <= vld_reg and vld_flag;
            end if;
        end if;
    end process;

end architecture;
