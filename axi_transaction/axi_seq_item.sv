


    `define DATA_WIDTH 32
    `define ADDR_WIDTH  32
    `define ID_WIDTH    8
    `define USER_WIDTH  1


class axi_seq_item extends uvm_sequence_item;

        rand bit ARESETn;	
	rand bit [`ID_WIDTH-1:0]       AWID;
    	rand bit [`ADDR_WIDTH-1:0]     AWADDR;
	rand bit [7:0]                AWLEN;
    	rand bit [2:0]                AWSIZE;
   	rand bit [1:0]                AWBURST;
   	rand bit                      AWLOCK;
    	rand bit [3:0]                AWCACHE;
   	rand bit [2:0]                AWPROT;
   	rand bit [3:0]                AWQOS;
   	rand bit [3:0]                AWREGION;
    	rand bit [`USER_WIDTH-1:0]     AWUSER;
   	rand bit                      AWVALID;
   	     bit                      AWREADY;

    	rand bit [`DATA_WIDTH-1:0]     WDATA [];
    	rand bit [`DATA_WIDTH/8-1:0]   WSTRB;
    	rand bit                      WLAST;
    	rand bit [`USER_WIDTH-1:0]     WUSER;
    	rand bit                      WVALID;
    	     bit                      WREADY;

    	     bit [`ID_WIDTH-1:0]       BID;
    	     bit [1:0]                BRESP;
    	     bit [`USER_WIDTH-1:0]     BUSER;
    	     bit                      BVALID;
    	rand bit                      BREADY;

    	rand bit [`ID_WIDTH-1:0]       ARID;
    	rand bit [`ADDR_WIDTH-1:0]     ARADDR;
    	rand bit [7:0]                ARLEN;
    	rand bit [2:0]                ARSIZE;
    	rand bit [1:0]                ARBURST;
    	rand bit                      ARLOCK;
    	rand bit [3:0]                ARCACHE;
    	rand bit [2:0]                ARPROT;
    	rand bit [3:0]                ARQOS;
    	rand bit [3:0]                ARREGION;
    	rand bit [`USER_WIDTH-1:0]     ARUSER;
    	rand bit                      ARVALID;
             bit                      ARREADY;

             bit [`ID_WIDTH-1:0]       RID;
             bit [`DATA_WIDTH-1:0]     RDATA;
             bit [1:0]                RRESP;
             bit                      RLAST;
             bit [`USER_WIDTH-1:0]     RUSER;
             bit                      RVALID;
        rand bit                      RREADY;
	
	
	`uvm_object_utils_begin(axi_seq_item)
	
	`uvm_object_utils_end



	function new(string name="axi_seq_item");
		super.new(name);
	endfunction


constraint c1 {
    soft WDATA.size() == (AWLEN + 1);
}

constraint c2 {
    AWADDR inside {[32'h0000_0000 : 32'h0000_FFFF]};
}

constraint c3 {
    AWID == ARID;
}

constraint c4 {
    AWLEN  == ARLEN;
    AWSIZE == ARSIZE;
    AWADDR == ARADDR;
}

constraint c5 {
    AWSIZE inside {[0:2]};
    ARSIZE inside {[0:2]};
}

constraint c6 {
    AWBURST == 2'b01;
    ARBURST == 2'b01;
}

constraint c7 {
    AWLOCK == 1'b0;
    ARLOCK == 1'b0;
}


endclass
