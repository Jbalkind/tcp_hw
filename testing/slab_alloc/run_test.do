
vlog -f slab_alloc.flist  +define+PREFER_TEST_OVERRIDE -sv +dumpon
vsim -voptargs=+acc -lib work slab_alloc_trace_tb
log * -r