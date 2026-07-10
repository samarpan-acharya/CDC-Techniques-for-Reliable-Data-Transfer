`timescale 1ns / 1ps

module tb_handshake_sync;

    parameter DATA_WIDTH     = 8;
    parameter CLK_SRC_PERIOD = 100;
    parameter CLK_DST_PERIOD =  70;

    reg                   clk_src;
    reg                   clk_dst;
    reg                   rst_src;
    reg                   rst_dst;
    reg  [DATA_WIDTH-1:0] data_in;
    reg                   send;
    wire [DATA_WIDTH-1:0] data_out;
    wire                  data_valid;
    wire                  ready;

    integer pass_count;
    integer fail_count;
    integer test_num;

    reg [DATA_WIDTH-1:0] captured_data;
    reg                  capture_done;

    handshake_sync #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_src   (clk_src),
        .clk_dst   (clk_dst),
        .rst_src   (rst_src),
        .rst_dst   (rst_dst),
        .data_in   (data_in),
        .send      (send),
        .data_out  (data_out),
        .data_valid(data_valid),
        .ready     (ready)
    );

    initial clk_src = 1'b0;
    always #(CLK_SRC_PERIOD/2) clk_src = ~clk_src;

    initial clk_dst = 1'b0;
    initial #30 clk_dst = 1'b1;
    always #(CLK_DST_PERIOD/2) clk_dst = ~clk_dst;

    initial begin
        $dumpfile("handshake_sim.vcd");
        $dumpvars(0, tb_handshake_sync);
    end

    always @(posedge clk_dst) begin
        if (data_valid) begin
            captured_data = data_out;
            capture_done  = 1'b1;
        end
    end

    task wait_src_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk_src);
        end
    endtask

    task wait_dst_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk_dst);
        end
    endtask

    task send_and_check;
        input [DATA_WIDTH-1:0] data_val;
        input [127:0]          label;
        integer timeout;
        begin
            timeout = 0;
            while (!ready) begin
                @(posedge clk_src);
                timeout = timeout + 1;
                if (timeout > 200) begin
                    $display("FAIL [T%0d - %0s]: Timeout waiting for ready",
                             test_num, label);
                    fail_count = fail_count + 1;
                    test_num   = test_num + 1;
                    disable send_and_check;
                end
            end

            capture_done = 1'b0;

            @(posedge clk_src); #1;
            data_in = data_val;
            send    = 1'b1;
            @(posedge clk_src); #1;
            send    = 1'b0;

            timeout = 0;
            while (!capture_done) begin
                @(posedge clk_dst);
                timeout = timeout + 1;
                if (timeout > 200) begin
                    $display("FAIL [T%0d - %0s]: Timeout waiting for data_valid",
                             test_num, label);
                    fail_count = fail_count + 1;
                    test_num   = test_num + 1;
                    disable send_and_check;
                end
            end

            if (captured_data === data_val) begin
                $display("PASS [T%0d - %0s]: Sent=0x%h Received=0x%h",
                         test_num, label, data_val, captured_data);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [T%0d - %0s]: Sent=0x%h Received=0x%h MISMATCH",
                         test_num, label, data_val, captured_data);
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;

            wait_src_cycles(15);
        end
    endtask

    initial begin
        rst_src      = 1'b1;
        rst_dst      = 1'b1;
        data_in      = 8'h00;
        send         = 1'b0;
        pass_count   = 0;
        fail_count   = 0;
        test_num     = 1;
        capture_done = 1'b0;
        captured_data = 8'h00;

        $display("============================================");
        $display("  Handshake Synchronizer Testbench         ");
        $display("  clk_src=%0dns | clk_dst=%0dns           ",
                 CLK_SRC_PERIOD, CLK_DST_PERIOD);
        $display("============================================");

        wait_src_cycles(5);
        @(posedge clk_src); rst_src = 1'b0;
        @(posedge clk_dst); rst_dst = 1'b0;
        wait_src_cycles(5);

        $display("\n--- Test 1: Single Transfer 0xAB ---");
        send_and_check(8'hAB, "Single_0xAB");

        $display("\n--- Test 2: All Zeros 0x00 ---");
        send_and_check(8'h00, "Zero_0x00");

        $display("\n--- Test 3: All Ones 0xFF ---");
        send_and_check(8'hFF, "Max_0xFF");

        $display("\n--- Test 4: Alternating 0x55 ---");
        send_and_check(8'h55, "Alt_0x55");

        $display("\n--- Test 5: Alternating 0xAA ---");
        send_and_check(8'hAA, "Alt_0xAA");

        $display("\n--- Test 6: Sequential Transfers ---");
        send_and_check(8'h01, "Seq_0x01");
        send_and_check(8'h02, "Seq_0x02");
        send_and_check(8'h04, "Seq_0x04");
        send_and_check(8'h08, "Seq_0x08");
        send_and_check(8'h10, "Seq_0x10");

        $display("\n--- Test 7: Boundary Values ---");
        send_and_check(8'h01, "Min_0x01");
        send_and_check(8'hFE, "MaxM1_0xFE");
        send_and_check(8'h80, "Mid_0x80");
        send_and_check(8'h7F, "MidM1_0x7F");

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
        #10000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule