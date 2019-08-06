package state_struct_pkg;
    import packet_struct_pkg::*;
    
    typedef struct packed {
        logic [`ACK_NUM_W-1:0]      rx_curr_ack_num;
        logic [`WIN_SIZE_W-1:0]     rx_curr_wnd_size;
    } recv_state_entry;
    localparam RECV_STATE_ENTRY_W = (`ACK_NUM_W + `WIN_SIZE_W);

    typedef struct packed {
        logic [PAYLOAD_ENTRY_ADDR_W-1:0]   pkt_payload_addr;
        logic [PAYLOAD_ENTRY_LEN_W-1:0]    pkt_payload_len;
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
        logic   [`RT_ACK_THRESHOLD_W-1:0]   tx_curr_ack_cnt;
        logic   [`ACK_NUM_W-1:0]            tx_curr_ack_num;
    } tx_ack_state_struct;
    localparam TX_ACK_STATE_STRUCT_W = (`RT_ACK_THRESHOLD_W + `ACK_NUM_W);

    typedef struct packed {
        logic   [`TIMESTAMP_W-1:0]  timestamp;
        logic                       timer_armed;
    } tx_ack_timer;
    localparam TX_ACK_TIMER_W = (`TIMESTAMP_W + 1);

    typedef struct packed {
        logic   [`SEQ_NUM_W-1:0]            tx_curr_seq_num;
        tx_ack_timer                        timer;
        tx_ack_state_struct                 tx_curr_ack_state;
    } tx_state_struct;
    localparam TX_STATE_STRUCT_W = (`SEQ_NUM_W + TX_ACK_STATE_STRUCT_W);

    typedef struct packed {
        logic   [`IP_ADDR_W-1:0]        src_ip;
        logic   [`IP_ADDR_W-1:0]        dst_ip;
        tcp_pkt_hdr                     tcp_hdr;
        logic                           payload_val;
        payload_buf_entry               payload_entry;
        logic                           new_flow;
        logic   [`FLOW_ID_W-1:0]        flowid;
    } fsm_input_queue_struct;
    localparam FSM_INPUT_QUEUE_STRUCT_W = ((2 * `IP_ADDR_W) + TCP_HDR_W + 1 + PAYLOAD_ENTRY_W + 1 + `FLOW_ID_W);

    typedef struct packed {
        logic   [`FLOW_ID_W-1:0]    flowid;
        tcp_pkt_hdr                 tcp_hdr;
        logic                       payload_val;
        payload_buf_entry           payload_entry;
    } fsm_reinject_queue_struct;
    localparam FSM_REINJECT_QUEUE_STRUCT_W = (`FLOW_ID_W + TCP_HDR_W + 1 + PAYLOAD_ENTRY_W);

    typedef struct packed {
        logic   [`IP_ADDR_W-1:0]        src_ip;
        logic   [`IP_ADDR_W-1:0]        dst_ip;
        logic   [`FLOW_ID_W-1:0]        flowid;
        tcp_pkt_hdr                     tcp_hdr;
    } rx_send_queue_struct;
    localparam RX_SEND_QUEUE_STRUCT_W = ((2 * `IP_ADDR_W) + `FLOW_ID_W + TCP_HDR_W);


endpackage
