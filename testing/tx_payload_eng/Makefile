build:
	vcs -full64 +v2k +vpi -debug_all +lint=all,noVCDE -timescale=1ps/1ps +vcs+vcdpluson -sverilog -f tx_mem_eng_test.flist

run:
	./simv 

%_input_cmd.sv: %_input_cmd.tr
	${BASEJUMP_STL_ROOT}/bsg_mem/bsg_ascii_to_rom.py $< input_cmd_rom > input_cmd_rom.sv

%_input_data.sv: %_input_data.tr
	${BASEJUMP_STL_ROOT}/bsg_mem/bsg_ascii_to_rom.py $< input_data_rom > input_data_rom.sv

%_output_data.sv: %_output_data.tr
	${BASEJUMP_STL_ROOT}/bsg_mem/bsg_ascii_to_rom.py $< output_data_rom > output_data_rom.sv

# For some reason, we can't remove directories occasionally
clean:
	rm -rf *_rom.sv
	-rm -rf csrc DVEfiles/ simv simv.daidir/ stack.info.* ucli.key vcdplus.vpd vc_hdrs.h
