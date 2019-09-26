--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RST_SYNC is
    Port (
        CLK        : in  std_logic;
        ASYNC_RST  : in  std_logic;
        SYNCED_RST : out std_logic
    );
end entity;

architecture RTL of RST_SYNC is

    signal meta_reg  : std_logic;
    signal reset_reg : std_logic;

begin

    process (CLK, ASYNC_RST)
    begin
        if (ASYNC_RST = '1') then
            meta_reg  <= '1';
            reset_reg <= '1';
        elsif (rising_edge(CLK)) then
            meta_reg  <= '0';
            reset_reg <= meta_reg;
        end if;
    end process;

    SYNCED_RST <= reset_reg;

end architecture;
