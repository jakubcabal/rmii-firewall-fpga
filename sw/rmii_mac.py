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
        version_reg = self.wb.read(self.ba+0x000)
        status_reg  = self.wb.read(self.ba+0x004)
        self.wb.write(self.ba+0x000,0x3) # sample counters
        rx_cnt_reg              = self.wb.read(self.ba+0x010)
        tx_cnt_reg              = self.wb.read(self.ba+0x014)
        cnt_rx_pkt_undersize    = self.wb.read(self.ba+0x020)
        cnt_rx_pkt_64_to_127    = self.wb.read(self.ba+0x024)
        cnt_rx_pkt_128_to_255   = self.wb.read(self.ba+0x028)
        cnt_rx_pkt_256_to_511   = self.wb.read(self.ba+0x02C)
        cnt_rx_pkt_512_to_767   = self.wb.read(self.ba+0x030)
        cnt_rx_pkt_768_to_1023  = self.wb.read(self.ba+0x034)
        cnt_rx_pkt_1024_to_1522 = self.wb.read(self.ba+0x038)
        cnt_rx_pkt_oversize     = self.wb.read(self.ba+0x03C)
        # decode status register
        enable_flag = True if ((status_reg & 1) == 0) else False
        fsm_dec_dbg_st = (status_reg & 768)/256
        fsm_mrk_dbg_st = (status_reg & 12288)/4096
        fifom_status = (status_reg & 134152192)/65536
        fifom_full = True if (((status_reg & 128)/128) == 0) else False

        print("========================================")
        print("ETH%d RX RMII MAC REPORT:" % self.port_id)
        print("========================================")
        print("RX MAC is enabled:            %s" % enable_flag)
        print("----------------------------------------")
        print("Received frames:              %d" % rx_cnt_reg)
        print("Discarded frames:             %d" % (rx_cnt_reg-tx_cnt_reg))
        print("Released frames:              %d" % tx_cnt_reg)
        print("----------------------------------------")
        print("Received frames length histogram:")
        print("----------------------------------------")
        print("Frames below 64 bytes:        %d" % cnt_rx_pkt_undersize)
        print("Frames 64   to 127  bytes:    %d" % cnt_rx_pkt_64_to_127)
        print("Frames 128  to 255  bytes:    %d" % cnt_rx_pkt_128_to_255)
        print("Frames 256  to 511  bytes:    %d" % cnt_rx_pkt_256_to_511)
        print("Frames 512  to 767  bytes:    %d" % cnt_rx_pkt_512_to_767)
        print("Frames 768  to 1023 bytes:    %d" % cnt_rx_pkt_768_to_1023)
        print("Frames 1024 to 1522 bytes:    %d" % cnt_rx_pkt_1024_to_1522)
        print("Frames over 1522 bytes:       %d" % cnt_rx_pkt_oversize)
        if full:
            print("----------------------------------------")
            print("Debug registers:")
            print("----------------------------------------")
            print("Version register:             %s" % hex(version_reg))
            print("Decoder FSM state:            %d" % fsm_dec_dbg_st)
            print("Mark FSM state:               %d" % fsm_mrk_dbg_st)
            print("Mark FIFO status:             %d" % fifom_status)
            print("Mark FIFO full:               %s" % fifom_full)
            print("Status register:              %s" % hex(status_reg))
        print("----------------------------------------\n")

    def tx_mac_report(self, full=False):
        version_reg = self.wb.read(self.ba+0x100)
        status_reg  = self.wb.read(self.ba+0x104)
        self.wb.write(self.ba+0x100,0x3) # sample counters
        tx_cnt_reg = self.wb.read(self.ba+0x110)

        enable_flag = True if ((status_reg & 1) == 0) else False
        asfifo_full = True if (((status_reg & 32)/32) == 0) else False

        print("========================================")
        print("ETH%d TX RMII MAC REPORT:" % self.port_id)
        print("========================================")
        print("TX MAC is enabled:            %s" % enable_flag)
        print("----------------------------------------")
        print("Transmitted frames:           %d" % tx_cnt_reg)        
        if full:
            print("----------------------------------------")
            print("Version register:             %s" % hex(version_reg))
            print("TX ASFIFO full:               %s" % asfifo_full)
            print("Status register:              %s" % hex(status_reg))
        print("----------------------------------------\n")
