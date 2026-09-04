class axi_master_driver extends uvm_driver #(axi_seq_item);

	`uvm_component_utils(axi_master_driver)


	virtual axi4_intf vif;



	function new(string name="axi_master_driver",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db #(virtual axi4_intf)::get(this,"","vif",vif))begin
			`uvm_fatal("M_DRIVER", "virtual interface is not set")
		end
	endfunction

	virtual task run_phase(uvm_phase phase);
	//	super.run_phase(phase);
		axi_seq_item pkt;
		
		forever begin
			pkt=axi_seq_item::type_id::create("pkt",this);
			seq_item_port.get_next_item(pkt);
			if (pkt.ARESETn == 1'b0) begin
				`uvm_info("RESET", "Driving ARESETn LOW", UVM_MEDIUM)
				vif.ARESETn <= 1'b0;
				reset_logic();
			end
			else begin
				`uvm_info("RESET", "Driving ARESETn HIGH", UVM_MEDIUM)
				vif.ARESETn <= 1'b1;
				drive(pkt);
			end
			seq_item_port.item_done();
		end
	endtask


   task reset_logic;
      vif.AWVALID    <=    0;
      vif.WVALID    <=    0;
      vif.BREADY     <=    0;
      vif.ARVALID    <=    0;
      vif.RREADY     <=    0;
      //wait(v_intf.reset==0);
   endtask

	task drive(axi_seq_item pkt);
	        
		fork
			aw_channel(pkt);
			//w_channel(pkt);
			//b_channel(pkt);

			//ar_channel(pkt);
			//r_channel(pkt);
		join
	endtask


task aw_channel(axi_seq_item pkt);

    // Drive AW payload
    vif.AWID     <= pkt.AWID;
    vif.AWADDR   <= pkt.AWADDR;
    vif.AWLEN    <= pkt.AWLEN;
    vif.AWSIZE   <= pkt.AWSIZE;
    vif.AWBURST  <= pkt.AWBURST;
    vif.AWLOCK   <= pkt.AWLOCK;
    vif.AWCACHE  <= pkt.AWCACHE;
    vif.AWPROT   <= pkt.AWPROT;
    vif.AWQOS    <= pkt.AWQOS;
    vif.AWREGION <= pkt.AWREGION;
    vif.AWUSER   <= pkt.AWUSER;
    vif.AWVALID <= 1'b1;

    // Wait for clocked handshake
    do begin
        @(posedge vif.ACLK);
    end
    while (vif.AWREADY !== 1'b1);

    // Handshake completed
    vif.AWVALID <= 1'b0;

    `uvm_info("AW_DRIVER",
          $sformatf("AWVALID=%0b AWREADY=%0b ADDR=%h LEN=%0d",
                    vif.AWVALID,
                    vif.AWREADY,
                    vif.AWADDR,
                    vif.AWLEN),
          UVM_MEDIUM)

endtask

endclass




