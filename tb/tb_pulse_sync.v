`timescale 1ns / 1ps

module tb_pulse_sync;

    parameter CLK_SRC_PERIOD = 10;
    parameter CLK_DST_PERIOD =  7;

    reg  clk_src;
    reg  clk_dst;
    reg  rst_src;
    reg  rst_dst;
    reg  pulse_in;
    wire pulse_out;

    integer pass_count;
    integer fail_count;
    integer pulse_out_count; 
    integer i;

    pulse_sync dut (
        .clk_src  (clk_src),
        .clk_dst  (clk_dst),
        .rst_src  (rst_src),
        .rst_dst  (rst_dst),
        .pulse_in (pulse_in),
        .pulse_out(pulse_out)
    );

    initial clk_src = 1'b0;
    always #(CLK_SRC_PERIOD/2) clk_src = ~clk_src;

    initial clk_dst = 1'b0;
    initial #3 clk_dst = 1'b1;
    always #(CLK_DST_PERIOD/2) clk_dst = ~clk_dst;

    initial begin
        $dumpfile("pulse_sync_sim.vcd");
        $dumpvars(0, tb_pulse_sync);
    end

    always @(posedge clk_dst) begin
        if (pulse_out)
            pulse_out_count = pulse_out_count + 1;
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

    task send_pulse;
        begin
            @(posedge clk_src); #1;
            pulse_in = 1'b1;
            @(posedge clk_src); #1;
            pulse_in = 1'b0;
        end
    endtask

    initial begin
        clk_src        = 1'b0;
        rst_src        = 1'b1;
        rst_dst        = 1'b1;
        pulse_in       = 1'b0;
        pass_count     = 0;
        fail_count     = 0;
        pulse_out_count = 0;

        $display("============================================");
        $display("  Pulse Synchronizer Testbench Start       ");
        $display("  clk_src=%0dns | clk_dst=%0dns          ",
                 CLK_SRC_PERIOD, CLK_DST_PERIOD);
        $display("============================================");

        $display("\n--- Test 1: Reset Behavior ---");
        pulse_in = 1'b1; 
        wait_dst_cycles(5);
        pulse_in = 1'b0;
        #1;
        if (pulse_out === 1'b0) begin
            $display("PASS [Test 1]: pulse_out=0 during reset (expected 0)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 1]: pulse_out=%0b during reset (expected 0)", pulse_out);
            fail_count = fail_count + 1;
        end

        @(posedge clk_src); rst_src = 1'b0;
        @(posedge clk_dst); rst_dst = 1'b0;
        wait_dst_cycles(3);

        $display("\n--- Test 2: Single Pulse ---");
        pulse_out_count = 0;

        send_pulse; 

        wait_dst_cycles(8);

        if (pulse_out_count === 1) begin
            $display("PASS [Test 2]: pulse_out fired %0d time (expected 1)", pulse_out_count);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 2]: pulse_out fired %0d times (expected 1)", pulse_out_count);
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 3: Second Pulse After Sufficient Gap ---");
        pulse_out_count = 0;

        send_pulse;
        wait_dst_cycles(10); 
        send_pulse;
        wait_dst_cycles(10); 

        if (pulse_out_count === 2) begin
            $display("PASS [Test 3]: pulse_out fired %0d times (expected 2)", pulse_out_count);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 3]: pulse_out fired %0d times (expected 2)", pulse_out_count);
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 4: Short Pulse (1 clk_src cycle) ---");
        $display("  (Toggle sync must capture this — 2-flop sync alone would miss it)");
        pulse_out_count = 0;

        send_pulse; 
        wait_dst_cycles(10);

        if (pulse_out_count === 1) begin
            $display("PASS [Test 4]: Short pulse captured. pulse_out fired %0d time", pulse_out_count);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 4]: Short pulse NOT captured. pulse_out fired %0d times", pulse_out_count);
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 5: 5 Pulses with Sufficient Gap ---");
        pulse_out_count = 0;

        repeat(5) begin
            send_pulse;
            wait_dst_cycles(15); 
        end

        if (pulse_out_count === 5) begin
            $display("PASS [Test 5]: All 5 pulses captured. pulse_out=%0d", pulse_out_count);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test 5]: Only %0d/5 pulses captured", pulse_out_count);
            fail_count = fail_count + 1;
        end

        $display("\n--- Test 6: Back-to-Back Pulses (insufficient gap) ---");
        $display("  NOTE: Second pulse will be lost. This is EXPECTED behavior.");
        $display("  This demonstrates why pulse sync cannot handle bursts.");
        pulse_out_count = 0;

        send_pulse;
        wait_src_cycles(1); 
        send_pulse;
        wait_dst_cycles(15);

        $display("  Back-to-back result: pulse_out fired %0d time(s)", pulse_out_count);
        $display("  (Expected 1 — second pulse lost because toggle hadn't propagated yet)");

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
        #200000;
        $display("TIMEOUT: Simulation exceeded limit.");
        $finish;
    end

    initial begin
        $monitor("Time=%0t | pulse_in=%0b | toggle=%0b | sync1=%0b | sync2=%0b | pulse_out=%0b",
                 $time,
                 pulse_in,
                 dut.toggle_ff,
                 dut.sync_ff1,
                 dut.sync_ff2,
                 pulse_out);
    end

endmodule