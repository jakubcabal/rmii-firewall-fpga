--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FIFO is
    Generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 4
    );
    Port (
        CLK         : in  std_logic;
        RST         : in  std_logic;
        -- FIFO WRITE INTERFACE
        WR_DATA     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        WR_REQ      : in  std_logic;
        WR_FULL     : out std_logic;
        -- FIFO READ INTERFACE
        RD_DATA     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        RD_DATA_VLD : out std_logic;
        RD_REQ      : in  std_logic;
        -- FIFO STATUS SIGNAL
        STATUS      : out std_logic_vector(ADDR_WIDTH-1 downto 0)
    );
end entity;

architecture RTL of FIFO is

begin

    fifo_mark_i : entity work.FIFO_MARK
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        ADDR_WIDTH => ADDR_WIDTH
    )
    port map (
        CLK         => CLK,
        RST         => RST,
        -- FIFO WRITE INTERFACE
        WR_DATA     => WR_DATA,
        WR_REQ      => WR_REQ,
        WR_FULL     => WR_FULL,
        -- FIFO READ INTERFACE
        RD_DATA     => RD_DATA,
        RD_DATA_VLD => RD_DATA_VLD,
        RD_REQ      => RD_REQ,
        -- FIFO OTHERS SIGNALS
        MARK        => '1',
        DISCARD     => '0',
        STATUS      => STATUS
    );

end architecture;
