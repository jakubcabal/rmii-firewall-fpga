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

    def rx_mac_report(self):
        enable_reg = self.wb.read(self.ba+0x000)
        status_reg = self.wb.read(self.ba+0x004)
        rx_cnt_reg = self.wb.read(self.ba+0x010)
        tx_cnt_reg = self.wb.read(self.ba+0x014)
        #wb.write(self.ba+0x000,0x1)

        enable_flag = True if (enable_reg == 1) else False
        fsm_dec_dbg_st = status_reg & 3
        fifom_status = (status_reg & 524032)/256
        fifom_full_reg = (status_reg & 16)/16
        fifom_full = True if (fifom_full_reg == 1) else False

        print("\n==============================")
        print("ETH%d RX RMII MAC REPORT:" % self.port_id)
        print("==============================")
        print("RX MAC is enabled: %s" % enable_flag)
        print("------------------------------")
        print("Received frames:   %d" % rx_cnt_reg)
        print("Discarded frames:  %d" % (rx_cnt_reg-tx_cnt_reg))
        print("Released frames:   %d" % tx_cnt_reg)
        print("------------------------------")
        print("Decoder FSM state: %d" % fsm_dec_dbg_st)
        print("Mark FIFO status:  %d" % fifom_status)
        print("Mark FIFO full:    %s" % fifom_full)
        print("Status register:   %s" % hex(status_reg))
        print("------------------------------\n")

    def tx_mac_report(self):
        enable_reg = self.wb.read(self.ba+0x100)
        status_reg = self.wb.read(self.ba+0x104)
        tx_cnt_reg = self.wb.read(self.ba+0x110)
        #wb.write(self.ba+0x000,0x1)

        enable_flag = True if (enable_reg == 1) else False

        print("\n==============================")
        print("ETH%d TX RMII MAC REPORT:" % self.port_id)
        print("==============================")
        print("TX MAC is enabled:  %s" % enable_flag)
        print("------------------------------")
        print("Transmitted frames: %d" % tx_cnt_reg)
        print("------------------------------")
        print("Status register:    %s" % hex(status_reg))
        print("------------------------------\n")
