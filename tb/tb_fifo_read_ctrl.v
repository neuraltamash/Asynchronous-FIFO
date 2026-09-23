`timescale 1ns / 1ps

module tb_fifo_read_ctrl;

    parameter ADDR_WIDTH = 4;
    parameter PTR_WIDTH  = ADDR_WIDTH + 1;

    reg                  rd_clk;
    reg                  rd_rst_n;
    reg                  rd_en;

    // Represents the synchronized write pointer.
    reg [PTR_WIDTH-1:0]  wr_ptr_gray_sync;

    wire [PTR_WIDTH-1:0] rd_ptr_bin;
    wire [PTR_WIDTH-1:0] rd_ptr_gray;
    wire                 empty;

    // ============================================================
    // DUT
    // ============================================================

    fifo_read_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .rd_clk           (rd_clk),
        .rd_rst_n         (rd_rst_n),
        .rd_en            (rd_en),
        .wr_ptr_gray_sync (wr_ptr_gray_sync),
        .rd_ptr_bin       (rd_ptr_bin),
        .rd_ptr_gray      (rd_ptr_gray),
        .empty            (empty)
    );

    // ============================================================
    // READ CLOCK
    // 100 MHz -> 10 ns period
    // ============================================================

    initial begin
        rd_clk = 1'b0;
        forever #5 rd_clk = ~rd_clk;
    end

    // ============================================================
    // BINARY TO GRAY FUNCTION
    // ============================================================

    function [PTR_WIDTH-1:0] binary_to_gray;
        input [PTR_WIDTH-1:0] binary;

        begin
            binary_to_gray = binary ^ (binary >> 1);
        end
    endfunction

    // ============================================================
    // TEST SEQUENCE
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Initial conditions
        // --------------------------------------------------------

        rd_rst_n         = 1'b0;
        rd_en            = 1'b0;
        wr_ptr_gray_sync = 5'b00000;

        // ========================================================
        // TEST 1: RESET
        // ========================================================

        #12;

        if (rd_ptr_bin !== 5'b00000) begin
            $display("ERROR: Read binary pointer reset failed.");
            $stop;
        end

        if (rd_ptr_gray !== 5'b00000) begin
            $display("ERROR: Read Gray pointer reset failed.");
            $stop;
        end

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY should be 1 after reset.");
            $stop;
        end

        $display("PASS: Reset test");

        rd_rst_n = 1'b1;

        // ========================================================
        // TEST 2: READ WHILE EMPTY
        // ========================================================

        rd_en = 1'b1;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00000) begin
            $display("ERROR: Pointer advanced while EMPTY.");
            $stop;
        end

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY deasserted unexpectedly.");
            $stop;
        end

        $display("PASS: EMPTY protection test");

        // ========================================================
        // TEST 3: READ DISABLED
        // ========================================================

        rd_en            = 1'b0;
        wr_ptr_gray_sync = 5'b00001;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00000) begin
            $display("ERROR: Pointer changed with rd_en = 0.");
            $stop;
        end

        if (empty !== 1'b0) begin
            $display("ERROR: EMPTY did not clear when data became available.");
            $stop;
        end

        $display("PASS: Read disabled test");

        // ========================================================
        // TEST 4: SINGLE READ
        // ========================================================

        rd_en = 1'b1;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00001) begin
            $display("ERROR: Single read failed.");
            $stop;
        end

        if (rd_ptr_gray !== binary_to_gray(rd_ptr_bin)) begin
            $display("ERROR: Gray pointer incorrect after single read.");
            $stop;
        end

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY did not assert after consuming last item.");
            $stop;
        end

        $display("PASS: Single read / EMPTY assertion test");

        // ========================================================
        // TEST 5: CREATE MULTIPLE ITEMS
        //
        // Current read pointer = 1
        // Write pointer = 6
        //
        // Therefore five entries are available.
        // ========================================================

        wr_ptr_gray_sync = binary_to_gray(5'b00110);
        rd_en            = 1'b0;

        @(posedge rd_clk);
        #1;

        if (empty !== 1'b0) begin
            $display("ERROR: EMPTY asserted with unread data available.");
            $stop;
        end

        if (rd_ptr_bin !== 5'b00001) begin
            $display("ERROR: Read pointer changed unexpectedly.");
            $stop;
        end

        $display("PASS: Multiple-data availability test");

        // ========================================================
        // TEST 6: MULTIPLE READS
        //
        // Read pointer:
        //
        // 1 -> 2 -> 3 -> 4 -> 5
        //
        // One entry remains at address 5.
        // ========================================================

        rd_en = 1'b1;

        repeat (4) begin

            @(posedge rd_clk);
            #1;

            if (rd_ptr_gray !== binary_to_gray(rd_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch during reads.");
                $stop;
            end

        end

        if (rd_ptr_bin !== 5'b00101) begin
            $display("ERROR: Read pointer count incorrect.");
            $stop;
        end

        if (empty !== 1'b0) begin
            $display("ERROR: EMPTY asserted too early.");
            $stop;
        end

        $display("PASS: Multiple read test");

        // ========================================================
        // TEST 7: READ LAST AVAILABLE ITEM
        //
        // Current read pointer = 5
        // Write pointer = 6
        //
        // One item remains.
        // ========================================================

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00110) begin
            $display("ERROR: Last read did not increment pointer.");
            $stop;
        end

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY did not assert after last read.");
            $stop;
        end

        $display("PASS: Last-item / EMPTY transition test");

        // ========================================================
        // TEST 8: UNDERFLOW PROTECTION
        // ========================================================

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00110) begin
            $display("ERROR: Pointer advanced during underflow attempt.");
            $stop;
        end

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY deasserted during underflow attempt.");
            $stop;
        end

        $display("PASS: Underflow protection test");

        // ========================================================
        // TEST 9: MOVE TO POINTER WRAPAROUND REGION
        //
        // Current read pointer = 6.
        //
        // Set synchronized write pointer = 31.
        //
        // Number of valid reads:
        //
        // 31 - 6 = 25
        //
        // Therefore 25 reads are required to reach 31.
        // ========================================================

        wr_ptr_gray_sync = binary_to_gray(5'b11111);
        rd_en            = 1'b1;

        @(posedge rd_clk);
        #1;

        if (empty !== 1'b0) begin
            $display("ERROR: EMPTY asserted before wraparound test.");
            $stop;
        end

        // --------------------------------------------------------
        // 6 -> 31 requires 25 reads.
        // --------------------------------------------------------

        repeat (25) begin

            @(posedge rd_clk);
            #1;

            if (rd_ptr_gray !== binary_to_gray(rd_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch during wraparound.");
                $stop;
            end

        end

        if (rd_ptr_bin !== 5'b11111) begin
            $display("ERROR: Read pointer did not reach 31.");
            $stop;
        end

        if (rd_ptr_gray !== binary_to_gray(5'b11111)) begin
            $display("ERROR: Gray pointer incorrect at binary 31.");
            $stop;
        end

        $display("PASS: Pointer reached 31 test");

        // ========================================================
        // TEST 10: CREATE ONE VALID ENTRY ACROSS WRAP
        //
        // Current read pointer:
        //
        // rd_ptr = 31
        //
        // Move the synchronized write pointer to binary 32.
        //
        // Binary 32 using a 5-bit pointer:
        //
        // 32 = 1_00000
        //
        // Lower five bits = 00000
        //
        // Gray(32) = 00000
        //
        // Therefore:
        //
        // read pointer  = 31
        // write pointer = 32
        //
        // One entry is available.
        // ========================================================

        wr_ptr_gray_sync = 5'b00000;

        @(posedge rd_clk);
        #1;

        if (empty !== 1'b0) begin
            $display("ERROR: EMPTY asserted before wrapped read.");
            $stop;
        end

        $display("PASS: Wrapped entry availability test");

        // ========================================================
        // TEST 11: READ ACROSS POINTER WRAP
        //
        // 31 -> 0
        // ========================================================

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00000) begin
            $display("ERROR: Read pointer did not wrap to 0.");
            $stop;
        end

        if (rd_ptr_gray !== 5'b00000) begin
            $display("ERROR: Gray pointer incorrect after wrap.");
            $stop;
        end

        if (empty !== 1'b1) begin
            $display("ERROR: EMPTY did not assert after wrapped read.");
            $stop;
        end

        $display("PASS: Pointer wraparound test");

        // ========================================================
        // ALL TESTS PASSED
        // ========================================================

        $display("-----------------------------------------------");
        $display("ALL READ CONTROLLER TESTS PASSED");
        $display("-----------------------------------------------");

        $finish;

    end

endmodule