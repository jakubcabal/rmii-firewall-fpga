#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: RMII FIREWALL FPGA
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

class rmii_mac:
    def __init__(self, wishbone, base_addr, port):
        self.wb = wishbone
        self.ba = base_addr
        self.port_id = port

    def rx_mac_report(self, full=False):
        status_reg = self.wb.read(self.ba+0x004)
        self.wb.write(self.ba+0x000,0x3) # sample counters
        rx_cnt_reg = self.wb.read(self.ba+0x010)
        tx_cnt_reg = self.wb.read(self.ba+0x014)
        # decode status register
        enable_flag = True if ((status_reg & 1) == 0) else False
        fsm_dec_dbg_st = (status_reg & 768)/256
        fsm_mrk_dbg_st = (status_reg & 12288)/4096
        fifom_status = (status_reg & 134152192)/65536
        fifom_full = True if (((status_reg & 128)/128) == 0) else False

        print("==============================")
        print("ETH%d RX RMII MAC REPORT:" % self.port_id)
        print("==============================")
        print("RX MAC is enabled: %s" % enable_flag)
        print("------------------------------")
        print("Received frames:   %d" % rx_cnt_reg)
        print("Discarded frames:  %d" % (rx_cnt_reg-tx_cnt_reg))
        print("Released frames:   %d" % tx_cnt_reg)
        if full:
            print("------------------------------")
            print("Decoder FSM state: %d" % fsm_dec_dbg_st)
            print("Mark FSM state:    %d" % fsm_mrk_dbg_st)
            print("Mark FIFO status:  %d" % fifom_status)
            print("Mark FIFO full:    %s" % fifom_full)
            print("Status register:   %s" % hex(status_reg))
        print("------------------------------\n")

    def tx_mac_report(self, full=False):
        status_reg = self.wb.read(self.ba+0x104)
        self.wb.write(self.ba+0x100,0x3) # sample counters
        tx_cnt_reg = self.wb.read(self.ba+0x110)

        enable_flag = True if ((status_reg & 1) == 0) else False
        asfifo_full = True if (((status_reg & 32)/32) == 0) else False

        print("==============================")
        print("ETH%d TX RMII MAC REPORT:" % self.port_id)
        print("==============================")
        print("TX MAC is enabled:  %s" % enable_flag)
        print("------------------------------")
        print("Transmitted frames: %d" % tx_cnt_reg)        
        if full:
            print("------------------------------")
            print("TX ASFIFO full:     %s" % asfifo_full)
            print("Status register:    %s" % hex(status_reg))
        print("------------------------------\n")
