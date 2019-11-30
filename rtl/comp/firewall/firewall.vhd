--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FIREWALL is
    Port (
        -- CLOCK AND RESET
        CLK      : in  std_logic;
        RST      : in  std_logic;

        -- INPUT STREAM INTERFACE
        RX_DATA  : in  std_logic_vector(7 downto 0);
        RX_SOP   : in  std_logic;
        RX_EOP   : in  std_logic;
        RX_VLD   : in  std_logic;
        RX_RDY   : out std_logic;

        -- OUTPUT STREAM INTERFACE
        TX_DATA  : out std_logic_vector(7 downto 0);
        TX_SOP   : out std_logic;
        TX_EOP   : out std_logic;
        TX_VLD   : out std_logic;
        TX_RDY   : in  std_logic;

        -- WISHBONE SLAVE INTERFACE
        WB_CYC   : in  std_logic;
        WB_STB   : in  std_logic;
        WB_WE    : in  std_logic;
        WB_ADDR  : in  std_logic_vector(15 downto 0);
        WB_DIN   : in  std_logic_vector(31 downto 0);
        WB_STALL : out std_logic;
        WB_ACK   : out std_logic;
        WB_DOUT  : out std_logic_vector(31 downto 0)
    );
end entity;

architecture RTL of FIREWALL is

    constant WB_PORTS        : natural := 8;
    constant WB_OFFSET       : natural := 10;
    constant FIFO_DATA_WIDTH : natural := 8+1+1; -- data + sop + eop
    constant FIFO_ADDR_WIDTH : natural := 12; -- fifo depth = 4096 - 1 words

    signal wb_mfs_cyc   : std_logic_vector(WB_PORTS-1 downto 0);
    signal wb_mfs_stb   : std_logic_vector(WB_PORTS-1 downto 0);
    signal wb_mfs_we    : std_logic_vector(WB_PORTS-1 downto 0);
    signal wb_mfs_addr  : std_logic_vector(WB_PORTS*16-1 downto 0);
    signal wb_mfs_din   : std_logic_vector(WB_PORTS*32-1 downto 0) := (others => '0');
    signal wb_mfs_stall : std_logic_vector(WB_PORTS-1 downto 0) := (others => '0');
    signal wb_mfs_ack   : std_logic_vector(WB_PORTS-1 downto 0) := (others => '0');
    signal wb_mfs_dout  : std_logic_vector(WB_PORTS*32-1 downto 0);

    signal parser_data     : std_logic_vector(7 downto 0);
    signal parser_sop      : std_logic;
    signal parser_eop      : std_logic;
    signal parser_vld      : std_logic;
    signal parser_rdy      : std_logic;
    signal parser_eop_vld  : std_logic;
    signal parser_ipv4_vld : std_logic;
    signal parser_ipv6_vld : std_logic;

    signal ex_mac_dst      : std_logic_vector(47 downto 0);
    signal ex_mac_src      : std_logic_vector(47 downto 0);
    signal ex_ipv4_dst     : std_logic_vector(31 downto 0);
    signal ex_ipv4_src     : std_logic_vector(31 downto 0);
    signal ex_ipv4_vld     : std_logic;
    signal ex_ipv6_dst     : std_logic_vector(127 downto 0);
    signal ex_ipv6_src     : std_logic_vector(127 downto 0);
    signal ex_ipv6_vld     : std_logic;

    signal fifo_din        : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    signal fifo_wr         : std_logic;
    signal fifo_full       : std_logic;
    signal fifo_dout       : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    signal fifo_dout_vld   : std_logic;
    signal fifo_rd         : std_logic;

    signal stfi_data       : std_logic_vector(7 downto 0);
    signal stfi_sop        : std_logic;
    signal stfi_eop        : std_logic;
    signal stfi_vld        : std_logic;
    signal stfi_rdy        : std_logic;

    signal eraser_data     : std_logic_vector(7 downto 0);
    signal eraser_sop      : std_logic;
    signal eraser_eop      : std_logic;
    signal eraser_vld      : std_logic;
    signal eraser_rdy      : std_logic;

    signal match_mac_dst_hit  : std_logic;
    signal match_mac_dst_vld  : std_logic;
    signal match_mac_src_hit  : std_logic;
    signal match_mac_src_vld  : std_logic;

    signal match_ipv4_dst_hit : std_logic;
    signal match_ipv4_dst_vld : std_logic;
    signal match_ipv4_src_hit : std_logic;
    signal match_ipv4_src_vld : std_logic;

    signal match_ipv6_dst_hit : std_logic;
    signal match_ipv6_dst_vld : std_logic;
    signal match_ipv6_src_hit : std_logic;
    signal match_ipv6_src_vld : std_logic;

    signal match_hit          : std_logic;
    signal match_vld          : std_logic;

    signal cnt_pkt              : unsigned(31 downto 0);
    signal cnt_ipv4             : unsigned(31 downto 0);
    signal cnt_ipv6             : unsigned(31 downto 0);
    signal cnt_mac_dst_hit      : unsigned(31 downto 0);
    signal cnt_mac_src_hit      : unsigned(31 downto 0);
    signal cnt_ipv4_dst_hit     : unsigned(31 downto 0);
    signal cnt_ipv4_src_hit     : unsigned(31 downto 0);
    signal cnt_ipv6_dst_hit     : unsigned(31 downto 0);
    signal cnt_ipv6_src_hit     : unsigned(31 downto 0);

    signal cnt_mac_dst_hit_en   : std_logic;
    signal cnt_mac_src_hit_en   : std_logic;
    signal cnt_ipv4_dst_hit_en  : std_logic;
    signal cnt_ipv4_src_hit_en  : std_logic;
    signal cnt_ipv6_dst_hit_en  : std_logic;
    signal cnt_ipv6_src_hit_en  : std_logic;

    signal cnt_pkt_reg          : std_logic_vector(31 downto 0);
    signal cnt_ipv4_reg         : std_logic_vector(31 downto 0);
    signal cnt_ipv6_reg         : std_logic_vector(31 downto 0);
    signal cnt_mac_dst_hit_reg  : std_logic_vector(31 downto 0);
    signal cnt_mac_src_hit_reg  : std_logic_vector(31 downto 0);
    signal cnt_ipv4_dst_hit_reg : std_logic_vector(31 downto 0);
    signal cnt_ipv4_src_hit_reg : std_logic_vector(31 downto 0);
    signal cnt_ipv6_dst_hit_reg : std_logic_vector(31 downto 0);
    signal cnt_ipv6_src_hit_reg : std_logic_vector(31 downto 0);

    signal cmd_sel        : std_logic;
    signal cmd_we         : std_logic;
    signal cmd_enable     : std_logic;
    signal cmd_disable    : std_logic;
    signal cmd_cnt_clear  : std_logic;
    signal cmd_cnt_sample : std_logic;

    signal disable_reg    : std_logic;
    signal status_reg     : std_logic_vector(31 downto 0);

begin

    -- -------------------------------------------------------------------------
    --  WISHBONE SPLITTER
    -- -------------------------------------------------------------------------

    wb_splitter_i : entity work.WB_SPLITTER
    generic map (
        MASTER_PORTS => WB_PORTS,
        ADDR_OFFSET  => WB_OFFSET
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        WB_S_CYC   => WB_CYC,
        WB_S_STB   => WB_STB,
        WB_S_WE    => WB_WE,
        WB_S_ADDR  => WB_ADDR,
        WB_S_DIN   => WB_DIN,
        WB_S_STALL => WB_STALL,
        WB_S_ACK   => WB_ACK,
        WB_S_DOUT  => WB_DOUT,

        WB_M_CYC   => wb_mfs_cyc,
        WB_M_STB   => wb_mfs_stb,
        WB_M_WE    => wb_mfs_we,
        WB_M_ADDR  => wb_mfs_addr,
        WB_M_DOUT  => wb_mfs_dout,
        WB_M_STALL => wb_mfs_stall,
        WB_M_ACK   => wb_mfs_ack,
        WB_M_DIN   => wb_mfs_din
    );

    -- -------------------------------------------------------------------------
    --  PACKET PARSER
    -- -------------------------------------------------------------------------

    parser_i : entity work.PARSER
    port map (
        CLK => CLK,
        RST => RST,

        RX_DATA => RX_DATA,
        RX_SOP  => RX_SOP,
        RX_EOP  => RX_EOP,
        RX_VLD  => RX_VLD,
        RX_RDY  => RX_RDY,

        TX_DATA => parser_data,
        TX_SOP  => parser_sop,
        TX_EOP  => parser_eop,
        TX_VLD  => parser_vld,
        TX_RDY  => parser_rdy,

        EX_MAC_DST  => ex_mac_dst,
        EX_MAC_SRC  => ex_mac_src,
        EX_IPV4_VLD => ex_ipv4_vld,
        EX_IPV4_DST => ex_ipv4_dst,
        EX_IPV4_SRC => ex_ipv4_src,
        EX_IPV6_VLD => ex_ipv6_vld,
        EX_IPV6_DST => ex_ipv6_dst,
        EX_IPV6_SRC => ex_ipv6_src
    );

    parser_eop_vld  <= parser_vld and parser_rdy and parser_eop;
    parser_ipv4_vld <= parser_eop_vld and ex_ipv4_vld;
    parser_ipv6_vld <= parser_eop_vld and ex_ipv6_vld;

    -- -------------------------------------------------------------------------
    --  STREAM FIFO
    -- -------------------------------------------------------------------------

    fifo_din   <= parser_data & parser_sop & parser_eop;
    fifo_wr    <= parser_vld;
    parser_rdy <= not fifo_full;

    fifo_i : entity work.FIFO
    generic map (
        DATA_WIDTH => FIFO_DATA_WIDTH,
        ADDR_WIDTH => FIFO_ADDR_WIDTH
    )
    port map (
        CLK         => CLK,
        RST         => RST,
        -- FIFO WRITE INTERFACE
        WR_DATA     => fifo_din,
        WR_REQ      => fifo_wr,
        WR_FULL     => fifo_full,
        -- FIFO READ INTERFACE
        RD_DATA     => fifo_dout,
        RD_DATA_VLD => fifo_dout_vld,
        RD_REQ      => fifo_rd,
        -- FIFO OTHERS SIGNALS
        STATUS      => open
    );

    fifo_rd   <= stfi_rdy;
    stfi_data <= fifo_dout(8+2-1 downto 2);
    stfi_sop  <= fifo_dout(1);
    stfi_eop  <= fifo_dout(0);
    stfi_vld  <= fifo_dout_vld;

    -- -------------------------------------------------------------------------
    --  MATCH UNITS
    -- -------------------------------------------------------------------------

    match_mac_dst_i : entity work.MATCH_UNIT_WB
    generic map (
        DATA_WIDTH => 48,
        ADDR_WIDTH => 5
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        MATCH_DATA => ex_mac_dst,
        MATCH_ENA  => '1',
        MATCH_REQ  => parser_eop_vld,
        MATCH_BUSY => open,
        MATCH_ADDR => open,
        MATCH_HIT  => match_mac_dst_hit,
        MATCH_VLD  => match_mac_dst_vld,

        WB_CYC     => wb_mfs_cyc(1),
        WB_STB     => wb_mfs_stb(1),
        WB_WE      => wb_mfs_we(1),
        WB_ADDR    => wb_mfs_addr((1+1)*16-1 downto 1*16),
        WB_DIN     => wb_mfs_dout((1+1)*32-1 downto 1*32),
        WB_STALL   => wb_mfs_stall(1),
        WB_ACK     => wb_mfs_ack(1),
        WB_DOUT    => wb_mfs_din((1+1)*32-1 downto 1*32)
    );

    match_mac_src_i : entity work.MATCH_UNIT_WB
    generic map (
        DATA_WIDTH => 48,
        ADDR_WIDTH => 5
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        MATCH_DATA => ex_mac_src,
        MATCH_ENA  => '1',
        MATCH_REQ  => parser_eop_vld,
        MATCH_BUSY => open,
        MATCH_ADDR => open,
        MATCH_HIT  => match_mac_src_hit,
        MATCH_VLD  => match_mac_src_vld,

        WB_CYC     => wb_mfs_cyc(2),
        WB_STB     => wb_mfs_stb(2),
        WB_WE      => wb_mfs_we(2),
        WB_ADDR    => wb_mfs_addr((2+1)*16-1 downto 2*16),
        WB_DIN     => wb_mfs_dout((2+1)*32-1 downto 2*32),
        WB_STALL   => wb_mfs_stall(2),
        WB_ACK     => wb_mfs_ack(2),
        WB_DOUT    => wb_mfs_din((2+1)*32-1 downto 2*32)
    );

    match_ipv4_dst_i : entity work.MATCH_UNIT_WB
    generic map (
        DATA_WIDTH => 32,
        ADDR_WIDTH => 5
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        MATCH_DATA => ex_ipv4_dst,
        MATCH_ENA  => ex_ipv4_vld,
        MATCH_REQ  => parser_eop_vld,
        MATCH_BUSY => open,
        MATCH_ADDR => open,
        MATCH_HIT  => match_ipv4_dst_hit,
        MATCH_VLD  => match_ipv4_dst_vld,

        WB_CYC     => wb_mfs_cyc(3),
        WB_STB     => wb_mfs_stb(3),
        WB_WE      => wb_mfs_we(3),
        WB_ADDR    => wb_mfs_addr((3+1)*16-1 downto 3*16),
        WB_DIN     => wb_mfs_dout((3+1)*32-1 downto 3*32),
        WB_STALL   => wb_mfs_stall(3),
        WB_ACK     => wb_mfs_ack(3),
        WB_DOUT    => wb_mfs_din((3+1)*32-1 downto 3*32)
    );

    match_ipv4_src_i : entity work.MATCH_UNIT_WB
    generic map (
        DATA_WIDTH => 32,
        ADDR_WIDTH => 5
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        MATCH_DATA => ex_ipv4_src,
        MATCH_ENA  => ex_ipv4_vld,
        MATCH_REQ  => parser_eop_vld,
        MATCH_BUSY => open,
        MATCH_ADDR => open,
        MATCH_HIT  => match_ipv4_src_hit,
        MATCH_VLD  => match_ipv4_src_vld,

        WB_CYC     => wb_mfs_cyc(4),
        WB_STB     => wb_mfs_stb(4),
        WB_WE      => wb_mfs_we(4),
        WB_ADDR    => wb_mfs_addr((4+1)*16-1 downto 4*16),
        WB_DIN     => wb_mfs_dout((4+1)*32-1 downto 4*32),
        WB_STALL   => wb_mfs_stall(4),
        WB_ACK     => wb_mfs_ack(4),
        WB_DOUT    => wb_mfs_din((4+1)*32-1 downto 4*32)
    );

    match_ipv6_dst_i : entity work.MATCH_UNIT_WB
    generic map (
        DATA_WIDTH => 128,
        ADDR_WIDTH => 5
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        MATCH_DATA => ex_ipv6_dst,
        MATCH_ENA  => ex_ipv6_vld,
        MATCH_REQ  => parser_eop_vld,
        MATCH_BUSY => open,
        MATCH_ADDR => open,
        MATCH_HIT  => match_ipv6_dst_hit,
        MATCH_VLD  => match_ipv6_dst_vld,

        WB_CYC     => wb_mfs_cyc(5),
        WB_STB     => wb_mfs_stb(5),
        WB_WE      => wb_mfs_we(5),
        WB_ADDR    => wb_mfs_addr((5+1)*16-1 downto 5*16),
        WB_DIN     => wb_mfs_dout((5+1)*32-1 downto 5*32),
        WB_STALL   => wb_mfs_stall(5),
        WB_ACK     => wb_mfs_ack(5),
        WB_DOUT    => wb_mfs_din((5+1)*32-1 downto 5*32)
    );

    match_ipv6_src_i : entity work.MATCH_UNIT_WB
    generic map (
        DATA_WIDTH => 128,
        ADDR_WIDTH => 5
    )
    port map (
        CLK        => CLK,
        RST        => RST,

        MATCH_DATA => ex_ipv6_src,
        MATCH_ENA  => ex_ipv6_vld,
        MATCH_REQ  => parser_eop_vld,
        MATCH_BUSY => open,
        MATCH_ADDR => open,
        MATCH_HIT  => match_ipv6_src_hit,
        MATCH_VLD  => match_ipv6_src_vld,

        WB_CYC     => wb_mfs_cyc(6),
        WB_STB     => wb_mfs_stb(6),
        WB_WE      => wb_mfs_we(6),
        WB_ADDR    => wb_mfs_addr((6+1)*16-1 downto 6*16),
        WB_DIN     => wb_mfs_dout((6+1)*32-1 downto 6*32),
        WB_STALL   => wb_mfs_stall(6),
        WB_ACK     => wb_mfs_ack(6),
        WB_DOUT    => wb_mfs_din((6+1)*32-1 downto 6*32)
    );

    match_hit <= match_mac_dst_hit  or match_mac_src_hit  or
                 match_ipv4_dst_hit or match_ipv4_src_hit or
                 match_ipv6_dst_hit or match_ipv6_src_hit;
    match_vld <= match_ipv4_dst_vld;

    -- -------------------------------------------------------------------------
    --  ERASER MODULE
    -- -------------------------------------------------------------------------

    eraser_i : entity work.ERASER
    port map (
        CLK             => CLK,
        RST             => RST,

        RX_META_DISCARD => match_hit,
        RX_META_VLD     => match_vld,

        RX_DATA         => stfi_data,
        RX_SOP          => stfi_sop,
        RX_EOP          => stfi_eop,
        RX_VLD          => stfi_vld,
        RX_RDY          => stfi_rdy,

        TX_DATA         => eraser_data,
        TX_SOP          => eraser_sop,
        TX_EOP          => eraser_eop,
        TX_VLD          => eraser_vld,
        TX_RDY          => eraser_rdy
    );

    TX_DATA <= eraser_data;
    TX_SOP  <= eraser_sop;
    TX_EOP  <= eraser_eop;
    TX_VLD  <= eraser_vld;
    eraser_rdy <= TX_RDY;

    -- -------------------------------------------------------------------------
    --  STATISTICS COUNTERS
    -- -------------------------------------------------------------------------

    cnt_mac_dst_hit_en  <= match_mac_dst_vld  and match_mac_dst_hit;
    cnt_mac_src_hit_en  <= match_mac_src_vld  and match_mac_src_hit;
    cnt_ipv4_dst_hit_en <= match_ipv4_dst_vld and match_ipv4_dst_hit;
    cnt_ipv4_src_hit_en <= match_ipv4_src_vld and match_ipv4_src_hit;
    cnt_ipv6_dst_hit_en <= match_ipv6_dst_vld and match_ipv6_dst_hit;
    cnt_ipv6_src_hit_en <= match_ipv6_src_vld and match_ipv6_src_hit;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_pkt <= (others => '0');
            elsif (parser_eop_vld = '1') then
                cnt_pkt <= cnt_pkt + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_ipv4 <= (others => '0');
            elsif (parser_ipv4_vld = '1') then
                cnt_ipv4 <= cnt_ipv4 + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_ipv6 <= (others => '0');
            elsif (parser_eop_vld = '1' and ex_ipv6_vld = '1') then
                cnt_ipv6 <= cnt_ipv6 + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_mac_dst_hit <= (others => '0');
            elsif (cnt_mac_dst_hit_en = '1') then
                cnt_mac_dst_hit <= cnt_mac_dst_hit + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_mac_src_hit <= (others => '0');
            elsif (cnt_mac_src_hit_en = '1') then
                cnt_mac_src_hit <= cnt_mac_src_hit + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_ipv4_dst_hit <= (others => '0');
            elsif (cnt_ipv4_dst_hit_en = '1') then
                cnt_ipv4_dst_hit <= cnt_ipv4_dst_hit + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_ipv4_src_hit <= (others => '0');
            elsif (cnt_ipv4_src_hit_en = '1') then
                cnt_ipv4_src_hit <= cnt_ipv4_src_hit + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_ipv6_dst_hit <= (others => '0');
            elsif (cnt_ipv6_dst_hit_en = '1') then
                cnt_ipv6_dst_hit <= cnt_ipv6_dst_hit + 1;
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_cnt_clear = '1') then
                cnt_ipv6_src_hit <= (others => '0');
            elsif (cnt_ipv6_src_hit_en = '1') then
                cnt_ipv6_src_hit <= cnt_ipv6_src_hit + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  WISHBONE SLAVE LOGIC
    -- -------------------------------------------------------------------------

    cmd_sel <= '1' when (wb_mfs_addr(7 downto 0) = X"00") else '0';
    cmd_we  <= wb_mfs_stb(0) and wb_mfs_we(0) and cmd_sel;

    cmd_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            cmd_enable     <= '0';
            cmd_disable    <= '0';
            cmd_cnt_clear  <= '0';
            cmd_cnt_sample <= '0';
            if (cmd_we = '1' and wb_mfs_dout(7 downto 0) = X"00") then
                cmd_enable <= '1';
            end if;
            if (cmd_we = '1' and wb_mfs_dout(7 downto 0) = X"01") then
                cmd_disable <= '1';
            end if;
            if (cmd_we = '1' and wb_mfs_dout(7 downto 0) = X"02") then
                cmd_cnt_clear <= '1';
            end if;
            if (cmd_we = '1' and wb_mfs_dout(7 downto 0) = X"03") then
                cmd_cnt_sample <= '1';
            end if;
        end if;
    end process;

    disable_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or cmd_disable = '1') then
                disable_reg <= '0';
            elsif (cmd_enable = '1') then
                disable_reg <= '1';
            end if;
        end if;
    end process;

    cnt_sampled_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (cmd_cnt_sample = '1') then
                cnt_pkt_reg          <= std_logic_vector(cnt_pkt);
                cnt_ipv4_reg         <= std_logic_vector(cnt_ipv4);
                cnt_ipv6_reg         <= std_logic_vector(cnt_ipv6);
                cnt_mac_dst_hit_reg  <= std_logic_vector(cnt_mac_dst_hit);
                cnt_mac_src_hit_reg  <= std_logic_vector(cnt_mac_src_hit);
                cnt_ipv4_dst_hit_reg <= std_logic_vector(cnt_ipv4_dst_hit);
                cnt_ipv4_src_hit_reg <= std_logic_vector(cnt_ipv4_src_hit);
                cnt_ipv6_dst_hit_reg <= std_logic_vector(cnt_ipv6_dst_hit);
                cnt_ipv6_src_hit_reg <= std_logic_vector(cnt_ipv6_src_hit);
            end if;
        end if;
    end process;

    status_reg <= (others => '0');

    wb_mfs_stall(0) <= '0';

    wb_ack_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            wb_mfs_ack(0) <= wb_mfs_cyc(0) and wb_mfs_stb(0);
        end if;
    end process;

    wb_dout_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            case wb_mfs_addr(7 downto 0) is
                when X"00" =>
                    wb_mfs_din(31 downto 0) <= X"20191130"; -- version
                when X"04" =>
                    wb_mfs_din(31 downto 0) <= status_reg;
                when X"10" =>
                    wb_mfs_din(31 downto 0) <= cnt_pkt_reg;
                when X"14" =>
                    wb_mfs_din(31 downto 0) <= cnt_ipv4_reg;
                when X"18" =>
                    wb_mfs_din(31 downto 0) <= cnt_ipv6_reg;
                when X"20" =>
                    wb_mfs_din(31 downto 0) <= cnt_mac_dst_hit_reg;
                when X"24" =>
                    wb_mfs_din(31 downto 0) <= cnt_mac_src_hit_reg;
                when X"28" =>
                    wb_mfs_din(31 downto 0) <= cnt_ipv4_dst_hit_reg;
                when X"2C" =>
                    wb_mfs_din(31 downto 0) <= cnt_ipv4_src_hit_reg;
                when X"30" =>
                    wb_mfs_din(31 downto 0) <= cnt_ipv6_dst_hit_reg;
                when X"34" =>
                    wb_mfs_din(31 downto 0) <= cnt_ipv6_src_hit_reg;
                when others =>
                    wb_mfs_din(31 downto 0) <= X"DEADCAFE";
            end case;
        end if;
    end process;

end architecture;
