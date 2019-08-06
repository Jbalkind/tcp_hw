build:
	vcs -full64 +v2k +vpi -debug_acc+all+dmptf -debug_region+cell+encrypt +lint=all,noVCDE -timescale=1ps/1ps +vcs+vcdpluson -sverilog -f buckfast_test.flist

run:
	./simv 

%_rom.sv: %.tr
	${BASEJUMP_STL_ROOT}/bsg_mem/bsg_ascii_to_rom.py $< buckfast_test_rom > buckfast_test_rom.sv

# For some reason, we can't remove directories occasionally
clean:
	rm -rf *_rom.sv
	-rm -rf csrc DVEfiles/ simv simv.daidir/ stack.info.* ucli.key vcdplus.vpd vc_hdrs.h
