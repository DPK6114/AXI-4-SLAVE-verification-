class axi_slave_monitor extends uvm_monitor;

    `uvm_component_utils(axi_slave_monitor)

    //============================================================
    // Virtual interface
    //============================================================
    virtual axi4_intf vif;

    //============================================================
    // Analysis port
    //============================================================
    uvm_analysis_port #(axi_seq_item) mon_port;

    //============================================================
    // Transaction
    //============================================================
    axi_seq_item trans_collected;

    //============================================================
    // Variables
    //============================================================
    int expected_beats;
    int beat_count;

    //============================================================
    // Constructor
    //============================================================
    function new(
        string name = "axi_slave_monitor",
        uvm_component parent
    );

        super.new(name, parent);

        mon_port = new("mon_port", this);

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
                "SLAVE_MONITOR",
                "Virtual interface is not connected"
            );

        end

    endfunction


    //============================================================
    // RUN PHASE
    //============================================================
    task run_phase(uvm_phase phase);

        forever begin

            //========================================================
            // Wait for AR handshake
            //========================================================

            @(posedge vif.ACLK);
            #1step;

            if (vif.ARVALID && vif.ARREADY) begin

                //====================================================
                // Create transaction
                //====================================================

                trans_collected =
                    axi_seq_item::type_id::create(
                        "trans_collected"
                    );


                //====================================================
                // Capture AR channel
                //====================================================

                trans_collected.ARVALID  = vif.ARVALID;
                trans_collected.ARREADY  = vif.ARREADY;

                trans_collected.ARID     = vif.ARID;
                trans_collected.ARADDR   = vif.ARADDR;
                trans_collected.ARLEN    = vif.ARLEN;
                trans_collected.ARSIZE   = vif.ARSIZE;
                trans_collected.ARBURST  = vif.ARBURST;

                trans_collected.ARLOCK   = vif.ARLOCK;
                trans_collected.ARCACHE  = vif.ARCACHE;
                trans_collected.ARPROT   = vif.ARPROT;
                trans_collected.ARQOS    = vif.ARQOS;
                trans_collected.ARREGION = vif.ARREGION;
                trans_collected.ARUSER   = vif.ARUSER;


                //====================================================
                // AXI burst length
                //====================================================

                expected_beats =
                    trans_collected.ARLEN + 1;

                beat_count = 0;


                //====================================================
                // Allocate R arrays
                //====================================================

                trans_collected.RDATA =
                    new[expected_beats];

                trans_collected.RRESP =
                    new[expected_beats];

                trans_collected.RLAST =
                    new[expected_beats];


                `uvm_info(
                    "SLAVE_MONITOR_AR",
                    $sformatf(
                        "AR HANDSHAKE: ARVALID=%0b ARREADY=%0b ARID=%0d ARADDR=%h ARLEN=%0d ARSIZE=%0d ARBURST=%0d",
                        vif.ARVALID,
                        vif.ARREADY,
                        vif.ARID,
                        vif.ARADDR,
                        vif.ARLEN,
                        vif.ARSIZE,
                        vif.ARBURST
                    ),
                    UVM_MEDIUM
                );


                //====================================================
                // R CHANNEL
                //====================================================

                while (beat_count < expected_beats) begin

                    @(posedge vif.ACLK);
                    #1step;

                    if (vif.RVALID && vif.RREADY) begin

                        //================================================
                        // IMPORTANT FIX:
                        // Capture RID
                        //================================================

                        trans_collected.RID =
                            vif.RID;


                        //================================================
                        // Capture RDATA
                        //================================================

                        trans_collected.RDATA[beat_count] =
                            vif.RDATA;


                        //================================================
                        // Capture RRESP
                        //================================================

                        trans_collected.RRESP[beat_count] =
                            vif.RRESP;


                        //================================================
                        // Capture RLAST
                        //================================================

                        trans_collected.RLAST[beat_count] =
                            vif.RLAST;


                        `uvm_info(
                            "SLAVE_MONITOR_R",
                            $sformatf(
                                "R HANDSHAKE: BEAT=%0d/%0d RID=%0d RDATA=%h RRESP=%0d RLAST=%0b",
                                beat_count,
                                expected_beats-1,
                                vif.RID,
                                vif.RDATA,
                                vif.RRESP,
                                vif.RLAST
                            ),
                            UVM_MEDIUM
                        );


                        //================================================
                        // Check RLAST
                        //================================================

                        if (vif.RLAST) begin

                            if (beat_count != expected_beats-1) begin

                                `uvm_error(
                                    "SLAVE_MONITOR",
                                    $sformatf(
                                        "EARLY RLAST: beat=%0d expected final beat=%0d",
                                        beat_count,
                                        expected_beats-1
                                    )
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
                        "SLAVE_MONITOR",
                        $sformatf(
                            "READ BURST INCOMPLETE: captured=%0d expected=%0d",
                            beat_count,
                            expected_beats
                        )
                    );

                end
                else begin

                    `uvm_info(
                        "SLAVE_MONITOR",
                        $sformatf(
                            "COMPLETE READ BURST CAPTURED: ARADDR=%h ARLEN=%0d BEATS=%0d RID=%0d",
                            trans_collected.ARADDR,
                            trans_collected.ARLEN,
                            expected_beats,
                            trans_collected.RID
                        ),
                        UVM_MEDIUM
                    );


                    //================================================
                    // Send complete R transaction to scoreboard
                    //================================================

                    mon_port.write(trans_collected);

                end

            end

        end

    endtask

endclass


