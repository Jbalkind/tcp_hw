`ifndef PROTOCOL_DEFS_H
`define PROTOCOL_DEFS_H
`include "bsg_defines.v"

`define RT_ACK_THRESHOLD 3
`define RT_ACK_THRESHOLD_W (`BSG_SAFE_CLOG2(`RT_ACK_THRESHOLD))
`endif
