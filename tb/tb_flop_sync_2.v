`timescale 1ns / 1ps

module tb_flop_sync_2;

    parameter CLK_SRC_PERIOD = 10; 
    parameter CLK_DST_PERIOD =  7; 
    parameter RESET_CYCLES   =  5; 

    reg  clk_src;    
    reg  clk_dst;    
    reg  rst_dst;    
    reg  data_in;    
    wire data_out;   

    integer pass_count;
    integer fail_count;
    integer test_num;

    flop_sync_2 dut (
        .clk_dst  (clk_dst),
        .rst_dst  (rst_dst),
        .data_in  (data_in),
        .data_out (data_out)
    );

    initial clk_src = 1'b0;
    always #(CLK_SRC_PERIOD/2) clk_src = ~clk_src;

    initial clk_dst = 1'b0;
    initial #3 clk_dst = 1'b1; 
    always #(CLK_DST_PERIOD/2) clk_dst = ~clk_dst;

    initial begin
        $dumpfile("cdc_sim.vcd");
        $dumpvars(0, tb_flop_sync_2);
    end

    task wait_dst_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk_dst);
        end
    endtask

    task wait_src_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk_src);
        end
    endtask

    task check_output;
        input expected_val;
        input [127:0] test_name;
        begin
            wait_dst_cycles(2);
            #1; 

            if (data_out === expected_val) begin
                $display("PASS [Test %0d - %0s] : data_out = %0b (expected %0b)",
                         test_num, test_name, data_out, expected_val);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [Test %0d - %0s] : data_out = %0b (expected %0b)",
                         test_num, test_name, data_out, expected_val);
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;
        data_in    = 1'b0;
        rst_dst    = 1'b1;

        $display("========================================");
        $display("  2-Flop Synchronizer Testbench Start  ");
        $display("  clk_src: %0d ns | clk_dst: %0d ns   ", CLK_SRC_PERIOD, CLK_DST_PERIOD);
        $display("========================================");

        $display("\n--- Test 1: Reset Behavior ---");
        data_in = 1'b1; 
        wait_dst_cycles(RESET_CYCLES);
        #1;
        if (data_out === 1'b0) begin
            $display("PASS [Test 1 - Reset] : data_out = 0 during reset (expected 0)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 1 - Reset] : data_out = %0b during reset (expected 0)", data_out);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        @(posedge clk_dst);
        rst_dst = 1'b0;
        data_in = 1'b0;
        wait_dst_cycles(3); 

        $display("\n--- Test 2: data_in HIGH -> data_out HIGH ---");
        @(posedge clk_src);
        #1; 
        data_in = 1'b1;
        $display("  data_in asserted at time %0t", $time);

        wait_dst_cycles(3);
        #1;
        if (data_out === 1'b1) begin
            $display("PASS [Test 2 - Assert] : data_out = 1 after 3 clk_dst cycles (expected 1)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 2 - Assert] : data_out = %0b after 3 clk_dst cycles (expected 1)", data_out);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        $display("\n--- Test 3: data_in LOW -> data_out LOW ---");
        @(posedge clk_src);
        #1;
        data_in = 1'b0;
        $display("  data_in deasserted at time %0t", $time);

        wait_dst_cycles(3);
        #1;
        if (data_out === 1'b0) begin
            $display("PASS [Test 3 - Deassert] : data_out = 0 after 3 clk_dst cycles (expected 0)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 3 - Deassert] : data_out = %0b after 3 clk_dst cycles (expected 0)", data_out);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        $display("\n--- Test 4: Short Pulse (1 clk_src cycle) ---");
        $display("  NOTE: This pulse may not be captured. That is correct behavior.");
        $display("  Inspect waveform to observe capture uncertainty.");

        wait_dst_cycles(5);
        @(posedge clk_src); #1;
        data_in = 1'b1;
        @(posedge clk_src); #1;
        data_in = 1'b0;
        $display("  Short pulse sent at time %0t", $time);
        wait_dst_cycles(5);
        $display("  data_out after short pulse = %0b (may be 0 or 1)", data_out);
        test_num = test_num + 1;

        $display("\n--- Test 5: Long Pulse (10 clk_src cycles) ---");
        @(posedge clk_src); #1;
        data_in = 1'b1;
        wait_src_cycles(10);
        wait_dst_cycles(3); #1;
        if (data_out === 1'b1) begin
            $display("PASS [Test 5 - Long Pulse] : data_out = 1 (expected 1)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 5 - Long Pulse] : data_out = %0b (expected 1)", data_out);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        @(posedge clk_src); #1;
        data_in = 1'b0;
        wait_dst_cycles(5);

        $display("\n--- Test 6: Multiple Transitions ---");
        repeat(4) begin
            @(posedge clk_src); #1;
            data_in = ~data_in;
            wait_src_cycles(3);
        end
        wait_dst_cycles(5);
        $display("  Multiple transitions complete. Inspect waveform.");
        test_num = test_num + 1;

        $display("\n========================================");
        $display("  Simulation Complete");
        $display("  PASSED : %0d", pass_count);
        $display("  FAILED : %0d", fail_count);
        $display("========================================");

        if (fail_count == 0)
            $display("  ALL DIRECTED TESTS PASSED");
        else
            $display("  FAILURES DETECTED — CHECK WAVEFORM");

        $finish;
    end

    initial begin
        #100000;
        $display("TIMEOUT: Simulation exceeded 100us. Terminating.");
        $finish;
    end

    initial begin
        $monitor("Time=%0t | rst=%0b | data_in=%0b | ff1=%0b | data_out=%0b",
                 $time, rst_dst, data_in, dut.ff1, data_out);
    end

endmodule