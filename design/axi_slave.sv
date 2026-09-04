

module axi4_slave #(
    parameter int DATA_WIDTH    = 32,
    parameter int ADDR_WIDTH    = 32,
    parameter int ID_WIDTH      = 4,
    parameter int USER_WIDTH    = 1,

    parameter int MEM_BYTES     = 64*1024,

    parameter int AW_FIFO_DEPTH = 8,
    parameter int AR_FIFO_DEPTH = 8
)(
    input  logic                         ACLK,
    input  logic                         ARESETn,

    // ============================================================
    // WRITE ADDRESS CHANNEL
    // ============================================================

    input  logic [ID_WIDTH-1:0]          AWID,
    input  logic [ADDR_WIDTH-1:0]        AWADDR,
    input  logic [7:0]                   AWLEN,
    input  logic [2:0]                   AWSIZE,
    input  logic [1:0]                   AWBURST,
    input  logic                         AWLOCK,
    input  logic [3:0]                   AWCACHE,
    input  logic [2:0]                   AWPROT,
    input  logic [3:0]                   AWQOS,
    input  logic [3:0]                   AWREGION,
    input  logic [USER_WIDTH-1:0]        AWUSER,

    input  logic                         AWVALID,
    output logic                         AWREADY,

    // ============================================================
    // WRITE DATA CHANNEL
    // ============================================================

    input  logic [DATA_WIDTH-1:0]        WDATA,
    input  logic [DATA_WIDTH/8-1:0]      WSTRB,
    input  logic                         WLAST,
    input  logic [USER_WIDTH-1:0]        WUSER,

    input  logic                         WVALID,
    output logic                         WREADY,

    // ============================================================
    // WRITE RESPONSE CHANNEL
    // ============================================================

    output logic [ID_WIDTH-1:0]          BID,
    output logic [1:0]                   BRESP,
    output logic [USER_WIDTH-1:0]        BUSER,

    output logic                         BVALID,
    input  logic                         BREADY,

    // ============================================================
    // READ ADDRESS CHANNEL
    // ============================================================

    input  logic [ID_WIDTH-1:0]          ARID,
    input  logic [ADDR_WIDTH-1:0]        ARADDR,
    input  logic [7:0]                   ARLEN,
    input  logic [2:0]                   ARSIZE,
    input  logic [1:0]                   ARBURST,
    input  logic                         ARLOCK,
    input  logic [3:0]                   ARCACHE,
    input  logic [2:0]                   ARPROT,
    input  logic [3:0]                   ARQOS,
    input  logic [3:0]                   ARREGION,
    input  logic [USER_WIDTH-1:0]        ARUSER,

    input  logic                         ARVALID,
    output logic                         ARREADY,

    // ============================================================
    // READ DATA CHANNEL
    // ============================================================

    output logic [ID_WIDTH-1:0]          RID,
    output logic [DATA_WIDTH-1:0]        RDATA,
    output logic [1:0]                   RRESP,
    output logic                         RLAST,
    output logic [USER_WIDTH-1:0]        RUSER,

    output logic                         RVALID,
    input  logic                         RREADY
);

    // ============================================================
    // CONSTANTS
    // ============================================================

    localparam int BUS_BYTES = DATA_WIDTH / 8;

    localparam logic [1:0] BURST_FIXED = 2'b00;
    localparam logic [1:0] BURST_INCR  = 2'b01;
    localparam logic [1:0] BURST_WRAP  = 2'b10;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_EXOKAY = 2'b01;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    localparam int AW_PTR_WIDTH =
        (AW_FIFO_DEPTH <= 1) ? 1 : $clog2(AW_FIFO_DEPTH);

    localparam int AR_PTR_WIDTH =
        (AR_FIFO_DEPTH <= 1) ? 1 : $clog2(AR_FIFO_DEPTH);

    localparam int AW_COUNT_WIDTH =
        (AW_FIFO_DEPTH <= 1) ? 1 : $clog2(AW_FIFO_DEPTH + 1);

    localparam int AR_COUNT_WIDTH =
        (AR_FIFO_DEPTH <= 1) ? 1 : $clog2(AR_FIFO_DEPTH + 1);

    // ============================================================
    // ADDRESS COMMAND STRUCTURE
    // ============================================================

    typedef struct packed {

        logic [ID_WIDTH-1:0]       id;
        logic [ADDR_WIDTH-1:0]     addr;
        logic [7:0]                len;
        logic [2:0]                size;
        logic [1:0]                burst;
        logic                      lock;

        logic [3:0]                cache;
        logic [2:0]                prot;
        logic [3:0]                qos;
        logic [3:0]                region;

        logic [USER_WIDTH-1:0]      user;

    } addr_cmd_t;

    // ============================================================
    // MEMORY
    // ============================================================

    logic [7:0] mem [0:MEM_BYTES-1];

    // ============================================================
    // AW FIFO
    // ============================================================

    addr_cmd_t aw_fifo [0:AW_FIFO_DEPTH-1];

    logic [AW_PTR_WIDTH-1:0] aw_wr_ptr;
    logic [AW_PTR_WIDTH-1:0] aw_rd_ptr;

    logic [AW_COUNT_WIDTH-1:0] aw_count;

    logic aw_push;
    logic aw_pop;

    // ============================================================
    // AR FIFO
    // ============================================================

    addr_cmd_t ar_fifo [0:AR_FIFO_DEPTH-1];

    logic [AR_PTR_WIDTH-1:0] ar_wr_ptr;
    logic [AR_PTR_WIDTH-1:0] ar_rd_ptr;

    logic [AR_COUNT_WIDTH-1:0] ar_count;

    logic ar_push;
    logic ar_pop;

    // ============================================================
    // WRITE TRANSACTION STATE
    // ============================================================

    logic                     wr_active;

    logic [ID_WIDTH-1:0]      wr_id;
    logic [ADDR_WIDTH-1:0]    wr_addr;
    logic [7:0]               wr_len;
    logic [2:0]               wr_size;
    logic [1:0]               wr_burst;
    logic                     wr_lock;
    logic [USER_WIDTH-1:0]    wr_user;

    logic [8:0]               wr_beat;

    // Once a burst is invalid, all remaining beats return SLVERR.
    logic                     wr_error;

    // ============================================================
    // READ TRANSACTION STATE
    // ============================================================

    logic                     rd_active;

    logic [ID_WIDTH-1:0]      rd_id;
    logic [ADDR_WIDTH-1:0]    rd_addr;
    logic [7:0]               rd_len;
    logic [2:0]               rd_size;
    logic [1:0]               rd_burst;
    logic                     rd_lock;
    logic [USER_WIDTH-1:0]    rd_user;

    logic [8:0]               rd_beat;

    logic                     rd_error;

    // ============================================================
    // EXCLUSIVE ACCESS MONITOR
    // ============================================================

    logic                     excl_valid;
    logic [ID_WIDTH-1:0]      excl_id;
    logic [ADDR_WIDTH-1:0]    excl_addr;
    logic [2:0]               excl_size;

    // ============================================================
    // COMBINATIONAL WRITE INFORMATION
    // ============================================================

    logic [ADDR_WIDTH-1:0]    wr_transfer_bytes;
    logic [ADDR_WIDTH-1:0]    wr_offset;

    logic                     wr_current_bad;
    logic                     wr_exclusive_match;

    logic [ADDR_WIDTH-1:0]    wr_next_addr;

    // ============================================================
    // COMBINATIONAL READ INFORMATION
    // ============================================================

    logic [ADDR_WIDTH-1:0]    rd_transfer_bytes;
    logic [ADDR_WIDTH-1:0]    rd_offset;

    logic                     rd_current_bad;

    logic [ADDR_WIDTH-1:0]    rd_next_addr;

    logic [DATA_WIDTH-1:0]    rd_data_next;

    // ============================================================
    // TEMPORARY LOOP VARIABLE
    // ============================================================

    integer i;

    // ============================================================
    // FUNCTION:
    // BYTES PER AXI SIZE
    //
    // SIZE encoding:
    //
    // 000 -> 1 byte
    // 001 -> 2 bytes
    // 010 -> 4 bytes
    // 011 -> 8 bytes
    // ...
    // ============================================================

    function automatic int unsigned get_transfer_bytes(
        input logic [2:0] size
    );

        begin

            if (size <= 3'd5)
                get_transfer_bytes = (1 << size);
            else
                get_transfer_bytes = 0;

        end

    endfunction

    // ============================================================
    // FUNCTION:
    // SIZE VALIDATION
    // ============================================================

    function automatic logic valid_size(
        input logic [2:0] size
    );

        int unsigned nbytes;

        begin

            nbytes = get_transfer_bytes(size);

            valid_size =
                (nbytes >= 1) &&
                (nbytes <= BUS_BYTES);

        end

    endfunction

    // ============================================================
    // FUNCTION:
    // BURST VALIDATION
    // ============================================================

    function automatic logic valid_burst(
        input logic [1:0] burst,
        input logic [7:0] len
    );

        begin

            case (burst)

                BURST_FIXED,
                BURST_INCR:
                    valid_burst = 1'b1;

                BURST_WRAP:
                    valid_burst =
                        (len == 8'd1)  ||   // 2 beats
                        (len == 8'd3)  ||   // 4 beats
                        (len == 8'd7)  ||   // 8 beats
                        (len == 8'd15);     // 16 beats

                default:
                    valid_burst = 1'b0;

            endcase

        end

    endfunction

    // ============================================================
    // FUNCTION:
    // WRAP ALIGNMENT
    //
    // Example:
    //
    // 4-beat burst, SIZE=2
    //
    // wrap bytes = 4 * 4 = 16
    //
    // address must be 16-byte aligned.
    // ============================================================

    function automatic logic valid_wrap_alignment(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [7:0]            len,
        input logic [2:0]            size
    );

        logic [ADDR_WIDTH-1:0] wrap_bytes;

        begin

            wrap_bytes =
                (len + 1) << size;

            valid_wrap_alignment =
                ((addr & (wrap_bytes - 1)) == 0);

        end

    endfunction

    // ============================================================
    // FUNCTION:
    // 4KB CHECK
    // ============================================================

    function automatic logic crosses_4kb(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [7:0]            len,
        input logic [2:0]            size,
        input logic [1:0]            burst
    );

        logic [ADDR_WIDTH-1:0] total_bytes;

        logic [ADDR_WIDTH-1:0] last_addr;

        logic [ADDR_WIDTH-1:0] wrap_base;
        logic [ADDR_WIDTH-1:0] wrap_last;

        begin

            total_bytes =
                (len + 1) << size;

            case (burst)

                BURST_WRAP: begin

                    wrap_base =
                        addr & ~(total_bytes - 1);

                    wrap_last =
                        wrap_base + total_bytes - 1;

                    crosses_4kb =
                        (wrap_base[ADDR_WIDTH-1:12] !=
                         wrap_last[ADDR_WIDTH-1:12]);

                end

                default: begin

                    last_addr =
                        addr + total_bytes - 1;

                    crosses_4kb =
                        (addr[ADDR_WIDTH-1:12] !=
                         last_addr[ADDR_WIDTH-1:12]);

                end

            endcase

        end

    endfunction

    // ============================================================
    // FUNCTION:
    // MEMORY RANGE CHECK
    // ============================================================

    function automatic logic outside_memory(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [7:0]            len,
        input logic [2:0]            size,
        input logic [1:0]            burst
    );

        logic [ADDR_WIDTH-1:0] total_bytes;

        logic [ADDR_WIDTH-1:0] last_addr;

        logic [ADDR_WIDTH-1:0] wrap_base;
        logic [ADDR_WIDTH-1:0] wrap_last;

        begin

            total_bytes =
                (len + 1) << size;

            case (burst)

                BURST_WRAP: begin

                    wrap_base =
                        addr & ~(total_bytes - 1);

                    wrap_last =
                        wrap_base + total_bytes - 1;

                    outside_memory =
                        (wrap_base >= MEM_BYTES) ||
                        (wrap_last >= MEM_BYTES);

                end

                default: begin

                    last_addr =
                        addr + total_bytes - 1;

                    outside_memory =
                        (addr >= MEM_BYTES) ||
                        (last_addr >= MEM_BYTES);

                end

            endcase

        end

    endfunction

    // ============================================================
    // FUNCTION:
    // VALIDATE COMPLETE ADDRESS COMMAND
    // ============================================================

    function automatic logic invalid_command(
        input addr_cmd_t cmd
    );

        logic bad;

        begin

            bad = 1'b0;

            // SIZE
            if (!valid_size(cmd.size))
                bad = 1'b1;

            // BURST
            if (!valid_burst(cmd.burst, cmd.len))
                bad = 1'b1;

            // WRAP alignment
            if ((cmd.burst == BURST_WRAP) &&
                !valid_wrap_alignment(
                    cmd.addr,
                    cmd.len,
                    cmd.size
                ))
                bad = 1'b1;

            // 4KB rule
            if (crosses_4kb(
                    cmd.addr,
                    cmd.len,
                    cmd.size,
                    cmd.burst
                ))
                bad = 1'b1;

            // memory range
            if (outside_memory(
                    cmd.addr,
                    cmd.len,
                    cmd.size,
                    cmd.burst
                ))
                bad = 1'b1;

            // Exclusive transactions are single-beat.
            if (cmd.lock && (cmd.len != 0))
                bad = 1'b1;

            invalid_command = bad;

        end

    endfunction

    // ============================================================
    // FUNCTION:
    // NEXT BURST ADDRESS
    // ============================================================

    function automatic logic [ADDR_WIDTH-1:0] calculate_next_address(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [7:0]            len,
        input logic [2:0]            size,
        input logic [1:0]            burst
    );

        logic [ADDR_WIDTH-1:0] increment;
        logic [ADDR_WIDTH-1:0] wrap_bytes;
        logic [ADDR_WIDTH-1:0] wrap_base;
        logic [ADDR_WIDTH-1:0] wrap_limit;
        logic [ADDR_WIDTH-1:0] next_value;

        begin

            increment =
                get_transfer_bytes(size);

            wrap_bytes =
                (len + 1) << size;

            case (burst)

                BURST_FIXED: begin

                    calculate_next_address =
                        addr;

                end

                BURST_INCR: begin

                    calculate_next_address =
                        addr + increment;

                end

                BURST_WRAP: begin

                    wrap_base =
                        addr & ~(wrap_bytes - 1);

                    wrap_limit =
                        wrap_base + wrap_bytes;

                    next_value =
                        addr + increment;

                    if (next_value >= wrap_limit)
                        next_value =
                            wrap_base +
                            (next_value - wrap_limit);

                    calculate_next_address =
                        next_value;

                end

                default: begin

                    calculate_next_address =
                        addr;

                end

            endcase

        end

    endfunction

    // ============================================================
    // READY SIGNALS
    // ============================================================

    always_comb begin

        // AW FIFO can accept another address
        AWREADY =
            (aw_count < AW_FIFO_DEPTH);

        // AR FIFO can accept another address
        ARREADY =
            (ar_count < AR_FIFO_DEPTH);

        // W data accepted only for an active write.
        //
        // This keeps AW and W correctly associated.
        WREADY =
            wr_active &&
            !BVALID;

    end

    // ============================================================
    // FIFO HANDSHAKES
    // ============================================================

    always_comb begin

        aw_push =
            AWVALID &&
            AWREADY;

        ar_push =
            ARVALID &&
            ARREADY;

        aw_pop =
            !wr_active &&
            !BVALID &&
            (aw_count != 0);

        ar_pop =
            !rd_active &&
            !RVALID &&
            (ar_count != 0);

    end

    // ============================================================
    // WRITE COMBINATIONAL CALCULATIONS
    // ============================================================

    always_comb begin

        wr_transfer_bytes =
            get_transfer_bytes(wr_size);

        wr_offset =
            wr_addr % BUS_BYTES;

        wr_current_bad =
            wr_error;

        // Invalid SIZE
        if (!valid_size(wr_size))
            wr_current_bad = 1'b1;

        // Transfer must fit inside this bus beat.
        //
        // Example 32-bit bus:
        //
        // address = 0x103
        // SIZE    = 1 (2 bytes)
        //
        // bytes 0x103 and 0x104 would require two bus lanes/beat
        // boundaries, so this reference slave rejects it.
        if ((wr_offset + wr_transfer_bytes) > BUS_BYTES)
            wr_current_bad = 1'b1;

        // Memory range
        if ((wr_addr + wr_transfer_bytes) > MEM_BYTES)
            wr_current_bad = 1'b1;

        // WLAST must occur exactly on final beat.
        if ((wr_beat == wr_len) &&
            !WLAST)
            wr_current_bad = 1'b1;

        if ((wr_beat != wr_len) &&
            WLAST)
            wr_current_bad = 1'b1;

        // Exclusive reservation comparison.
        wr_exclusive_match =
            wr_lock &&
            excl_valid &&
            (excl_id   == wr_id) &&
            (excl_addr == wr_addr) &&
            (excl_size == wr_size);

        wr_next_addr =
            calculate_next_address(
                wr_addr,
                wr_len,
                wr_size,
                wr_burst
            );

    end

    // ============================================================
    // READ COMBINATIONAL CALCULATIONS
    // ============================================================

    always_comb begin

        rd_transfer_bytes =
            get_transfer_bytes(rd_size);

        rd_offset =
            rd_addr % BUS_BYTES;

        rd_current_bad =
            rd_error;

        // SIZE
        if (!valid_size(rd_size))
            rd_current_bad = 1'b1;

        // Must fit in current bus beat
        if ((rd_offset + rd_transfer_bytes) > BUS_BYTES)
            rd_current_bad = 1'b1;

        // Memory range
        if ((rd_addr + rd_transfer_bytes) > MEM_BYTES)
            rd_current_bad = 1'b1;

        rd_next_addr =
            calculate_next_address(
                rd_addr,
                rd_len,
                rd_size,
                rd_burst
            );

        // Default
        rd_data_next = '0;

        // Only generate data for a valid access.
        if (!rd_current_bad) begin
          int i;

            for (i = 0; i < BUS_BYTES; i = i + 1) begin

                if ((i >= rd_offset) &&
                    (i < (rd_offset + rd_transfer_bytes))) begin

                    rd_data_next[i*8 +: 8] =
                        mem[
                            rd_addr +
                            (i - rd_offset)
                        ];

                end

            end

        end

    end

    // ============================================================
    // MAIN SEQUENTIAL PROCESS
    // ============================================================

    always_ff @(posedge ACLK or negedge ARESETn) begin

        if (!ARESETn) begin

            // ====================================================
            // AW FIFO
            // ====================================================

            aw_wr_ptr <= '0;
            aw_rd_ptr <= '0;
            aw_count  <= '0;

            // ====================================================
            // AR FIFO
            // ====================================================

            ar_wr_ptr <= '0;
            ar_rd_ptr <= '0;
            ar_count  <= '0;

            // ====================================================
            // WRITE STATE
            // ====================================================

            wr_active <= 1'b0;

            wr_id     <= '0;
            wr_addr   <= '0;
            wr_len    <= '0;
            wr_size   <= '0;
            wr_burst  <= BURST_INCR;
            wr_lock   <= 1'b0;
            wr_user   <= '0;

            wr_beat   <= '0;
            wr_error  <= 1'b0;

            // ====================================================
            // READ STATE
            // ====================================================

            rd_active <= 1'b0;

            rd_id     <= '0;
            rd_addr   <= '0;
            rd_len    <= '0;
            rd_size   <= '0;
            rd_burst  <= BURST_INCR;
            rd_lock   <= 1'b0;
            rd_user   <= '0;

            rd_beat   <= '0;
            rd_error  <= 1'b0;

            // ====================================================
            // B CHANNEL
            // ====================================================

            BID    <= '0;
            BRESP  <= RESP_OKAY;
            BUSER  <= '0;
            BVALID <= 1'b0;

            // ====================================================
            // R CHANNEL
            // ====================================================

            RID    <= '0;
            RDATA  <= '0;
            RRESP  <= RESP_OKAY;
            RLAST  <= 1'b0;
            RUSER  <= '0;
            RVALID <= 1'b0;

            // ====================================================
            // EXCLUSIVE MONITOR
            // ====================================================

            excl_valid <= 1'b0;
            excl_id    <= '0;
            excl_addr  <= '0;
            excl_size  <= '0;

        end
        else begin

            // ====================================================
            // AW FIFO PUSH
            // ====================================================

            if (aw_push) begin

                aw_fifo[aw_wr_ptr].id     <= AWID;
                aw_fifo[aw_wr_ptr].addr   <= AWADDR;
                aw_fifo[aw_wr_ptr].len    <= AWLEN;
                aw_fifo[aw_wr_ptr].size   <= AWSIZE;
                aw_fifo[aw_wr_ptr].burst  <= AWBURST;
                aw_fifo[aw_wr_ptr].lock   <= AWLOCK;

                aw_fifo[aw_wr_ptr].cache  <= AWCACHE;
                aw_fifo[aw_wr_ptr].prot   <= AWPROT;
                aw_fifo[aw_wr_ptr].qos    <= AWQOS;
                aw_fifo[aw_wr_ptr].region <= AWREGION;

                aw_fifo[aw_wr_ptr].user   <= AWUSER;

                if (aw_wr_ptr == AW_FIFO_DEPTH-1)
                    aw_wr_ptr <= '0;
                else
                    aw_wr_ptr <= aw_wr_ptr + 1'b1;

            end

            // ====================================================
            // AR FIFO PUSH
            // ====================================================

            if (ar_push) begin

                ar_fifo[ar_wr_ptr].id     <= ARID;
                ar_fifo[ar_wr_ptr].addr   <= ARADDR;
                ar_fifo[ar_wr_ptr].len    <= ARLEN;
                ar_fifo[ar_wr_ptr].size   <= ARSIZE;
                ar_fifo[ar_wr_ptr].burst  <= ARBURST;
                ar_fifo[ar_wr_ptr].lock   <= ARLOCK;

                ar_fifo[ar_wr_ptr].cache  <= ARCACHE;
                ar_fifo[ar_wr_ptr].prot   <= ARPROT;
                ar_fifo[ar_wr_ptr].qos    <= ARQOS;
                ar_fifo[ar_wr_ptr].region <= ARREGION;

                ar_fifo[ar_wr_ptr].user   <= ARUSER;

                if (ar_wr_ptr == AR_FIFO_DEPTH-1)
                    ar_wr_ptr <= '0;
                else
                    ar_wr_ptr <= ar_wr_ptr + 1'b1;

            end

            // ====================================================
            // AW FIFO COUNT
            //
            // Handles:
            //
            // push only
            // pop only
            // push + pop
            // neither
            // ====================================================

            case ({aw_push, aw_pop})

                2'b10:
                    aw_count <= aw_count + 1'b1;

                2'b01:
                    aw_count <= aw_count - 1'b1;

                default:
                    aw_count <= aw_count;

            endcase

            // ====================================================
            // AR FIFO COUNT
            // ====================================================

            case ({ar_push, ar_pop})

                2'b10:
                    ar_count <= ar_count + 1'b1;

                2'b01:
                    ar_count <= ar_count - 1'b1;

                default:
                    ar_count <= ar_count;

            endcase

            // ====================================================
            // START WRITE TRANSACTION
            // ====================================================

            if (aw_pop) begin

                wr_id    <= aw_fifo[aw_rd_ptr].id;
                wr_addr  <= aw_fifo[aw_rd_ptr].addr;
                wr_len   <= aw_fifo[aw_rd_ptr].len;
                wr_size  <= aw_fifo[aw_rd_ptr].size;
                wr_burst <= aw_fifo[aw_rd_ptr].burst;
                wr_lock  <= aw_fifo[aw_rd_ptr].lock;
                wr_user  <= aw_fifo[aw_rd_ptr].user;

                wr_beat <= 9'd0;

                wr_error <=
                    invalid_command(
                        aw_fifo[aw_rd_ptr]
                    );

                wr_active <= 1'b1;

                if (aw_rd_ptr == AW_FIFO_DEPTH-1)
                    aw_rd_ptr <= '0;
                else
                    aw_rd_ptr <= aw_rd_ptr + 1'b1;

            end

            // ====================================================
            // WRITE DATA
            // ====================================================

            if (WVALID && WREADY) begin

                // ------------------------------------------------
                // Perform memory write.
                //
                // For normal write:
                //
                //     write memory
                //
                // For successful exclusive:
                //
                //     write memory
                //
                // For failed exclusive:
                //
                //     DO NOT write memory
                // ------------------------------------------------

                if (!wr_current_bad) begin

                    if (!wr_lock || wr_exclusive_match) begin

                        for (i = 0; i < BUS_BYTES; i = i + 1) begin

                            if ((i >= wr_offset) &&
                                (i < (wr_offset + wr_transfer_bytes)) &&
                                WSTRB[i]) begin

                                mem[
                                    wr_addr +
                                    (i - wr_offset)
                                ] <=
                                    WDATA[i*8 +: 8];

                            end

                        end

                    end

                end

                // ------------------------------------------------
                // Exclusive reservation invalidation
                //
                // Any successful normal write to the reserved
                // location breaks the reservation.
                // ------------------------------------------------

                if (!wr_lock &&
                    excl_valid &&
                    !wr_current_bad) begin

                    if ((wr_addr <= excl_addr) &&
                        ((wr_addr + wr_transfer_bytes) >
                         excl_addr)) begin

                        excl_valid <= 1'b0;

                    end

                end

                // ------------------------------------------------
                // Final write beat
                // ------------------------------------------------

                if (wr_beat == wr_len) begin

                    BID <= wr_id;

                    if (wr_current_bad) begin

                        BRESP <= RESP_SLVERR;

                    end
                    else if (wr_lock) begin

                        if (wr_exclusive_match)
                            BRESP <= RESP_EXOKAY;
                        else
                            BRESP <= RESP_OKAY;

                    end
                    else begin

                        BRESP <= RESP_OKAY;

                    end

                    BUSER <= wr_user;

                    BVALID <= 1'b1;

                    wr_active <= 1'b0;

                    // Exclusive write consumes reservation.
                    if (wr_lock)
                        excl_valid <= 1'b0;

                end
                else begin

                    // ------------------------------------------------
                    // Move to next write beat
                    // ------------------------------------------------

                    wr_addr <= wr_next_addr;

                    wr_beat <=
                        wr_beat + 1'b1;

                    if (wr_current_bad)
                        wr_error <= 1'b1;

                end

            end

            // ====================================================
            // B RESPONSE HANDSHAKE
            // ====================================================

            if (BVALID &&
                BREADY) begin

                BVALID <= 1'b0;

            end

            // ====================================================
            // START READ TRANSACTION
            // ====================================================

            if (ar_pop) begin

                rd_id    <= ar_fifo[ar_rd_ptr].id;
                rd_addr  <= ar_fifo[ar_rd_ptr].addr;
                rd_len   <= ar_fifo[ar_rd_ptr].len;
                rd_size  <= ar_fifo[ar_rd_ptr].size;
                rd_burst <= ar_fifo[ar_rd_ptr].burst;
                rd_lock  <= ar_fifo[ar_rd_ptr].lock;
                rd_user  <= ar_fifo[ar_rd_ptr].user;

                rd_beat <= 9'd0;

                rd_error <=
                    invalid_command(
                        ar_fifo[ar_rd_ptr]
                    );

                rd_active <= 1'b1;

                if (ar_rd_ptr == AR_FIFO_DEPTH-1)
                    ar_rd_ptr <= '0;
                else
                    ar_rd_ptr <= ar_rd_ptr + 1'b1;

            end

            // ====================================================
            // GENERATE READ RESPONSE
            //
            // RVALID is asserted and then held until RREADY.
            // ====================================================

            if (rd_active &&
                !RVALID) begin

                RID <= rd_id;

                RDATA <=
                    rd_data_next;

                RUSER <=
                    rd_user;

                if (rd_current_bad)
                    RRESP <= RESP_SLVERR;

                else if (rd_lock)
                    RRESP <= RESP_EXOKAY;

                else
                    RRESP <= RESP_OKAY;

                // ------------------------------------------------
                // CRITICAL RLAST CONDITION
                // ------------------------------------------------

                RLAST <=
                    (rd_beat == rd_len);

                RVALID <= 1'b1;

            end

            // ====================================================
            // READ RESPONSE HANDSHAKE
            // ====================================================

            if (RVALID &&
                RREADY) begin

                // ------------------------------------------------
                // FINAL BEAT
                // ------------------------------------------------

                if (rd_beat == rd_len) begin

                    rd_active <= 1'b0;

                    RVALID <= 1'b0;
                    RLAST  <= 1'b0;

                    // ------------------------------------------------
                    // Exclusive read establishes reservation.
                    // ------------------------------------------------

                    if (rd_lock &&
                        !rd_current_bad) begin

                        excl_valid <= 1'b1;

                        excl_id <=
                            rd_id;

                        excl_addr <=
                            rd_addr;

                        excl_size <=
                            rd_size;

                    end

                end

                // ------------------------------------------------
                // NON-FINAL BEAT
                // ------------------------------------------------

                else begin

                    rd_addr <=
                        rd_next_addr;

                    rd_beat <=
                        rd_beat + 1'b1;

                    RVALID <= 1'b0;
                    RLAST  <= 1'b0;

                end

            end

        end

    end

endmodule
