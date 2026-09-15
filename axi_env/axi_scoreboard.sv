
`uvm_analysis_imp_decl(_master)
`uvm_analysis_imp_decl(_slave)

class axi_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axi_scoreboard)

    //============================================================
    // Analysis ports
    //============================================================

    uvm_analysis_imp_master #(axi_seq_item, axi_scoreboard) master_export;
    uvm_analysis_imp_slave  #(axi_seq_item, axi_scoreboard) slave_export;


    //============================================================
    // Reference memory
    //============================================================

    bit [7:0] reference_memory [longint unsigned];


    //============================================================
    // WSTRB information for each beat address
    // Used to reconstruct expected RDATA
    //============================================================

    bit [`DATA_WIDTH/8-1:0] reference_wstrb [longint unsigned];


    //============================================================
    // Pending read transactions
    //============================================================

    axi_seq_item read_queue[$];


    //============================================================
    // Constructor
    //============================================================

    function new(
        string name = "axi_scoreboard",
        uvm_component parent = null
    );

        super.new(name, parent);

        master_export = new("master_export", this);
        slave_export  = new("slave_export", this);

    endfunction


    //============================================================
    // MASTER MONITOR
    //============================================================

    function void write_master(axi_seq_item tr);

        if (tr == null)
            return;


        //========================================================
        // WRITE TRANSACTION
        //========================================================

        if (tr.AWVALID) begin

            process_write(tr);

        end


        //========================================================
        // READ ADDRESS TRANSACTION
        //========================================================

        if (tr.ARVALID) begin

            process_read_request(tr);

        end

    endfunction


    //============================================================
    // SLAVE MONITOR
    //============================================================

    function void write_slave(axi_seq_item tr);

        if (tr == null)
            return;

        compare_read_response(tr);

    endfunction


    //============================================================
    // PROCESS WRITE
    //============================================================

    function void process_write(axi_seq_item tr);

        int beat;
        int lane;

        int beats;
        int bus_bytes;

        int byte_index;

        longint unsigned beat_addr;
        longint unsigned byte_addr;


        beats    = tr.AWLEN + 1;
        bus_bytes = `DATA_WIDTH / 8;


        `uvm_info(
            "SCOREBOARD",
            $sformatf(
                "WRITE: ADDR=%08h ID=%0d LEN=%0d SIZE=%0d BURST=%0d",
                tr.AWADDR,
                tr.AWID,
                tr.AWLEN,
                tr.AWSIZE,
                tr.AWBURST
            ),
            UVM_MEDIUM
        );


        //========================================================
        // Process every beat
        //========================================================

        for (beat = 0; beat < beats; beat++) begin

            beat_addr = get_burst_address(
                tr.AWADDR,
                beat,
                beats,
                (1 << tr.AWSIZE),
                tr.AWBURST
            );


            //====================================================
            // Save WSTRB for this beat
            //====================================================

            reference_wstrb[beat_addr] = tr.WSTRB[beat];


            //====================================================
            // Store valid bytes into reference memory
            //
            // Enabled WSTRB lanes are stored sequentially
            // starting from beat_addr.
            //====================================================

            byte_index = 0;

            for (lane = 0; lane < bus_bytes; lane++) begin

                if (tr.WSTRB[beat][lane]) begin

                    byte_addr = beat_addr + byte_index;

                    reference_memory[byte_addr] =
                        tr.WDATA[beat][lane*8 +: 8];

                    byte_index++;

                end

            end


            `uvm_info(
                "SCOREBOARD",
                $sformatf(
                    "WRITE BEAT=%0d ADDR=%08h DATA=%08h WSTRB=%b",
                    beat,
                    beat_addr,
                    tr.WDATA[beat],
                    tr.WSTRB[beat]
                ),
                UVM_HIGH
            );

        end

    endfunction


    //============================================================
    // PROCESS READ REQUEST
    //============================================================

    function void process_read_request(axi_seq_item tr);

        axi_seq_item read_tr;


        read_tr =
            axi_seq_item::type_id::create("read_tr");


        //========================================================
        // Copy READ address information
        //========================================================

        read_tr.ARVALID = tr.ARVALID;
        read_tr.ARID    = tr.ARID;
        read_tr.ARADDR  = tr.ARADDR;
        read_tr.ARLEN   = tr.ARLEN;
        read_tr.ARSIZE  = tr.ARSIZE;
        read_tr.ARBURST = tr.ARBURST;


        //========================================================
        // Store expected read
        //========================================================

        read_queue.push_back(read_tr);


        `uvm_info(
            "SCOREBOARD",
            $sformatf(
                "READ REQUEST: ADDR=%08h ID=%0d LEN=%0d SIZE=%0d BURST=%0d",
                tr.ARADDR,
                tr.ARID,
                tr.ARLEN,
                tr.ARSIZE,
                tr.ARBURST
            ),
            UVM_MEDIUM
        );

    endfunction


    //============================================================
    // COMPARE READ RESPONSE
    //============================================================

    function void compare_read_response(axi_seq_item actual);

        axi_seq_item expected;

        bit [`DATA_WIDTH-1:0] expected_data;

        int beat;
        int lane;
        int byte_index;

        int beats;
        int bus_bytes;

        longint unsigned beat_addr;
        longint unsigned byte_addr;


        //========================================================
        // Check expected READ exists
        //========================================================

        if (read_queue.size() == 0) begin

            `uvm_error(
                "SCOREBOARD",
                "Received READ response without READ request"
            );

            return;

        end


        //========================================================
        // Get oldest READ
        //========================================================

        expected = read_queue.pop_front();


        beats     = expected.ARLEN + 1;
        bus_bytes = `DATA_WIDTH / 8;


        //========================================================
        // Check RID
        //========================================================

        if (actual.RID != expected.ARID) begin

            `uvm_error(
                "SCOREBOARD",
                $sformatf(
                    "RID ERROR: Expected=%0d Actual=%0d",
                    expected.ARID,
                    actual.RID
                )
            );

        end
        else begin

            `uvm_info(
                "SCOREBOARD",
                $sformatf(
                    "RID MATCH: %0d",
                    actual.RID
                ),
                UVM_MEDIUM
            );

        end


        //========================================================
        // Check every RDATA beat
        //========================================================

        for (beat = 0; beat < beats; beat++) begin


            //====================================================
            // Calculate address
            //====================================================

            beat_addr = get_burst_address(
                expected.ARADDR,
                beat,
                beats,
                (1 << expected.ARSIZE),
                expected.ARBURST
            );


            expected_data = '0;


            //====================================================
            // Reconstruct expected RDATA
            //
            // Example:
            //
            // WDATA  = 4c5e7793
            // WSTRB  = 1100
            //
            // Stored bytes:
            //
            // byte0 = 4c
            // byte1 = 5e
            //
            // Expected RDATA:
            //
            // 4c5e0000
            //====================================================

            if (reference_wstrb.exists(beat_addr)) begin

                byte_index = 0;

                for (lane = 0; lane < bus_bytes; lane++) begin

                    if (reference_wstrb[beat_addr][lane]) begin

                        byte_addr = beat_addr + byte_index;


                        if (reference_memory.exists(byte_addr)) begin

                            expected_data[lane*8 +: 8] =
                                reference_memory[byte_addr];

                        end


                        byte_index++;

                    end

                end

            end


            //====================================================
            // Compare RDATA
            //====================================================

            if (actual.RDATA[beat] !== expected_data) begin

                `uvm_error(
                    "SCOREBOARD",
                    $sformatf(
                        "RDATA ERROR: BEAT=%0d ADDR=%08h EXPECTED=%08h ACTUAL=%08h",
                        beat,
                        beat_addr,
                        expected_data,
                        actual.RDATA[beat]
                    )
                );

            end
            else begin

                `uvm_info(
                    "SCOREBOARD",
                    $sformatf(
                        "RDATA MATCH: BEAT=%0d ADDR=%08h DATA=%08h",
                        beat,
                        beat_addr,
                        actual.RDATA[beat]
                    ),
                    UVM_MEDIUM
                );

            end

        end


        //========================================================
        // Check RRESP
        //========================================================

        for (beat = 0; beat < beats; beat++) begin

            if (actual.RRESP[beat] != 2'b00) begin

                `uvm_error(
                    "SCOREBOARD",
                    $sformatf(
                        "RRESP ERROR: BEAT=%0d RRESP=%02b",
                        beat,
                        actual.RRESP[beat]
                    )
                );

            end

        end


        //========================================================
        // Check RLAST
        //========================================================

        for (beat = 0; beat < beats; beat++) begin

            if (beat == beats-1) begin

                if (actual.RLAST[beat] != 1'b1) begin

                    `uvm_error(
                        "SCOREBOARD",
                        $sformatf(
                            "RLAST ERROR: Final beat %0d should have RLAST=1",
                            beat
                        )
                    );

                end

            end
            else begin

                if (actual.RLAST[beat] != 1'b0) begin

                    `uvm_error(
                        "SCOREBOARD",
                        $sformatf(
                            "RLAST ERROR: Beat %0d should have RLAST=0",
                            beat
                        )
                    );

                end

            end

        end


        `uvm_info(
            "SCOREBOARD",
            $sformatf(
                "READ CHECK COMPLETE: ADDR=%08h ID=%0d BEATS=%0d",
                expected.ARADDR,
                expected.ARID,
                beats
            ),
            UVM_LOW
        );

    endfunction


    //============================================================
    // BURST ADDRESS CALCULATION
    //============================================================

    function automatic longint unsigned get_burst_address(
        longint unsigned start_addr,
        int beat,
        int beats,
        int bytes_per_beat,
        bit [1:0] burst_type
    );

        longint unsigned addr;

        longint unsigned wrap_size;
        longint unsigned wrap_base;


        case (burst_type)


            //====================================================
            // FIXED
            //====================================================

            2'b00: begin

                addr = start_addr;

            end


            //====================================================
            // INCR
            //====================================================

            2'b01: begin

                addr =
                    start_addr +
                    (beat * bytes_per_beat);

            end


            //====================================================
            // WRAP
            //====================================================

            2'b10: begin

                wrap_size =
                    beats * bytes_per_beat;

                wrap_base =
                    (start_addr / wrap_size) *
                    wrap_size;

                addr =
                    wrap_base +
                    ((start_addr - wrap_base +
                      beat * bytes_per_beat) %
                     wrap_size);

            end


            //====================================================
            // RESERVED
            //====================================================

            default: begin

                addr = start_addr;

            end

        endcase


        return addr;

    endfunction


    //============================================================
    // CHECK PHASE
    //============================================================

    function void check_phase(uvm_phase phase);

        super.check_phase(phase);


        if (read_queue.size() != 0) begin

            `uvm_error(
                "SCOREBOARD",
                $sformatf(
                    "Pending READ transactions = %0d",
                    read_queue.size()
                )
            );

        end

    endfunction


    //============================================================
    // REPORT PHASE
    //============================================================

    function void report_phase(uvm_phase phase);

        super.report_phase(phase);

        `uvm_info(
            "SCOREBOARD",
            "========================================",
            UVM_LOW
        );

        `uvm_info(
            "SCOREBOARD",
            "       AXI SCOREBOARD COMPLETE",
            UVM_LOW
        );

        `uvm_info(
            "SCOREBOARD",
            "========================================",
            UVM_LOW
        );

    endfunction

endclass

