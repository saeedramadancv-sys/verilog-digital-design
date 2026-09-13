`timescale 1ns / 1ps
//=============================================================================
// seq_detector.v - Moore finite state machine detecting the pattern 1011
//
// Overlapping detection: after a match the machine does not restart from
// scratch, it falls back to the longest suffix of what it has already seen
// that is also a prefix of the pattern. For 1011 the last two bits "11" end
// with a "1", which is a valid start, so the machine returns to S1 rather than
// S0. The input stream 1011011 therefore produces two detections, not one.
//
// Written in the three-block style:
//   1. state register   - sequential, the only clocked logic
//   2. next-state logic - combinational
//   3. output logic     - combinational
//
// Keeping them apart is what makes the design map predictably to hardware:
// exactly one register bank is inferred, and the combinational cones feeding
// it are visible in isolation. Folding all three into one clocked block still
// simulates, but the synthesised result stops matching the state diagram you
// drew, and debugging it means reading the netlist instead of the source.
//=============================================================================

module seq_detector (
    input  wire clk,
    input  wire rst_n,       // active-low synchronous reset
    input  wire din,         // serial input, one bit per clock
    output wire detected     // high for one cycle when 1011 completes
);

    //-------------------------------------------------------------------------
    // State encoding.
    //
    // Each state means "this much of the pattern has been matched so far":
    //   S0 - nothing      S1 - 1        S2 - 10
    //   S3 - 101          S4 - 1011 (match)
    //
    // Binary encoding over one-hot: five states fit in three bits, and on an
    // FPGA the synthesiser re-encodes this anyway based on its own timing and
    // area analysis. Writing it readably matters more than guessing at that.
    //-------------------------------------------------------------------------
    localparam [2:0] S0 = 3'd0,
                     S1 = 3'd1,
                     S2 = 3'd2,
                     S3 = 3'd3,
                     S4 = 3'd4;

    reg [2:0] state, next_state;

    //-------------------------------------------------------------------------
    // 1. State register.
    //
    // Synchronous reset: the reset is sampled on the clock edge like any other
    // input. On most FPGA families this maps into the flip-flop's own reset
    // port and keeps the reset inside the timed clock domain, where static
    // timing analysis can see it.
    //
    // Non-blocking assignment (<=) because this models a flip-flop: every
    // register in the block updates from the values the others held at the
    // clock edge. Blocking assignment here would make the result depend on
    // statement order, which is the classic source of simulation-synthesis
    // mismatch.
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n)
            state <= S0;
        else
            state <= next_state;
    end

    //-------------------------------------------------------------------------
    // 2. Next-state logic - purely combinational.
    //
    // next_state is assigned a default before the case so that every path
    // assigns it. Without that default, a missing branch would make the tool
    // infer a latch to "remember" the old value - a latch that never appeared
    // in the state diagram.
    //-------------------------------------------------------------------------
    always @(*) begin
        next_state = state;

        case (state)
            // Nothing matched yet. A 1 starts the pattern.
            S0: next_state = din ? S1 : S0;

            // Matched "1". A 0 extends to "10"; another 1 means the useful
            // history is still just a single 1, so stay in S1.
            S1: next_state = din ? S1 : S2;

            // Matched "10". A 1 extends to "101"; a 0 breaks the pattern and
            // "00" shares no prefix with 1011, so fall back to S0.
            S2: next_state = din ? S3 : S0;

            // Matched "101". A 1 completes 1011; a 0 leaves "1010", whose
            // suffix "10" is a valid partial match, so return to S2 rather
            // than S0 - this is where a naive implementation loses detections.
            S3: next_state = din ? S4 : S2;

            // Match emitted. Overlap handling: the tail of 1011 is "11", so a
            // following 1 leaves us with a single matched 1 (S1) and a 0
            // leaves "110" -> "10" (S2).
            S4: next_state = din ? S1 : S2;

            default: next_state = S0;
        endcase
    end

    //-------------------------------------------------------------------------
    // 3. Output logic - Moore.
    //
    // The output depends on the state alone, never on din. That is the whole
    // point of a Moore machine here: the pulse is glitch-free and aligned to
    // the clock, so downstream logic can sample it safely. A Mealy version
    // would assert one cycle earlier but would follow din combinationally,
    // carrying any glitch on din straight through to the output.
    //-------------------------------------------------------------------------
    assign detected = (state == S4);

endmodule
