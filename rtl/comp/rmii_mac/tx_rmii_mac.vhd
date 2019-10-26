--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Only 100 Mbps full duplex mode is supported now.

entity TX_RMII_MAC is
    Port (
        -- CLOCKS AND RESETS
        RMII_CLK    : in  std_logic;
        RMII_RST    : in  std_logic;
        USER_CLK    : in  std_logic;
        USER_RST    : in  std_logic;

        -- RMII OUTPUT INTERFACE (RMII_CLK)
        RMII_TXD    : out std_logic_vector(1 downto 0);
        RMII_TX_EN  : out std_logic;

        -- USER INPUT STREAM INTERFACE (USER_CLK)
        RX_DATA     : in  std_logic_vector(7 downto 0);
        RX_SOP      : in  std_logic;
        RX_EOP      : in  std_logic;
        RX_VLD      : in  std_logic;
        RX_RDY      : out std_logic;

        -- WISHBONE SLAVE INTERFACE (USER_CLK)
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

architecture RTL of TX_RMII_MAC is

    constant ASFIFO_DATA_WIDTH : natural := 8+1+1; -- data + sop + eop
    constant ASFIFO_ADDR_WIDTH : natural := 11; -- fifo depth

    signal rx_rdy_en : std_logic;
    signal rx_vld_en : std_logic;

    signal asfifo_din  : std_logic_vector(ASFIFO_DATA_WIDTH-1 downto 0);
    signal asfifo_dout : std_logic_vector(ASFIFO_DATA_WIDTH-1 downto 0);
    signal asfifo_full : std_logic;

    signal rx_data_synced : std_logic_vector(7 downto 0);
    signal rx_sop_synced  : std_logic;
    signal rx_eop_synced  : std_logic;
    signal rx_vld_synced  : std_logic;
    signal rx_rdy_synced  : std_logic;

    signal rx_eop_vld   : std_logic;
    signal pkt_rdy      : std_logic;
    signal pkt_rdy_next : std_logic;

    signal cnt_rx_pkt     : unsigned(31 downto 0);
    signal cnt_rx_pkt_reg : std_logic_vector(31 downto 0);

    type fsm_tx_state is (idle, preamble, sfd, packet, ipg);
    signal fsm_tx_pstate : fsm_tx_state;
    signal fsm_tx_nstate : fsm_tx_state;
    signal fsm_tx_enable : std_logic;
    signal fsm_tx_dbg_st : std_logic_vector(2 downto 0);

    signal cnt_reg       : unsigned(3 downto 0);
    signal cnt_reg_next  : unsigned(3 downto 0);
    signal tx_byte       : std_logic_vector(7 downto 0);
    signal tx_en         : std_logic;

    signal tx_cnt    : unsigned(1 downto 0);
    signal txd_reg   : std_logic_vector(1 downto 0);
    signal tx_en_reg : std_logic;

    signal cmd_sel        : std_logic;
    signal cmd_we         : std_logic;
    signal cmd_disable    : std_logic;
    signal cmd_enable     : std_logic;
    signal cmd_cnt_clear  : std_logic;
    signal cmd_cnt_sample : std_logic;

    signal disable_reg : std_logic;

begin

    -- -------------------------------------------------------------------------
    --  FRAME STATISTICS
    -- -------------------------------------------------------------------------

    process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1' or cmd_cnt_clear = '1') then
                cnt_rx_pkt <= (others => '0');
            elsif (RX_EOP = '1' and rx_vld_en = '1' and rx_rdy_en = '1') then
                cnt_rx_pkt <= cnt_rx_pkt + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  RX DATA BUFFER
    -- -------------------------------------------------------------------------

    rx_rdy_en <= not disable_reg and not asfifo_full;
    rx_vld_en <= RX_VLD and not disable_reg;

    RX_RDY <= rx_rdy_en;

    asfifo_din <= RX_DATA & RX_SOP & RX_EOP;

    data_asfifo_i : entity work.ASFIFO
    generic map (
        DATA_WIDTH => ASFIFO_DATA_WIDTH,
        ADDR_WIDTH => ASFIFO_ADDR_WIDTH
    )
    port map (
        -- FIFO WRITE INTERFACE
        WR_CLK      => USER_CLK,
        WR_RST      => USER_RST,
        WR_DATA     => asfifo_din,
        WR_REQ      => rx_vld_en,
        WR_FULL     => asfifo_full,
        -- FIFO READ INTERFACE
        RD_CLK      => RMII_CLK,
        RD_RST      => RMII_RST,
        RD_DATA     => asfifo_dout,
        RD_DATA_VLD => rx_vld_synced,
        RD_REQ      => rx_rdy_synced
    );

    rx_data_synced <= asfifo_dout(8+2-1 downto 2);
    rx_sop_synced  <= asfifo_dout(1);
    rx_eop_synced  <= asfifo_dout(0);

    rx_eop_vld <= rx_vld_en and rx_rdy_en and RX_EOP;

    eop_asfifo_i : entity work.ASFIFO
    generic map (
        DATA_WIDTH => 1,
        ADDR_WIDTH => ASFIFO_ADDR_WIDTH-4
    )
    port map (
        -- FIFO WRITE INTERFACE
        WR_CLK      => USER_CLK,
        WR_RST      => USER_RST,
        WR_DATA     => (others => '1'),
        WR_REQ      => rx_eop_vld,
        WR_FULL     => open,
        -- FIFO READ INTERFACE
        RD_CLK      => RMII_CLK,
        RD_RST      => RMII_RST,
        RD_DATA     => open,
        RD_DATA_VLD => pkt_rdy,
        RD_REQ      => pkt_rdy_next
    );

    -- -------------------------------------------------------------------------
    --  RMII TX FSM
    -- -------------------------------------------------------------------------

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                fsm_tx_pstate <= idle;
                cnt_reg <= (others => '0');
            elsif (fsm_tx_enable = '1') then
                fsm_tx_pstate <= fsm_tx_nstate;
                cnt_reg <= cnt_reg_next;
            end if;
        end if;
    end process;

    process (fsm_tx_pstate, fsm_tx_enable, rx_data_synced, rx_vld_synced,
        rx_sop_synced, rx_eop_synced, pkt_rdy, cnt_reg)
    begin
        fsm_tx_nstate <= idle;
        fsm_tx_dbg_st <= "000";
        rx_rdy_synced <= '0';
        cnt_reg_next  <= (others => '0');
        pkt_rdy_next  <= '0';
        tx_byte       <= X"00";
        tx_en         <= '0';

        case fsm_tx_pstate is
            when idle =>
                fsm_tx_dbg_st <= "000";
                if (rx_sop_synced = '1' and rx_vld_synced = '1' and pkt_rdy = '1') then
                    fsm_tx_nstate <= preamble;
                else
                    fsm_tx_nstate <= idle;
                end if;

            when preamble => -- seven preamble bytes
                fsm_tx_dbg_st <= "001";
                cnt_reg_next <= cnt_reg + 1;
                tx_byte <= X"55";
                tx_en   <= '1';

                if (cnt_reg = 6) then
                    fsm_tx_nstate <= sfd;
                else
                    fsm_tx_nstate <= preamble;
                end if;

            when sfd => -- one SFD byte
                fsm_tx_dbg_st <= "010";
                pkt_rdy_next <= fsm_tx_enable;
                tx_byte <= X"D5";
                tx_en   <= '1';

                fsm_tx_nstate <= packet;

            when packet =>
                fsm_tx_dbg_st <= "011";
                rx_rdy_synced <= fsm_tx_enable;
                tx_byte <= rx_data_synced;
                tx_en   <= '1';

                if (rx_vld_synced = '1' and rx_eop_synced = '1') then
                    fsm_tx_nstate <= ipg;
                else
                    fsm_tx_nstate <= packet;
                end if;

            when ipg => -- inter packet gap = 12 bytes
                fsm_tx_dbg_st <= "100";
                cnt_reg_next <= cnt_reg + 1;

                if (cnt_reg = 11) then
                    fsm_tx_nstate <= idle;
                else
                    fsm_tx_nstate <= ipg;
                end if;

        end case;
    end process;

    -- -------------------------------------------------------------------------
    --  BYTE STREAM TO RMII
    -- -------------------------------------------------------------------------

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                tx_cnt <= (others => '0');
            else
                tx_cnt <= tx_cnt + 1;
            end if;
        end if;
    end process;

    fsm_tx_enable <= '1' when (tx_cnt = "11") else '0';

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            case tx_cnt is
                when "00" =>
                    txd_reg <= tx_byte(1 downto 0);
                when "01" =>
                    txd_reg <= tx_byte(3 downto 2);
                when "10" =>
                    txd_reg <= tx_byte(5 downto 4);
                when others =>
                    txd_reg <= tx_byte(7 downto 6);
            end case;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1') then
                tx_en_reg <= '0';
            else
                tx_en_reg <= tx_en;
            end if;
        end if;
    end process;

    RMII_TXD   <= txd_reg;
    RMII_TX_EN <= tx_en_reg;

    -- -------------------------------------------------------------------------
    --  WISHBONE SLAVE LOGIC
    -- -------------------------------------------------------------------------

    cmd_sel <= '1' when (WB_ADDR(7 downto 0) = X"00") else '0';
    cmd_we  <= wb_stb and wb_we and cmd_sel;

    cmd_reg_p : process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            cmd_disable    <= '0';
            cmd_enable     <= '0';
            cmd_cnt_clear  <= '0';
            cmd_cnt_sample <= '0';
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"00") then
                cmd_disable <= '1';
            end if;
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"01") then
                cmd_enable <= '1';
            end if;
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"02") then
                cmd_cnt_clear <= '1';
            end if;
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"03") then
                cmd_cnt_sample <= '1';
            end if;
        end if;
    end process;

    disable_reg_p : process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1' or cmd_enable = '1') then
                disable_reg <= '0';
            elsif (cmd_disable = '1') then
                disable_reg <= '1';
            end if;
        end if;
    end process;

    cnt_sampled_reg_p : process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (cmd_cnt_sample = '1') then
                cnt_rx_pkt_reg <= std_logic_vector(cnt_rx_pkt);
            end if;
        end if;
    end process;

    WB_STALL <= '0';

    wb_ack_reg_p : process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            WB_ACK <= WB_CYC and WB_STB;
        end if;
    end process;

    wb_dout_reg_p : process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            case WB_ADDR(7 downto 0) is
                when X"00" =>
                    WB_DOUT <= X"20191026"; -- version
                when X"04" =>
                    WB_DOUT <= (31 downto 8 => '0') & "00" & (not asfifo_full) & RX_VLD & "000" & disable_reg;
                when X"10" =>
                    WB_DOUT <= cnt_rx_pkt_reg;
                when others =>
                    WB_DOUT <= X"DEADCAFE";
            end case;
        end if;
    end process;

end architecture;
