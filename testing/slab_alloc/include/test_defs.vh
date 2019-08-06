`ifndef TEST_DEFS_VH
`define TEST_DEFS_VH

`include "bsg_defines.v"

`define TEST_NUM_SLABS 16
`define TEST_SLAB_BYTES 16
`define TEST_SLAB_NUM_W `BSG_SAFE_CLOG2(`TEST_NUM_SLABS)
`define TEST_SLAB_BYTES_W `BSG_SAFE_CLOG2(`TEST_SLAB_BYTES)
`define TEST_ADDR_W (`TEST_SLAB_NUM_W + `TEST_SLAB_BYTES_W)

`define IF_SELECT_W 1
`define ALLOC_REQ 0
`define FREE_REQ 1

`define TRACE_W (`IF_SELECT_W + 1 + `TEST_ADDR_W)
`define CMD_TRACE_W (`TRACE_W - `IF_SELECT_W)

typedef struct packed {
    logic   [`TEST_ADDR_W-1:0]  addr;
} slab_free_req_struct;
`define SLAB_FREE_REQ_STRUCT_W (`TEST_ADDR_W)

typedef struct packed {
    logic                       error;
    logic   [`TEST_ADDR_W-1:0]  addr;
} slab_alloc_resp_struct;
`define SLAB_ALLOC_RESP_STRUCT_W (1 + `TEST_ADDR_W)

`endif
