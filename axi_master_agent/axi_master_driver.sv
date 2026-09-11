class axi_master_driver extends uvm_driver #(axi_seq_item);

    parameter int DATA_WIDTH = 32;
    localparam int BUS_BYTES = DATA_WIDTH/8;

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
			w_channel(pkt);
			b_channel(pkt);
		join

		fork

			ar_channel(pkt);
			r_channel(pkt);
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

    		`uvm_info("MASTER_DRIVER_FOR_AW_CHANNEL",
			$sformatf("AWVALID=%0d AWREADY=%0d AWID=%0d AWADDR=%0d AWLEN=%0d AWSIZE=%0d AWBURST=%0d AWLOCK=%0d AWCACHE=%0d AWPROT=%0d  AWQOS=%0d  AWREGION=%0d  AWUSER=%0d",vif.AWVALID, vif.AWREADY, vif.AWID,vif.AWADDR, vif.AWLEN, vif.AWSIZE, vif.AWBURST, vif.AWLOCK, vif.AWCACHE, vif.AWPROT, vif.AWQOS, vif.AWREGION, vif.AWUSER),
			UVM_MEDIUM)
	endtask
	
	//============Calculate Bytes Per Beat============== 
	//==============AWSIZE encoding=====================
	//
	//	AWSIZE = 0 -> 1 byte 
	// 	AWSIZE = 1 -> 2 bytes 
	// 	AWSIZE = 2 -> 4 bytes 
	// 	AWSIZE = 3 -> 8 bytes 
	// 	
	//==================================================
	
	function automatic int unsigned get_bytes_per_beat( input bit [2:0] size );
		return (1 << size);
	endfunction
	
	function automatic bit [31:0] calculate_current_addr(input bit [31:0] start_addr, input int unsigned beat, input bit [2:0] size );
		int unsigned bytes_per_beat; 
		bytes_per_beat = get_bytes_per_beat(size);
		calculate_current_addr = start_addr + (beat * bytes_per_beat);
	endfunction
	
	function automatic bit [BUS_BYTES-1:0] calculate_wstrb( input bit [31:0] addr, input bit [2:0] size);
		int unsigned transfer_bytes;
		int unsigned offset;
		transfer_bytes = get_bytes_per_beat(size);
		offset = addr % BUS_BYTES;
		calculate_wstrb = '0;
		for (int i = 0; i < transfer_bytes; i++) begin
			if ((offset + i) < BUS_BYTES) begin
				calculate_wstrb[offset + i] = 1'b1;
			end
		end
	endfunction

	
	
	task w_channel(axi_seq_item pkt);
		
		int unsigned curr_addr;
		@(posedge vif.ACLK);
		
		for (int beat = 0; beat <= pkt.AWLEN; beat++) begin
			
			//---------------------------------------------------
        		// Calculate current address
        		//---------------------------------------------------
         		curr_addr = calculate_current_addr(pkt.AWADDR, beat, pkt.AWSIZE);

        		//---------------------------------------------------
        		// Drive bus
        		//---------------------------------------------------
        		vif.WDATA  <= pkt.WDATA[beat];
        		vif.WSTRB  <= calculate_wstrb(curr_addr, pkt.AWSIZE);
        		vif.WLAST  <= (beat == pkt.AWLEN);

        		//---------------------------------------------------
        		// Assert WVALID
        		//---------------------------------------------------
        		vif.WVALID <= 1'b1;

        		//---------------------------------------------------
        		// Wait until slave asserts WREADY
        		//---------------------------------------------------
        		do begin
           		 @(posedge vif.ACLK);
        		end
        		while (!vif.WREADY);

       	 		//---------------------------------------------------
        		// Handshake completed
        		//---------------------------------------------------
        		$display("Beat=%0d Handshake Done  WDATA=%h WSTRB=%b WLAST=%b Time=%0t",
             		     beat,
               		   vif.WDATA,
               		   vif.WSTRB,
                	   vif.WLAST,
                 		$time);

        		//---------------------------------------------------
       		 	// Deassert VALID
       		 	//---------------------------------------------------
        		vif.WVALID <= 1'b0;

        		//---------------------------------------------------
        		// Optional idle cycle between beats
        		//---------------------------------------------------
        		@(posedge vif.ACLK);
		end
		//-------------------------------------------------------
    		// Return bus to idle
    		//-------------------------------------------------------
    		vif.WLAST <= 0;
    		vif.WSTRB <= 0;
    		vif.WDATA <= 0;
	endtask
	
	
	task b_channel(axi_seq_item pkt);
		// Wait for slave to assert BVALID
		@(posedge vif.ACLK);
		vif.BREADY <= 1'b1;
		while (vif.BVALID !== 1'b1) begin
			@(posedge vif.ACLK);
		end
		// BVALID && BREADY = response handshake
    		`uvm_info("B_DRIVER",
			$sformatf("B Handshake Done: BID=%0h BRESP=%0b Time=%0t",
			vif.BID,
                  	vif.BRESP,
                  		$time),
				UVM_MEDIUM)
				// Deassert BREADY after handshake
				@(posedge vif.ACLK);
				vif.BREADY <= 1'b0;
       endtask



       	task ar_channel(axi_seq_item pkt);

    		// Drive AW payload
    		vif.ARID     <= pkt.ARID;
   		vif.ARADDR   <= pkt.ARADDR;
    		vif.ARLEN    <= pkt.ARLEN;
   		vif.ARSIZE   <= pkt.ARSIZE;
   		vif.ARBURST  <= pkt.ARBURST;
    		vif.ARLOCK   <= pkt.ARLOCK;
   		vif.ARCACHE  <= pkt.ARCACHE;
   		vif.ARPROT   <= pkt.ARPROT;
  		vif.ARQOS    <= pkt.ARQOS;
   		vif.ARREGION <= pkt.ARREGION;
    		vif.ARUSER   <= pkt.ARUSER;
    		vif.ARVALID <= 1'b1;

    		// Wait for clocked handshake
    		do begin
        		@(posedge vif.ACLK);
		end
    		while (vif.ARREADY !== 1'b1);

    		// Handshake completed
    		vif.ARVALID <= 1'b0;

    		`uvm_info("AW_DRIVER",
			$sformatf("ARVALID=%0b ARREADY=%0b ARADDR=%h ARLEN=%0d ARSIZE=%0d",
			vif.ARVALID,
			vif.ARREADY,
			vif.ARADDR,
			vif.ARLEN,
			vif.ARSIZE),
			UVM_MEDIUM)
	endtask


task r_channel(axi_seq_item pkt);

    int beat;

    beat = 0;

    // Master is ready to accept read data
    vif.RREADY <= 1'b1;

    forever begin

        @(posedge vif.ACLK);

        // R channel handshake
        if (vif.RVALID && vif.RREADY) begin

            `uvm_info("R_DRIVER",
                $sformatf(
                    "R Handshake Done: Beat=%0d RID=%0h RDATA=%0h RRESP=%0b RLAST=%0b Time=%0t",
                    beat,
                    vif.RID,
                    vif.RDATA,
                    vif.RRESP,
                    vif.RLAST,
                    $time
                ),
                UVM_MEDIUM
            );

            // Check last beat
            if (vif.RLAST) begin
                break;
            end

            beat++;

        end

    end

    // Return RREADY to idle
    vif.RREADY <= 1'b0;

endtask



endclass
