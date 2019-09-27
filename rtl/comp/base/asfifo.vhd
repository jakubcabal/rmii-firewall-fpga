--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

LIBRARY altera_mf;
USE altera_mf.all;

entity ASFIFO is
    Generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 4
    );
    Port (
        -- FIFO WRITE INTERFACE
        WR_CLK      : in  std_logic;
        WR_RST      : in  std_logic;
        WR_DATA     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        WR_REQ      : in  std_logic;
        WR_FULL     : out std_logic;
        -- FIFO READ INTERFACE
        RD_CLK      : in  std_logic;
        RD_RST      : in  std_logic;
        RD_DATA     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        RD_DATA_VLD : out std_logic;
        RD_REQ      : in  std_logic
    );
end entity;

architecture RTL of ASFIFO is

    component dcfifo
    generic (
        intended_device_family : string;
        lpm_numwords           : natural;
        lpm_showahead          : string;
        lpm_type               : string;
        lpm_width              : natural;
        lpm_widthu             : natural;
        overflow_checking      : string;
        rdsync_delaypipe       : natural;
        read_aclr_synch        : string;
        underflow_checking     : string;
        use_eab                : string;
        write_aclr_synch       : string;
        wrsync_delaypipe       : natural
    );
    port (
        aclr	: in  std_logic;
        data	: in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rdclk	: in  std_logic;
        rdreq	: in  std_logic;
        wrclk	: in  std_logic;
        wrreq	: in  std_logic;
        q	    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        rdempty	: out std_logic;
        wrfull	: out std_logic 
    );
    end component;

    attribute ALTERA_ATTRIBUTE : string;

    signal fifo_aclr     : std_logic;
    signal rd_data_vld_n : std_logic;

    attribute ALTERA_ATTRIBUTE of RTL : architecture is "-name SDC_STATEMENT ""set_false_path -through [get_nets *fifo_aclr]""";

begin

    fifo_aclr <= WR_RST or RD_RST;

    dcfifo_i : dcfifo
    GENERIC MAP (
        intended_device_family => "Cyclone 10 LP",
        lpm_numwords           => 2**ADDR_WIDTH,
        lpm_showahead          => "ON",
        lpm_type               => "dcfifo",
        lpm_width              => DATA_WIDTH,
        lpm_widthu             => ADDR_WIDTH,
        overflow_checking      => "ON",
        rdsync_delaypipe       => 4,
        read_aclr_synch        => "ON",
        underflow_checking     => "ON",
        use_eab                => "ON",
        write_aclr_synch       => "ON",
        wrsync_delaypipe       => 4
    )
    PORT MAP (
        aclr    => fifo_aclr,
        data    => WR_DATA,
        rdclk   => RD_CLK,
        rdreq   => RD_REQ,
        wrclk   => WR_CLK,
        wrreq   => WR_REQ,
        q       => RD_DATA,
        rdempty => rd_data_vld_n,
        wrfull  => WR_FULL
    );

    RD_DATA_VLD <= not rd_data_vld_n;

end architecture;
