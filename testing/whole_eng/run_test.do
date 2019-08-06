vlog -f buckfast_test.flist +define+PREFER_TEST_OVERRIDE -sv +dumpon
vsim -voptargs=+acc -lib work buckfast_trace_test_harness
log * -r