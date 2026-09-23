`timescale 1ns / 1ps

module tb_fifo_read_ptr;

    parameter ADDR_WIDTH = 4;

    // ------------------------------------------------------------
    // Testbench signals
    // ------------------------------------------------------------

    reg                     rd_clk;
    reg                     rd_rst_n;
    reg                     rd_en;
    reg                     empty;

    wire [ADDR_WIDTH:0]     rd_ptr_bin;
    wire [ADDR_WIDTH:0]     rd_ptr_gray;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    fifo_read_ptr #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_en(rd_en),
        .empty(empty),

        .rd_ptr_bin(rd_ptr_bin),
        .rd_ptr_gray(rd_ptr_gray)
    );

    // ------------------------------------------------------------
    // Clock generation
    // 10 ns period = 100 MHz
    // ------------------------------------------------------------

    initial begin
        rd_clk = 1'b0;

        forever #5 rd_clk = ~rd_clk;
    end

    // ------------------------------------------------------------
    // Binary-to-Gray conversion function
    // ------------------------------------------------------------

    function [ADDR_WIDTH:0] binary_to_gray;
        input [ADDR_WIDTH:0] binary;

        begin
            binary_to_gray = binary ^ (binary >> 1);
        end
    endfunction

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------

    initial begin

        // Initial conditions
        rd_rst_n = 1'b0;
        rd_en    = 1'b0;
        empty    = 1'b1;

        // --------------------------------------------------------
        // Test 1: Reset
        // --------------------------------------------------------

        #12;

        if (rd_ptr_bin !== 5'b00000) begin
            $display("ERROR: Binary read pointer not reset correctly.");
            $stop;
        end

        if (rd_ptr_gray !== 5'b00000) begin
            $display("ERROR: Gray read pointer not reset correctly.");
            $stop;
        end

        $display("PASS: Reset test");

        // Release reset
        rd_rst_n = 1'b1;

        // --------------------------------------------------------
        // Test 2: Read while EMPTY
        // --------------------------------------------------------

        rd_en = 1'b1;
        empty = 1'b1;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00000) begin
            $display("ERROR: Pointer advanced while FIFO was empty.");
            $stop;
        end

        $display("PASS: EMPTY protection test");

        // --------------------------------------------------------
        // Test 3: Read disabled
        // --------------------------------------------------------

        rd_en = 1'b0;
        empty = 1'b0;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00000) begin
            $display("ERROR: Pointer changed when rd_en = 0.");
            $stop;
        end

        $display("PASS: Read disabled test");

        // --------------------------------------------------------
        // Test 4: Single read
        // --------------------------------------------------------

        rd_en = 1'b1;
        empty = 1'b0;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00001) begin
            $display("ERROR: Pointer did not increment correctly.");
            $stop;
        end

        if (rd_ptr_gray !== binary_to_gray(rd_ptr_bin)) begin
            $display("ERROR: Gray pointer incorrect after first read.");
            $stop;
        end

        $display("PASS: Single read test");

        // --------------------------------------------------------
        // Test 5: Multiple reads
        // --------------------------------------------------------

        repeat (4) begin

            @(posedge rd_clk);
            #1;

            if (rd_ptr_gray !== binary_to_gray(rd_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch.");
                $stop;
            end

        end

        if (rd_ptr_bin !== 5'b00101) begin
            $display("ERROR: Multiple read pointer count incorrect.");
            $stop;
        end

        $display("PASS: Multiple read test");

        // --------------------------------------------------------
        // Test 6: EMPTY protection after reads
        // --------------------------------------------------------

        empty = 1'b1;
        rd_en = 1'b1;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00101) begin
            $display("ERROR: Pointer advanced while FIFO was empty.");
            $stop;
        end

        $display("PASS: EMPTY protection after multiple reads");

        // --------------------------------------------------------
        // Test 7: Resume reading after EMPTY is removed
        // --------------------------------------------------------

        empty = 1'b0;

        @(posedge rd_clk);
        #1;

        if (rd_ptr_bin !== 5'b00110) begin
            $display("ERROR: Pointer did not resume correctly.");
            $stop;
        end

        $display("PASS: Resume-after-EMPTY test");

        // --------------------------------------------------------
        // Test 8: Wraparound and Gray-code verification
        // --------------------------------------------------------

        repeat (25) begin

            @(posedge rd_clk);
            #1;

            if (rd_ptr_gray !== binary_to_gray(rd_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch during wraparound.");
                $stop;
            end

        end

        $display("PASS: Wraparound / Gray-code test");

        // --------------------------------------------------------
        // End simulation
        // --------------------------------------------------------

        $display("-----------------------------------------");
        $display("ALL READ POINTER TESTS PASSED");
        $display("-----------------------------------------");

        $finish;

    end

endmodule