#-------------------------------------------------------------------------------
# PROJECT: RMII FIREWALL FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

create_clock -name CLK12M -period 12MHz [get_ports {CLK_12M}]
create_clock -name ETH0_CLK -period 50MHz [get_ports {ETH0_CLK}]
derive_pll_clocks
