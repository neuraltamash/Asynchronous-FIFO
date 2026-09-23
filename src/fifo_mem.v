`timescale 1ns / 1ps

module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // ------------------------------------------------------------
    // Write side
    // ------------------------------------------------------------

    input  wire                     wr_clk,
    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data,

    // ------------------------------------------------------------
    // Read side
    // ------------------------------------------------------------

    input  wire                     rd_clk,
    input  wire                     rd_en,
    input  wire [ADDR_WIDTH-1:0]    rd_addr,
    output reg  [DATA_WIDTH-1:0]    rd_data
);

    // ------------------------------------------------------------
    // FIFO storage
    //
    // Depth = 2^ADDR_WIDTH
    //
    // For ADDR_WIDTH = 4:
    //     2^4 = 16 locations
    //
    // Each location stores DATA_WIDTH bits.
    // ------------------------------------------------------------

    reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];

    // ------------------------------------------------------------
    // WRITE PORT
    //
    // Data is written on the rising edge of wr_clk.
    // ------------------------------------------------------------

    always @(posedge wr_clk) begin

        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end

    end

    // ------------------------------------------------------------
    // READ PORT
    //
    // Data is read on the rising edge of rd_clk.
    //
    // This gives us a registered read-data output.
    // ------------------------------------------------------------

    always @(posedge rd_clk) begin

        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end

    end

endmodule
