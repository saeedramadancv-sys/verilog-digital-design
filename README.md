# Digital design: an ALU and a sequence detector

[![CI](https://github.com/saeedramadancv-sys/verilog-digital-design/actions/workflows/ci.yml/badge.svg)](https://github.com/saeedramadancv-sys/verilog-digital-design/actions/workflows/ci.yml)

I work mostly as a .NET developer now, but my degree is in Computer Engineering, and this repo is me going back to the hardware side of it.

It has a parameterised arithmetic logic unit and a Moore state machine, both with testbenches that check themselves. I wrote the ALU twice, once in Verilog and once in VHDL, and both have to pass the same test vectors.

Each testbench compares the outputs with expected values worked out separately, and exits with an error if anything is wrong. That means the whole suite can run in CI without anyone looking at waveforms. If a person has to read a waveform to decide whether a test passed, it isn't really a regression test.

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
| `alu.vhd` | GHDL (VHDL-2008) | 24 | pass |
| `seq_detector.v` | Icarus Verilog 12 | 24 bits, 3 pulses | pass |

That's 72 checks in total, and CI runs all of them on every push.

## Running it

You need [Icarus Verilog](https://bleyer.org/icarus/), and [GHDL](https://github.com/ghdl/ghdl) for the VHDL part.

```bash
make            # runs everything
make alu        # Verilog ALU only
make fsm        # sequence detector only
make vhdl       # VHDL ALU only
```

On Windows without `make`, double-click `run_all.bat` (or `./run_all.sh` in Git Bash). The testbenches write `.vcd` files to `sim/`, and `view_waves.bat` opens them in GTKWave.

## Design notes

### ALU

**One adder instead of two.** Subtraction is done as `a + (~b) + 1`, so `ADD`, `SUB` and `SLT` share a single carry chain instead of the synthesiser building one for each.

**Carry and overflow are different things.** `carry` is for unsigned numbers: it's the bit that falls off the top of the adder. `overflow` is for signed numbers. They really are independent: in 8-bit two's complement, `100 + 50` sets overflow but not carry, and `-1 + 1` sets carry but not overflow. The testbench checks both cases, because mixing the two up is a common mistake.

**Set-less-than has to account for overflow.** The signed difference is negative exactly when `a < b`, unless the subtraction overflowed, which flips the sign bit. So the result is `sign_sum XOR overflow`, not just `sign_sum`. `SLT(-128, 127)` is the case that catches an implementation that only looks right.

**No accidental latches.** Every combinational block gives all its outputs a default value before the `case`, and every `case` has a `default`. A branch that leaves an output unassigned is how a latch sneaks into the synthesised design without anyone writing one.

### Sequence detector

**Overlapping matches.** After a match, the machine doesn't go back to the start. It falls back to the longest ending of what it has seen that is also a beginning of the pattern. So `1011011` gives two detections. A machine that resets to idle after each match would miss the second one.

**Three separate blocks.** The state register, the next-state logic and the output logic are written as three blocks. Only one set of registers is inferred, and you can read each piece of combinational logic on its own. If you merged everything into one clocked block, the output would also become a register, so the detection pulse would come one clock later unless you decoded it from the next state, and the synthesised result would stop matching the state diagram.

**Moore, not Mealy.** The output depends only on the state, so the detection pulse is clean and lines up with the clock. A Mealy version would fire one cycle earlier, but its output would follow `din` directly, so any glitch on the input would show up on the output.

**Synchronous reset.** Reset is sampled on the clock edge like any other input. That keeps it inside the clocked logic, where static timing analysis can check it.

### VHDL next to Verilog

Writing the same design in both languages made the differences obvious:

- `numeric_std` makes signed and unsigned separate types. You have to say what you mean instead of the tool guessing from context, and `std_logic_vector` has no numeric meaning at all, so every conversion is visible in the code.
- `process(all)` always has a complete sensitivity list. With a hand-written list, forgetting one signal makes the simulation behave differently from the hardware, and `process(all)` rules that out.
- The ALU's result is kept in an internal signal, and the status flags are worked out from it. VHDL-2008 does allow reading an `out` port, but the internal signal makes the flag logic easier to follow.
