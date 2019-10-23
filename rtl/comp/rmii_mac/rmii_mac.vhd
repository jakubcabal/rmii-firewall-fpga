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

entity RMII_MAC is
    Port (
        -- CLOCKS AND RESETS
        RMII_CLK    : in  std_logic;
        RMII_RST    : in  std_logic;
        USER_CLK    : in  std_logic;
        USER_RST    : in  std_logic;

        -- RMII INTERFACE (RMII_CLK)
        RMII_RXD    : in  std_logic_vector(1 downto 0);
        RMII_CSR_DV : in  std_logic;
        RMII_TXD    : out std_logic_vector(1 downto 0);
        RMII_TX_EN  : out std_logic;

        -- USER OUTPUT STREAM INTERFACE (USER_CLK)
        TX_DATA     : out std_logic_vector(7 downto 0);
        TX_SOP      : out std_logic;
        TX_EOP      : out std_logic;
        TX_VLD      : out std_logic;
        TX_RDY      : in  std_logic;

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

architecture RTL of RMII_MAC is

    constant WB_PORTS : natural := 2;

    signal split_wb_cyc   : std_logic_vector(WB_PORTS-1 downto 0);
    signal split_wb_stb   : std_logic_vector(WB_PORTS-1 downto 0);
    signal split_wb_we    : std_logic_vector(WB_PORTS-1 downto 0);
    signal split_wb_addr  : std_logic_vector(WB_PORTS*16-1 downto 0);
    signal split_wb_din   : std_logic_vector(WB_PORTS*32-1 downto 0);
    signal split_wb_stall : std_logic_vector(WB_PORTS-1 downto 0);
    signal split_wb_ack   : std_logic_vector(WB_PORTS-1 downto 0);
    signal split_wb_dout  : std_logic_vector(WB_PORTS*32-1 downto 0);

begin

    rx_i : entity work.RX_RMII_MAC
    port map (
        RMII_CLK    => RMII_CLK,
        RMII_RST    => RMII_RST,
        USER_CLK    => USER_CLK,
        USER_RST    => USER_RST,

        RMII_RXD    => RMII_RXD,
        RMII_CSR_DV => RMII_CSR_DV,

        TX_DATA     => TX_DATA,
        TX_SOP      => TX_SOP,
        TX_EOP      => TX_EOP,
        TX_VLD      => TX_VLD,
        TX_RDY      => TX_RDY,

        WB_CYC      => split_wb_cyc(0),
        WB_STB      => split_wb_stb(0),
        WB_WE       => split_wb_we(0),
        WB_ADDR     => split_wb_addr(16-1 downto 0),
        WB_DIN      => split_wb_din(32-1 downto 0),
        WB_STALL    => split_wb_stall(0),
        WB_ACK      => split_wb_ack(0),
        WB_DOUT     => split_wb_dout(32-1 downto 0)
    );

    tx_i : entity work.TX_RMII_MAC
    port map (
        RMII_CLK    => RMII_CLK,
        RMII_RST    => RMII_RST,
        USER_CLK    => USER_CLK,
        USER_RST    => USER_RST,

        RMII_TXD    => RMII_TXD,
        RMII_TX_EN  => RMII_TX_EN,

        RX_DATA     => RX_DATA,
        RX_SOP      => RX_SOP,
        RX_EOP      => RX_EOP,
        RX_VLD      => RX_VLD,
        RX_RDY      => RX_RDY,

        WB_CYC      => split_wb_cyc(1),
        WB_STB      => split_wb_stb(1),
        WB_WE       => split_wb_we(1),
        WB_ADDR     => split_wb_addr(32-1 downto 16),
        WB_DIN      => split_wb_din(64-1 downto 32),
        WB_STALL    => split_wb_stall(1),
        WB_ACK      => split_wb_ack(1),
        WB_DOUT     => split_wb_dout(64-1 downto 32)
    );

    wb_splitter_i : entity work.WB_SPLITTER
    generic map (
        MASTER_PORTS => WB_PORTS,
        ADDR_OFFSET  => 8
    )
    port map (
        CLK        => USER_CLK,
        RST        => USER_RST,

        WB_S_CYC   => WB_CYC,
        WB_S_STB   => WB_STB,
        WB_S_WE    => WB_WE,
        WB_S_ADDR  => WB_ADDR,
        WB_S_DIN   => WB_DIN,
        WB_S_STALL => WB_STALL,
        WB_S_ACK   => WB_ACK,
        WB_S_DOUT  => WB_DOUT,

        WB_M_CYC   => split_wb_cyc,
        WB_M_STB   => split_wb_stb,
        WB_M_WE    => split_wb_we,
        WB_M_ADDR  => split_wb_addr,
        WB_M_DOUT  => split_wb_din,
        WB_M_STALL => split_wb_stall,
        WB_M_ACK   => split_wb_ack,
        WB_M_DIN   => split_wb_dout
    );

end architecture;
