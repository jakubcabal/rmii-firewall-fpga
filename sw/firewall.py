#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: RMII FIREWALL FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

class firewall:
    def __init__(self, wishbone, base_addr, port):
        self.wb = wishbone
        self.ba = base_addr
        self.port_id = port

    def firewall_report(self, full=False):
        version_reg = self.wb.read(self.ba+0x000)
        status_reg  = self.wb.read(self.ba+0x004)
        self.wb.write(self.ba+0x000,0x3) # sample counters
        cnt_pkt  = self.wb.read(self.ba+0x010)
        cnt_ipv4 = self.wb.read(self.ba+0x014)
        cnt_ipv6 = self.wb.read(self.ba+0x018)

        print("========================================")
        print("FIREWALL%d REPORT:" % self.port_id)
        print("========================================")
        print("Frames all:                   %d" % cnt_pkt)
        print("Frames with IPV4:             %d" % cnt_ipv4)
        print("Frames with IPV6:             %d" % cnt_ipv6)
        print("Frames without IPV4/6:        %d" % (cnt_pkt-(cnt_ipv4+cnt_ipv6)))
        if full:
            print("----------------------------------------")
            print("Debug registers:")
            print("----------------------------------------")
            print("Version register:             %s" % hex(version_reg))
            print("Status register:              %s" % hex(status_reg))
        print("----------------------------------------\n")
