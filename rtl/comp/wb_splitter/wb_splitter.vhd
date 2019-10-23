--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity WB_SPLITTER is
    Generic (
        MASTER_PORTS : natural := 2;
        ADDR_OFFSET  : natural := 8
    );
    Port (
        -- CLOCK AND RESET
        CLK        : in  std_logic;
        RST        : in  std_logic;

        -- WISHBONE SLAVE INTERFACE
        WB_S_CYC   : in  std_logic;
        WB_S_STB   : in  std_logic;
        WB_S_WE    : in  std_logic;
        WB_S_ADDR  : in  std_logic_vector(15 downto 0);
        WB_S_DIN   : in  std_logic_vector(31 downto 0);
        WB_S_STALL : out std_logic;
        WB_S_ACK   : out std_logic;
        WB_S_DOUT  : out std_logic_vector(31 downto 0);

        -- WISHBONE MASTER INTERFACES
        WB_M_CYC   : out std_logic_vector(MASTER_PORTS-1 downto 0);
        WB_M_STB   : out std_logic_vector(MASTER_PORTS-1 downto 0);
        WB_M_WE    : out std_logic_vector(MASTER_PORTS-1 downto 0);
        WB_M_ADDR  : out std_logic_vector(MASTER_PORTS*16-1 downto 0);
        WB_M_DOUT  : out std_logic_vector(MASTER_PORTS*32-1 downto 0);
        WB_M_STALL : in  std_logic_vector(MASTER_PORTS-1 downto 0);
        WB_M_ACK   : in  std_logic_vector(MASTER_PORTS-1 downto 0);
        WB_M_DIN   : in  std_logic_vector(MASTER_PORTS*32-1 downto 0)
    );
end entity;

architecture RTL of WB_SPLITTER is

    constant PORT_SEL_W  : natural := integer(ceil(log2(real(MASTER_PORTS))));
    constant WB_ADDR_GND : std_logic_vector(16-ADDR_OFFSET-1 downto 0) := (others => '0');

    signal wb_port_sel_bin : std_logic_vector(PORT_SEL_W-1 downto 0);
    signal wb_port_sel     : std_logic_vector(MASTER_PORTS-1 downto 0);

begin

    wb_port_sel_bin <= WB_S_ADDR(PORT_SEL_W+ADDR_OFFSET-1 downto ADDR_OFFSET);

    process (wb_port_sel_bin)
    begin
        wb_port_sel <= (others => '0');
        for i in 0 to MASTER_PORTS-1 loop
            if (unsigned(wb_port_sel_bin) = i) then
                wb_port_sel(i) <= '1';
                exit;
            end if;
        end loop;
    end process;

    req_g : for i in 0 to MASTER_PORTS-1 generate
        WB_M_CYC(i) <= WB_S_CYC and wb_port_sel(i);
        WB_M_STB(i) <= WB_S_STB and wb_port_sel(i);
        WB_M_WE(i)  <= WB_S_WE and wb_port_sel(i);
        WB_M_ADDR((i+1)*16-1 downto i*16) <= WB_ADDR_GND & WB_S_ADDR(ADDR_OFFSET-1 downto 0);
        WB_M_DOUT((i+1)*32-1 downto i*32) <= WB_S_DIN;
    end generate;

    process (WB_M_STALL)
    begin
        WB_S_STALL <= '0';
        for i in 0 to MASTER_PORTS-1 loop
            if (WB_M_STALL(i) = '1') then
                WB_S_STALL <= '1';
            end if;
        end loop;
    end process;

    process (WB_M_ACK,WB_M_DIN)
    begin
        WB_S_ACK  <= '0';
        WB_S_DOUT <= WB_M_DIN(32-1 downto 0);
        for i in 0 to MASTER_PORTS-1 loop
            if (WB_M_ACK(i) = '1') then
                WB_S_ACK  <= '1';
                WB_S_DOUT <= WB_M_DIN((i+1)*32-1 downto i*32);
            end if;
        end loop;
    end process;

end architecture;
