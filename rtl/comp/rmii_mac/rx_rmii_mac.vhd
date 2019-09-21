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
            rmii_rxd_sync    <= rmii_rxd_meta;
            rmii_csr_dv_meta <= RMII_CSR_DV;
            rmii_csr_dv_sync <= rmii_csr_dv_meta;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            rmii_rxd_reg    <= rmii_rxd_sync;
            rmii_csr_dv_reg <= rmii_csr_dv_sync;
            if (rmii_csr_dv_sync = '1') then
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
            rx_byte <= rmii_rxd_reg & rx_byte(7 downto 2);
            rx_byte_last <= rmii_csr_dv_reg and not rmii_csr_dv_sync;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                rx_byte_vld <= '0';
            else
                rx_byte_vld <= rx_cnt_max and rmii_csr_dv_reg;
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

    process (fsm_pstate, rx_byte_vld, rx_byte, rx_byte_last)
    begin
        fsm_nstate <= idle;
        vld_flag   <= '0';
        sop_flag   <= '0';
        eop_flag   <= '0';

        case fsm_pstate is
            when idle =>
                if (rx_byte_vld = '1' and rx_byte = X"55") then
                    fsm_nstate <= preamble;
                else
                    fsm_nstate <= idle;
                end if;

            when preamble => -- todo check number of preamble bytes
                if (rx_byte_vld = '1') then
                    if (rx_byte = X"D5") then
                        fsm_nstate <= sfd;
                    elsif (rx_byte = X"55") then
                        fsm_nstate <= preamble;
                    else
                        fsm_nstate <= idle;
                    end if;
                else
                    fsm_nstate <= preamble;
                end if;

            when sfd => -- start frame delimiter
                if (rx_byte_vld = '1') then
                    fsm_nstate <= sop;
                else
                    fsm_nstate <= sfd;
                end if;

            when sop => -- start of packet (first byte)
                vld_flag <= '1';
                sop_flag <= '1';
                if (rx_byte_vld = '1') then
                    fsm_nstate <= wait4eop;
                else
                    fsm_nstate <= sfd;
                end if;

            when wait4eop => -- wait for end of packet (last byte)
                vld_flag <= '1';
                if (rx_byte_vld = '1' and rx_byte_last = '1') then
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
            sb0_data <= rx_byte;
            sb0_sop  <= sop_flag;
            sb0_eop  <= eop_flag;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                sb0_vld <= '0';
            else
                sb0_vld <= rx_byte_vld and vld_flag;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  FRAME CHECK AND STATISTICS
    -- -------------------------------------------------------------------------

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                rx_pkt_cnt <= (others => '0');
            elsif (sb0_sop = '1' and sb0_vld = '1') then
                rx_pkt_cnt <= rx_pkt_cnt + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  STORE AND FORWARD/DISCARD FIFO
    -- -------------------------------------------------------------------------

    fifom_din  <= sb1_data & sb1_sop & sb1_eop;
    fifom_mark <= sb1_sop and sb1_vld;
    --fifom_discard <= fifom_full; TODO

    fifo_mark_i: entity work.FIFO_MARK
    generic map (
        DATA_WIDTH => 8+1+1, -- data + sop + eop
        ADDR_WIDTH => 11 -- fifo depth = 2048 - 1 words
    )
    port map (
        CLK      => RMII_CLK,
        RST      => RMII_RST,
        -- FIFO WRITE INTERFACE
        DIN      => fifom_din,
        WR_EN    => sb1_vld,
        MARK     => fifom_mark,
        DISCARD  => fifom_discard,
        FULL     => fifom_full,
        -- FIFO READ INTERFACE
        DOUT     => fifom_dout,
        DOUT_VLD => sb2_vld,
        RD_EN    => sb2_rdy,
        -- FIFO STATUS SIGNAL
        STATUS   => fifom_status
    );

    sb2_data <= fifom_dout(8+2-1 downto 2);
    sb2_sop  <= fifom_dout(1);
    sb2_eop  <= fifom_dout(0);

    -- -------------------------------------------------------------------------
    --  CROSS DOMAIN CROSSING FIFO
    -- -------------------------------------------------------------------------

end architecture;
