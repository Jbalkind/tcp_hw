build:
	vcs -full64 +v2k +vpi -debug_all +lint=all,noVCDE -timescale=1ps/1ps +vcs+vcdpluson -sverilog -f rx_pkt_payload_q.flist

run:
	./simv 

%_rom.sv: %.tr
	${BASEJUMP_STL_ROOT}/bsg_mem/bsg_ascii_to_rom.py $< test_rom > test_rom.sv

# For some reason, we can't remove directories occasionally
clean:
	rm -rf *_rom.sv
	-rm -rf csrc DVEfiles/ simv simv.daidir/ stack.info.* ucli.key vcdplus.vpd vc_hdrs.h
