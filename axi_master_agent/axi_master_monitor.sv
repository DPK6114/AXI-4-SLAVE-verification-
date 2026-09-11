class axi_master_monitor extends uvm_monitor;

    `uvm_component_utils(axi_master_monitor)

    virtual axi4_intf vif;

    uvm_analysis_port#(axi_seq_item) mon1_port;

    axi_seq_item trans_collected;

    int expected_beats;
    int beat_count;


    function new(string name="axi_master_monitor",
                 uvm_component parent);
        super.new(name,parent);
        mon1_port = new("mon1_port",this);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if(!uvm_config_db #(virtual axi4_intf)::get(this,"","vif",vif)) begin
            `uvm_fatal("M_MONITOR",
                       "virtual interface is not connected");
        end

    endfunction


    task run_phase(uvm_phase phase);

        forever begin

            @(posedge vif.ACLK);

            //========================================================
            // AW CHANNEL
            //========================================================
            if (vif.AWVALID && vif.AWREADY) begin

                trans_collected = axi_seq_item::type_id::create("trans_collected");


                // Capture AW channel
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
                    "MASTER_MONITOR_AW_CHANNEL",
                    $sformatf(
                    "AW HANDSHAKE: AWVALID=%0b AWREADY=%0b AWID=%0d AWADDR=%h AWLEN=%0d AWSIZE=%0d AWBURST=%0d AWLOCK=%0d AWCACHE=%0d AWPROT=%0d AWQOS=%0d AWREGION=%0d AWUSER=%0d",
                    trans_collected.AWVALID,
                    trans_collected.AWREADY,
                    trans_collected.AWID,
                    trans_collected.AWADDR,
                    trans_collected.AWLEN,
                    trans_collected.AWSIZE,
                    trans_collected.AWBURST,
                    trans_collected.AWLOCK,
                    trans_collected.AWCACHE,
                    trans_collected.AWPROT,
                    trans_collected.AWQOS,
                    trans_collected.AWREGION,
                    trans_collected.AWUSER),
                    UVM_MEDIUM
                );


                //====================================================
                // Number of W beats
                // AWLEN = number of beats - 1
                //====================================================

                expected_beats = trans_collected.AWLEN + 1;

                beat_count = 0;


                // Allocate WDATA array
                trans_collected.WDATA = new[expected_beats];


                //====================================================
                // W CHANNEL
                //====================================================

                while (beat_count < expected_beats) begin

                    @(posedge vif.ACLK);
                   


                    // W transfer occurs only when
                    // WVALID && WREADY
                    if (vif.WVALID && vif.WREADY) begin

                        trans_collected.WDATA[beat_count] = vif.WDATA;


                        `uvm_info(
                            "MASTER_MONITOR_W_CHANNEL",
                            $sformatf(
                            "W HANDSHAKE: BEAT=%0d/%0d WVALID=%0b WREADY=%0b WDATA=%h WSTRB=%b WLAST=%0b",
                            beat_count,
                            expected_beats-1,
                            vif.WVALID,
                            vif.WREADY,
                            vif.WDATA,
                            vif.WSTRB,
                            vif.WLAST),
                            UVM_MEDIUM
                        );


                        //================================================
                        // Check WLAST
                        //================================================

                        if (vif.WLAST) begin

                            if (beat_count != expected_beats-1) begin

                                `uvm_error(
                                    "MASTER_MONITOR",
                                    $sformatf(
                                    "EARLY WLAST: beat=%0d expected=%0d",
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
                // Check complete burst
                //====================================================

                if (beat_count != expected_beats) begin

                    `uvm_error(
                        "MASTER_MONITOR",
                        $sformatf(
                        "W BURST INCOMPLETE: captured=%0d expected=%0d",
                        beat_count,
                        expected_beats)
                    );

                end
                else begin

                    `uvm_info(
                        "MASTER_MONITOR",
                        $sformatf(
                        "COMPLETE WRITE TRANSACTION CAPTURED: ADDR=%h BEATS=%0d",
                        trans_collected.AWADDR,
                        expected_beats),
                        UVM_MEDIUM
                    );

                    // Send complete transaction to scoreboard
                    mon1_port.write(trans_collected);

                end

            end

        end

    endtask

endclass
