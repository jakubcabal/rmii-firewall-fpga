#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: RMII FIREWALL FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

from wishbone import wishbone
from rmii_mac import rmii_mac
from sys_module import sys_module

print("SUMMARY REPORTS OF RMII FIREWALL FPGA:")
print("========================================")

wb = wishbone("COM4")
sm = sys_module(wb)
mac0 = rmii_mac(wb,0x4000,0)
mac1 = rmii_mac(wb,0x6000,1)

#sm.report()
mac0.rx_mac_report()
mac0.tx_mac_report()
mac1.rx_mac_report()
mac1.tx_mac_report()

wb.close()
