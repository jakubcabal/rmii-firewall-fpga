--------------------------------------------------------------------------------
-- PROJECT: RMII FIREWALL FPGA
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SYS_MODULE is
    Port (
        -- CLOCK AND RESET
        CLK      : in  std_logic;
        RST      : in  std_logic;

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

architecture RTL of SYS_MODULE is

    signal debug_reg_sel : std_logic;
    signal debug_reg_we  : std_logic;
    signal debug_reg     : std_logic_vector(31 downto 0);

begin

    debug_reg_sel <= '1' when (WB_ADDR = X"0004") else '0';
    debug_reg_we  <= WB_STB and WB_WE and debug_reg_sel;

    debug_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (debug_reg_we = '1') then
                debug_reg <= WB_DIN;
            end if;
        end if;
    end process;

    WB_STALL <= '0';

    wb_ack_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            WB_ACK <= WB_CYC and WB_STB;
        end if;
    end process;

    wb_dout_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            case WB_ADDR is
                when X"0000" =>
                    WB_DOUT <= X"20191023";
                when X"0004" =>
                    WB_DOUT <= debug_reg;
                when others =>
                    WB_DOUT <= X"DEADCAFE";
            end case;
        end if;
    end process;

end architecture;
