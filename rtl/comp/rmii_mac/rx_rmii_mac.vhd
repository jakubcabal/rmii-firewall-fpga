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

entity RX_RMII_MAC is
    Port (
        -- CLOCKS AND RESETS
        RMII_CLK    : in  std_logic;
        RMII_RST    : in  std_logic;
        USER_CLK    : in  std_logic;
        USER_RST    : in  std_logic;

        -- RMII INPUT INTERFACE (RMII_CLK)
        RMII_RXD    : in  std_logic_vector(1 downto 0);
        RMII_CSR_DV : in  std_logic;

        -- USER OUTPUT STREAM INTERFACE (USER_CLK)
        TX_DATA     : out std_logic_vector(7 downto 0);
        TX_SOP      : out std_logic;
        TX_EOP      : out std_logic;
        TX_VLD      : out std_logic;
        TX_RDY      : in  std_logic;

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

architecture RTL of RX_RMII_MAC is

    constant ASFIFO_DATA_WIDTH : natural := 8+1; -- data + last
    constant ASFIFO_ADDR_WIDTH : natural := 6;
    constant FIFO_DATA_WIDTH   : natural := 8+1+1; -- data + sop + eop
    constant FIFO_ADDR_WIDTH   : natural := 11; -- fifo depth = 2048 - 1 words

    signal rmii_rxd_meta    : std_logic_vector(1 downto 0);
    signal rmii_rxd_sync    : std_logic_vector(1 downto 0);
    signal rmii_csr_dv_meta : std_logic;
    signal rmii_csr_dv_sync : std_logic;

    signal rmii_rxd_reg     : std_logic_vector(1 downto 0);
    signal rmii_csr_dv_reg  : std_logic;
    signal rx_cnt           : unsigned(1 downto 0);
    signal rx_cnt_max       : std_logic;
    signal rx_cnt_rst       : std_logic;

    signal rx_byte          : std_logic_vector(7 downto 0);
    signal rx_byte_last     : std_logic;
    signal rx_byte_vld      : std_logic;

    signal asfifo_din  : std_logic_vector(ASFIFO_DATA_WIDTH-1 downto 0);
    signal asfifo_dout : std_logic_vector(ASFIFO_DATA_WIDTH-1 downto 0);

    signal rx_byte_synced      : std_logic_vector(7 downto 0);
    signal rx_byte_last_synced : std_logic;
    signal rx_byte_vld_synced  : std_logic;

    type fsm_dec_state is (idle, preamble, sop, wait4eop);
    signal fsm_dec_pstate : fsm_dec_state;
    signal fsm_dec_nstate : fsm_dec_state;
    signal fsm_dec_dbg_st : std_logic_vector(1 downto 0);

    signal vld_flag  : std_logic;
    signal sop_flag  : std_logic;
    signal eop_flag  : std_logic;

    signal sb0_data : std_logic_vector(7 downto 0);
    signal sb0_sop  : std_logic;
    signal sb0_eop  : std_logic;
    signal sb0_vld  : std_logic;

    signal sb1_data : std_logic_vector(7 downto 0);
    signal sb1_sop  : std_logic;
    signal sb1_eop  : std_logic;
    signal sb1_vld  : std_logic;

    signal cnt_rx_pkt : unsigned(31 downto 0);
    signal cnt_tx_pkt : unsigned(31 downto 0);

    type fsm_fic_state is (idle, packet, discard);
    signal fsm_fic_pstate : fsm_fic_state;
    signal fsm_fic_nstate : fsm_fic_state;

    signal fifom_din      : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    signal fifom_wr       : std_logic;
    signal fifom_mark     : std_logic;
    signal fifom_discard  : std_logic;
    signal fifom_full     : std_logic;
    signal fifom_dout     : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    signal fifom_dout_vld : std_logic;
    signal fifom_rd       : std_logic;
    signal fifom_status   : std_logic_vector(FIFO_ADDR_WIDTH-1 downto 0);

    signal cmd_sel          : std_logic;
    signal cmd_we           : std_logic;
    signal cmd_enable_reset : std_logic;
    signal cmd_enable_set   : std_logic;
    signal cmd_cnt_clear    : std_logic;

    signal enable_reg : std_logic;
    signal status_reg : std_logic_vector(31 downto 0);

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
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (RMII_RST = '1' or rmii_csr_dv_reg = '0') then
                rx_cnt_rst <= '1';
            elsif (rmii_csr_dv_reg = '1' and rmii_rxd_reg = "01") then
                rx_cnt_rst <= '0';
            end if;
        end if;
    end process;

    process (RMII_CLK)
    begin
        if (rising_edge(RMII_CLK)) then
            if (rx_cnt_rst = '1') then
                rx_cnt <= to_unsigned(1,2);
            else
                rx_cnt <= rx_cnt + 1;
            end if;
        end if;
    end process;

    rx_cnt_max <= '1' when (rx_cnt = 3) else '0';

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
    --  CROSS DOMAIN CROSSING OF BYTE STREAM
    -- -------------------------------------------------------------------------

    asfifo_din <= rx_byte & rx_byte_last;

    asfifo_i : entity work.ASFIFO
    generic map (
        DATA_WIDTH => ASFIFO_DATA_WIDTH,
        ADDR_WIDTH => ASFIFO_ADDR_WIDTH
    )
    port map (
        -- FIFO WRITE INTERFACE
        WR_CLK      => RMII_CLK,
        WR_RST      => RMII_RST,
        WR_DATA     => asfifo_din,
        WR_REQ      => rx_byte_vld,
        WR_FULL     => open, -- USER_CLK must be >= RMII_CLK/4
        -- FIFO READ INTERFACE
        RD_CLK      => USER_CLK,
        RD_RST      => USER_RST,
        RD_DATA     => asfifo_dout,
        RD_DATA_VLD => rx_byte_vld_synced,
        RD_REQ      => rx_byte_vld_synced
    );

    rx_byte_synced      <= asfifo_dout(8+1-1 downto 1);
    rx_byte_last_synced <= asfifo_dout(0);

    -- -------------------------------------------------------------------------
    --  FSM - DECODING PACKET IN BYTE STREAM 
    -- -------------------------------------------------------------------------

    process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1') then
                fsm_dec_pstate <= idle;
            else
                fsm_dec_pstate <= fsm_dec_nstate;
            end if;
        end if;
    end process;

    process (fsm_dec_pstate, rx_byte_vld_synced, rx_byte_synced, rx_byte_last_synced)
    begin
        fsm_dec_nstate <= idle;
        fsm_dec_dbg_st <= "00";
        vld_flag       <= '0';
        sop_flag       <= '0';
        eop_flag       <= '0';

        case fsm_dec_pstate is
            when idle =>
                fsm_dec_dbg_st <= "00";
                if (rx_byte_vld_synced = '1' and rx_byte_synced = X"55") then
                    fsm_dec_nstate <= preamble;
                else
                    fsm_dec_nstate <= idle;
                end if;

            when preamble => -- todo check number of preamble bytes
                fsm_dec_dbg_st <= "01";
                if (rx_byte_vld_synced = '1') then
                    if (rx_byte_synced = X"D5") then
                        fsm_dec_nstate <= sop;
                    elsif (rx_byte_synced = X"55") then
                        fsm_dec_nstate <= preamble;
                    else
                        fsm_dec_nstate <= idle;
                    end if;
                else
                    fsm_dec_nstate <= preamble;
                end if;

            when sop => -- start of packet (first byte)
                fsm_dec_dbg_st <= "10";
                vld_flag <= '1';
                sop_flag <= '1';
                if (rx_byte_vld_synced = '1') then
                    fsm_dec_nstate <= wait4eop;
                else
                    fsm_dec_nstate <= sop;
                end if;

            when wait4eop => -- wait for end of packet (last byte)
                fsm_dec_dbg_st <= "11";
                vld_flag <= '1';
                if (rx_byte_vld_synced = '1' and rx_byte_last_synced = '1') then
                    eop_flag   <= '1';
                    fsm_dec_nstate <= idle;
                else
                    fsm_dec_nstate <= wait4eop;
                end if;

        end case;
    end process;

    process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            sb0_data <= rx_byte_synced;
            sb0_sop  <= sop_flag;
            sb0_eop  <= eop_flag;
        end if;
    end process;

    process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1') then
                sb0_vld <= '0';
            else
                sb0_vld <= rx_byte_vld_synced and vld_flag;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  FRAME CHECK
    -- -------------------------------------------------------------------------

    sb1_data <= sb0_data;
    sb1_sop  <= sb0_sop;
    sb1_eop  <= sb0_eop;
    sb1_vld  <= sb0_vld;

    -- -------------------------------------------------------------------------
    --  FRAME STATISTICS
    -- -------------------------------------------------------------------------

    process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1' or cmd_cnt_clear = '1') then
                cnt_rx_pkt <= (others => '0');
            elsif (sb1_eop = '1' and sb1_vld = '1') then
                cnt_rx_pkt <= cnt_rx_pkt + 1;
            end if;
        end if;
    end process;

    process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1' or cmd_cnt_clear = '1') then
                cnt_tx_pkt <= (others => '0');
            elsif (fifom_discard = '0' and sb1_eop = '1' and sb1_vld = '1') then
                cnt_tx_pkt <= cnt_tx_pkt + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  STORE AND FORWARD/DISCARD FIFO
    -- -------------------------------------------------------------------------

    process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1') then
                fsm_fic_pstate <= idle;
            else
                fsm_fic_pstate <= fsm_fic_nstate;
            end if;
        end if;
    end process;

    process (fsm_fic_pstate, fifom_full, sb1_vld, sb1_sop, sb1_eop)
    begin
        fsm_fic_nstate <= idle;
        fifom_mark     <= '0';
        fifom_discard  <= '0';

        case fsm_fic_pstate is
            when idle =>
                fifom_mark <= '1';
                if (fifom_full = '1') then
                    fsm_fic_nstate <= discard;
                elsif (sb1_vld = '1' and sb1_sop = '1') then
                    fsm_fic_nstate <= packet;
                else
                    fsm_fic_nstate <= idle;
                end if;

            when packet =>
                if (fifom_full = '1') then
                    fsm_fic_nstate <= discard;
                elsif (sb1_vld = '1' and sb1_eop = '1') then
                    fsm_fic_nstate <= idle;
                else
                    fsm_fic_nstate <= packet;
                end if;

            when discard =>
                fifom_discard <= '1';
                if (sb1_vld = '0' and fifom_full = '0') then
                    fsm_fic_nstate <= idle;
                else
                    fsm_fic_nstate <= discard;
                end if;

        end case;
    end process;

    fifom_din <= sb1_data & sb1_sop & sb1_eop;
    fifom_wr  <= sb1_vld;

    fifo_mark_i : entity work.FIFO_MARK
    generic map (
        DATA_WIDTH => FIFO_DATA_WIDTH,
        ADDR_WIDTH => FIFO_ADDR_WIDTH
    )
    port map (
        CLK         => USER_CLK,
        RST         => USER_RST,
        -- FIFO WRITE INTERFACE
        WR_DATA     => fifom_din,
        WR_REQ      => fifom_wr,
        WR_FULL     => fifom_full,
        -- FIFO READ INTERFACE
        RD_DATA     => fifom_dout,
        RD_DATA_VLD => fifom_dout_vld,
        RD_REQ      => fifom_rd,
        -- FIFO OTHERS SIGNALS
        MARK        => fifom_mark,
        DISCARD     => fifom_discard,
        STATUS      => fifom_status
    );

    fifom_rd <= TX_RDY and enable_reg;

    TX_DATA <= fifom_dout(8+2-1 downto 2);
    TX_SOP  <= fifom_dout(1);
    TX_EOP  <= fifom_dout(0);
    TX_VLD  <= fifom_dout_vld and enable_reg;

    -- -------------------------------------------------------------------------
    --  WISHBONE SLAVE LOGIC
    -- -------------------------------------------------------------------------

    cmd_sel <= '1' when (WB_ADDR(7 downto 0) = X"00") else '0';
    cmd_we  <= wb_stb and wb_we and cmd_sel;

    cmd_reg_p : process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            cmd_enable_reset <= '0';
            cmd_enable_set   <= '0';
            cmd_cnt_clear    <= '0';
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"00") then
                cmd_enable_reset <= '1';
            end if;
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"01") then
                cmd_enable_set <= '1';
            end if;
            if (cmd_we = '1' and WB_DIN(7 downto 0) = X"02") then
                cmd_cnt_clear <= '1';
            end if;
        end if;
    end process;

    enable_reg_p : process (USER_CLK)
    begin
        if (rising_edge(USER_CLK)) then
            if (USER_RST = '1' or cmd_enable_set = '1') then
                enable_reg <= '1';
            elsif (cmd_enable_reset = '1') then
                enable_reg <= '0';
            end if;
        end if;
    end process;

    status_reg <= (31 downto 19 => '0') & fifom_status & "000" & fifom_full & "00" & fsm_dec_dbg_st;

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
                    WB_DOUT <= (31 downto 1 => '0') & enable_reg;
                when X"04" =>
                    WB_DOUT <= status_reg;
                when X"10" =>
                    WB_DOUT <= std_logic_vector(cnt_rx_pkt);
                when X"14" =>
                    WB_DOUT <= std_logic_vector(cnt_tx_pkt);
                when others =>
                    WB_DOUT <= X"DEADCAFE";
            end case;
        end if;
    end process;

end architecture;
