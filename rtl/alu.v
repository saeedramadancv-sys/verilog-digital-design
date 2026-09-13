`timescale 1ns / 1ps
//=============================================================================
// alu.v - parameterised arithmetic logic unit
//
// A purely combinational ALU: every output is a function of the current
// inputs only, with no clock and no stored state. That is deliberate - an ALU
// sits inside a datapath and must settle within one clock period, so adding a
// register here would push the pipelining decision into the wrong module.
//
// The design uses a single shared adder for ADD and SUB. Subtraction is
// performed as a + (~b) + 1 (two's complement), so the synthesiser infers one
// adder rather than two. On an FPGA that halves the carry-chain resources this
// block consumes.
//=============================================================================

module alu #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,          // first operand
    input  wire [WIDTH-1:0] b,          // second operand
    input  wire [3:0]       opcode,     // operation select
    output reg  [WIDTH-1:0] result,     // operation result
    output wire             zero,       // result == 0
    output wire             negative,   // result MSB (sign bit, two's complement)
    output reg              carry,      // carry-out / no-borrow, arithmetic ops only
    output reg              overflow    // signed overflow, arithmetic ops only
);

    //-------------------------------------------------------------------------
    // Operation encoding.
    //
    // localparam rather than `define: these names stay scoped to this module
    // instead of leaking into every file compiled after it.
    //-------------------------------------------------------------------------
    localparam [3:0] OP_ADD = 4'b0000;
    localparam [3:0] OP_SUB = 4'b0001;
    localparam [3:0] OP_AND = 4'b0010;
    localparam [3:0] OP_OR  = 4'b0011;
    localparam [3:0] OP_XOR = 4'b0100;
    localparam [3:0] OP_NOT = 4'b0101;
    localparam [3:0] OP_SLL = 4'b0110;  // shift left logical by 1
    localparam [3:0] OP_SRL = 4'b0111;  // shift right logical by 1
    localparam [3:0] OP_SLT = 4'b1000;  // set on less than, signed

    //-------------------------------------------------------------------------
    // Shared adder.
    //
    // add_b is b for addition and ~b for subtraction; carry_in supplies the
    // +1 that completes the two's complement negation. sum is WIDTH+1 bits
    // wide so the carry-out falls naturally into the top bit instead of being
    // reconstructed from the operand sign bits.
    //-------------------------------------------------------------------------
    wire                is_sub   = (opcode == OP_SUB) || (opcode == OP_SLT);
    wire [WIDTH-1:0]    add_b    = is_sub ? ~b : b;
    wire                carry_in = is_sub ? 1'b1 : 1'b0;
    wire [WIDTH:0]      sum      = {1'b0, a} + {1'b0, add_b} + carry_in;

    //-------------------------------------------------------------------------
    // Signed overflow.
    //
    // Overflow happens only when the operand signs allow it and the result
    // sign contradicts them:
    //   addition    - both operands share a sign, result differs
    //   subtraction - operands differ in sign, result differs from a
    // Checking the carry-out instead would be wrong: carry-out is the unsigned
    // indicator and says nothing about signed range.
    //-------------------------------------------------------------------------
    wire sign_a   = a[WIDTH-1];
    wire sign_b   = b[WIDTH-1];
    wire sign_sum = sum[WIDTH-1];

    wire add_overflow = (sign_a == sign_b)      && (sign_sum != sign_a);
    wire sub_overflow = (sign_a != sign_b)      && (sign_sum != sign_a);

    //-------------------------------------------------------------------------
    // Result and flag selection.
    //
    // A single always @(*) block with a full case and a default branch: every
    // output is assigned on every path, so no latch can be inferred. Leaving
    // one output unassigned in one branch is the classic way an accidental
    // latch appears in synthesis.
    //-------------------------------------------------------------------------
    always @(*) begin
        // Defaults. Logical and shift operations do not define carry or
        // overflow, so they read as 0 rather than holding a stale value.
        result   = {WIDTH{1'b0}};
        carry    = 1'b0;
        overflow = 1'b0;

        case (opcode)
            OP_ADD: begin
                result   = sum[WIDTH-1:0];
                carry    = sum[WIDTH];
                overflow = add_overflow;
            end

            OP_SUB: begin
                result   = sum[WIDTH-1:0];
                // For subtraction the adder's carry-out means "no borrow
                // occurred", i.e. a >= b when read as unsigned.
                carry    = sum[WIDTH];
                overflow = sub_overflow;
            end

            OP_AND: result = a & b;
            OP_OR:  result = a | b;
            OP_XOR: result = a ^ b;
            OP_NOT: result = ~a;

            // Shifts by a constant 1: the synthesiser turns these into wiring,
            // not logic, because the bit positions are known at elaboration.
            OP_SLL: begin
                result = {a[WIDTH-2:0], 1'b0};
                carry  = a[WIDTH-1];        // bit shifted out of the top
            end

            OP_SRL: begin
                result = {1'b0, a[WIDTH-1:1]};
                carry  = a[0];              // bit shifted out of the bottom
            end

            // Signed comparison. The subtraction already sits in sum; the
            // signed result is negative exactly when a < b, except that a
            // signed overflow inverts the sign bit, so the two are XORed.
            OP_SLT: result = {{(WIDTH-1){1'b0}}, (sign_sum ^ sub_overflow)};

            default: begin
                result   = {WIDTH{1'b0}};
                carry    = 1'b0;
                overflow = 1'b0;
            end
        endcase
    end

    //-------------------------------------------------------------------------
    // Status flags derived from the result.
    //
    // Continuous assignments rather than case branches: these mean the same
    // thing for every operation, so writing them once removes a whole class of
    // copy-paste mistakes.
    //-------------------------------------------------------------------------
    assign zero     = (result == {WIDTH{1'b0}});
    assign negative = result[WIDTH-1];

endmodule
