**1. Project Overview**
This project implements and verifies a parameterized AMBA AXI4 Slave using SystemVerilog and UVM. The primary objective is to develop a reusable UVM-based verification environment and verify AXI4 read and write transactions, burst transfers, byte strobes, response generation, and AXI VALID/READY handshaking.


**2. Project Objectives**
    •	Implement a parameterized AXI4 Slave RTL.
    •	Develop a reusable SystemVerilog AXI4 interface.
    •	Develop an AXI4 UVM Master Driver.
    •	Generate AXI4 read and write transactions.
    •	Verify AXI4 VALID/READY handshaking.
    •	Verify burst transactions.
    •	Verify INCR burst operation.
    •	Verify different burst lengths and transfer sizes.
    •	Verify WSTRB byte-enable functionality.
    •	Verify write and read responses.
    •	Verify WLAST and RLAST behavior.
    •	Develop a self-checking UVM verification environment.
    •	Debug AXI protocol behavior using QuestaSim waveforms.


**3. AXI4 Architecture**
The AXI4 interface consists of five independent channels:
    •	Write Address Channel — AW
    •	Write Data Channel — W
    •	Write Response Channel — B
    •	Read Address Channel — AR
    •	Read Data Channel — R

A transfer occurs only when both VALID and READY are asserted:
VALID && READY


**4. DUT Features**
The AXI4 Slave RTL is parameterized to support configurable:
    •	Data width
    •	Address width
    •	ID width
    •	User width
    •	Memory size
    •	Address FIFO depth
    •	Read-address FIFO depth
    Example configuration:
    DATA_WIDTH = 32
    ADDR_WIDTH = 32
    ID_WIDTH   = 4
    USER_WIDTH = 1
    MEM_BYTES  = 64 KB



**5. AXI4 Features Verified**
5.1 Write Transactions
    The write address channel includes:
    •	AWID
    •	AWADDR
    •	AWLEN
    •	AWSIZE
    •	AWBURST
    •	AWLOCK
    •	AWCACHE
    •	AWPROT
    •	AWQOS
    •	AWREGION
    •	AWUSER
    The write data channel includes:
    •	WDATA
    •	WSTRB
    •	WLAST
    The write response channel includes:
    •	BID
    •	BRESP
    •	BUSER
5.2 Read Transactions
    The read address channel includes:
    •	ARID
    •	ARADDR
    •	ARLEN
    •	ARSIZE
    •	ARBURST
    •	ARLOCK
    •	ARCACHE
    •	ARPROT
    •	ARQOS
    •	ARREGION
    •	ARUSER
    The read data channel includes:
    •	RDATA
    •	RRESP
    •	RLAST
    •	RID
    •	RUSER


**6. Burst Verification**
6.1 INCR Burst
    For an INCR burst, the next address is calculated by adding the number of bytes per transfer to the current address.
    Next Address = Current Address + Bytes per Transfer
    Bytes per beat = 2^AWSIZE
    Example:
    AWADDR  = 0x100
    AWLEN   = 9
    AWSIZE  = 2
    AWBURST = INCR
    AWLEN = 9 represents 10 data beats. Expected addresses are:
    Beat	Address
    Beat 0	0x100
    Beat 1	0x104
    Beat 2	0x108
    Beat 3	0x10C
    Beat 4	0x110
    Beat 5	0x114
    Beat 6	0x118
    Beat 7	0x11C
    Beat 8	0x120
    Beat 9	0x124
    WLAST must be asserted on the final write-data beat. Similarly, RLAST must be asserted on the final read-data beat.


**7. UVM Verification Architecture**
+------------------------------------------------------------------------------------------+
| AXI_TOP                                                                                  |
|                                                                                          |
|  +----------------------------------------------------------------------------------+    |
|  | AXI_TEST                                                                         |    |
|  |                                                                                  |    |
|  |  +------------------------------------------------------------------------+      |    |
|  |  | AXI_ENV                                                                |      |    |
|  |  |                                                                        |      |    |
|  |  |                    +-----------------------------+                     |      |    |
|  |  |                    |      AXI_SCOREBOARD         |                     |      |    |
|  |  |                    +-----------------------------+                     |      |    |
|  |  |                         ^                       ^                      |      |    |
|  |  |                         |                       |                      |      |    |
|  |  |        +--------------------------+     +----------------------+       |      |    |
|  |  |        | AXI_MASTER_AGENT         |     | AXI_SLAVE_AGENT      |       |      |    |
|  |  |        |                          |     |                      |       |      |    |
|  |  |        |  +---------------+       |     |                      |       |      |    |
|  |  |        |  |   AXI_SEQR    |       |     |                      |       |      |    |
|  |  |        |  +---------------+       |     |                      |       |      |    |
|  |  |        |          |               |     |                      |       |      |    |
|  |  |        |          v               |     |                      |       |      |    |
|  |  |        |  +----------+ +-------+  |     |  +-----------+       |       |      |    |
|  |  |        |  |AXI_DRIVER| |AXI_MON1| |     |  |  AXI_MON2 |       |       |      |    |
|  |  |        |  +----------+ +-------+  |     |  +-----------+       |       |      |    |
|  |  |        +--------------------------+     +----------------------+       |      |    |
|  |  |                 |       |                    |                         |      |    |
|  |  +-----------------|-------|--------------------|-------------------------+      |    |
|  |                    |       |                    |                                |    |
|  +--------------------|-------|--------------------|--------------------------------+    |
|                       |       |                    |                                     |
|                       v       v                    v                                     |
|        <================================================================>                |
|        |                          AXI_INTERFACE                         |                |
|        <================================================================>                |
|                                       v                                                  |
|                                +-------------+                                           |
|                                | DESIGN(DUT) |                                           |
|                                +-------------+                                           |
|                                                                                          |
+------------------------------------------------------------------------------------------+


**8. UVM Components**
8.1 Sequence Item
The sequence item contains AXI transaction-level information such as address, ID, burst length, transfer size, burst type, write data, write strobes, and response information.

**8.2 Sequence**
The sequence generates AXI transactions and sends them to the sequencer.
    Example:
    Address  : 0x100
    Length   : 9
    Size     : 2
    Burst    : INCR
    Data     : 10 beats

**8.3 Sequencer**
The sequencer transfers sequence items from the sequence to the driver.

**8.4 Driver**
The AXI driver converts transaction-level information into pin-level AXI signals. The driver handles AW, W, B, AR, and R channels and waits for the corresponding READY signals while maintaining VALID until the handshake occurs.
do begin
    @(posedge vif.ACLK);
end while (!vif.AWREADY);

**8.5 Monitor**
The monitor observes AXI bus activity without driving signals. It captures address transactions, write/read data, responses, burst information, and handshake events.

**8.6 Scoreboard**
The scoreboard compares expected transactions against actual transactions.
    •	Write data correctness
    •	Read data correctness
    •	Address progression
    •	Burst length
    •	Response codes
    •	Transaction completion
    •	Data integrity

**8.7 Agent**
            +----------------------+
            |      AXI Agent       |
            |                      |
            |  +--------------+    |
            |  |  Sequencer   |    |
            |  +--------------+    |
            |                      |
            |  +--------------+    |
            |  |   Driver     |    |
            |  +--------------+    |
            |                      |
            |  +--------------+    |
            |  |   Monitor    |    |
            |  +--------------+    |
            +----------------------+

**8.8 Environment**
The environment connects the AXI agent and scoreboard to form the complete verification environment.


**9. Write Transaction Flow**
    1. Reset
       ↓
    2. AWVALID asserted
       ↓
    3. AWREADY asserted by DUT
       ↓
    4. AWVALID && AWREADY
       ↓
    5. Write address accepted
       ↓
    6. WVALID asserted
       ↓
    7. WREADY asserted by DUT
       ↓
    8. WVALID && WREADY
       ↓
    9. Write data transferred
       ↓
    10. WLAST on final beat
       ↓
    11. BVALID asserted
       ↓
    12. BREADY asserted
       ↓
    13. BVALID && BREADY
       ↓
    14. Write transaction complete


**10. Read Transaction Flow**
        1.Reset
           ↓
        2. ARVALID asserted
           ↓
        3. ARREADY asserted
           ↓
        4. ARVALID && ARREADY
           ↓
        5. Read address accepted
           ↓
        6. DUT generates RVALID
           ↓
        7. Master asserts RREADY
           ↓
        8. RVALID && RREADY
           ↓
        9. Read data transferred
           ↓
        10. RLAST on final beat
           ↓
        11. Read transaction complete


**11. Test Scenarios**
Test	Description
Basic Write Test	Single-beat write, full byte strobes, and successful BRESP.
INCR Burst Write	10-beat INCR burst using AWADDR=0x100, AWLEN=9, AWSIZE=2.
Basic Read Test	Single-beat read and read-response verification.
INCR Burst Read	Address progression, multiple read beats, RLAST, and RDATA verification.
WSTRB Test	Partial-byte writes using different WSTRB combinations.
Backpressure Test	Behavior when AWREADY, WREADY, BREADY, or RREADY is deasserted.

**12. Verification Tools**
    •	SystemVerilog
    •	UVM
    •	QuestaSim
    •	Makefile
    •	Git / GitHub
        Primary simulator:
        QuestaSim 10.7c


**13. Simulation**
      13.1 Compile
           make compile
      13.2 Run Simulation
           make run
Alternatively, the simulation can be launched using a QuestaSim command/do-file flow. The exact command depends on the local project Makefile and QuestaSim installation.


14. Waveform Debugging
Important AXI signals to observe:
Write Address: AWVALID, AWREADY, AWADDR, AWLEN, AWSIZE, AWBURST
Write Data: WVALID, WREADY, WDATA, WSTRB, WLAST
Write Response: BVALID, BREADY, BRESP, BID
Read Address: ARVALID, ARREADY, ARADDR, ARLEN, ARSIZE, ARBURST
Read Data: RVALID, RREADY, RDATA, RRESP, RLAST, RID


15. AXI Handshake Verification
For each AXI channel, the fundamental transfer condition is:
VALID && READY
Examples:
AWVALID && AWREADY
WVALID  && WREADY
BVALID  && BREADY
ARVALID && ARREADY
RVALID  && RREADY


16. Project Structure
AXI-4-SLAVE-verification/
│
├── rtl/
│   └── axi4_slave.sv
│
├── axi_interface/
│   └── axi4_intf.sv
│
├── axi_sequence/
│   ├── axi_seq_item.sv
│   └── axi_sequence.sv
│
├── axi_driver/
│   └── axi_master_driver.sv
│
├── axi_monitor/
│   └── axi_monitor.sv
│
├── axi_agent/
│   └── axi_agent.sv
│
├── axi_env/
│   └── axi_env.sv
│
├── axi_test/
│   └── axi_test.sv
│
├── axi_package/
│   └── axi_package.sv
│
├── tb/
│   └── axi_top.sv
│
├── Makefile
│
└── README.md


17. Verification Checklist
Feature	Status
AXI4 Write Address Channel	Implemented
AXI4 Write Data Channel	Implemented
AXI4 Write Response Channel	Implemented
AXI4 Read Address Channel	Implemented
AXI4 Read Data Channel	Implemented
VALID/READY Handshake	Implemented
INCR Burst	Implemented
Burst Length	Implemented
Transfer Size	Implemented
WSTRB	Implemented
WLAST	Implemented
RLAST	Implemented
Read Response	Implemented
Write Response	Implemented
UVM Driver	Implemented
UVM Monitor	Implemented
UVM Sequencer	Implemented
UVM Agent	Implemented
UVM Environment	Implemented
Scoreboard	Update to actual status
Functional Coverage	Future / In progress
Assertions	Future / In progress
Regression Tests	Future / In progress


18. Future Improvements
•	Functional coverage
•	SystemVerilog Assertions
•	Constrained-random testing
•	Directed corner-case tests
•	FIXED burst verification
•	WRAP burst verification
•	4 KB boundary testing
•	Multiple outstanding transactions
•	ID-based transaction tracking
•	Response error testing
•	Random READY backpressure
•	Random VALID delays
•	Automated regression
•	Coverage-driven verification
•	Protocol compliance checking


19. Learning Outcomes
•	AXI4 protocol and AMBA architecture
•	SystemVerilog and UVM
•	Transaction-level modeling
•	UVM factory and virtual interfaces
•	Sequences, sequencers, drivers, monitors, agents, and scoreboards
•	Constrained-random verification
•	Burst transaction verification
•	VALID/READY handshaking
•	Waveform-based debugging
•	QuestaSim simulation
•	Makefile-based simulation
•	Git/GitHub project management


20. Author
Deepak H Rathod
Design Verification Engineer
Technical Interests: Design Verification, SystemVerilog, UVM, AXI/AHB/APB, DDR/LPDDR, SoC Verification, RTL Design, and ASIC Verification.

21. Project Goal
The goal of this project is to build a reusable, scalable, and self-checking AXI4 verification environment that can be extended for more complex AXI4 protocol scenarios and used as a foundation for industry-level verification projects.
