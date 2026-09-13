# Digital Design — ALU and Sequence Detector

RTL implementations of a parameterised arithmetic logic unit and a Moore
finite state machine, with self-checking testbenches. The ALU is written twice,
once in Verilog and once in VHDL, and both are held to the same test vectors.

Every testbench compares outputs against independently computed expected values
and exits non-zero on failure, so the whole suite runs unattended in CI. A test
that needs someone to read a waveform to decide whether it passed is not a
regression test.

```
rtl/    alu.v              parameterised ALU, purely combinational
        seq_detector.v     Moore FSM, overlapping 1011 detection
vhdl/   alu.vhd            the same ALU in VHDL-2008
        alu_tb.vhd         VHDL testbench, same vectors as the Verilog one
tb/     alu_tb.v           24 directed checks
        seq_detector_tb.v  bit-stream checks including overlap and reset
```

## Results

| Design | Simulator | Checks | Result |
|---|---|---|---|
| `alu.v` | Icarus Verilog 12 | 24 | pass |
| `alu.vhd` | GHDL 6 (VHDL-2008) | 24 | pass |
| `seq_detector.v` | Icarus Verilog 12 | 21 bits, 3 pulses | pass |

## Running it

Requires [Icarus Verilog](https://bleyer.org/icarus/) and, for the VHDL,
[GHDL](https://github.com/ghdl/ghdl).

```bash
make            # runs everything
make alu        # Verilog ALU only
make fsm        # sequence detector only
make vhdl       # VHDL ALU only
make waves      # regenerate the VCD files for GTKWave
```

## Design notes

### ALU

**One adder, not two.** Subtraction is computed as `a + (~b) + 1`, so the
synthesiser infers a single carry chain shared by `ADD`, `SUB` and `SLT`
instead of one per operation.

**Carry is not overflow.** `carry` is the unsigned indicator — the bit that
falls out of the top of the adder. `overflow` is the signed one, and they are
genuinely independent: `100 + 50` in 8-bit two's complement sets overflow with
no carry, while `-1 + 1` sets carry with no overflow. The testbench pins both
cases precisely because conflating them is the common mistake.

**Set-less-than corrects for overflow.** The signed difference is negative
exactly when `a < b`, except that a signed overflow inverts the sign bit — so
the comparison is `sign_sum XOR overflow`, not `sign_sum` alone.
`SLT(-128, 127)` is the case that separates a correct implementation from one
that only looks correct.

**No inferred latches.** Every combinational block assigns defaults to all of
its outputs before the `case`, and every `case` has a `default`. A branch that
leaves an output unassigned is how a latch appears in synthesis without ever
being written down.

### Sequence detector

**Overlapping detection.** After a match the machine falls back to the longest
suffix of what it has already seen that is also a prefix of the pattern, rather
than restarting. `1011011` therefore produces two detections. A machine that
returns to the idle state after a match silently loses the second one.

**Three-block style.** State register, next-state logic and output logic are
written as three separate blocks. Exactly one register bank is inferred and the
combinational cones feeding it can be read in isolation. Folding all three into
one clocked block simulates the same but makes the synthesised result stop
matching the state diagram.

**Moore, not Mealy.** The output is a function of state alone, so the detection
pulse is glitch-free and aligned to the clock. A Mealy version would assert a
cycle earlier but would follow `din` combinationally, passing any glitch on the
input straight through.

**Synchronous reset.** The reset is sampled on the clock edge like any other
input, which keeps it inside the timed clock domain where static timing
analysis can see it.

### VHDL against Verilog

The same design in both languages, kept side by side because they force
different habits:

- `numeric_std` makes signed and unsigned explicit types. Intent is written
  down rather than inferred from context, and `std_logic_vector` carries no
  numeric meaning at all, so every conversion is visible.
- `process(all)` gives a complete sensitivity list by construction. A
  hand-written list that misses a signal simulates differently from the
  hardware it synthesises to; that failure mode simply cannot occur.
- VHDL-93 forbids reading an `out` port, which is why the result is kept in an
  internal signal and the status flags derive from that.
