`ifndef STATE_DEFS_V
`define STATE_DEFS_V
`include "packet_defs.vh"
`include "protocol_defs.vh"
`include "soc_defs.vh"
//`include "tonic_params.vh"
`include "bsg_defines.v"


// This lets us resize queues and things for easier testing
`ifndef PREFER_TEST_OVERRIDE
`define     MAX_FLOW_CNT            8// should be power of two


//`define RX_PAYLOAD_Q_SIZE_W 7
//`define RX_PAYLOAD_Q_SIZE   (2**`RX_PAYLOAD_Q_SIZE_W)
//
//`define PAYLOAD_BUF_MEM_ELS (`MAX_FLOW_CNT * `RX_PAYLOAD_Q_SIZE)
//`define PAYLOAD_BUF_MEM_ADDR_W (`BSG_SAFE_CLOG2(`PAYLOAD_BUF_MEM_ELS))
`else 
`include "test_override_defs.vh"
`endif

//`define     MAX_FLOW_CNT_WIDTH      (`BSG_SAFE_CLOG2(`MAX_FLOW_CNT))
//`define     FLOW_ID_W               `MAX_FLOW_CNT_WIDTH
//
//`define PAYLOAD_PTR_W  12
//`define RX_PAYLOAD_PTR_W `PAYLOAD_PTR_W
//
//`define PAYLOAD_WIN_SIZE     128
//`define PAYLOAD_WIN_SIZE_W `BSG_SAFE_CLOG2(128)
//
//`define RX_TMP_BUF_NUM_SLABS 10
//`define RX_TMP_BUF_SLAB_NUM_W (`BSG_SAFE_CLOG2(`RX_TMP_BUF_NUM_SLABS))
//`define RX_TMP_BUF_SLAB_BYTES 2048
//`define RX_TMP_BUF_SLAB_BYTES_W (`BSG_SAFE_CLOG2(`RX_TMP_BUF_SLAB_BYTES))
//// some nice log trick math
//`define RX_TMP_BUF_ADDR_W (`RX_TMP_BUF_SLAB_NUM_W + `RX_TMP_BUF_SLAB_BYTES_W)
//// calculate the number of bytes available across all slabs and then divide by the number of bytes 
//// in the MAC data interface to get els needed in the memory
//`define RX_TMP_BUF_MEM_ELS ((`RX_TMP_BUF_NUM_SLABS * `RX_TMP_BUF_SLAB_BYTES)/(`MAC_INTERFACE_BYTES))
//`define RX_TMP_BUF_MEM_ADDR_W (`BSG_SAFE_CLOG2(`RX_TMP_BUF_MEM_ELS))
//
//`define TIMESTAMP_W 64
//`define TX_TIMER_LEN 512

`endif
