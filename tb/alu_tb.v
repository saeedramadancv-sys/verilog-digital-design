`timescale 1ns / 1ps
//=============================================================================
// alu_tb.v - self-checking testbench for the ALU
//
// The testbench compares every output against an independently computed
// expected value and counts failures, rather than printing values for a human
// to read off a waveform. A test that needs someone to squint at a waveform to
// decide whether it passed is not a regression test.
//
// Run:
//   iverilog -g2012 -o sim/alu_tb.vvp rtl/alu.v tb/alu_tb.v
//   vvp sim/alu_tb.vvp
//=============================================================================

module alu_tb;

    localparam WIDTH = 8;

    reg  [WIDTH-1:0] a, b;
    reg  [3:0]       opcode;
    wire [WIDTH-1:0] result;
    wire             zero, negative, carry, overflow;

    integer errors = 0;
    integer checks = 0;

    alu #(.WIDTH(WIDTH)) dut (
        .a(a), .b(b), .opcode(opcode),
        .result(result), .zero(zero), .negative(negative),
        .carry(carry), .overflow(overflow)
    );

    localparam [3:0] OP_ADD = 4'b0000;
    localparam [3:0] OP_SUB = 4'b0001;
    localparam [3:0] OP_AND = 4'b0010;
    localparam [3:0] OP_OR  = 4'b0011;
    localparam [3:0] OP_XOR = 4'b0100;
    localparam [3:0] OP_NOT = 4'b0101;
    localparam [3:0] OP_SLL = 4'b0110;
    localparam [3:0] OP_SRL = 4'b0111;
    localparam [3:0] OP_SLT = 4'b1000;

    //-------------------------------------------------------------------------
    // One directed check: drive the inputs, wait for the combinational logic
    // to settle, then compare every output against the expected value.
    //-------------------------------------------------------------------------
    task check;
        input [WIDTH-1:0] ta, tb;
        input [3:0]       top;
        input [WIDTH-1:0] exp_result;
        input             exp_carry, exp_ovf, exp_zero, exp_neg;
        input [200*8:1]   label;
        begin
            a      = ta;
            b      = tb;
            opcode = top;
            #1;                 // settle: combinational logic has no clock

            checks = checks + 1;

            if (result   !== exp_result ||
                carry    !== exp_carry  ||
                overflow !== exp_ovf    ||
                zero     !== exp_zero   ||
                negative !== exp_neg) begin
                errors = errors + 1;
                $display("FAIL  %0s", label);
                $display("      a=%0d (%b) b=%0d (%b) opcode=%b", ta, ta, tb, tb, top);
                $display("      got      result=%0d (%b) c=%b v=%b z=%b n=%b",
                         result, result, carry, overflow, zero, negative);
                $display("      expected result=%0d (%b) c=%b v=%b z=%b n=%b",
                         exp_result, exp_result, exp_carry, exp_ovf, exp_zero, exp_neg);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/alu_tb.vcd");
        $dumpvars(0, alu_tb);

        $display("=== ALU testbench, WIDTH=%0d ===", WIDTH);

        //---------------------------------------------------------------------
        // Addition
        //---------------------------------------------------------------------
        //          a     b    opcode   result  c v z n   label
        check(8'd10, 8'd15, OP_ADD, 8'd25,  0,0,0,0, "ADD 10+15=25");
        check(8'd0,  8'd0,  OP_ADD, 8'd0,   0,0,1,0, "ADD 0+0 sets zero");

        // Unsigned carry-out: 200+100 = 300, does not fit in 8 bits.
        check(8'd200, 8'd100, OP_ADD, 8'd44, 1,0,0,0, "ADD unsigned carry-out");

        // Signed overflow: 100+50 = 150 > 127, so as a signed value the result
        // (-106) has the wrong sign. Carry-out is 0 here, which is exactly why
        // carry cannot be used as the signed overflow indicator.
        check(8'd100, 8'd50, OP_ADD, 8'd150, 0,1,0,1, "ADD signed overflow, no carry");

        // -1 + 1 = 0, with a carry-out. Carry set while the result is zero.
        check(8'hFF, 8'd1, OP_ADD, 8'd0, 1,0,1,0, "ADD -1+1 carry with zero result");

        //---------------------------------------------------------------------
        // Subtraction. Carry-out means "no borrow", i.e. a >= b unsigned.
        //---------------------------------------------------------------------
        check(8'd20, 8'd5,  OP_SUB, 8'd15,  1,0,0,0, "SUB 20-5=15, no borrow");
        check(8'd5,  8'd20, OP_SUB, 8'd241, 0,0,0,1, "SUB 5-20 borrows, negative");
        check(8'd7,  8'd7,  OP_SUB, 8'd0,   1,0,1,0, "SUB equal operands set zero");

        // Signed overflow on subtraction: -128 - 1 leaves the signed range.
        check(8'h80, 8'd1, OP_SUB, 8'h7F, 1,1,0,0, "SUB signed overflow at -128");

        //---------------------------------------------------------------------
        // Logic. These operations leave carry and overflow at 0.
        //---------------------------------------------------------------------
        check(8'b1100_1010, 8'b1010_1100, OP_AND, 8'b1000_1000, 0,0,0,1, "AND");
        check(8'b1100_0000, 8'b0000_0011, OP_OR,  8'b1100_0011, 0,0,0,1, "OR");
        check(8'b1111_0000, 8'b1111_1111, OP_XOR, 8'b0000_1111, 0,0,0,0, "XOR");
        check(8'b1010_1010, 8'd0,         OP_NOT, 8'b0101_0101, 0,0,0,0, "NOT a");
        check(8'b1111_1111, 8'b1111_1111, OP_XOR, 8'd0,         0,0,1,0, "XOR equal sets zero");

        //---------------------------------------------------------------------
        // Shifts. carry carries the bit shifted out.
        //---------------------------------------------------------------------
        check(8'b0001_0001, 8'd0, OP_SLL, 8'b0010_0010, 0,0,0,0, "SLL no bit lost");
        check(8'b1000_0001, 8'd0, OP_SLL, 8'b0000_0010, 1,0,0,0, "SLL MSB into carry");
        check(8'b1000_0010, 8'd0, OP_SRL, 8'b0100_0001, 0,0,0,0, "SRL no bit lost");
        check(8'b0000_0011, 8'd0, OP_SRL, 8'b0000_0001, 1,0,0,0, "SRL LSB into carry");

        //---------------------------------------------------------------------
        // Signed set-on-less-than, including the overflow case that a naive
        // "just look at the sign bit" implementation gets wrong.
        //---------------------------------------------------------------------
        check(8'd5,  8'd10, OP_SLT, 8'd1, 0,0,0,0, "SLT 5 < 10");
        check(8'd10, 8'd5,  OP_SLT, 8'd0, 0,0,1,0, "SLT 10 not < 5");
        check(8'hFB, 8'd5,  OP_SLT, 8'd1, 0,0,0,0, "SLT -5 < 5 signed");
        check(8'd5,  8'hFB, OP_SLT, 8'd0, 0,0,1,0, "SLT 5 not < -5 signed");
        check(8'h80, 8'd127, OP_SLT, 8'd1, 0,0,0,0, "SLT -128 < 127, overflow corrected");

        //---------------------------------------------------------------------
        // Unknown opcode must produce a defined result, not X.
        //---------------------------------------------------------------------
        check(8'hAA, 8'h55, 4'b1111, 8'd0, 0,0,1,0, "unknown opcode is defined");

        $display("---------------------------------------------");
        if (errors == 0)
            $display("PASS  %0d checks, 0 failures", checks);
        else
            $display("FAIL  %0d checks, %0d failures", checks, errors);
        $display("---------------------------------------------");

        if (errors != 0) $fatal(1, "ALU testbench failed");
        $finish;
    end

endmodule
