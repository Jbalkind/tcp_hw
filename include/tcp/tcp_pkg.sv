package tcp_pkg;
    `include "noc_defs.vh"
    `include "packet_defs.vh"
    `include "soc_defs.vh"

    import packet_struct_pkg::*;

    localparam MAX_FLOW_CNT = 16;
    localparam FLOWID_W = $clog2(MAX_FLOW_CNT);

    localparam PAYLOAD_ENTRY_ADDR_W = 32;
    localparam PAYLOAD_ENTRY_LEN_W = 16;

    localparam PAYLOAD_PTR_W = 12;
    localparam TX_PAYLOAD_PTR_W = PAYLOAD_PTR_W;
    localparam RX_PAYLOAD_PTR_W = PAYLOAD_PTR_W;

    localparam RT_ACK_THRESHOLD = 3;
    localparam RT_ACK_THRESHOLD_W = $clog2(RT_ACK_THRESHOLD);

    localparam TIMESTAMP_W = 64;
    localparam TX_TIMER_LEN = 512;
    
    typedef struct packed {
        logic [`IP_ADDR_W-1:0]      host_ip;
        logic [`IP_ADDR_W-1:0]      dest_ip;
        logic [`PORT_NUM_W-1:0]     host_port;
        logic [`PORT_NUM_W-1:0]     dest_port;
    } flow_lookup_entry;
    localparam FLOW_LOOKUP_ENTRY_W = ((`IP_ADDR_W * 2) + (`PORT_NUM_W * 2));

    typedef struct packed {
        logic [`ACK_NUM_W-1:0]      rx_curr_ack_num;
        logic [`WIN_SIZE_W-1:0]     rx_curr_wnd_size;
    } recv_state_entry;
    localparam RECV_STATE_ENTRY_W = $bits(recv_state_entry);;

    typedef struct packed {
        logic [PAYLOAD_ENTRY_ADDR_W-1:0]   payload_addr;
        logic [PAYLOAD_ENTRY_LEN_W-1:0]    payload_len;
    } payload_buf_struct;
    localparam PAYLOAD_ENTRY_W = $bits(payload_buf_struct);

    localparam TCP_STATE_W = 3;
    typedef enum logic[TCP_STATE_W-1:0] {
        TCP_NONE = 3'd0,
        TCP_SYN_RECV = 3'd1,
        TCP_EST = 3'd3,
        TCP_HALF_CLOSE = 3'd4,
        TCP_UND = 'X
    } tcp_flow_state_e;

    typedef struct packed {
        tcp_flow_state_e state;
    } tcp_flow_state_struct;

    typedef struct packed {
        logic   timeout_pending;
        logic   rt_pending;
    } rt_timeout_flag_struct;
    localparam RT_TIMEOUT_FLAGS_W = (1 + 1);

    typedef struct packed {
        logic   [RT_ACK_THRESHOLD_W-1:0]   tx_curr_ack_cnt;
        logic   [`ACK_NUM_W-1:0]            tx_curr_ack_num;
    } tx_ack_state_struct;
    localparam TX_ACK_STATE_STRUCT_W = $bits(tx_ack_state_struct);

    typedef struct packed {
        logic   [TIMESTAMP_W-1:0]   timestamp;
        logic                       timer_armed;
    } tx_ack_timer;
    localparam TX_ACK_TIMER_W = $bits(tx_ack_timer);

    typedef struct packed {
        logic   [`SEQ_NUM_W-1:0]            tx_curr_seq_num;
        tx_ack_timer                        timer;
        tx_ack_state_struct                 tx_curr_ack_state;
    } tx_state_struct;
    localparam TX_STATE_STRUCT_W = (`SEQ_NUM_W + TX_ACK_STATE_STRUCT_W);

    typedef struct packed {
        logic   [`IP_ADDR_W-1:0]    src_ip;
        logic   [`IP_ADDR_W-1:0]    dst_ip;
        tcp_pkt_hdr                 tcp_hdr;
        logic                       payload_val;
        payload_buf_struct          payload_entry;
        logic                       new_flow;
        logic   [FLOWID_W-1:0]      flowid;
    } fsm_input_queue_struct;
    localparam FSM_INPUT_QUEUE_STRUCT_W = $bits(fsm_input_queue_struct);

    typedef struct packed {
        logic   [FLOWID_W-1:0]  flowid;
        tcp_pkt_hdr             tcp_hdr;
        logic                   payload_val;
        payload_buf_struct      payload_entry;
    } fsm_reinject_queue_struct;
    localparam FSM_REINJECT_QUEUE_STRUCT_W = $bits(fsm_reinject_queue_struct);

    typedef struct packed {
        logic   [`IP_ADDR_W-1:0]        src_ip;
        logic   [`IP_ADDR_W-1:0]        dst_ip;
        logic   [FLOWID_W-1:0]          flowid;
        tcp_pkt_hdr                     tcp_hdr;
    } rx_send_queue_struct;
    localparam RX_SEND_QUEUE_STRUCT_W = $bits(rx_send_queue_struct);

    localparam RX_TMP_BUF_NUM_SLABS = 10;
    localparam RX_TMP_BUF_SLAB_NUM_W = $clog2(RX_TMP_BUF_NUM_SLABS);
    localparam RX_TMP_BUF_SLAB_BYTES = 2048;
    localparam RX_TMP_BUF_SLAB_BYTES_W = $clog2(RX_TMP_BUF_SLAB_BYTES);

    // some nice log trick math
    localparam RX_TMP_BUF_ADDR_W = (RX_TMP_BUF_SLAB_NUM_W + RX_TMP_BUF_SLAB_BYTES_W);
    // calculate the number of bytes available across all slabs and then divide by the number of bytes 
    // in the MAC data interface to get els needed in the memory
    localparam RX_TMP_BUF_MEM_ELS = ((RX_TMP_BUF_NUM_SLABS * RX_TMP_BUF_SLAB_BYTES)/(`MAC_INTERFACE_BYTES));
    localparam RX_TMP_BUF_MEM_ADDR_W = $clog2(RX_TMP_BUF_MEM_ELS);
    
    typedef struct packed {
        logic   [FLOWID_W-1:0]  flowid;
        logic                   accept_payload;
        payload_buf_struct      payload_entry;
    } rx_store_buf_q_struct;
    localparam RX_STORE_BUF_Q_STRUCT_W = $bits(rx_store_buf_q_struct);
endpackage
