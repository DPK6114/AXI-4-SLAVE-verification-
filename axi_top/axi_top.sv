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
	.AWREADY(intf.AWREADY)


     
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






