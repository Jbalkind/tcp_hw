vlog -f top_sim.flist -sv +dumpon
vsim -voptargs=+acc -lib work avocado_sim_top
log * -r
