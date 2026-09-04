interface axi4_intf #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 8,
    parameter int USER_WIDTH = 1
)(
    input logic ACLK
);
    logic ARESETn;
    logic [ID_WIDTH-1:0]       AWID;
    logic [ADDR_WIDTH-1:0]     AWADDR;
    logic [7:0]                AWLEN;
    logic [2:0]                AWSIZE;
    logic [1:0]                AWBURST;
    logic                      AWLOCK;
    logic [3:0]                AWCACHE;
    logic [2:0]                AWPROT;
    logic [3:0]                AWQOS;
    logic [3:0]                AWREGION;
    logic [USER_WIDTH-1:0]     AWUSER;
    logic                      AWVALID;
    logic                      AWREADY;

    logic [DATA_WIDTH-1:0]     WDATA;
    logic [DATA_WIDTH/8-1:0]   WSTRB;
    logic                      WLAST;
    logic [USER_WIDTH-1:0]     WUSER;
    logic                      WVALID;
    logic                      WREADY;

    logic [ID_WIDTH-1:0]       BID;
    logic [1:0]                BRESP;
    logic [USER_WIDTH-1:0]     BUSER;
    logic                      BVALID;
    logic                      BREADY;

    logic [ID_WIDTH-1:0]       ARID;
    logic [ADDR_WIDTH-1:0]     ARADDR;
    logic [7:0]                ARLEN;
    logic [2:0]                ARSIZE;
    logic [1:0]                ARBURST;
    logic                      ARLOCK;
    logic [3:0]                ARCACHE;
    logic [2:0]                ARPROT;
    logic [3:0]                ARQOS;
    logic [3:0]                ARREGION;
    logic [USER_WIDTH-1:0]     ARUSER;
    logic                      ARVALID;
    logic                      ARREADY;

    logic [ID_WIDTH-1:0]       RID;
    logic [DATA_WIDTH-1:0]     RDATA;
    logic [1:0]                RRESP;
    logic                      RLAST;
    logic [USER_WIDTH-1:0]     RUSER;
    logic                      RVALID;
    logic                      RREADY;

endinterface
