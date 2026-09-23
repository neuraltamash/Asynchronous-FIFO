`timescale 1ns / 1ps




module tb_fifo_write_ptr;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------

    parameter ADDR_WIDTH = 4;

    // ------------------------------------------------------------
    // Testbench signals
    // ------------------------------------------------------------

    reg                     wr_clk;
    reg                     wr_rst_n;
    reg                     wr_en;
    reg                     full;

    wire [ADDR_WIDTH:0]     wr_ptr_bin;
    wire [ADDR_WIDTH:0]     wr_ptr_gray;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    fifo_write_ptr #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_en(wr_en),
        .full(full),

        .wr_ptr_bin(wr_ptr_bin),
        .wr_ptr_gray(wr_ptr_gray)
    );

    // ------------------------------------------------------------
    // Clock generation
    // 10 ns period = 100 MHz
    // ------------------------------------------------------------

    initial begin
        wr_clk = 1'b0;

        forever #5 wr_clk = ~wr_clk;
    end

    // ------------------------------------------------------------
    // Gray-code conversion function
    // Used only by the testbench for checking the DUT.
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

        // Initial values
        wr_rst_n = 1'b0;
        wr_en    = 1'b0;
        full     = 1'b0;

        // --------------------------------------------------------
        // Reset test
        // --------------------------------------------------------

        #12;

        if (wr_ptr_bin !== 5'b00000) begin
            $display("ERROR: Binary pointer not reset correctly.");
            $stop;
        end

        if (wr_ptr_gray !== 5'b00000) begin
            $display("ERROR: Gray pointer not reset correctly.");
            $stop;
        end

        $display("PASS: Reset test");

        // Release reset
        wr_rst_n = 1'b1;

        // --------------------------------------------------------
        // Test 1: No write
        // --------------------------------------------------------

        wr_en = 1'b0;

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b00000) begin
            $display("ERROR: Pointer changed when wr_en = 0.");
            $stop;
        end

        $display("PASS: Write disabled test");

        // --------------------------------------------------------
        // Test 2: Single write
        // --------------------------------------------------------

        wr_en = 1'b1;

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b00001) begin
            $display("ERROR: Pointer did not increment correctly.");
            $stop;
        end

        if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
            $display("ERROR: Gray pointer incorrect after first write.");
            $stop;
        end

        $display("PASS: Single write test");

        // --------------------------------------------------------
        // Test 3: Multiple writes
        // --------------------------------------------------------

        repeat (4) begin
            @(posedge wr_clk);
            #1;

            if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch.");
                $stop;
            end
        end

        if (wr_ptr_bin !== 5'b00101) begin
            $display("ERROR: Multiple write pointer count incorrect.");
            $stop;
        end

        $display("PASS: Multiple write test");

        // --------------------------------------------------------
        // Test 4: FULL must block writing
        // --------------------------------------------------------

        full  = 1'b1;
        wr_en = 1'b1;

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b00101) begin
            $display("ERROR: Pointer advanced while FIFO was full.");
            $stop;
        end

        $display("PASS: FULL protection test");

        // --------------------------------------------------------
        // Test 5: Resume writing after FULL is removed
        // --------------------------------------------------------

        full = 1'b0;

        @(posedge wr_clk);
        #1;

        if (wr_ptr_bin !== 5'b00110) begin
            $display("ERROR: Pointer did not resume correctly.");
            $stop;
        end

        $display("PASS: Resume-after-FULL test");

        // --------------------------------------------------------
        // Test 6: Run pointer through wraparound
        // --------------------------------------------------------

        repeat (25) begin

            @(posedge wr_clk);
            #1;

            if (wr_ptr_gray !== binary_to_gray(wr_ptr_bin)) begin
                $display("ERROR: Gray pointer mismatch during wraparound.");
                $stop;
            end

        end

        $display("PASS: Wraparound / Gray-code test");

        // --------------------------------------------------------
        // End simulation
        // --------------------------------------------------------

        $display("-----------------------------------------");
        $display("ALL WRITE POINTER TESTS PASSED");
        $display("-----------------------------------------");

        $finish;

    end

endmodule