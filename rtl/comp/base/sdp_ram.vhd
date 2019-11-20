--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SDP_RAM is
    Generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 4
    );
    Port (
        CLK         : in  std_logic;
        RST         : in  std_logic;
        -- WRITE INTERFACE
        WR_DATA     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        WR_ADDR     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        WR_REQ      : in  std_logic;
        -- READ INTERFACE
        RD_ADDR     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        RD_REQ      : in  std_logic;
        RD_DATA     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        RD_DATA_VLD : out std_logic
    );
end entity;

architecture RTL of SDP_RAM is

    type bram_type is array(2**ADDR_WIDTH-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal bram : bram_type := (others => (others => '0'));

begin

    bram_wr_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (WR_REQ = '1') then
                bram(to_integer(unsigned(WR_ADDR))) <= WR_DATA;
            end if;
        end if;
    end process;

    bram_rd_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RD_REQ = '1') then
                RD_DATA <= bram(to_integer(unsigned(RD_ADDR)));
            end if;
        end if;
    end process;

    rd_data_vld_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            RD_DATA_VLD <= RD_REQ;
        end if;
    end process;

end architecture;
