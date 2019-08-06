vlog -f rx_pkt_payload_q.flist  +define+PREFER_TEST_OVERRIDE -sv +dumpon
vsim -voptargs=+acc -lib work rx_pkt_payload_q_trace_tb
log * -r