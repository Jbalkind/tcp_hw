`ifndef TEST_VH
`define TEST_VH
`include "noc_defs.vh"
`include "soc_defs.vh"


`define TRACE_ADDR_W    `MEM_REQ_ADDR_W
`define TRACE_SIZE_W    8
`define TRACE_CMD_W     1

`define CMD_TRACE_W (`TRACE_CMD_W + `TRACE_SIZE_W + `TRACE_ADDR_W)
`define DATA_TRACE_W (`MAC_INTERFACE_W + ` + `MAC_PADBYTES_W)

`define NUM_INPUT_CMD_TRACES 4
`define NUM_INPUT_DATA_TRACES 3
`define NUM_OUTPUT_DATA_TRACES 2

`define INPUT_CMD_ROM_ADDR_W (`BSG_SAFE_CLOG2(`NUM_INPUT_CMD_TRACES))
`define INPUT_DATA_ROM_ADDR_W (`BSG_SAFE_CLOG2(`NUM_INPUT_DATA_TRACES))
`define OUTPUT_DATA_ROM_ADDR_W (`BSG_SAFE_CLOG2(`NUM_OUTPUT_DATA_TRACES))

`define CMD_WR 0
`define CMD_RD 1

typedef struct packed {
    logic                       trace_cmd;
    logic   [`TRACE_ADDR_W-1:0] trace_addr;
    logic   [`TRACE_SIZE_W-1:0] trace_size;
} cmd_trace_struct;
`define CMD_TRACE_STRUCT_W (1 + `TRACE_ADDR_W + `TRACE_SIZE_W)

typedef struct packed {
    logic   [`MAC_INTERFACE_W-1:0]  trace_data;
    logic                           trace_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   trace_data_padbytes;
} data_trace_struct;
`define DATA_TRACE_STRUCT_W (`MAC_INTERFACE_W + 1 + `MAC_INTERFACE_BYTES_W)
`endif
