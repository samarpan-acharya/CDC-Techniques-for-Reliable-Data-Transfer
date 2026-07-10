`timescale 1ns / 1ps

module tb_async_fifo;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter FIFO_DEPTH = 16;
    parameter CLK_SRC_PERIOD = 100;
    parameter CLK_DST_PERIOD =  70;

    reg                   clk_src;
    reg                   clk_dst;
    reg                   rst_src;
    reg                   rst_dst;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;

    integer pass_count;
    integer fail_count;
    integer i;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk_src(clk_src),
        .rst_src(rst_src),
        .wr_en  (wr_en),
        .wr_data(wr_data),
        .full   (full),
        .clk_dst(clk_dst),
        .rst_dst(rst_dst),
        .rd_en  (rd_en),
        .rd_data(rd_data),
        .empty  (empty)
    );

    initial clk_src = 1'b0;
    always #(CLK_SRC_PERIOD/2) clk_src = ~clk_src;

    initial clk_dst = 1'b0;
    initial #30 clk_dst = 1'b1;
    always #(CLK_DST_PERIOD/2) clk_dst = ~clk_dst;

    initial begin
        $dumpfile("async_fifo_sim.vcd");
        $dumpvars(0, tb_async_fifo);
    end

    task wait_src;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk_src);
        end
    endtask

    task wait_dst;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk_dst);
        end
    endtask

    task write_word;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk_src); #1;
            if (!full) begin
                wr_en   = 1'b1;
                wr_data = data;
            end else begin
                wr_en = 1'b0;
                $display("  Write blocked — FIFO full");
            end
            @(posedge clk_src); #1;
            wr_en = 1'b0;
        end
    endtask

    task read_check;
        input [DATA_WIDTH-1:0] expected;
        input [127:0]          label;
        begin
            @(posedge clk_dst); #1;
            if (!empty) begin
                rd_en = 1'b1;
                @(posedge clk_dst); #1;
                rd_en = 1'b0;
                #5;
                if (rd_data === expected) begin
                    $display("PASS [%0s]: Got=0x%h Expected=0x%h",
                             label, rd_data, expected);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL [%0s]: Got=0x%h Expected=0x%h",
                             label, rd_data, expected);
                    fail_count = fail_count + 1;
                end
            end else begin
                $display("FAIL [%0s]: FIFO empty — cannot read", label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        rst_src    = 1'b1;
        rst_dst    = 1'b1;
        wr_en      = 1'b0;
        rd_en      = 1'b0;
        wr_data    = 8'h00;
        pass_count = 0;
        fail_count = 0;

        $display("============================================");
        $display("  Async FIFO Testbench                      ");
        $display("  Depth=%0d | Width=%0d bits               ",
                 FIFO_DEPTH, DATA_WIDTH);
        $display("============================================");

        wait_src(5);
        @(posedge clk_src); rst_src = 1'b0;
        @(posedge clk_dst); rst_dst = 1'b0;
        wait_src(3);

        $display("\n--- Test 1: Basic Write Then Read ---");
        write_word(8'hA1);
        write_word(8'hB2);
        write_word(8'hC3);
        write_word(8'hD4);

        wait_dst(8);

        read_check(8'hA1, "T1_word1");
        read_check(8'hB2, "T1_word2");
        read_check(8'hC3, "T1_word3");
        read_check(8'hD4, "T1_word4");

        wait_dst(5);

        $display("\n--- Test 2: Fill to Full ---");
        for (i = 0; i < FIFO_DEPTH; i = i + 1)
            write_word(8'h10 + i); 

        wait_src(5);
        #1;
        if (full) begin
            $display("PASS [T2_Full]: full=1 after writing %0d words",
                     FIFO_DEPTH);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [T2_Full]: full=0 after writing %0d words",
                     FIFO_DEPTH);
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 3: Overflow Attempt ---");
        @(posedge clk_src); #1;
        wr_en   = 1'b1;
        wr_data = 8'hFF; 
        @(posedge clk_src); #1;
        wr_en = 1'b0;
        wait_src(3);
        #1;
        if (full) begin
            $display("PASS [T3_Overflow]: FIFO still full after overflow attempt");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [T3_Overflow]: full flag lost after overflow attempt");
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 4: Read Until Empty ---");
        wait_dst(8); 

        for (i = 0; i < FIFO_DEPTH; i = i + 1)
            read_check(8'h10 + i, "T4_read");

        wait_dst(8);
        #1;
        if (empty) begin
            $display("PASS [T4_Empty]: empty=1 after reading all words");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [T4_Empty]: empty=0 after reading all words");
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 5: Underflow Attempt ---");
        @(posedge clk_dst); #1;
        rd_en = 1'b1;
        @(posedge clk_dst); #1;
        rd_en = 1'b0;
        wait_dst(3);
        #1;
        if (empty) begin
            $display("PASS [T5_Underflow]: FIFO still empty after underflow attempt");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [T5_Underflow]: empty flag lost after underflow attempt");
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 6: Simultaneous Read/Write ---");

        for (i = 0; i < 8; i = i + 1)
            write_word(8'hE0 + i);

        wait_dst(8); 

        fork
            begin : writer
                for (i = 0; i < 8; i = i + 1)
                    write_word(8'hF0 + i);
            end
            begin : reader
                for (i = 0; i < 8; i = i + 1)
                    read_check(8'hE0 + i, "T6_SimRW");
            end
        join

        wait_dst(10);

        $display("\n============================================");
        $display("  Simulation Complete");
        $display("  PASSED : %0d", pass_count);
        $display("  FAILED : %0d", fail_count);
        $display("============================================");
        if (fail_count == 0)
            $display("  ALL DIRECTED TESTS PASSED");
        else
            $display("  FAILURES DETECTED — CHECK WAVEFORM");

        $finish;
    end

    initial begin
        #50000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule