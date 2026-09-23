`timescale 1ns / 1ps

module tb_async_fifo;

    // ============================================================
    // PARAMETERS
    // ============================================================

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter FIFO_DEPTH = (1 << ADDR_WIDTH);

    // ============================================================
    // DUT INTERFACE
    // ============================================================

    reg                     wr_clk;
    reg                     wr_rst_n;
    reg                     wr_en;
    reg [DATA_WIDTH-1:0]    wr_data;
    wire                    full;

    reg                     rd_clk;
    reg                     rd_rst_n;
    reg                     rd_en;
    wire [DATA_WIDTH-1:0]   rd_data;
    wire                    empty;

    // ============================================================
    // DUT
    // ============================================================

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk  (wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .full    (full),

        .rd_clk  (rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .empty   (empty)
    );

    // ============================================================
    // WRITE CLOCK
    //
    // 10 ns period = 100 MHz
    // ============================================================

    initial begin
        wr_clk = 1'b0;

        forever #5 wr_clk = ~wr_clk;
    end

    // ============================================================
    // READ CLOCK
    //
    // 14 ns period ~= 71.43 MHz
    //
    // Deliberately different from write clock.
    // ============================================================

    initial begin
        rd_clk = 1'b0;

        forever #7 rd_clk = ~rd_clk;
    end

    // ============================================================
    // WRITE TASK
    // ============================================================

    task fifo_write;
        input [DATA_WIDTH-1:0] data;

        begin

            wr_data = data;
            wr_en   = 1'b1;

            @(posedge wr_clk);
            #1;

            wr_en = 1'b0;

        end
    endtask

    // ============================================================
    // READ TASK
    //
    // rd_data is registered in fifo_mem.
    // Therefore check it after the read clock edge.
    // ============================================================

    task fifo_read;
        input [DATA_WIDTH-1:0] expected;

        begin

            rd_en = 1'b1;

            @(posedge rd_clk);
            #1;

            if (rd_data !== expected) begin

                $display(
                    "ERROR: FIFO data mismatch. Expected=%02h Got=%02h Time=%0t",
                    expected,
                    rd_data,
                    $time
                );

                $stop;

            end

            rd_en = 1'b0;

        end
    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================

    integer i;

    initial begin

        // --------------------------------------------------------
        // INITIAL CONDITIONS
        // --------------------------------------------------------

        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;

        wr_en   = 1'b0;
        rd_en   = 1'b0;

        wr_data = 8'h00;

        // ========================================================
        // TEST 1: RESET
        // ========================================================

        #30;

        if (full !== 1'b0) begin
            $display("ERROR: FULL should be 0 after reset.");
            $stop;
        end

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY should be 1 after reset.");
            $stop;
        end

        $display("PASS: Reset test");

        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        // Give both domains time to leave reset.
        repeat (3) @(posedge wr_clk);
        repeat (3) @(posedge rd_clk);

        // ========================================================
        // TEST 2: WRITE SINGLE DATA
        // ========================================================

        fifo_write(8'hA1);

        // Allow write pointer to cross clock domains.
        repeat (4) @(posedge rd_clk);

        if (empty !== 1'b0) begin
            $display("ERROR: EMPTY did not clear after write.");
            $stop;
        end

        $display("PASS: Single write / EMPTY clearing test");

        // ========================================================
        // TEST 3: READ SINGLE DATA
        // ========================================================

        fifo_read(8'hA1);

        // Allow read pointer to update.
        repeat (4) @(posedge rd_clk);

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY did not assert after reading last item.");
            $stop;
        end

        $display("PASS: Single read / EMPTY assertion test");

        // ========================================================
        // TEST 4: UNDERFLOW PROTECTION
        // ========================================================

        rd_en = 1'b1;

        @(posedge rd_clk);
        #1;

        rd_en = 1'b0;

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY changed during underflow attempt.");
            $stop;
        end

        $display("PASS: Underflow protection test");

        // ========================================================
        // TEST 5: MULTIPLE DATA / FIFO ORDER
        //
        // Write:
        //
        // A0 A1 A2 A3 A4 A5 A6 A7
        //
        // Then read in exactly the same order.
        // ========================================================

        fifo_write(8'hA0);
        fifo_write(8'hA1);
        fifo_write(8'hA2);
        fifo_write(8'hA3);
        fifo_write(8'hA4);
        fifo_write(8'hA5);
        fifo_write(8'hA6);
        fifo_write(8'hA7);

        // Wait for write pointer synchronization.
        repeat (4) @(posedge rd_clk);

        if (empty !== 1'b0) begin
            $display("ERROR: FIFO still EMPTY after multiple writes.");
            $stop;
        end

        fifo_read(8'hA0);
        fifo_read(8'hA1);
        fifo_read(8'hA2);
        fifo_read(8'hA3);
        fifo_read(8'hA4);
        fifo_read(8'hA5);
        fifo_read(8'hA6);
        fifo_read(8'hA7);

        $display("PASS: FIFO ordering test");

        // ========================================================
        // TEST 6: FILL FIFO COMPLETELY
        //
        // FIFO depth = 16.
        //
        // We write exactly 16 entries.
        // ========================================================

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin

            fifo_write(8'h10 + i);

        end

        // FULL is generated in the write clock domain,
        // so one small delay is sufficient after the final
        // write edge.
        @(posedge wr_clk);
        #1;

        if (full !== 1'b1) begin
            $display("ERROR: FULL did not assert after 16 writes.");
            $stop;
        end

        $display("PASS: FIFO FULL detection test");

        // ========================================================
        // TEST 7: OVERFLOW PROTECTION
        //
        // FIFO is already full.
        //
        // This write must NOT be accepted.
        // ========================================================

        wr_data = 8'hFF;
        wr_en   = 1'b1;

        @(posedge wr_clk);
        #1;

        wr_en = 1'b0;

        if (full !== 1'b1) begin
            $display("ERROR: FULL cleared during overflow attempt.");
            $stop;
        end

        $display("PASS: Overflow protection test");

        // ========================================================
        // TEST 8: WAIT FOR READ DOMAIN TO SEE DATA
        // ========================================================

        repeat (5) @(posedge rd_clk);

        if (empty !== 1'b0) begin
            $display("ERROR: READ domain still reports EMPTY.");
            $stop;
        end

        // ========================================================
        // TEST 9: DRAIN COMPLETE FIFO
        //
        // Expected sequence:
        //
        // 10 11 12 ... 1F
        //
        // The 16th read should make EMPTY assert.
        // ========================================================

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin

            fifo_read(8'h10 + i);

        end

        repeat (4) @(posedge rd_clk);

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY did not assert after draining FIFO.");
            $stop;
        end

        $display("PASS: FIFO full-to-empty drain test");

        // ========================================================
        // TEST 10: SECOND UNDERFLOW TEST
        // ========================================================

        rd_en = 1'b1;

        @(posedge rd_clk);
        #1;

        rd_en = 1'b0;

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY changed during second underflow attempt.");
            $stop;
        end

        $display("PASS: Second underflow protection test");

        // ========================================================
        // TEST 11: POINTER / MEMORY WRAPAROUND
        //
        // The pointers have now crossed the 16-entry boundary.
        //
        // Write another complete FIFO.
        //
        // This verifies that the memory addresses correctly
        // wrap from:
        //
        // 1111 -> 0000
        // ========================================================

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin

            fifo_write(8'h80 + i);

        end

        @(posedge wr_clk);
        #1;

        if (full !== 1'b1) begin
            $display("ERROR: FULL did not assert during second fill.");
            $stop;
        end

        repeat (5) @(posedge rd_clk);

        // ========================================================
        // TEST 12: READ SECOND FIFO CONTENTS
        // ========================================================

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin

            fifo_read(8'h80 + i);

        end

        repeat (4) @(posedge rd_clk);

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY did not assert after second drain.");
            $stop;
        end

        $display("PASS: Pointer and memory wraparound test");

        // ========================================================
        // ALL TESTS PASSED
        // ========================================================

        $display("");
        $display("================================================");
        $display("       ALL ASYNCHRONOUS FIFO TESTS PASSED");
        $display("================================================");

        $finish;

    end

endmodule