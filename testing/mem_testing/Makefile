make_rom:
	../../basejump_files/bsg_mem/bsg_ascii_to_rom.py memory_test_trace.tr memory_test_trace_rom > memory_test_trace_rom.sv

build:
	vcs -full64 +v2k +vpi -debug_all +lint=all,noVCDE -timescale=1ps/1ps +vcs+vcdpluson -sverilog -f mem_test.flist

clean:
	rm -rf csrc DVEfiles simv simv.daidir stack.info.* ucli.key vcdplus.vpd vc_hdrs.h
