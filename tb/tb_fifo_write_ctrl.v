`timescale 1ns / 1ps

module tb_fifo_write_ctrl;

    parameter ADDR_WIDTH = 4;
    parameter PTR_WIDTH  = ADDR_WIDTH + 1;

    reg                  wr_clk;
    reg                  wr_rst_n;
    reg                  wr_en;
    reg [PTR_WIDTH-1:0]  rd_ptr_gray_sync;

    wire [PTR_WIDTH-1:0] wr_ptr_bin;
    wire [PTR_WIDTH-1:0] wr_ptr_gray;
    wire                 full;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    fifo_write_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk           (wr_clk),
        .wr_rst_n         (wr_rst_n),
        .wr_en            (wr_en),
        .rd_ptr_gray_sync (rd_ptr_gray_sync),
        .wr_ptr_bin       (wr_ptr_bin),
        .wr_ptr_gray      (wr_ptr_gray),
        .full             (full)
    );

    // ------------------------------------------------------------
    // 100 MHz write clock
    // ------------------------------------------------------------

    initial begin
        wr_clk = 1'b0;
        forever #5 wr_clk = ~wr_clk;
    end

    // ------------------------------------------------------------
    // Binary -> Gray function
    // ------------------------------------------------------------

    function [PTR_WIDTH-1:0] binary_to_gray;
        input [PTR_WIDTH-1:0] binary;

        begin
            binary_to_gray = binary ^ (binary >> 1);
        end
    endfunction

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------

    initial begin

        wr_rst_n         = 1'b0;
        wr_en            = 1'b0;
        rd_ptr_gray_sync = 5'b00000;

        // ========================================================
        // TEST 1: RESET
        // ========================================================

        #12;

        if (wr_ptr_bin !== 5'b00000) begin
            $display("ERROR: Write binary pointer reset failed.");
            $stop;
        end

        if (wr_ptr_gray !== 5'b00000) begin
            $display("ERROR: Write Gray pointer reset failed.");
            $stop;
        end

        if (full !== 1'b0) begin
            $display("ERROR: FULL should be 0 after reset.");
            $stop;
        end

        $display("PASS: Reset test");

        wr_rst_n = 1'b1;

        // ========================================================
        // TEST 2: WRITE DISABLED
        // ========================================================

        wr_en = 1'b0;

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b00000) begin
            $display("ERROR: Pointer changed with wr_en = 0.");
            $stop;
        end

        $display("PASS: Write disabled test");

        // ========================================================
        // TEST 3: SINGLE WRITE
        // ========================================================

        wr_en = 1'b1;

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b00001) begin
            $display("ERROR: Single write failed.");
            $stop;
        end

        if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
            $display("ERROR: Gray pointer incorrect.");
            $stop;
        end

        $display("PASS: Single write test");

        // ========================================================
        // TEST 4: MULTIPLE WRITES
        // ========================================================

        repeat (4) begin
            @(posedge wr_clk);
            #1;

            if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch.");
                $stop;
            end
        end

        if (wr_ptr_bin !== 5'b00101) begin
            $display("ERROR: Multiple write count incorrect.");
            $stop;
        end

        $display("PASS: Multiple write test");

        // ========================================================
        // TEST 5: FILL FIFO
        //
        // Current pointer = 5
        // 11 additional writes -> pointer = 16
        // ========================================================

        repeat (11) begin
            @(posedge wr_clk);
            #1;

            if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch while filling.");
                $stop;
            end
        end

        if (wr_ptr_bin !== 5'b10000) begin
            $display("ERROR: Pointer did not reach 16.");
            $stop;
        end

        if (full !== 1'b1) begin
            $display("ERROR: FULL did not assert at depth 16.");
            $stop;
        end

        $display("PASS: FIFO FULL detection test");

        // ========================================================
        // TEST 6: WRITE WHILE FULL
        // ========================================================

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b10000) begin
            $display("ERROR: Pointer advanced while FULL.");
            $stop;
        end

        if (full !== 1'b1) begin
            $display("ERROR: FULL unexpectedly cleared.");
            $stop;
        end

        $display("PASS: FULL protection test");

        // ========================================================
        // TEST 7: SIMULATE ONE READ
        //
        // Read pointer:
        // binary 00000 -> 00001
        // Gray   00000 -> 00001
        //
        // One location becomes free.
        // ========================================================

        rd_ptr_gray_sync = 5'b00001;
        wr_en = 1'b0;

        @(posedge wr_clk);
        #1;

        if (full !== 1'b0) begin
            $display("ERROR: FULL did not clear after read pointer advanced.");
            $stop;
        end

        if (wr_ptr_bin !== 5'b10000) begin
            $display("ERROR: Write pointer changed unexpectedly.");
            $stop;
        end

        $display("PASS: FULL clearing test");

        // ========================================================
        // TEST 8: WRITE AFTER FULL CLEARS
        // ========================================================

        wr_en = 1'b1;

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b10001) begin
            $display("ERROR: Write did not resume after FULL cleared.");
            $stop;
        end

        if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
            $display("ERROR: Gray pointer incorrect after write.");
            $stop;
        end

        // Since read pointer = 1 and write pointer = 17,
        // FIFO is full again.

        if (full !== 1'b1) begin
            $display("ERROR: FULL did not reassert at distance 16.");
            $stop;
        end

        $display("PASS: Write-after-FULL test");

        // ========================================================
        // TEST 9: CREATE SPACE AND TEST POINTER WRAP
        //
        // Move read pointer forward to binary 17.
        // Binary 17 -> Gray 11001
        //
        // Current write pointer is also 17.
        // Therefore FIFO is empty, not full.
        // ========================================================

        rd_ptr_gray_sync = 5'b11001;
        wr_en = 1'b0;

        @(posedge wr_clk);
        #1;

        if (full !== 1'b0) begin
            $display("ERROR: FULL should clear when pointers are equal.");
            $stop;
        end

        if (wr_ptr_bin !== 5'b10001) begin
            $display("ERROR: Write pointer changed unexpectedly.");
            $stop;
        end

        $display("PASS: Pointer-space recovery test");

        // ========================================================
        // TEST 10: WRITE UNTIL BINARY POINTER WRAPS
        //
        // 17 -> 31 requires 14 writes
        // 31 -> 0 requires one more write
        // ========================================================

        repeat (14) begin
            @(posedge wr_clk);
            #1;

            if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch before wrap.");
                $stop;
            end
        end

        if (wr_ptr_bin !== 5'b11111) begin
            $display("ERROR: Pointer did not reach 31.");
            $stop;
        end

        // One more write: 31 -> 0

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b00000) begin
            $display("ERROR: Binary pointer did not wrap to 0.");
            $stop;
        end

        if (wr_ptr_gray !== 5'b00000) begin
            $display("ERROR: Gray pointer incorrect after wrap.");
            $stop;
        end

        $display("PASS: Pointer wraparound test");

        // ========================================================
        // ALL TESTS PASSED
        // ========================================================

        $display("-----------------------------------------------");
        $display("ALL WRITE CONTROLLER TESTS PASSED");
        $display("-----------------------------------------------");

        $finish;

    end

endmodule