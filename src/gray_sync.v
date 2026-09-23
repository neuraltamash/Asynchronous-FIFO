`timescale 1ns / 1ps

module gray_sync #(
    parameter PTR_WIDTH = 5
)(
    input  wire                 dst_clk,
    input  wire                 dst_rst_n,
    input  wire [PTR_WIDTH-1:0] gray_in,

    output reg  [PTR_WIDTH-1:0] gray_sync
);

    reg [PTR_WIDTH-1:0] sync_ff1;

    always @(posedge dst_clk or negedge dst_rst_n) begin

        if (!dst_rst_n) begin
            sync_ff1  <= {PTR_WIDTH{1'b0}};
            gray_sync <= {PTR_WIDTH{1'b0}};
        end
        else begin
            sync_ff1  <= gray_in;
            gray_sync <= sync_ff1;
        end

    end

endmodule