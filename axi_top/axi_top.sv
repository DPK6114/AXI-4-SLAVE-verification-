module axi_top #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 8,
    parameter int USER_WIDTH = 1
);

    import uvm_pkg::*;
    import axi_package::*;

    logic aclk;
    logic arst_n;

    // Clock
    initial begin
        aclk = 1'b1;
        forever #5 aclk = ~aclk;
    end
    
    assign intf.ARESETn = arst_n;
    // Reset
    initial begin
        arst_n = 1'b0;
        #15 arst_n = 1'b1;
    end

    // AXI Interface
    axi4_intf #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH  (ID_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) intf (.ACLK (aclk));

    // DUT
    axi4_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH  (ID_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) dut (
        .ACLK    (intf.ACLK),
        .ARESETn (intf.ARESETn),
	.AWID(intf.AWID),
	.AWADDR(intf.AWADDR),
	.AWLEN(intf.AWLEN),
	.AWSIZE(intf.AWSIZE),
	.AWBURST(intf.AWBURST),
	.AWLOCK(intf.AWLOCK),
	.AWCACHE(intf.AWCACHE),
	.AWPROT(intf.AWPROT),
	.AWQOS(intf.AWPROT),
	.AWREGION(intf.AWREGION),
	.AWUSER(intf.AWUSER),
	.AWVALID(intf.AWVALID),
	.AWREADY(intf.AWREADY),


	.WDATA(intf.WDATA),
	.WSTRB(intf.WSTRB),
	.WLAST(intf.WLAST),
	.WUSER(intf.WUSER),
	.WVALID(intf.WVALID),
	.WREADY(intf.WREADY),

	.BID(intf.BID),
	.BRESP(intf.BRESP),
	.BUSER(intf.BUSER),
	.BVALID(intf.BVALID),
	.BREADY(intf.BREADY),

	.ARID(intf.ARID),
	.ARADDR(intf.ARADDR),
	.ARLEN(intf.ARLEN),
	.ARSIZE(intf.ARSIZE),
	.ARBURST(intf.ARBURST),
	.ARLOCK(intf.ARLOCK),
	.ARCACHE(intf.ARCACHE),
	.ARPROT(intf.ARPROT),
	.ARQOS(intf.ARPROT),
	.ARREGION(intf.ARREGION),
	.ARUSER(intf.ARUSER),
	.ARVALID(intf.ARVALID),
	.ARREADY(intf.ARREADY),


	.RID(intf.RID),
	.RDATA(intf.RDATA),
	.RRESP(intf.RRESP),
	.RLAST(intf.RLAST),
	.RUSER(intf.RUSER),
	.RVALID(intf.RVALID),
	.RREADY(intf.RREADY)





     
    );


    initial begin
	    uvm_config_db#(virtual axi4_intf)::set(null,"*","vif",intf);
    end

    // UVM
    initial begin
        run_test("axi_test");
    end

    initial begin
        #1000;
        $finish();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, axi_top);
    end

endmodule
