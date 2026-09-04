QUESTA = /mnt/c/questasim64_10.7c/win64

VLIB = $(QUESTA)/vlib.exe
VMAP = $(QUESTA)/vmap.exe
VLOG = $(QUESTA)/vlog.exe
VSIM = $(QUESTA)/vsim.exe

TOP  = axi_top
TEST = axi_test

WORK = work

INCDIRS = \
	+incdir+../../axi_interface \
	+incdir+../../axi_sequence  \
	+incdir+../../axi_transaction \
	+incdir+../../axi_master_agent \
	+incdir+../../axi_slave_agent \
	+incdir+../../axi_env \
	+incdir+../../axi_test

all: compile sim

lib:
	$(VLIB) $(WORK)
	$(VMAP) $(WORK) $(WORK)

compile: lib
	$(VLOG) -sv $(INCDIRS) ../../axi_pkg/axi_package.sv
	$(VLOG) -sv $(INCDIRS) ../../axi_interface/axi_interface.sv
	$(VLOG) -sv $(INCDIRS) ../../design/axi_slave.sv
	$(VLOG) -sv $(INCDIRS) ../../axi_top/axi_top.sv


sim: compile
	$(VSIM) -c -voptargs=+acc $(WORK).$(TOP) \
		+UVM_TESTNAME=$(TEST) \
		-do "run -all; quit -f"
gui:
	$(VSIM) -voptargs=+acc $(WORK).$(TOP) \
		#if we want waveform according to signal 
		#-do "add wave sim:/axi_top/aclk; add wave sim:/axi_top/arst_n; add wave sim:/axi_top/intf/aclk; add wave sim:/axi_top/intf/arst_n; add wave sim:/axi_top/dut/clk; add wave sim:/axi_top/dut/rst; run 100ns"


clean:
	rm -rf $(WORK)
	rm -f transcript
	rm -f vsim.wlf


# ============================================================
# Clean + Compile
# ============================================================

rebuild: clean compile


# ============================================================
# Help
# ============================================================

help:
	@echo ""
	@echo "AXI UVM QuestaSim Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make compile    - Compile the AXI UVM environment"
	@echo "  make sim        - Run simulation in command-line mode"
	@echo "  make gui        - Run simulation in Questa GUI"
	@echo "  make debug      - Compile and open Questa GUI"
	@echo "  make rebuild    - Clean and compile everything"
	@echo "  make clean      - Remove work library and simulation files"
	@echo "  make all        - Compile and run simulation"
	@echo ""
