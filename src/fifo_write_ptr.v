`timescale 1ns / 1ps



module fifo_write_ptr #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire                  full,

    output reg  [ADDR_WIDTH:0]   wr_ptr_bin,
    output reg  [ADDR_WIDTH:0]   wr_ptr_gray
);

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------

    wire                         wr_allow;
    wire [ADDR_WIDTH:0]          wr_ptr_bin_next;
    wire [ADDR_WIDTH:0]          wr_ptr_gray_next;

    // A write is accepted only when write is requested
    // and the FIFO is not full.
    assign wr_allow = wr_en && !full;

    // ------------------------------------------------------------
    // Next binary write pointer
    // ------------------------------------------------------------

    assign wr_ptr_bin_next = wr_ptr_bin + wr_allow;

    // ------------------------------------------------------------
    // Binary-to-Gray conversion
    //
    // Gray = Binary XOR (Binary >> 1)
    // ------------------------------------------------------------

    assign wr_ptr_gray_next =
            wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    // ------------------------------------------------------------
    // Sequential state
    // ------------------------------------------------------------

    always @(posedge wr_clk or negedge wr_rst_n) begin

        if (!wr_rst_n) begin

            wr_ptr_bin  <= {(ADDR_WIDTH + 1){1'b0}};
            wr_ptr_gray <= {(ADDR_WIDTH + 1){1'b0}};

        end
        else begin

            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;

        end

    end

endmodule

 
