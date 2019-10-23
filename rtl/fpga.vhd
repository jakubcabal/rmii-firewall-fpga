--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FPGA is
    Port (
        -- System clock and reset button
        CLK_12M     : in  std_logic;
        RST_BTN_N   : in  std_logic;
        -- Ethernet port 0 (RMII interface)
        ETH0_CLK    : in  std_logic;
        ETH0_RXD    : in  std_logic_vector(1 downto 0);
        ETH0_CSR_DV : in  std_logic;
        ETH0_TXD    : out std_logic_vector(1 downto 0);
        ETH0_TX_EN  : out std_logic;
        -- Ethernet port 1 (RMII interface)
        ETH1_CLK    : in  std_logic;
        ETH1_RXD    : in  std_logic_vector(1 downto 0);
        ETH1_CSR_DV : in  std_logic;
        ETH1_TXD    : out std_logic_vector(1 downto 0);
        ETH1_TX_EN  : out std_logic;
        -- UART interface
        UART_RXD    : in  std_logic;
        UART_TXD    : out std_logic
    );
end entity;

architecture FULL of FPGA is

    constant WB_BASE_PORTS  : natural := 4;  -- system, eth, app, reserved
    constant WB_BASE_OFFSET : natural := 14;
    constant WB_ETH_PORTS   : natural := 2;  -- eth0, eth1
    constant WB_ETH_OFFSET  : natural := 13;

    signal rst_btn : std_logic;

    signal pll_locked   : std_logic;
    signal pll_locked_n : std_logic;

    signal clk_usr  : std_logic;
    signal rst_usr  : std_logic;
    signal rst_eth0 : std_logic;
    signal rst_eth1 : std_logic;

    signal wb_master_cyc   : std_logic;
    signal wb_master_stb   : std_logic;
    signal wb_master_we    : std_logic;
    signal wb_master_addr  : std_logic_vector(15 downto 0);
    signal wb_master_dout  : std_logic_vector(31 downto 0);
    signal wb_master_stall : std_logic;
    signal wb_master_ack   : std_logic;
    signal wb_master_din   : std_logic_vector(31 downto 0);

    signal wb_mbs_cyc   : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_stb   : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_we    : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_addr  : std_logic_vector(WB_BASE_PORTS*16-1 downto 0);
    signal wb_mbs_din   : std_logic_vector(WB_BASE_PORTS*32-1 downto 0);
    signal wb_mbs_stall : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_ack   : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_dout  : std_logic_vector(WB_BASE_PORTS*32-1 downto 0);

    signal wb_mes_cyc   : std_logic_vector(WB_ETH_PORTS-1 downto 0);
    signal wb_mes_stb   : std_logic_vector(WB_ETH_PORTS-1 downto 0);
    signal wb_mes_we    : std_logic_vector(WB_ETH_PORTS-1 downto 0);
    signal wb_mes_addr  : std_logic_vector(WB_ETH_PORTS*16-1 downto 0);
    signal wb_mes_din   : std_logic_vector(WB_ETH_PORTS*32-1 downto 0);
    signal wb_mes_stall : std_logic_vector(WB_ETH_PORTS-1 downto 0);
    signal wb_mes_ack   : std_logic_vector(WB_ETH_PORTS-1 downto 0);
    signal wb_mes_dout  : std_logic_vector(WB_ETH_PORTS*32-1 downto 0);

    signal eth01_data : std_logic_vector(7 downto 0);
    signal eth01_sop  : std_logic;
    signal eth01_eop  : std_logic;
    signal eth01_vld  : std_logic;
    signal eth01_rdy  : std_logic;

    signal eth10_data : std_logic_vector(7 downto 0);
    signal eth10_sop  : std_logic;
    signal eth10_eop  : std_logic;
    signal eth10_vld  : std_logic;
    signal eth10_rdy  : std_logic;

begin

    rst_btn <= not RST_BTN_N;

    pll_i : entity work.PLL
    port map (
        IN_CLK_12M     => CLK_12M,
        IN_RST_BTN     => rst_btn,
        OUT_PLL_LOCKED => pll_locked,
        OUT_CLK_25M    => clk_usr,
        OUT_CLK_50M    => open
    );

    pll_locked_n <= not pll_locked;

    rst_usr_sync_i : entity work.RST_SYNC
    port map (
        CLK        => clk_usr,
        ASYNC_RST  => pll_locked_n,
        SYNCED_RST => rst_usr
    );

    rst_eth0_sync_i : entity work.RST_SYNC
    port map (
        CLK        => ETH0_CLK,
        ASYNC_RST  => pll_locked_n,
        SYNCED_RST => rst_eth0
    );

    rst_eth1_sync_i : entity work.RST_SYNC
    port map (
        CLK        => ETH1_CLK,
        ASYNC_RST  => pll_locked_n,
        SYNCED_RST => rst_eth1
    );

    uart2wbm_i : entity work.UART2WBM
    generic map (
        CLK_FREQ  => 25e6,
        BAUD_RATE => 9600
    )
    port map (
        CLK      => clk_usr,
        RST      => rst_usr,
        -- UART INTERFACE
        UART_TXD => UART_TXD,
        UART_RXD => UART_RXD,
        -- WISHBONE MASTER INTERFACE
        WB_CYC   => wb_master_cyc,
        WB_STB   => wb_master_stb,
        WB_WE    => wb_master_we,
        WB_ADDR  => wb_master_addr,
        WB_DOUT  => wb_master_dout,
        WB_STALL => wb_master_stall,
        WB_ACK   => wb_master_ack,
        WB_DIN   => wb_master_din
    );

    wb_splitter_base_i : entity work.WB_SPLITTER
    generic map (
        MASTER_PORTS => WB_BASE_PORTS,
        ADDR_OFFSET  => WB_BASE_OFFSET
    )
    port map (
        CLK        => clk_usr,
        RST        => rst_usr,

        WB_S_CYC   => wb_master_cyc,
        WB_S_STB   => wb_master_stb,
        WB_S_WE    => wb_master_we,
        WB_S_ADDR  => wb_master_addr,
        WB_S_DIN   => wb_master_dout,
        WB_S_STALL => wb_master_stall,
        WB_S_ACK   => wb_master_ack,
        WB_S_DOUT  => wb_master_din,

        WB_M_CYC   => wb_mbs_cyc,
        WB_M_STB   => wb_mbs_stb,
        WB_M_WE    => wb_mbs_we,
        WB_M_ADDR  => wb_mbs_addr,
        WB_M_DOUT  => wb_mbs_dout,
        WB_M_STALL => wb_mbs_stall,
        WB_M_ACK   => wb_mbs_ack,
        WB_M_DIN   => wb_mbs_din
    );

    sys_module_i : entity work.SYS_MODULE
    port map (
        -- CLOCK AND RESET
        CLK      => clk_usr,
        RST      => rst_usr,

        -- WISHBONE SLAVE INTERFACE
        WB_CYC   => wb_mbs_cyc(0),
        WB_STB   => wb_mbs_stb(0),
        WB_WE    => wb_mbs_we(0),
        WB_ADDR  => wb_mbs_addr((0+1)*16-1 downto 0*16),
        WB_DIN   => wb_mbs_dout((0+1)*32-1 downto 0*32),
        WB_STALL => wb_mbs_stall(0),
        WB_ACK   => wb_mbs_ack(0),
        WB_DOUT  => wb_mbs_din((0+1)*32-1 downto 0*32)
    );

    wb_splitter_eth_i : entity work.WB_SPLITTER
    generic map (
        MASTER_PORTS => WB_ETH_PORTS,
        ADDR_OFFSET  => WB_ETH_OFFSET
    )
    port map (
        CLK        => clk_usr,
        RST        => rst_usr,

        WB_S_CYC   => wb_mbs_cyc(1),
        WB_S_STB   => wb_mbs_stb(1),
        WB_S_WE    => wb_mbs_we(1),
        WB_S_ADDR  => wb_mbs_addr((1+1)*16-1 downto 1*16),
        WB_S_DIN   => wb_mbs_dout((1+1)*32-1 downto 1*32),
        WB_S_STALL => wb_mbs_stall(1),
        WB_S_ACK   => wb_mbs_ack(1),
        WB_S_DOUT  => wb_mbs_din((1+1)*32-1 downto 1*32),

        WB_M_CYC   => wb_mes_cyc,
        WB_M_STB   => wb_mes_stb,
        WB_M_WE    => wb_mes_we,
        WB_M_ADDR  => wb_mes_addr,
        WB_M_DOUT  => wb_mes_dout,
        WB_M_STALL => wb_mes_stall,
        WB_M_ACK   => wb_mes_ack,
        WB_M_DIN   => wb_mes_din
    );

    eth0_mac_i : entity work.RMII_MAC
    port map (
        -- CLOCKS AND RESETS
        RMII_CLK => ETH0_CLK,
        RMII_RST => rst_eth0,
        USER_CLK => clk_usr,
        USER_RST => rst_usr,

        -- RMII INTERFACE (RMII_CLK)
        RMII_RXD    => ETH0_RXD,
        RMII_CSR_DV => ETH0_CSR_DV,
        RMII_TXD    => ETH0_TXD,
        RMII_TX_EN  => ETH0_TX_EN,

        -- USER OUTPUT STREAM INTERFACE (USER_CLK)
        TX_DATA => eth01_data,
        TX_SOP  => eth01_sop,
        TX_EOP  => eth01_eop,
        TX_VLD  => eth01_vld,
        TX_RDY  => eth01_rdy,

        -- USER INPUT STREAM INTERFACE (USER_CLK)
        RX_DATA => eth10_data,
        RX_SOP  => eth10_sop,
        RX_EOP  => eth10_eop,
        RX_VLD  => eth10_vld,
        RX_RDY  => eth10_rdy,

        -- WISHBONE SLAVE INTERFACE (USER_CLK)
        WB_CYC   => wb_mes_cyc(0),
        WB_STB   => wb_mes_stb(0),
        WB_WE    => wb_mes_we(0),
        WB_ADDR  => wb_mes_addr((0+1)*16-1 downto 0*16),
        WB_DIN   => wb_mes_dout((0+1)*32-1 downto 0*32),
        WB_STALL => wb_mes_stall(0),
        WB_ACK   => wb_mes_ack(0),
        WB_DOUT  => wb_mes_din((0+1)*32-1 downto 0*32)
    );

    eth1_mac_i : entity work.RMII_MAC
    port map (
        -- CLOCKS AND RESETS
        RMII_CLK => ETH1_CLK,
        RMII_RST => rst_eth1,
        USER_CLK => clk_usr,
        USER_RST => rst_usr,

        -- RMII INTERFACE (RMII_CLK)
        RMII_RXD    => ETH1_RXD,
        RMII_CSR_DV => ETH1_CSR_DV,
        RMII_TXD    => ETH1_TXD,
        RMII_TX_EN  => ETH1_TX_EN,

        -- USER OUTPUT STREAM INTERFACE (USER_CLK)
        TX_DATA => eth10_data,
        TX_SOP  => eth10_sop,
        TX_EOP  => eth10_eop,
        TX_VLD  => eth10_vld,
        TX_RDY  => eth10_rdy,

        -- USER INPUT STREAM INTERFACE (USER_CLK)
        RX_DATA => eth01_data,
        RX_SOP  => eth01_sop,
        RX_EOP  => eth01_eop,
        RX_VLD  => eth01_vld,
        RX_RDY  => eth01_rdy,

        -- WISHBONE SLAVE INTERFACE (USER_CLK)
        WB_CYC   => wb_mes_cyc(1),
        WB_STB   => wb_mes_stb(1),
        WB_WE    => wb_mes_we(1),
        WB_ADDR  => wb_mes_addr((1+1)*16-1 downto 1*16),
        WB_DIN   => wb_mes_dout((1+1)*32-1 downto 1*32),
        WB_STALL => wb_mes_stall(1),
        WB_ACK   => wb_mes_ack(1),
        WB_DOUT  => wb_mes_din((1+1)*32-1 downto 1*32)
    );

end architecture;
