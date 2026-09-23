`timescale 1ns / 1ps

module tb_gray_sync;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------

    parameter PTR_WIDTH = 5;

    // ------------------------------------------------------------
    // Testbench signals
    // ------------------------------------------------------------

    reg                     dst_clk;
    reg                     dst_rst_n;
    reg  [PTR_WIDTH-1:0]    gray_in;

    wire [PTR_WIDTH-1:0]    gray_sync;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    gray_sync #(
        .PTR_WIDTH(PTR_WIDTH)
    ) dut (
        .dst_clk(dst_clk),
        .dst_rst_n(dst_rst_n),
        .gray_in(gray_in),
        .gray_sync(gray_sync)
    );

    // ------------------------------------------------------------
    // Destination clock
    // 10 ns period = 100 MHz
    // ------------------------------------------------------------

    initial begin
        dst_clk = 1'b0;

        forever #5 dst_clk = ~dst_clk;
    end

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------

    initial begin

        // Initial conditions
        dst_rst_n = 1'b0;
        gray_in   = 5'b00000;

        // --------------------------------------------------------
        // Test 1: Reset
        // --------------------------------------------------------

        #12;

        if (gray_sync !== 5'b00000) begin
            $display("ERROR: Synchronizer output not reset correctly.");
            $stop;
        end

        $display("PASS: Reset test");

        // Release reset
        dst_rst_n = 1'b1;

        // --------------------------------------------------------
        // Test 2: First pointer value
        // --------------------------------------------------------

        gray_in = 5'b00001;

        @(posedge dst_clk);
        #1;

        // After first clock:
        // FF1 = 00001
        // FF2 = previous FF1 = 00000
        // Therefore output must still be 00000.

        if (gray_sync !== 5'b00000) begin
            $display("ERROR: Synchronizer output changed after only one clock.");
            $stop;
        end

        $display("PASS: First-stage delay test");

        // --------------------------------------------------------
        // Test 3: Second-stage propagation
        // --------------------------------------------------------

        @(posedge dst_clk);
        #1;

        // Now FF2 should contain 00001.

        if (gray_sync !== 5'b00001) begin
            $display("ERROR: Gray pointer did not propagate after two clocks.");
            $stop;
        end

        $display("PASS: Two-stage propagation test");

        // --------------------------------------------------------
        // Test 4: Change input to another Gray value
        // --------------------------------------------------------

        gray_in = 5'b00011;

        @(posedge dst_clk);
        #1;

        // Output should still contain the previous value.

        if (gray_sync !== 5'b00001) begin
            $display("ERROR: Synchronizer propagated input too early.");
            $stop;
        end

        @(posedge dst_clk);
        #1;

        if (gray_sync !== 5'b00011) begin
            $display("ERROR: New Gray value did not propagate correctly.");
            $stop;
        end

        $display("PASS: Second Gray value propagation test");

        // --------------------------------------------------------
        // Test 5: Multiple Gray pointer changes
        // --------------------------------------------------------

        gray_in = 5'b00100;

        @(posedge dst_clk);
        #1;

        if (gray_sync !== 5'b00011) begin
            $display("ERROR: Synchronizer changed output too early.");
            $stop;
        end

        @(posedge dst_clk);
        #1;

        if (gray_sync !== 5'b00100) begin
            $display("ERROR: Gray value 00100 did not propagate correctly.");
            $stop;
        end

        gray_in = 5'b00110;

        @(posedge dst_clk);
        #1;

        if (gray_sync !== 5'b00100) begin
            $display("ERROR: Synchronizer changed output too early.");
            $stop;
        end

        @(posedge dst_clk);
        #1;

        if (gray_sync !== 5'b00110) begin
            $display("ERROR: Gray value 00110 did not propagate correctly.");
            $stop;
        end

        $display("PASS: Multiple Gray pointer propagation test");

        // --------------------------------------------------------
        // Test 6: Reset during operation
        // --------------------------------------------------------

        gray_in = 5'b01100;

        @(posedge dst_clk);
        #1;

        // Assert reset asynchronously
        dst_rst_n = 1'b0;

        #2;

        if (gray_sync !== 5'b00000) begin
            $display("ERROR: Synchronizer did not reset asynchronously.");
            $stop;
        end

        $display("PASS: Asynchronous reset test");

        // --------------------------------------------------------
        // Test 7: Resume after reset
        // --------------------------------------------------------

        dst_rst_n = 1'b1;

        gray_in = 5'b01000;

        @(posedge dst_clk);
        #1;

        if (gray_sync !== 5'b00000) begin
            $display("ERROR: Output changed too early after reset.");
            $stop;
        end

        @(posedge dst_clk);
        #1;

        if (gray_sync !== 5'b01000) begin
            $display("ERROR: Synchronizer did not resume correctly.");
            $stop;
        end

        $display("PASS: Resume-after-reset test");

        // --------------------------------------------------------
        // End simulation
        // --------------------------------------------------------

        $display("-----------------------------------------");
        $display("ALL GRAY SYNCHRONIZER TESTS PASSED");
        $display("-----------------------------------------");

        $finish;

    end

endmodule