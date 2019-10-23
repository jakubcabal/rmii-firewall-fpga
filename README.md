# RMII Firewall FPGA
The project "RMII Firewall FPGA" is VHDL implementation of 100 Mbps (RMII) firewall for FPGA. The RMII Firewall FPGA allows to filter Ethernet packets according to MAC or IP addresses. The Wishbone bus is used to control the entire design. The Wishbone requests can be transmitted from a PC via the UART interface. The target device is FPGA board CYC1000 by Trenz Electronic. As Ethernet PHY are used two LAN8720 boards connected to FPGA via RMII interfaces.

## Current status
In development, it may not work properly!

## Top level diagram
```
         +---------+    +-------------+    +---------+
ETH0 <===| RMII    |<===| FIREWALL    |<===| RMII    |<=== ETH1
PORT ===>| MAC     |===>| APP (TODO)  |===>| MAC     |===> PORT
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
* FIREWALL APP - Parses (extraction of MAC and IP addresses) and filters incoming packets by MAC or IP address (not yet implemented).
* UART2WB MASTER - Transmits the Wishbone requests and responses via UART interface (Wishbone bus master module).
* SYSTEM MODULE - Basic system control and status registers (version, debug space etc.) accessible via Wishbone bus.

## License
The RMII Firewall FPGA is available under the MIT license (MIT). Please read [LICENSE file](LICENSE).