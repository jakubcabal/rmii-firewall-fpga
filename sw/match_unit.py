#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: RMII FIREWALL FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

class match_unit:
    def __init__(self, wishbone, base_addr, instance):
        self.wb = wishbone
        self.ba = base_addr
        self.inst = instance

    def add_record(self, id, record):
        # record is list of unsigned integers (dwords)
        dwords = self.wb.read(self.ba+0x04) # read record size in dwords (32b)
        print("%d dwords is supported in MatchUnit %s." % (dwords, self.inst))
        self.wb.write(self.ba+0x08,id) # write record address (ID)
        for i in range(0, dwords):
            self.wb.write(self.ba+0x0C,record[i]) # write record per dwords
            print("Write %s to MatchUnit %s." % (hex(record[i]), self.inst))
        self.wb.write(self.ba+0x00,0x0) # command add record
        print("Record %d added in MatchUnit %s." % (id, self.inst))

    def rm_record(self, id):
        self.wb.write(self.ba+0x08,id) # write record address (ID)
        self.wb.write(self.ba+0x00,0x1) # command remove record
        print("Record %d removed in MatchUnit %s." % (id, self.inst))

