class axi_master_monitor extends uvm_monitor;

    `uvm_component_utils(axi_master_monitor)

    //============================================================
    // Virtual interface
    //============================================================
    virtual axi4_intf vif;

    //============================================================
    // Analysis port
    //============================================================
    uvm_analysis_port #(axi_seq_item) mon1_port;

    //============================================================
    // Transaction
    //============================================================
    axi_seq_item trans_collected;

    //============================================================
    // Write control
    //============================================================
    int expected_beats;
    int beat_count;

    //============================================================
    // Constructor
    //============================================================
    function new(
        string name = "axi_master_monitor",
        uvm_component parent
    );

        super.new(name, parent);

        mon1_port = new("mon1_port", this);

    endfunction


    //============================================================
    // BUILD PHASE
    //============================================================
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual axi4_intf)::get(
                this,
                "",
                "vif",
                vif
            )) begin

            `uvm_fatal(
                "M_MONITOR",
                "virtual interface is not connected"
            );

        end

    endfunction


    //============================================================
    // RUN PHASE
    //============================================================
    task run_phase(uvm_phase phase);

        fork

            monitor_write();

            monitor_read();

        join

    endtask


    //################################################################
    // WRITE MONITOR
    //################################################################

    task monitor_write();

        forever begin

            //========================================================
            // Wait for AW handshake
            //========================================================

            @(posedge vif.ACLK);

            if (vif.AWVALID && vif.AWREADY) begin

                //====================================================
                // Create transaction
                //====================================================

                trans_collected =
                    axi_seq_item::type_id::create("trans_collected");


                //====================================================
                // Capture AW channel
                //====================================================

                trans_collected.AWVALID  = vif.AWVALID;
                trans_collected.AWREADY  = vif.AWREADY;

                trans_collected.AWID     = vif.AWID;
                trans_collected.AWADDR   = vif.AWADDR;
                trans_collected.AWLEN    = vif.AWLEN;
                trans_collected.AWSIZE   = vif.AWSIZE;
                trans_collected.AWBURST  = vif.AWBURST;

                trans_collected.AWLOCK   = vif.AWLOCK;
                trans_collected.AWCACHE  = vif.AWCACHE;
                trans_collected.AWPROT   = vif.AWPROT;
                trans_collected.AWQOS    = vif.AWQOS;
                trans_collected.AWREGION = vif.AWREGION;
                trans_collected.AWUSER   = vif.AWUSER;


                `uvm_info(
                    "MASTER_MONITOR_AW",
                    $sformatf("AW HANDSHAKE: AWVALID=%0b AWREADY=%0b AWID=%0d AWADDR=%h AWLEN=%0d AWSIZE=%0d AWBURST=%0d",
                              trans_collected.AWVALID,
                              trans_collected.AWREADY,
                              trans_collected.AWID,
                              trans_collected.AWADDR,
                              trans_collected.AWLEN,
                              trans_collected.AWSIZE,
                              trans_collected.AWBURST),
                    UVM_MEDIUM
                );


                //====================================================
                // AXI burst length
                //
                // AWLEN = number of beats - 1
                //====================================================

                expected_beats = trans_collected.AWLEN + 1;

                beat_count = 0;


                //====================================================
                // Allocate WDATA
                //====================================================

                trans_collected.WDATA =
                    new[expected_beats];


                //====================================================
                // Allocate WSTRB
                //====================================================

                trans_collected.WSTRB =
                    new[expected_beats];


                //====================================================
                // W CHANNEL
                //====================================================

                while (beat_count < expected_beats) begin

                    @(posedge vif.ACLK);

                    if (vif.WVALID && vif.WREADY) begin

                        //================================================
                        // Capture WDATA
                        //================================================

                        trans_collected.WDATA[beat_count] =
                            vif.WDATA;


                        //================================================
                        // Capture WSTRB
                        //================================================

                        trans_collected.WSTRB[beat_count] =
                            vif.WSTRB;


                        `uvm_info(
                            "MASTER_MONITOR_W",
                            $sformatf("W HANDSHAKE: BEAT=%0d/%0d WDATA=%h WSTRB=%b WLAST=%0b",
                                      beat_count,
                                      expected_beats-1,
                                      vif.WDATA,
                                      vif.WSTRB,
                                      vif.WLAST),
                            UVM_MEDIUM
                        );


                        //================================================
                        // WLAST check
                        //================================================

                        if (vif.WLAST) begin

                            if (beat_count != expected_beats-1) begin

                                `uvm_error(
                                    "MASTER_MONITOR",
                                    $sformatf("EARLY WLAST: beat=%0d expected=%0d",
                                              beat_count,
                                              expected_beats-1)
                                );

                            end

                            beat_count++;

                            break;

                        end


                        beat_count++;

                    end

                end


                //====================================================
                // Check complete W burst
                //====================================================

                if (beat_count != expected_beats) begin

                    `uvm_error(
                        "MASTER_MONITOR",
                        $sformatf("W BURST INCOMPLETE: captured=%0d expected=%0d",
                                  beat_count,
                                  expected_beats)
                    );

                end
                else begin

                    `uvm_info(
                        "MASTER_MONITOR",
                        $sformatf("COMPLETE WRITE TRANSACTION: ADDR=%h BEATS=%0d",
                                  trans_collected.AWADDR,
                                  expected_beats),
                        UVM_MEDIUM
                    );


                    //================================================
                    // Send write transaction to scoreboard
                    //================================================

                    mon1_port.write(trans_collected);

                end

            end

        end

    endtask


    //################################################################
    // READ MONITOR
    //################################################################

    task monitor_read();

        axi_seq_item read_trans;


        forever begin

            //========================================================
            // Wait for AR handshake
            //========================================================

            @(posedge vif.ACLK);

            if (vif.ARVALID && vif.ARREADY) begin

                //====================================================
                // Create read transaction
                //====================================================

                read_trans =
                    axi_seq_item::type_id::create("read_trans");


                //====================================================
                // Capture AR channel
                //====================================================

                read_trans.ARVALID  = vif.ARVALID;
                read_trans.ARREADY  = vif.ARREADY;

                read_trans.ARID     = vif.ARID;
                read_trans.ARADDR   = vif.ARADDR;
                read_trans.ARLEN    = vif.ARLEN;
                read_trans.ARSIZE   = vif.ARSIZE;
                read_trans.ARBURST  = vif.ARBURST;

                read_trans.ARLOCK   = vif.ARLOCK;
                read_trans.ARCACHE  = vif.ARCACHE;
                read_trans.ARPROT   = vif.ARPROT;
                read_trans.ARQOS    = vif.ARQOS;
                read_trans.ARREGION = vif.ARREGION;
                read_trans.ARUSER   = vif.ARUSER;


                //====================================================
                // Print AR
                //====================================================

                `uvm_info(
                    "MASTER_MONITOR_AR",
                    $sformatf("AR HANDSHAKE: ARVALID=%0b ARREADY=%0b ARID=%0d ARADDR=%h ARLEN=%0d ARSIZE=%0d ARBURST=%0d",
                              read_trans.ARVALID,
                              read_trans.ARREADY,
                              read_trans.ARID,
                              read_trans.ARADDR,
                              read_trans.ARLEN,
                              read_trans.ARSIZE,
                              read_trans.ARBURST),
                    UVM_MEDIUM
                );


                //====================================================
                // Send read transaction to scoreboard
                //====================================================

                mon1_port.write(read_trans);


                `uvm_info(
                    "MASTER_MONITOR",
                    $sformatf("COMPLETE READ ADDRESS: ARADDR=%h ARLEN=%0d",
                              read_trans.ARADDR,
                              read_trans.ARLEN),
                    UVM_MEDIUM
                );

            end

        end

    endtask

endclass


