`ifndef TEST_DEFS_VH
`define TEST_DEFS_VH

`include "state_defs.vh"

`define IF_SELECT_W 2
`define NEW_REQ 0
`define FULL_REQ 1
`define ENQ_REQ 2
`define DEQ_REQ 3

// interface select + flowid + 2 queue pointers + payload entry + empty
`define TRACE_W (`IF_SELECT_W + `FLOW_ID_W + ((`RX_PAYLOAD_Q_SIZE_W + 1) * 2) + `PAYLOAD_ENTRY_W + 1)
`define CMD_TRACE_W (`TRACE_W - `IF_SELECT_W)

typedef struct packed {
    logic   [`FLOW_ID_W-1:0]             flowid;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    head_ptr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    tail_ptr;
} new_req_struct;
`define NEW_REQ_STRUCT_W (`FLOW_ID_W + ((`RX_PAYLOAD_Q_SIZE_W + 1)*2))

typedef struct packed {
    logic   [`FLOW_ID_W-1:0] flowid;
} full_req_struct;
`define FULL_REQ_STRUCT_W (`FLOW_ID_W)

typedef struct packed {
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    head_ptr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    tail_ptr;
} full_resp_struct;
`define FULL_RESP_STRUCT_W ((`RX_PAYLOAD_Q_SIZE_W + 1) * 2)

typedef struct packed {
    logic   [`FLOW_ID_W-1:0]             flowid;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    tail_ptr;
    payload_buf_entry                   payload_desc;
} enq_req_struct;
`define ENQ_REQ_STRUCT_W (`FLOW_ID_W + (`RX_PAYLOAD_Q_SIZE_W + 1) + `PAYLOAD_ENTRY_W)

typedef struct packed {
    logic   [`FLOW_ID_W-1:0]             flowid;
} deq_req_struct;
`define DEQ_REQ_STRUCT_W (`FLOW_ID_W)

typedef struct packed {
    payload_buf_entry   payload_desc;
    logic               empty;
} deq_resp_struct;
`define DEQ_RESP_STRUCT_W (`PAYLOAD_ENTRY_W + 1)

`endif
