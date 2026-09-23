`timescale 1ns / 1ps

module fifo_read_ptr #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    input  wire                  empty,

    output reg  [ADDR_WIDTH:0]   rd_ptr_bin,
    output reg  [ADDR_WIDTH:0]   rd_ptr_gray
);

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------

    wire                         rd_allow;
    wire [ADDR_WIDTH:0]          rd_ptr_bin_next;
    wire [ADDR_WIDTH:0]          rd_ptr_gray_next;

    // A read is accepted only when read is requested
    // and the FIFO is not empty.
    assign rd_allow = rd_en && !empty;

    // ------------------------------------------------------------
    // Next binary read pointer
    // ------------------------------------------------------------

    assign rd_ptr_bin_next = rd_ptr_bin + rd_allow;

    // ------------------------------------------------------------
    // Binary-to-Gray conversion
    //
    // Gray = Binary XOR (Binary >> 1)
    // ------------------------------------------------------------

    assign rd_ptr_gray_next =
            rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    // ------------------------------------------------------------
    // Sequential state
    // ------------------------------------------------------------

    always @(posedge rd_clk or negedge rd_rst_n) begin

        if (!rd_rst_n) begin

            rd_ptr_bin  <= {(ADDR_WIDTH + 1){1'b0}};
            rd_ptr_gray <= {(ADDR_WIDTH + 1){1'b0}};

        end
        else begin

            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;

        end

    end

endmodule