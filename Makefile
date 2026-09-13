# Simulation targets for the digital design exercises.
#
# IVERILOG / GHDL can be overridden on the command line if the tools are not
# on PATH, which is the usual situation on a fresh Windows install:
#   make IVERILOG="/c/iverilog/bin/iverilog" VVP="/c/iverilog/bin/vvp"

IVERILOG ?= iverilog
VVP      ?= vvp
GHDL     ?= ghdl

SIM      := sim
GHDL_WORK := $(SIM)/ghdl

IVFLAGS  := -g2012 -Wall
GHDLFLAGS := --std=08 --workdir=$(GHDL_WORK)

.PHONY: all alu fsm vhdl clean dirs

all: alu fsm vhdl
	@echo ""
	@echo "All suites passed."

dirs:
	@mkdir -p $(SIM) $(GHDL_WORK)

# --- Verilog ALU -----------------------------------------------------------
alu: dirs
	@echo "== Verilog ALU =="
	$(IVERILOG) $(IVFLAGS) -o $(SIM)/alu_tb.vvp rtl/alu.v tb/alu_tb.v
	$(VVP) $(SIM)/alu_tb.vvp

# --- Verilog sequence detector ---------------------------------------------
fsm: dirs
	@echo "== Sequence detector =="
	$(IVERILOG) $(IVFLAGS) -o $(SIM)/seq_tb.vvp rtl/seq_detector.v tb/seq_detector_tb.v
	$(VVP) $(SIM)/seq_tb.vvp

# --- VHDL ALU ---------------------------------------------------------------
vhdl: dirs
	@echo "== VHDL ALU =="
	$(GHDL) -a $(GHDLFLAGS) vhdl/alu.vhd vhdl/alu_tb.vhd
	$(GHDL) -r $(GHDLFLAGS) alu_tb

clean:
	rm -rf $(SIM)
