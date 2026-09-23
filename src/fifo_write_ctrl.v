`timescale 1ns / 1ps

module fifo_write_ctrl #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,

    // Synchronized read pointer from the read-clock domain
    input  wire [ADDR_WIDTH:0]   rd_ptr_gray_sync,

    // Current write pointer
    output reg  [ADDR_WIDTH:0]   wr_ptr_bin,
    output reg  [ADDR_WIDTH:0]   wr_ptr_gray,

    // FIFO full flag
    output reg                  full
);

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------

    wire                         wr_allow;

    reg  [ADDR_WIDTH:0]          wr_ptr_bin_next;
    reg  [ADDR_WIDTH:0]          wr_ptr_gray_next;
    reg                          full_next;

    // ------------------------------------------------------------
    // Write is accepted only when:
    //     wr_en = 1
    //     FIFO is not full
    // ------------------------------------------------------------

    assign wr_allow = wr_en && !full;

    // ------------------------------------------------------------
    // Next binary write pointer
    // ------------------------------------------------------------

    always @(*) begin

        if (wr_allow)
            wr_ptr_bin_next = wr_ptr_bin + 1'b1;
        else
            wr_ptr_bin_next = wr_ptr_bin;

    end

    // ------------------------------------------------------------
    // Binary-to-Gray conversion
    //
    // Gray = Binary XOR (Binary >> 1)
    // ------------------------------------------------------------

    always @(*) begin

        wr_ptr_gray_next =
            wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    end

    // ------------------------------------------------------------
    // FULL detection
    //
    // For a 5-bit pointer:
    //
    // Full occurs when the NEXT write Gray pointer equals
    // the synchronized read Gray pointer with its two MSBs
    // inverted.
    //
    // General form:
    //
    // {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1],
    //  rd_ptr_gray_sync[ADDR_WIDTH-2:0]}
    //
    // For ADDR_WIDTH = 4:
    //
    // {~rd_ptr_gray_sync[4:3],
    //   rd_ptr_gray_sync[2:0]}
    // ------------------------------------------------------------

    always @(*) begin

        full_next =
            (wr_ptr_gray_next ==
             {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1],
               rd_ptr_gray_sync[ADDR_WIDTH-2:0]});

    end

    // ------------------------------------------------------------
    // Sequential state
    // ------------------------------------------------------------

    always @(posedge wr_clk or negedge wr_rst_n) begin

        if (!wr_rst_n) begin

            wr_ptr_bin  <= {(ADDR_WIDTH + 1){1'b0}};
            wr_ptr_gray <= {(ADDR_WIDTH + 1){1'b0}};
            full        <= 1'b0;

        end
        else begin

            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            full        <= full_next;

        end

    end

endmodule