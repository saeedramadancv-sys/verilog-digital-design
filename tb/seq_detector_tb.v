`timescale 1ns / 1ps
//=============================================================================
// seq_detector_tb.v - self-checking testbench for the 1011 sequence detector
//
// Drives a bit stream through the machine and checks the detection pulses land
// on exactly the expected cycles. The interesting cases are the overlapping
// stream and the reset behaviour, not the happy path.
//
// Run:
//   iverilog -g2012 -o sim/seq_tb.vvp rtl/seq_detector.v tb/seq_detector_tb.v
//   vvp sim/seq_tb.vvp
//=============================================================================

module seq_detector_tb;

    reg  clk = 0;
    reg  rst_n = 0;
    reg  din = 0;
    wire detected;

    integer errors = 0;
    integer pulses = 0;

    seq_detector dut (
        .clk(clk), .rst_n(rst_n), .din(din), .detected(detected)
    );

    // 10ns clock
    always #5 clk = ~clk;

    //-------------------------------------------------------------------------
    // Drive one bit and check the output during the following cycle.
    //
    // The Moore output reflects the state reached by this bit, so it is read
    // after the clock edge that consumed it.
    //-------------------------------------------------------------------------
    task send_bit;
        input       bit_in;
        input       expect_pulse;
        input [8*40:1] label;
        begin
            din = bit_in;
            @(posedge clk);
            #1;                     // let the state register settle

            if (detected !== expect_pulse) begin
                errors = errors + 1;
                $display("FAIL  %0s : din=%b expected detected=%b, got %b",
                         label, bit_in, expect_pulse, detected);
            end

            if (detected) pulses = pulses + 1;
        end
    endtask

    task do_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            #1;
            rst_n = 1;
        end
    endtask

    initial begin
        $dumpfile("sim/seq_tb.vcd");
        $dumpvars(0, seq_detector_tb);

        $display("=== 1011 sequence detector testbench ===");

        do_reset();

        //---------------------------------------------------------------------
        // Stream 1: a clean single match. 1 0 1 1 -> pulse on the final 1.
        //---------------------------------------------------------------------
        send_bit(1, 0, "S1: first 1");
        send_bit(0, 0, "S2: 10");
        send_bit(1, 0, "S3: 101");
        send_bit(1, 1, "S4: 1011 detected");

        //---------------------------------------------------------------------
        // Stream 2: overlap. Continuing with 0 1 1 completes a second match,
        // because the trailing 11 of the first match is reused. A machine that
        // restarted at S0 after a detection would miss this one entirely.
        //---------------------------------------------------------------------
        send_bit(0, 0, "overlap: 0 -> S2");
        send_bit(1, 0, "overlap: 1 -> S3");
        send_bit(1, 1, "overlap: second 1011 detected");

        //---------------------------------------------------------------------
        // Stream 3: 1010 must not detect - the pattern is 1011, not 1010.
        // The trailing 10 still leaves a usable partial match.
        //---------------------------------------------------------------------
        send_bit(0, 0, "1010: 0");
        send_bit(1, 0, "1010: 1");
        send_bit(0, 0, "1010: 0, no detection");

        //---------------------------------------------------------------------
        // Stream 4: a run of zeros clears any partial match.
        //---------------------------------------------------------------------
        send_bit(0, 0, "zeros: clear");
        send_bit(0, 0, "zeros: clear");
        send_bit(0, 0, "zeros: clear");

        //---------------------------------------------------------------------
        // Stream 5: a run of ones must not detect on its own.
        //---------------------------------------------------------------------
        send_bit(1, 0, "ones: 1");
        send_bit(1, 0, "ones: 11");
        send_bit(1, 0, "ones: 111 no detection");

        //---------------------------------------------------------------------
        // Stream 6: reset mid-pattern must discard the partial match. Feeding
        // 1 0 1 then resetting and feeding 1 must NOT complete a detection.
        //---------------------------------------------------------------------
        send_bit(0, 0, "pre-reset: 0");
        send_bit(1, 0, "pre-reset: 1");
        send_bit(0, 0, "pre-reset: 10");
        send_bit(1, 0, "pre-reset: 101");

        do_reset();

        send_bit(1, 0, "post-reset: 1 must not complete the old pattern");
        send_bit(0, 0, "post-reset: 10");
        send_bit(1, 0, "post-reset: 101");
        send_bit(1, 1, "post-reset: full 1011 detected");

        $display("---------------------------------------------");
        $display("detection pulses observed: %0d (expected 3)", pulses);
        if (errors == 0 && pulses == 3)
            $display("PASS  0 failures");
        else
            $display("FAIL  %0d failures", errors);
        $display("---------------------------------------------");

        if (errors != 0 || pulses != 3) $fatal(1, "sequence detector testbench failed");
        $finish;
    end

endmodule
