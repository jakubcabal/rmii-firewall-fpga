--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PARSER is
    Port (
        -- CLOCK AND RESET
        CLK    : in  std_logic;
        RST    : in  std_logic;

        -- INPUT STREAM INTERFACE
        RX_DATA     : in  std_logic_vector(7 downto 0);
        RX_SOP      : in  std_logic;
        RX_EOP      : in  std_logic;
        RX_VLD      : in  std_logic;
        RX_RDY      : out std_logic;

        -- OUTPUT STREAM INTERFACE
        TX_DATA     : out std_logic_vector(7 downto 0);
        TX_SOP      : out std_logic;
        TX_EOP      : out std_logic;
        TX_VLD      : out std_logic;
        TX_RDY      : in  std_logic;

        -- OUTPUT EXTRACT INTERFACE (valid with TX_EOP)
        EX_MAC_DST  : out std_logic_vector(47 downto 0);
        EX_MAC_SRC  : out std_logic_vector(47 downto 0);
        EX_IPV4_VLD : out std_logic;
        EX_IPV4_DST : out std_logic_vector(31 downto 0);
        EX_IPV4_SRC : out std_logic_vector(31 downto 0);
        EX_IPV6_VLD : out std_logic;
        EX_IPV6_DST : out std_logic_vector(127 downto 0);
        EX_IPV6_SRC : out std_logic_vector(127 downto 0)
    );
end entity;

architecture RTL of PARSER is

    signal rx_eop_vld  : std_logic;
    signal rx_word_vld : std_logic;
    signal rx_data_reg : std_logic_vector(8-1 downto 0);
    signal offset      : unsigned(14-1 downto 0);

    type fsm_state is (idle, mac_dst, mac_src, ethertype, ipv4_src, ipv4_dst,
        ipv6_src, ipv6_dst, done);
    signal fsm_pstate : fsm_state;
    signal fsm_nstate : fsm_state;

    signal mac_dst_shreg_en  : std_logic;
    signal mac_src_shreg_en  : std_logic;
    signal ipv4_vld_reg_next : std_logic;
    signal ipv4_src_shreg_en : std_logic;
    signal ipv4_dst_shreg_en : std_logic;
    signal ipv6_vld_reg_next : std_logic;
    signal ipv6_src_shreg_en : std_logic;
    signal ipv6_dst_shreg_en : std_logic;

    signal mac_dst_shreg  : std_logic_vector(48-1 downto 0);
    signal mac_src_shreg  : std_logic_vector(48-1 downto 0);
    signal ipv4_vld_reg   : std_logic;
    signal ipv4_dst_shreg : std_logic_vector(32-1 downto 0);
    signal ipv4_src_shreg : std_logic_vector(32-1 downto 0);
    signal ipv6_vld_reg   : std_logic;
    signal ipv6_dst_shreg : std_logic_vector(128-1 downto 0);
    signal ipv6_src_shreg : std_logic_vector(128-1 downto 0);

begin

    rx_eop_vld  <= RX_EOP and RX_VLD and TX_RDY;
    rx_word_vld <= RX_VLD and TX_RDY;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (rx_word_vld = '1') then
                rx_data_reg <= RX_DATA;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or rx_eop_vld = '1') then
                offset <= (others => '0');
            elsif (rx_word_vld = '1') then
                offset <= offset + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  FSM - PACKET PARSING
    -- -------------------------------------------------------------------------

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                fsm_pstate <= idle;
            elsif (TX_RDY = '1') then
                fsm_pstate <= fsm_nstate;
            end if;
        end if;
    end process;

    process (fsm_pstate, RX_DATA, RX_SOP, RX_EOP, RX_VLD, rx_data_reg, offset,
        ipv4_vld_reg, ipv6_vld_reg)
    begin
        fsm_nstate <= idle;
        mac_dst_shreg_en  <= '0';
        mac_src_shreg_en  <= '0';
        ipv4_vld_reg_next <= ipv4_vld_reg;
        ipv4_src_shreg_en <= '0';
        ipv4_dst_shreg_en <= '0';
        ipv6_vld_reg_next <= ipv6_vld_reg;
        ipv6_src_shreg_en <= '0';
        ipv6_dst_shreg_en <= '0';

        case fsm_pstate is
            when idle =>
                ipv4_vld_reg_next <= '0';
                ipv6_vld_reg_next <= '0';
                mac_dst_shreg_en  <= '1';
                if (RX_VLD = '1' and RX_SOP = '1') then
                    fsm_nstate <= mac_dst;
                else
                    fsm_nstate <= idle;
                end if;

            when mac_dst =>
                mac_dst_shreg_en <= '1';
                if (RX_VLD = '1' and offset = 5) then
                    fsm_nstate <= mac_src;
                else
                    fsm_nstate <= mac_dst;
                end if;

            when mac_src =>
                mac_src_shreg_en <= '1';
                if (RX_VLD = '1' and offset = 11) then
                    fsm_nstate <= ethertype;
                else
                    fsm_nstate <= mac_src;
                end if;

            when ethertype =>
                if (RX_VLD = '1' and offset = 13) then
                    if (rx_data_reg = X"08" and RX_DATA = X"00") then
                        fsm_nstate <= ipv4_src;
                    elsif (rx_data_reg = X"86" and RX_DATA = X"DD") then
                        fsm_nstate <= ipv6_src;
                    else
                        fsm_nstate <= done;
                    end if;
                else
                    fsm_nstate <= ethertype;
                end if;

            when ipv4_src =>
                ipv4_vld_reg_next <= '1';
                ipv4_src_shreg_en <= '1';
                if (RX_VLD = '1' and offset = 29) then
                    fsm_nstate <= ipv4_dst;
                else
                    fsm_nstate <= ipv4_src;
                end if;

            when ipv4_dst =>
                ipv4_vld_reg_next <= '1';
                ipv4_dst_shreg_en <= '1';
                if (RX_VLD = '1' and offset = 33) then
                    fsm_nstate <= done;
                else
                    fsm_nstate <= ipv4_dst;
                end if;

            when ipv6_src =>
                ipv6_vld_reg_next <= '1';
                ipv6_src_shreg_en <= '1';
                if (RX_VLD = '1' and offset = 37) then
                    fsm_nstate <= ipv6_dst;
                else
                    fsm_nstate <= ipv6_src;
                end if;

            when ipv6_dst =>
                ipv6_vld_reg_next <= '1';
                ipv6_dst_shreg_en <= '1';
                if (RX_VLD = '1' and offset = 53) then
                    fsm_nstate <= done;
                else
                    fsm_nstate <= ipv6_dst;
                end if;

            when done =>
                if (RX_VLD = '1' and RX_EOP = '1') then
                    fsm_nstate <= idle;
                else
                    fsm_nstate <= done;
                end if;

        end case;
    end process;

    -- -------------------------------------------------------------------------
    --  HELPER SHIFT REGSTERS AND STATE REGISTERS
    -- -------------------------------------------------------------------------

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (mac_dst_shreg_en = '1') then
                mac_dst_shreg <= mac_dst_shreg(47-8 downto 0) & RX_DATA;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (mac_src_shreg_en = '1') then
                mac_src_shreg <= mac_src_shreg(47-8 downto 0) & RX_DATA;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (ipv4_dst_shreg_en = '1') then
                ipv4_dst_shreg <= ipv4_dst_shreg(31-8 downto 0) & RX_DATA;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (ipv4_src_shreg_en = '1') then
                ipv4_src_shreg <= ipv4_src_shreg(31-8 downto 0) & RX_DATA;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (ipv6_dst_shreg_en = '1') then
                ipv6_dst_shreg <= ipv6_dst_shreg(127-8 downto 0) & RX_DATA;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (ipv6_src_shreg_en = '1') then
                ipv6_src_shreg <= ipv6_src_shreg(127-8 downto 0) & RX_DATA;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            ipv4_vld_reg <= ipv4_vld_reg_next;
            ipv6_vld_reg <= ipv6_vld_reg_next;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  OUTPUT ASSIGMENTS
    -- -------------------------------------------------------------------------

    TX_DATA <= RX_DATA;
    TX_SOP  <= RX_SOP;
    TX_EOP  <= RX_EOP;
    TX_VLD  <= RX_VLD;
    RX_RDY  <= TX_RDY;

    EX_MAC_DST  <= mac_dst_shreg;
    EX_MAC_SRC  <= mac_src_shreg;
    EX_IPV4_VLD <= ipv4_vld_reg;
    EX_IPV4_DST <= ipv4_dst_shreg;
    EX_IPV4_SRC <= ipv4_src_shreg;
    EX_IPV6_VLD <= ipv6_vld_reg;
    EX_IPV6_DST <= ipv6_dst_shreg;
    EX_IPV6_SRC <= ipv6_src_shreg;

end architecture;
