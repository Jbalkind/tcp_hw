run:
	rm -f sw_to_hw.txt hw_to_sw.txt
	./simv

modelsim:
	rm -f sw_to_hw.txt hw_to_sw.txt
	vsim -c -do run_sim.do

build:
	vcs -full64 +v2k +vpi -debug_all +lint=all,noVCDE -timescale=1ps/1ps +vcs+vcdpluson -sverilog -f ../top_sim.flist

wave:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -f sw_to_hw.txt hw_to_sw.txt
	rm -rf csrc DVEfiles simv simv.daidir stack.info.* ucli.key vcdplus.vpd vc_hdrs.h
