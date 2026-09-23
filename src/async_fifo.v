`timescale 1ns / 1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    // ============================================================
    // WRITE CLOCK DOMAIN
    // ============================================================

    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,

    output wire                  full,

    // ============================================================
    // READ CLOCK DOMAIN
    // ============================================================

    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,

    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    // ============================================================
    // POINTER WIDTH
    //
    // ADDR_WIDTH = 4
    //
    // FIFO depth = 2^4 = 16
    //
    // Pointer width = ADDR_WIDTH + 1 = 5
    //
    // Extra bit is used for wrap/phase information.
    // ============================================================

    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    // ============================================================
    // WRITE DOMAIN SIGNALS
    // ============================================================

    wire [PTR_WIDTH-1:0] wr_ptr_bin;
    wire [PTR_WIDTH-1:0] wr_ptr_gray;

    wire [ADDR_WIDTH-1:0] wr_addr;

    wire wr_allow;

    // ============================================================
    // READ DOMAIN SIGNALS
    // ============================================================

    wire [PTR_WIDTH-1:0] rd_ptr_bin;
    wire [PTR_WIDTH-1:0] rd_ptr_gray;

    wire [ADDR_WIDTH-1:0] rd_addr;

    wire rd_allow;

    // ============================================================
    // SYNCHRONIZED POINTERS
    //
    // Write pointer synchronized into READ clock domain.
    // Read pointer synchronized into WRITE clock domain.
    // ============================================================

    wire [PTR_WIDTH-1:0] wr_ptr_gray_sync;

    wire [PTR_WIDTH-1:0] rd_ptr_gray_sync;

    // ============================================================
    // WRITE OPERATION ACCEPTANCE
    //
    // A write is accepted only when:
    //
    //     wr_en = 1
    //     FIFO is not full
    // ============================================================

    assign wr_allow = wr_en && !full;

    // ============================================================
    // READ OPERATION ACCEPTANCE
    //
    // A read is accepted only when:
    //
    //     rd_en = 1
    //     FIFO is not empty
    // ============================================================

    assign rd_allow = rd_en && !empty;

    // ============================================================
    // MEMORY ADDRESSES
    //
    // The lower ADDR_WIDTH bits select the memory location.
    //
    // Example:
    //
    // Pointer = 5'b10011
    // Address =     0011
    //
    // The MSB is NOT used as the memory address.
    // ============================================================

    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

    // ============================================================
    // WRITE POINTER CONTROLLER
    // ============================================================

    fifo_write_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo_write_ctrl (
        .wr_clk           (wr_clk),
        .wr_rst_n         (wr_rst_n),
        .wr_en            (wr_en),
        .rd_ptr_gray_sync (rd_ptr_gray_sync),

        .wr_ptr_bin       (wr_ptr_bin),
        .wr_ptr_gray      (wr_ptr_gray),
        .full             (full)
    );

    // ============================================================
    // READ POINTER CONTROLLER
    // ============================================================

    fifo_read_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo_read_ctrl (
        .rd_clk           (rd_clk),
        .rd_rst_n         (rd_rst_n),
        .rd_en            (rd_en),
        .wr_ptr_gray_sync (wr_ptr_gray_sync),

        .rd_ptr_bin       (rd_ptr_bin),
        .rd_ptr_gray      (rd_ptr_gray),
        .empty            (empty)
    );

    // ============================================================
    // READ POINTER -> WRITE CLOCK DOMAIN
    //
    // rd_ptr_gray originates in rd_clk domain.
    //
    // It must pass through the Gray-code synchronizer before
    // being used by the write controller.
    // ============================================================

    gray_sync #(
        .PTR_WIDTH(PTR_WIDTH)
    ) u_rd_ptr_gray_sync (
        .dst_clk  (wr_clk),
        .dst_rst_n(wr_rst_n),

        .gray_in  (rd_ptr_gray),
        .gray_sync(rd_ptr_gray_sync)
    );

    // ============================================================
    // WRITE POINTER -> READ CLOCK DOMAIN
    //
    // wr_ptr_gray originates in wr_clk domain.
    //
    // It must pass through the Gray-code synchronizer before
    // being used by the read controller.
    // ============================================================

    gray_sync #(
        .PTR_WIDTH(PTR_WIDTH)
    ) u_wr_ptr_gray_sync (
        .dst_clk  (rd_clk),
        .dst_rst_n(rd_rst_n),

        .gray_in  (wr_ptr_gray),
        .gray_sync(wr_ptr_gray_sync)
    );

    // ============================================================
    // DUAL-CLOCK FIFO MEMORY
    // ============================================================

    fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo_mem (
        // --------------------------------------------------------
        // Write port
        // --------------------------------------------------------

        .wr_clk  (wr_clk),
        .wr_en   (wr_allow),
        .wr_addr (wr_addr),
        .wr_data (wr_data),

        // --------------------------------------------------------
        // Read port
        // --------------------------------------------------------

        .rd_clk  (rd_clk),
        .rd_en   (rd_allow),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

endmodule