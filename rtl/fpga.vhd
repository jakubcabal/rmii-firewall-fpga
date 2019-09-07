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
        CLK_12M   : in  std_logic;
        RST_BTN_N : in  std_logic;
        UART_RXD  : in  std_logic;
        UART_TXD  : out std_logic
    );
end entity;

architecture FULL of FPGA is

    signal reset : std_logic;

    signal wb_master_cyc   : std_logic;
    signal wb_master_stb   : std_logic;
    signal wb_master_we    : std_logic;
    signal wb_master_addr  : std_logic_vector(15 downto 0);
    signal wb_master_dout  : std_logic_vector(31 downto 0);
    signal wb_master_stall : std_logic;
    signal wb_master_ack   : std_logic;
    signal wb_master_din   : std_logic_vector(31 downto 0);

    signal debug_reg_sel : std_logic;
    signal debug_reg_we  : std_logic;
    signal debug_reg     : std_logic_vector(31 downto 0);

begin

    reset <= not RST_BTN_N;

	uart2wbm_i: entity work.UART2WBM
    generic map (
        CLK_FREQ  => 12e6,
        BAUD_RATE => 9600
    )
    port map (
        CLK      => CLK,
        RST      => reset,
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

    debug_reg_sel <= '1' when (wb_master_addr = X"0004") else '0';
    debug_reg_we  <= wb_master_stb and wb_master_we and debug_reg_sel;

    debug_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (debug_reg_we = '1') then
                debug_reg <= wb_master_dout;
            end if;
        end if;
    end process;

    wb_master_stall <= '0';

    wb_master_ack_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            wb_master_ack <= wb_master_cyc and wb_master_stb;
        end if;
    end process;

    wb_master_din_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            case wb_master_addr is
                when X"0000" =>
                    wb_master_din <= X"20190907";
                when X"0004" =>
                    wb_master_din <= debug_reg;
                when others =>
                    wb_master_din <= X"DEADCAFE";
            end case;
        end if;
    end process;

end architecture;
