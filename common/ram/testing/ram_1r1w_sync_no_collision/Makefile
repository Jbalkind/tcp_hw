# Makefile

# defaults
SIM ?= Questa
TOPLEVEL_LANG ?= verilog

export COCOTB_RESOLVE_X=ZEROS

# This is already in the flist, but cocotb needs to receive at least one Verilog 
# source file I guess to kick the compilation. There's probably a better way to 
# hand it a dummy file, but just give it the top level for now I guess
VERILOG_SOURCES += $(PWD)/tb_ram_1r1w_sync_no_collision.sv
VERILOG_SOURCES += $(PWD)/../../ram_1r1w_sync_no_collision.sv
VERILOG_SOURCES += $(PWD)/../../ram_1r1w_sync.sv

SIM_ARGS = -voptargs=+acc
# SCRIPT_FILE = wave.do
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = tb_ram_1r1w_sync_no_collision

# MODULE is the basename of the Python test file
MODULE = tb_ram_1r1w_sync_no_collision

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

