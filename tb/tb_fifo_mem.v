`timescale 1ns / 1ps

module tb_fifo_mem;

    // ============================================================
    // PARAMETERS
    // ============================================================

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH      = (1 << ADDR_WIDTH);

    // ============================================================
    // TESTBENCH SIGNALS
    // ============================================================

    reg                      wr_clk;
    reg                      rd_clk;

    reg                      wr_en;
    reg                      rd_en;

    reg  [ADDR_WIDTH-1:0]    wr_addr;
    reg  [ADDR_WIDTH-1:0]    rd_addr;

    reg  [DATA_WIDTH-1:0]    wr_data;

    wire [DATA_WIDTH-1:0]    rd_data;

    // ============================================================
    // DUT
    // ============================================================

    fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk  (wr_clk),
        .wr_en   (wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),

        .rd_clk  (rd_clk),
        .rd_en   (rd_en),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    // ============================================================
    // WRITE CLOCK
    //
    // 10 ns period = 100 MHz
    // ============================================================

    initial begin
        wr_clk = 1'b0;

        forever #5 wr_clk = ~wr_clk;
    end

    // ============================================================
    // READ CLOCK
    //
    // 14 ns period ~= 71.43 MHz
    //
    // Deliberately different from write clock.
    // ============================================================

    initial begin
        rd_clk = 1'b0;

        forever #7 rd_clk = ~rd_clk;
    end

    // ============================================================
    // WRITE TASK
    // ============================================================

    task write_memory;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;

        begin

            wr_addr = addr;
            wr_data = data;
            wr_en   = 1'b1;

            @(posedge wr_clk);
            #1;

            wr_en = 1'b0;

        end
    endtask

    // ============================================================
    // READ TASK
    //
    // Because rd_data is registered, the data is checked after
    // the rising edge of rd_clk.
    // ============================================================

    task read_memory;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected;

        begin

            rd_addr = addr;
            rd_en   = 1'b1;

            @(posedge rd_clk);
            #1;

            if (rd_data !== expected) begin

                $display(
                    "ERROR: Read mismatch. Address=%0d Expected=%02h Got=%02h",
                    addr,
                    expected,
                    rd_data
                );

                $stop;

            end

            rd_en = 1'b0;

        end
    endtask

    // ============================================================
    // MAIN TEST SEQUENCE
    // ============================================================

    integer i;

    initial begin

        // --------------------------------------------------------
        // INITIAL CONDITIONS
        // --------------------------------------------------------

        wr_en   = 1'b0;
        rd_en   = 1'b0;

        wr_addr = 4'b0000;
        rd_addr = 4'b0000;

        wr_data = 8'b00000000;

        // ========================================================
        // TEST 1: WRITE ALL 16 LOCATIONS
        // ========================================================

        for (i = 0; i < DEPTH; i = i + 1) begin

            write_memory(
                i[ADDR_WIDTH-1:0],
                (8'hA0 + i)
            );

        end

        $display("PASS: Write all memory locations test");

        // ========================================================
        // TEST 2: READ ALL 16 LOCATIONS
        // ========================================================

        for (i = 0; i < DEPTH; i = i + 1) begin

            read_memory(
                i[ADDR_WIDTH-1:0],
                (8'hA0 + i)
            );

        end

        $display("PASS: Read all memory locations test");

        // ========================================================
        // TEST 3: READ ENABLE PROTECTION
        //
        // Capture current rd_data.
        // rd_en = 0.
        // rd_data should remain unchanged.
        // ========================================================

        rd_addr = 4'b0011;
        rd_en   = 1'b1;

        @(posedge rd_clk);
        #1;

        if (rd_data !== 8'hA3) begin

            $display(
                "ERROR: Preparation for rd_en test failed. Expected A3, Got %02h",
                rd_data
            );

            $stop;

        end

        rd_en = 1'b0;

        // Change address while read is disabled.
        rd_addr = 4'b1111;

        repeat (3) begin

            @(posedge rd_clk);
            #1;

            if (rd_data !== 8'hA3) begin

                $display(
                    "ERROR: rd_data changed while rd_en = 0. Got %02h",
                    rd_data
                );

                $stop;

            end

        end

        $display("PASS: Read-enable protection test");

        // ========================================================
        // TEST 4: OVERWRITE MEMORY
        //
        // Replace data in selected locations.
        // ========================================================

        write_memory(4'd0, 8'h55);
        write_memory(4'd5, 8'hAA);
        write_memory(4'd10, 8'h3C);
        write_memory(4'd15, 8'hF0);

        $display("PASS: Memory overwrite test");

        // ========================================================
        // TEST 5: VERIFY OVERWRITTEN LOCATIONS
        // ========================================================

        read_memory(4'd0, 8'h55);
        read_memory(4'd5, 8'hAA);
        read_memory(4'd10, 8'h3C);
        read_memory(4'd15, 8'hF0);

        $display("PASS: Overwritten data verification test");

        // ========================================================
        // TEST 6: VERIFY NON-OVERWRITTEN LOCATIONS
        //
        // These should retain their original data.
        // ========================================================

        read_memory(4'd1,  8'hA1);
        read_memory(4'd2,  8'hA2);
        read_memory(4'd3,  8'hA3);
        read_memory(4'd4,  8'hA4);

        read_memory(4'd6,  8'hA6);
        read_memory(4'd7,  8'hA7);
        read_memory(4'd8,  8'hA8);
        read_memory(4'd9,  8'hA9);

        read_memory(4'd11, 8'hAB);
        read_memory(4'd12, 8'hAC);
        read_memory(4'd13, 8'hAD);
        read_memory(4'd14, 8'hAE);

        $display("PASS: Non-overwritten data preservation test");

        // ========================================================
        // TEST 7: ADDRESS WRAPAROUND
        //
        // 4-bit address:
        //
        // 1111 + 1 -> 0000
        //
        // We explicitly write address 15 and address 0 and
        // verify that they are independent memory locations.
        // ========================================================

        write_memory(4'b1111, 8'hDE);
        write_memory(4'b0000, 8'hAD);

        read_memory(4'b1111, 8'hDE);
        read_memory(4'b0000, 8'hAD);

        $display("PASS: Address wraparound test");

        // ========================================================
        // TEST 8: DIFFERENT CLOCK DOMAINS
        //
        // Write data and then read it using the independent
        // read clock.
        // ========================================================

        write_memory(4'd2, 8'h12);
        write_memory(4'd7, 8'h34);
        write_memory(4'd12, 8'h56);

        read_memory(4'd2, 8'h12);
        read_memory(4'd7, 8'h34);
        read_memory(4'd12, 8'h56);

        $display("PASS: Independent clock-domain test");

        // ========================================================
        // TEST 9: SIMULTANEOUS OPERATION
        //
        // Write and read different addresses at the same time.
        //
        // We intentionally use DIFFERENT addresses because
        // read-during-write to the SAME address is memory
        // implementation dependent.
        // ========================================================

        wr_addr = 4'd3;
        wr_data = 8'h77;
        wr_en   = 1'b1;

        rd_addr = 4'd8;
        rd_en   = 1'b1;

        @(posedge wr_clk);
        #1;

        wr_en = 1'b0;

        @(posedge rd_clk);
        #1;

        if (rd_data !== 8'hA8) begin

            $display(
                "ERROR: Simultaneous read/write test failed. Expected A8, Got %02h",
                rd_data
            );

            $stop;

        end

        rd_en = 1'b0;

        $display("PASS: Simultaneous read/write test");

        // ========================================================
        // TEST 10: FINAL DATA CHECK
        // ========================================================

        read_memory(4'd3, 8'h77);
        read_memory(4'd8, 8'hA8);

        $display("PASS: Final data integrity test");

        // ========================================================
        // ALL TESTS PASSED
        // ========================================================

        $display("");
        $display("===============================================");
        $display("      ALL FIFO MEMORY TESTS PASSED");
        $display("===============================================");

        $finish;

    end

endmodule