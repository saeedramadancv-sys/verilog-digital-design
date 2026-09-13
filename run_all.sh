#!/usr/bin/env bash
# Runs every simulation and fails the script if any suite fails.
# Works without make, which is the common case on a fresh Windows install.
#
#   ./run_all.sh
#
# Tool paths can be overridden:
#   IVERILOG=/c/iverilog/bin/iverilog VVP=/c/iverilog/bin/vvp ./run_all.sh

set -euo pipefail

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
GHDL="${GHDL:-ghdl}"

SIM=sim
GHDL_WORK="$SIM/ghdl"
mkdir -p "$SIM" "$GHDL_WORK"

echo "== Verilog ALU =="
"$IVERILOG" -g2012 -Wall -o "$SIM/alu_tb.vvp" rtl/alu.v tb/alu_tb.v
"$VVP" "$SIM/alu_tb.vvp"

echo
echo "== Sequence detector =="
"$IVERILOG" -g2012 -Wall -o "$SIM/seq_tb.vvp" rtl/seq_detector.v tb/seq_detector_tb.v
"$VVP" "$SIM/seq_tb.vvp"

echo
echo "== VHDL ALU =="
"$GHDL" -a --std=08 --workdir="$GHDL_WORK" vhdl/alu.vhd vhdl/alu_tb.vhd
"$GHDL" -r --std=08 --workdir="$GHDL_WORK" alu_tb

echo
echo "All suites passed."
