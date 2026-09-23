`timescale 1ns / 1ps

module fifo_read_ctrl #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,

    // Synchronized write pointer from the write-clock domain
    input  wire [ADDR_WIDTH:0]   wr_ptr_gray_sync,

    // Current read pointer
    output reg  [ADDR_WIDTH:0]   rd_ptr_bin,
    output reg  [ADDR_WIDTH:0]   rd_ptr_gray,

    // FIFO empty flag
    output reg                  empty
);

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------

    wire                         rd_allow;

    reg [ADDR_WIDTH:0]           rd_ptr_bin_next;
    reg [ADDR_WIDTH:0]           rd_ptr_gray_next;
    reg                          empty_next;

    // ------------------------------------------------------------
    // A read is accepted only when:
    //     rd_en = 1
    //     FIFO is not empty
    // ------------------------------------------------------------

    assign rd_allow = rd_en && !empty;

    // ------------------------------------------------------------
    // Next binary read pointer
    // ------------------------------------------------------------

    always @(*) begin

        if (rd_allow)
            rd_ptr_bin_next = rd_ptr_bin + 1'b1;
        else
            rd_ptr_bin_next = rd_ptr_bin;

    end

    // ------------------------------------------------------------
    // Binary-to-Gray conversion
    //
    // Gray = Binary XOR (Binary >> 1)
    // ------------------------------------------------------------

    always @(*) begin

        rd_ptr_gray_next =
            rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    end

    // ------------------------------------------------------------
    // EMPTY detection
    //
    // FIFO is empty when the NEXT read pointer equals the
    // synchronized write pointer.
    // ------------------------------------------------------------

    always @(*) begin

        empty_next =
            (rd_ptr_gray_next == wr_ptr_gray_sync);

    end

    // ------------------------------------------------------------
    // Sequential state
    // ------------------------------------------------------------

    always @(posedge rd_clk or negedge rd_rst_n) begin

        if (!rd_rst_n) begin

            rd_ptr_bin  <= {(ADDR_WIDTH + 1){1'b0}};
            rd_ptr_gray <= {(ADDR_WIDTH + 1){1'b0}};
            empty       <= 1'b1;

        end
        else begin

            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            empty       <= empty_next;

        end

    end

endmodule