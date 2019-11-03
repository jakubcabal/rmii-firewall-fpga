#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: RMII FIREWALL FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

class sys_module:

    def __init__(self, wishbone):
        self.wb = wishbone

    def report(self):
        version_reg = self.wb.read(0x0000)
        debug_reg   = self.wb.read(0x0004)

        print("========================================")
        print("SYSTEM MODULE REPORT:")
        print("========================================")
        print("Version register:             %s" % hex(version_reg))
        print("Debug register:               %s" % hex(debug_reg))
        print("----------------------------------------\n")
