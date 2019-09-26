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

entity PLL is
    Port (
        IN_CLK_12M     : in  std_logic;
        IN_RST_BTN     : in  std_logic;
        OUT_PLL_LOCKED : out std_logic;
        OUT_CLK_25M    : out std_logic;
        OUT_CLK_50M    : out std_logic
    );
end entity;

architecture RTL of PLL is

    component altpll
    generic (
        bandwidth_type		: string;
        clk0_divide_by		: natural;
        clk0_duty_cycle		: natural;
        clk0_multiply_by		: natural;
        clk0_phase_shift		: string;
        clk1_divide_by		: natural;
        clk1_duty_cycle		: natural;
        clk1_multiply_by		: natural;
        clk1_phase_shift		: string;
        compensate_clock		: string;
        inclk0_input_frequency		: natural;
        intended_device_family		: string;
        lpm_hint		: string;
        lpm_type		: string;
        operation_mode		: string;
        pll_type		: string;
        port_activeclock		: string;
        port_areset		: string;
        port_clkbad0		: string;
        port_clkbad1		: string;
        port_clkloss		: string;
        port_clkswitch		: string;
        port_configupdate		: string;
        port_fbin		: string;
        port_inclk0		: string;
        port_inclk1		: string;
        port_locked		: string;
        port_pfdena		: string;
        port_phasecounterselect		: string;
        port_phasedone		: string;
        port_phasestep		: string;
        port_phaseupdown		: string;
        port_pllena		: string;
        port_scanaclr		: string;
        port_scanclk		: string;
        port_scanclkena		: string;
        port_scandata		: string;
        port_scandataout		: string;
        port_scandone		: string;
        port_scanread		: string;
        port_scanwrite		: string;
        port_clk0		: string;
        port_clk1		: string;
        port_clk2		: string;
        port_clk3		: string;
        port_clk4		: string;
        port_clk5		: string;
        port_clkena0		: string;
        port_clkena1		: string;
        port_clkena2		: string;
        port_clkena3		: string;
        port_clkena4		: string;
        port_clkena5		: string;
        port_extclk0		: string;
        port_extclk1		: string;
        port_extclk2		: string;
        port_extclk3		: string;
        self_reset_on_loss_lock		: string;
        width_clock		: natural
    );
    port (
            areset : in  std_logic;
            inclk  : in  std_logic_vector(1 downto 0);
            clk    : out std_logic_vector(4 downto 0);
            locked : out std_logic 
    );
    end component;

    signal pll_in_clk  : std_logic_vector(1 downto 0);
    signal pll_out_clk : std_logic_vector(4 downto 0);

begin

    pll_in_clk <= '0' & IN_CLK_12M;

    altpll_i : altpll
    generic map (
        bandwidth_type => "AUTO",
        clk0_divide_by => 12,
        clk0_duty_cycle => 50,
        clk0_multiply_by => 25,
        clk0_phase_shift => "0",
        clk1_divide_by => 6,
        clk1_duty_cycle => 50,
        clk1_multiply_by => 25,
        clk1_phase_shift => "0",
        compensate_clock => "CLK0",
        inclk0_input_frequency => 83333,
        intended_device_family => "Cyclone 10 LP",
        lpm_hint => "CBX_MODULE_PREFIX=pll",
        lpm_type => "altpll",
        operation_mode => "NORMAL",
        pll_type => "AUTO",
        port_activeclock => "PORT_UNUSED",
        port_areset => "PORT_USED",
        port_clkbad0 => "PORT_UNUSED",
        port_clkbad1 => "PORT_UNUSED",
        port_clkloss => "PORT_UNUSED",
        port_clkswitch => "PORT_UNUSED",
        port_configupdate => "PORT_UNUSED",
        port_fbin => "PORT_UNUSED",
        port_inclk0 => "PORT_USED",
        port_inclk1 => "PORT_UNUSED",
        port_locked => "PORT_USED",
        port_pfdena => "PORT_UNUSED",
        port_phasecounterselect => "PORT_UNUSED",
        port_phasedone => "PORT_UNUSED",
        port_phasestep => "PORT_UNUSED",
        port_phaseupdown => "PORT_UNUSED",
        port_pllena => "PORT_UNUSED",
        port_scanaclr => "PORT_UNUSED",
        port_scanclk => "PORT_UNUSED",
        port_scanclkena => "PORT_UNUSED",
        port_scandata => "PORT_UNUSED",
        port_scandataout => "PORT_UNUSED",
        port_scandone => "PORT_UNUSED",
        port_scanread => "PORT_UNUSED",
        port_scanwrite => "PORT_UNUSED",
        port_clk0 => "PORT_USED",
        port_clk1 => "PORT_USED",
        port_clk2 => "PORT_UNUSED",
        port_clk3 => "PORT_UNUSED",
        port_clk4 => "PORT_UNUSED",
        port_clk5 => "PORT_UNUSED",
        port_clkena0 => "PORT_UNUSED",
        port_clkena1 => "PORT_UNUSED",
        port_clkena2 => "PORT_UNUSED",
        port_clkena3 => "PORT_UNUSED",
        port_clkena4 => "PORT_UNUSED",
        port_clkena5 => "PORT_UNUSED",
        port_extclk0 => "PORT_UNUSED",
        port_extclk1 => "PORT_UNUSED",
        port_extclk2 => "PORT_UNUSED",
        port_extclk3 => "PORT_UNUSED",
        self_reset_on_loss_lock => "OFF",
        width_clock => 5
    )
    port map (
        areset => IN_RST_BTN,
        inclk  => pll_in_clk,
        clk    => pll_out_clk,
        locked => OUT_PLL_LOCKED
    );

    OUT_CLK_25M <= pll_out_clk(0);
    OUT_CLK_50M <= pll_out_clk(1);

end architecture;
