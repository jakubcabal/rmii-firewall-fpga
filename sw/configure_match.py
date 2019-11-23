#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: RMII FIREWALL FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

from wishbone import wishbone
from match_unit import match_unit

print("CONFIGURATION OF MATCH UNITS:")
print("========================================")

wb = wishbone("COM4")
mu_ipv4_dst = match_unit(wb,0x8C00,"E01_IPV4_DST")

ipv4_dst_list = [0xA8C00001] #168.192.0.1
mu_ipv4_dst.add_record(0,ipv4_dst_list)

wb.close()
