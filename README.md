# RMII Firewall FPGA
The project "RMII Firewall FPGA" is VHDL implementation of 100 Mbps (RMII) firewall for FPGA. The RMII Firewall FPGA allows to filter Ethernet packets according to MAC or IP addresses. The Wishbone bus is used to control the entire design. The Wishbone requests can be transmitted from a PC via the UART interface. The target device is FPGA board CYC1000 by Trenz Electronic. As Ethernet PHY are used two LAN8720 boards connected to FPGA via RMII interfaces.

## Current status
In development, it may not work properly!

## Top level diagram
```
         +---------+    +-------------+    +---------+
ETH0 <===| RMII    |<===| FIREWALL in |<===| RMII    |<=== ETH1
PORT ===>| MAC     |===>| both ways   |===>| MAC     |===> PORT
         +----+----+    +------+------+    +----+----+
              ↕                ↕                ↕
              +================+================+ WISHBONE BUS
              ↕                                 ↕
         +----+----+                       +----+----+
UART <---| UART2WB |                       | SYSTEM  |
PORT --->| MASTER  |                       | MODULE  |
         +---------+                       +---------+
```
## Main modules description

* RMII MAC - Receiving and transmitting Ethernet packets on the RMII interface (limitations: only 100 Mbps full duplex mode, no CRC checking).
* FIREWALL - Parses (extraction of MAC and IP addresses) and filters incoming packets by MAC or IP address.
* UART2WB MASTER - Transmits the Wishbone requests and responses via UART interface (Wishbone bus master module).
* SYSTEM MODULE - Basic system control and status registers (version, debug space etc.) accessible via Wishbone bus.

## Resource usage summary:

Module | LE (LUT+FF) | LUT | FF | BRAM (M9k) | Fmax
:---:|:---:|:---:|:---:|:---:|:---:
FPGA (whole design) | 11471 | 6671‬ | 10147 | 52 | 70.2 MHz
**Some submodules:** | === | === | === | === | === 
UART2WBM | 192 | 103 | 156 | 0 | 303.9 MHz
RX_RMII_MAC | 1061 | 848 | 894 | 4 | 149.0 MHz
TX_RMII_MAC | 370 | 232 | 318 | 3 | 165.7 MHz
Firewall | 4121 | 2116 | 3746 | 19 | 153.6 MHz

*Implementation was performed using Quartus Prime Lite Edition 18.1.0 for FPGA Intel Cyclone 10 LP 10CL025YU256C8G.*

## Address space
```
0xOOOO - 0x3FFF -- System module
0x4000 - 0x40FF -- ETH PORT0 - RX RMII MAC module
0x4100 - 0x41FF -- ETH PORT0 - TX RMII MAC module
0x4200 - 0x5FFF -- Reserved
0x6000 - 0x60FF -- ETH PORT1 - RX RMII MAC module
0x6100 - 0x61FF -- ETH PORT1 - TX RMII MAC module
0x6200 - 0x7FFF -- Reserved
0x8000 - 0x83FF -- Firewall module (ETH PORT0 to PORT1)
0x8400 - 0x87FF -- MatchUnit MAC_DST (ETH PORT0 to PORT1)
0x8800 - 0x8BFF -- MatchUnit MAC_SRC (ETH PORT0 to PORT1)
0x8C00 - 0x8FFF -- MatchUnit IPV4_DST (ETH PORT0 to PORT1)
0x9000 - 0x93FF -- MatchUnit IPV4_SRC (ETH PORT0 to PORT1)
0x9400 - 0x97FF -- MatchUnit IPV6_DST (ETH PORT0 to PORT1)
0x9800 - 0x9BFF -- MatchUnit IPV6_SRC (ETH PORT0 to PORT1)
0x9C00 - 0x9FFF -- Reserved
0xA000 - 0xA3FF -- Firewall module (ETH PORT1 to PORT0)
0xA400 - 0xA7FF -- MatchUnit MAC_DST (ETH PORT1 to PORT0)
0xA800 - 0xABFF -- MatchUnit MAC_SRC (ETH PORT1 to PORT0)
0xAC00 - 0xAFFF -- MatchUnit IPV4_DST (ETH PORT1 to PORT0)
0xB000 - 0xB3FF -- MatchUnit IPV4_SRC (ETH PORT1 to PORT0)
0xB400 - 0xB7FF -- MatchUnit IPV6_DST (ETH PORT1 to PORT0)
0xB800 - 0xBBFF -- MatchUnit IPV6_SRC (ETH PORT1 to PORT0)
0xBC00 - 0xFFFF -- Reserved
```
## License
The RMII Firewall FPGA is available under the MIT license (MIT). Please read [LICENSE file](LICENSE).