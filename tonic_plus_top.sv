`include "packet_defs.vh"
`include "state_defs.vh"
`include "bsg_defines.v"
`include "tonic_params.vh"
`include "tonic_defaults.vh"

module tonic_plus_top(
     input                                      clk
    ,input                                      rst

    // For acks
    ,input                                      parser_tcp_rx_hdr_val
    ,output                                     tcp_parser_rx_rdy
    ,input  [`IP_ADDR_WIDTH-1:0]                parser_tcp_rx_src_ip
    ,input  [`IP_ADDR_WIDTH-1:0]                parser_tcp_rx_dst_ip
    ,input  [`TCP_HEADER_WIDTH-1:0]             parser_tcp_rx_tcp_hdr

    ,input                                      parser_tcp_rx_payload_val
    ,input  [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] parser_tcp_rx_payload_addr
    ,input  [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  parser_tcp_rx_payload_len

    // For adding a new flow to the FIFO
    ,input                                      new_flowid_val
    ,input  [`FLOW_ID_W-1:0]                    new_flowid

    // For adding a new flow's state to the state RAMs and the flow lookup table
    ,input                                      reset_tonic_cntxt_val
    ,input  [`FLOW_ID_W-1:0]                    reset_tonic_cntxt_flowid
    ,input  [`DD_CONTEXT_1_W-1:0]               reset_tonic_dd_cntxt_1
    ,input  [`DD_CONTEXT_2_W-1:0]               reset_tonic_dd_cntxt_2
    ,input  [`CR_CONTEXT_1_W-1:0]               reset_tonic_cr_cntxt_1
    
    ,input                                      reset_tonic_expected_ack_val
    ,input  [`FLOW_ID_W-1:0]                    reset_tonic_expected_ack_addr
    ,input  [`PAYLOAD_WIN_SIZE_WIDTH-1:0]       reset_tonic_expected_ack_data
    
    ,input                                      reset_tonic_next_free_val
    ,input  [`FLOW_ID_W-1:0]                    reset_tonic_next_free_addr
    ,input  [`PAYLOAD_WIN_SIZE_WIDTH-1:0]       reset_tonic_next_free_data

    ,input                                      reset_tonic_recv_enqueue_val
    ,input  [`FLOW_ID_W-1:0]                    reset_tonic_recv_enqueue_addr
    ,input  [`PAYLOAD_WIN_SIZE_WIDTH-1:0]       reset_tonic_recv_enqueue_data
    
    ,input                                      reset_tonic_recv_dequeue_val
    ,input  [`FLOW_ID_W-1:0]                    reset_tonic_recv_dequeue_addr
    ,input  [`PAYLOAD_WIN_SIZE_WIDTH-1:0]       reset_tonic_recv_dequeue_data

    // For adding packets to payload queues
    ,input                                      enqueue_packet_val
    ,input  [`FLOW_ID_W-1:0]                    enqueue_packet_flowid
    ,input  [`PAYLOAD_WIN_SIZE_WIDTH-1:0]       enqueue_packet_index
    ,input  [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] enqueue_packet_payload_addr
    ,input  [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  enqueue_packet_payload_len
    
    ,input                                      payload_queue_full_req_val
    ,input  [`FLOW_ID_W-1:0]                    payload_queue_full_req_flowid

    ,output                                     payload_queue_full_resp_val
    ,output                                     payload_queue_full_resp
    ,output [`PAYLOAD_WIN_SIZE_WIDTH-1:0]       payload_queue_next_free_index_resp

    // For dequeuing packets from the recv queue
    ,input                                      read_recv_payload_req_val
    ,input  [`FLOW_ID_W-1:0]                    read_recv_payload_req_flowid

    ,output                                     read_recv_payload_resp_val
    ,output                                     read_recv_payload_resp_empty
    ,output [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] read_recv_payload_resp_addr
    ,output [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  read_recv_payload_resp_len            

    // For sending out a complete packet
    ,output                                     tcp_parser_tx_val
    ,input                                      parser_tcp_tx_rdy
    ,output [`IP_ADDR_WIDTH-1:0]                tcp_parser_tx_src_ip
    ,output [`IP_ADDR_WIDTH-1:0]                tcp_parser_tx_dst_ip
    ,output [`TCP_HEADER_WIDTH-1:0]             tcp_parser_tx_tcp_hdr
    ,output [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] tcp_parser_tx_payload_addr
    ,output [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  tcp_parser_tx_payload_len

    ,output                                     app_new_flow_notif_val
    ,output [`FLOW_ID_W-1:0]                    app_new_flow_flow_id
);

tcp_packet_header packet_header_in;

logic                                       recv_state_for_ack_req_val;
logic   [`FLOW_ID_W-1:0]                    recv_state_for_ack_req_addr;
recv_state_entry                            recv_state_for_ack_resp;

wire                            lookedup_ack_pending;

wire [`FLOW_ID_W-1:0]           recv_set_ack_pending_addr;
wire                            recv_set_ack_pending;
wire [`FLOW_ID_W-1:0]           send_clear_ack_pending_addr;
wire                            send_clear_ack_pending;

logic    [`FLOW_ID_W-1:0]       tonic_flowid_lookup_flowid_t;

logic                           tonic_flowid_lookup_val_t;
logic    [`SEQ_NUM_WIDTH-1:0]   tonic_seq_out_t;
logic    [`TX_CNT_W-1:0]        tonic_seq_tx_id_out_t;

wire [`PKT_TYPE_W-1:0]          tonic_pkt_type_in;
wire [`PKT_DATA_W-1:0]          tonic_pkt_data_in;

wire                            tonic_new_flowid_val;
wire    [`FLOW_ID_W-1:0]        tonic_new_flowid;

wire    [`FLOW_ID_W-1:0]        tonic_incoming_fid;

wire    [`FLOW_SEQ_NUM_W-1:0]   wnd_start;
wire    [`FLOW_ID_W-1:0]        wnd_start_flowid;

logic                           empty_req_val;
logic   [`FLOW_ID_W-1:0]        empty_req_flowid;

logic                           empty_next_free_index_resp_val;
logic   [`PAYLOAD_WIN_SIZE_WIDTH-1:0] empty_next_free_index_resp;

logic                                       engine_recv_header_val;
tcp_packet_header                           engine_recv_tcp_hdr;
logic   [`FLOW_ID_W-1:0]                    engine_recv_flowid;
logic                                       engine_recv_packet_enqueue_val;
payload_buf_entry                           engine_recv_packet_enqueue_entry;

logic                                       write_recv_state_val;
logic   [`FLOW_ID_W-1:0]                    write_recv_state_addr;
recv_state_entry                            write_recv_state;

logic                                       curr_recv_state_req_val;
logic   [`FLOW_ID_W-1:0]                    curr_recv_state_req_addr;
logic                                       curr_recv_state_req_rdy;

logic                                       curr_recv_state_resp_val;
recv_state_entry                            curr_recv_state_resp;
logic                                       curr_recv_state_resp_rdy;

logic                                       next_recv_state_val;
logic   [`FLOW_ID_W-1:0]                    next_recv_state_addr;
recv_state_entry                            next_recv_state;
    
logic                                       new_idtoaddr_lookup_val;
logic   [`FLOW_ID_W-1:0]                    new_idtoaddr_lookup_flow_id;
flow_lookup_entry                           new_idtoaddr_lookup_entry;
logic   [`SEQ_NUM_WIDTH-1:0]                new_init_seq_num;

logic                                       syn_ack_val;
logic   [`IP_ADDR_WIDTH-1:0]                syn_ack_src_ip;
logic   [`IP_ADDR_WIDTH-1:0]                syn_ack_dst_ip;
tcp_packet_header                           syn_ack_hdr;

logic                                       recv_pipe_init_seq_num_rd_req_val;
logic   [`FLOW_ID_W-1:0]                    recv_pipe_init_seq_num_rd_req_addr;
logic                                       init_seq_num_recv_pipe_rd_req_rdy;

logic                                       init_seq_num_recv_pipe_rd_resp_val;
logic   [`SEQ_NUM_WIDTH-1:0]                init_seq_num_recv_pipe_rd_resp_data;
logic                                       recv_pipe_init_seq_num_rd_resp_rdy;

assign tonic_new_flowid_val = new_flowid_val;
assign tonic_new_flowid = new_flowid;

assign packet_header_in = parser_tcp_rx_tcp_hdr;


/**************************************************************************
 * Stall wires
 *************************************************************************/
logic   stall_t;
logic   stall_l;
logic   stall_th;

/**************************************************************************
 * Pull out ACKs for Tonic
 *************************************************************************/

// Receiving only ACKs right now
assign tonic_incoming_fid = engine_recv_header_val ? engine_recv_flowid : `FLOW_ID_NONE;
    
assign tonic_pkt_type_in = engine_recv_header_val & 
                           ((engine_recv_tcp_hdr.flags & `TCP_ACK) != 0) ? `CACK_PKT : `NONE_PKT;

//parser_tcp_rx_hdr_val ? 
//                                        (packet_header_in.flags & `TCP_ACK) > 0 ? `CACK_PKT : `NONE_PKT
//                                        : `NONE_PKT;


// because the engine doesn't think about the SYN-ACK, the ACK num sent to us is 1 ahead
assign tonic_pkt_data_in = {(engine_recv_tcp_hdr.ack_num) >> `SEQ_NUM_SHIFT, 
                            {(`PKT_DATA_W - `ACK_NUM_WIDTH){1'b0}}};
//parser_rx_tcp_hdr_val ? {packet_header_in.ack_num, {(`PKT_DATA_W - `ACK_NUM_WIDTH){1'b0}}}: 'b0;
/*************************************************************
 * Tonic stages
 ************************************************************/

tonic tonic(
     .clk(clk)
    ,.rst_n(~rst)
    
    ,.incoming_fid_in       (tonic_incoming_fid             )
    ,.pkt_type_in           (tonic_pkt_type_in              )
    ,.pkt_data_in           (tonic_pkt_data_in              )

    ,.new_flowid_val        (tonic_new_flowid_val           )
    ,.new_flowid            (tonic_new_flowid               )
    
    ,.new_cntxt_val         (reset_tonic_cntxt_val          )
    ,.new_cntxt_flowid      (reset_tonic_cntxt_flowid       )
    ,.dd_new_cntxt_1        (reset_tonic_dd_cntxt_1         )
    ,.dd_new_cntxt_2        (reset_tonic_dd_cntxt_2         )
    ,.cr_new_cntxt          (reset_tonic_cr_cntxt_1         )

    ,.link_avail(~stall_t)

    ,.next_val              (tonic_flowid_lookup_val_t      )
    ,.next_seq_fid_out      (tonic_flowid_lookup_flowid_t   )
    ,.next_seq_out          (tonic_seq_out_t                )
    ,.next_seq_tx_id_out    (tonic_seq_tx_id_out_t          )

    ,.wnd_start_out         (wnd_start                      )
    ,.wnd_start_out_flowid  (wnd_start_flowid               )

    ,.empty_req_val         (empty_req_val                  )
    ,.empty_req_flowid      (empty_req_flowid               )

    ,.empty_next_free_index_resp_val  (empty_next_free_index_resp_val )
    ,.empty_next_free_index_resp      (empty_next_free_index_resp     )
);

assign stall_t = stall_l;

/*************************************************************
 * (T)onic stages -> (L)ookup stages
 ************************************************************/
logic                           tonic_flowid_lookup_val_l;
logic   [`FLOW_ID_W-1:0]        tonic_flowid_lookup_flowid_l;
logic   [`SEQ_NUM_WIDTH-1:0]    tonic_seg_num_next_l;

always @(posedge clk) begin
    if (rst) begin
        tonic_flowid_lookup_val_l <= 'b0;
        tonic_flowid_lookup_flowid_l <= 'b0;
        tonic_seg_num_next_l <= 'b0;
    end
    else begin
        if (!stall_l) begin
            tonic_flowid_lookup_val_l <= tonic_flowid_lookup_val_t;
            tonic_flowid_lookup_flowid_l <= tonic_flowid_lookup_flowid_t;
            tonic_seg_num_next_l <= tonic_seq_out_t;
        end
    end
end

/*************************************************************
 * (L)ookup stages
 ************************************************************/
recv_state_entry    recv_state_for_ack_th;

// We need these here to support the synchronous read
payload_buf_entry               payload_buf_entry_th;
logic                           lookedup_entry_val_th;
logic   [`FLOW_ID_W-1:0]        lookedup_entry_host_flowid_th;
logic   [`SEQ_NUM_WIDTH-1:0]    tonic_seg_num_next_th;

logic                           read_packet_val_l;
logic   [`FLOW_ID_W-1:0]        read_packet_flowid_l;
logic   [`SEQ_NUM_WIDTH-1:0]    read_packet_num_l;

logic                           read_seq_num_req_val_l;
logic   [`FLOW_ID_W-1:0]        read_seq_num_req_flowid_l;
logic                           read_seq_num_resp_val_th;
logic   [`SEQ_NUM_WIDTH-1:0]    read_seq_num_resp_th;
logic                           read_seq_num_resp_rdy_th;

assign stall_l = stall_th;

// This logically belongs in the lookup stage, but because it's synchronous read, we have
// to start a cycle early
flow_lookup_entry   lookedup_entry_l;

flowid_to_addr flowid_addr_lookup(
     .clk(clk)
    ,.rst(rst)

    ,.write_val         (new_idtoaddr_lookup_val        )
    ,.write_flowid      (new_idtoaddr_lookup_flow_id    )
    ,.write_flow_entry  (new_idtoaddr_lookup_entry      )

    ,.read_val          (tonic_flowid_lookup_val_t      )
    ,.read_flowid       (tonic_flowid_lookup_flowid_t   )
    ,.read_flow_entry   (lookedup_entry_l               )

);

// if we're stalled, we need to re-read using the previous instruction (the one in th's) address
assign recv_state_for_ack_req_val = stall_l ? lookedup_entry_val_th : tonic_flowid_lookup_val_l;
assign recv_state_for_ack_req_addr = stall_l ? lookedup_entry_host_flowid_th 
                                             : tonic_flowid_lookup_flowid_l;

assign read_packet_val_l = stall_l ? lookedup_entry_val_th : tonic_flowid_lookup_val_l;
assign read_packet_flowid_l = stall_l ? lookedup_entry_host_flowid_th : tonic_flowid_lookup_flowid_l;
assign read_packet_num_l = stall_l ? tonic_seg_num_next_th : tonic_seg_num_next_l; 

send_packet_payload_queues send_queues (
     .clk(clk)
    ,.rst(rst)
    
    ,.new_expected_ack_val              (reset_tonic_expected_ack_val       )
    ,.new_expected_ack_addr             (reset_tonic_expected_ack_addr      )
    ,.new_expected_ack_data             (reset_tonic_expected_ack_data      )
                                                                            
    ,.new_next_free_val                 (reset_tonic_next_free_val          )
    ,.new_next_free_addr                (reset_tonic_next_free_addr         )
    ,.new_next_free_data                (reset_tonic_next_free_data         )

    ,.wnd_start                         (wnd_start                          )
    ,.wnd_start_flowid                  (wnd_start_flowid                   )

    ,.enqueue_packet_val                (enqueue_packet_val                 )
    ,.enqueue_packet_flowid             (enqueue_packet_flowid              )
    ,.enqueue_packet_index              (enqueue_packet_index               )
    ,.enqueue_packet_payload_addr       (enqueue_packet_payload_addr        )
    ,.enqueue_packet_payload_len        (enqueue_packet_payload_len         )

    ,.payload_queue_full_req_val        (payload_queue_full_req_val         )
    ,.payload_queue_full_req_flowid     (payload_queue_full_req_flowid      )
                                                                            
    ,.payload_queue_full_resp_val       (payload_queue_full_resp_val        )
    ,.payload_queue_full_resp           (payload_queue_full_resp            )
    ,.payload_queue_next_free_index_resp(payload_queue_next_free_index_resp )
    
    // These go to Tonic for scheduling the flow
    ,.empty_req_val                     (empty_req_val                      )
    ,.empty_req_flowid                  (empty_req_flowid                   )
    
    ,.empty_next_free_index_resp_val    (empty_next_free_index_resp_val     )
    ,.empty_next_free_index_resp        (empty_next_free_index_resp         )

    ,.read_packet_val                   (read_packet_val_l                  )
    ,.read_packet_flowid                (read_packet_flowid_l               )
    ,.read_packet_num                   (read_packet_num_l                  )
 
    // This read is synchronous, so we just assign it to the next stage
    ,.read_payload_buf_entry            (payload_buf_entry_th               )
);

assign read_seq_num_req_val_l = ~stall_l & tonic_flowid_lookup_val_l;
assign read_seq_num_req_flowid_l = tonic_flowid_lookup_flowid_l;

init_seq_num_mem #(
     .width_p   (`SEQ_NUM_WIDTH)
    ,.els_p     (`MAX_FLOW_CNT)
) tx_init_seq_num_mem (
     .clk   (clk)
    ,.rst   (rst)

    ,.init_seq_num_wr_req_val   (new_idtoaddr_lookup_val            )
    ,.init_seq_num_wr_req_addr  (new_idtoaddr_lookup_flow_id        )
    ,.init_seq_num_wr_num       (new_init_seq_num                   )
    ,.init_seq_num_wr_req_rdy   ()

    ,.init_seq_num_rd0_req_val  (read_seq_num_req_val_l             )
    ,.init_seq_num_rd0_req_addr (read_seq_num_req_flowid_l          )
    ,.init_seq_num_rd0_req_rdy  ()

    ,.init_seq_num_rd0_resp_val (read_seq_num_resp_val_th           )
    ,.init_seq_num_rd0_resp     (read_seq_num_resp_th               )
    ,.init_seq_num_rd0_resp_rdy (read_seq_num_resp_rdy_th           )
    
    ,.init_seq_num_rd1_req_val  (recv_pipe_init_seq_num_rd_req_val  )
    ,.init_seq_num_rd1_req_addr (recv_pipe_init_seq_num_rd_req_addr )
    ,.init_seq_num_rd1_req_rdy  (init_seq_num_recv_pipe_rd_req_rdy  )

    ,.init_seq_num_rd1_resp_val (init_seq_num_recv_pipe_rd_resp_val )
    ,.init_seq_num_rd1_resp     (init_seq_num_recv_pipe_rd_resp_data)
    ,.init_seq_num_rd1_resp_rdy (recv_pipe_init_seq_num_rd_resp_rdy )
);

/*************************************************************
 * (L)ookup stages -> (T)CP (H)eader stages
 ************************************************************/
flow_lookup_entry               lookedup_entry_th;
logic   [`ACK_NUM_WIDTH-1:0]    ack_num_th;

always @(posedge clk) begin
    if (rst) begin
        lookedup_entry_val_th <= 'b0;
        lookedup_entry_host_flowid_th <= 'b0;
        lookedup_entry_th <= 'b0;
        tonic_seg_num_next_th <= 'b0;
    end
    else begin
        if (!stall_th) begin
            lookedup_entry_val_th <= tonic_flowid_lookup_val_l;
            lookedup_entry_host_flowid_th <= tonic_flowid_lookup_flowid_l;
            lookedup_entry_th <= lookedup_entry_l;
            tonic_seg_num_next_th <= tonic_seg_num_next_l;
        end
    end
end

/*************************************************************
 * (T)CP (H)eader stages
 ************************************************************/
logic                           tcp_header_req_rdy_th;
logic                           tcp_header_req_val_th;
logic   [`SEQ_NUM_WIDTH-1:0]    converted_seq_num_th;

logic                           outbound_tcp_header_val_th;
tcp_packet_header               outbound_tcp_header_th;

assign recv_state_for_ack_th = recv_state_for_ack_resp;
assign ack_num_th = recv_state_for_ack_th.ack_num;
assign stall_th = ~parser_tcp_tx_rdy | ~tcp_header_req_rdy_th | syn_ack_val;
assign read_seq_num_resp_rdy_th = ~stall_th;

assign tcp_header_req_val_th = lookedup_entry_val_th & tcp_header_req_rdy_th;
assign converted_seq_num_th = (tonic_seg_num_next_th << `SEQ_NUM_SHIFT) + 1 + read_seq_num_resp_th;
tcp_header_assembler tcp_header_assembler(
     .clk(clk)
    ,.rst(rst)

    ,.tcp_header_req_val        (lookedup_entry_val_th              )
    ,.host_port                 (lookedup_entry_th.host_port        )
    ,.dest_port                 (lookedup_entry_th.dest_port        )
    ,.seq_num                   (converted_seq_num_th               )
    ,.ack_num                   (ack_num_th                         )
    ,.flags                     (`TCP_ACK | `TCP_PSH                )
    ,.tcp_header_req_rdy        (tcp_header_req_rdy_th              )

    ,.outbound_tcp_header_val   (outbound_tcp_header_val_th         )
    ,.outbound_tcp_header_rdy   (parser_tcp_tx_rdy                  )
    ,.outbound_tcp_header       (outbound_tcp_header_th             )
);


    // ability to inject packets comes here


assign tcp_parser_tx_val = syn_ack_val ? 1'b1 : outbound_tcp_header_val_th & read_seq_num_resp_val_th;
assign tcp_parser_tx_src_ip = syn_ack_val ? syn_ack_src_ip : lookedup_entry_th.host_ip;
assign tcp_parser_tx_dst_ip = syn_ack_val ? syn_ack_dst_ip : lookedup_entry_th.dest_ip;
assign tcp_parser_tx_tcp_hdr = syn_ack_val ? syn_ack_hdr : outbound_tcp_header_th;
assign tcp_parser_tx_payload_addr = syn_ack_val ? '0 : payload_buf_entry_th.packet_payload_addr;
assign tcp_parser_tx_payload_len = syn_ack_val ? '0 : payload_buf_entry_th.packet_payload_len;


/**************************************************************************
 * Receiving pipeline (ACKs still go into Tonic)
 *************************************************************************/
assign write_recv_state_val = next_recv_state_val;
assign write_recv_state_addr = next_recv_state_addr;
assign write_recv_state = next_recv_state;


recv_pipe_wrap rx_wrap (
     .clk                                   (clk)
    ,.rst                                   (rst)

    ,.recv_src_ip                           (parser_tcp_rx_src_ip               )
    ,.recv_dst_ip                           (parser_tcp_rx_dst_ip               )
    ,.recv_header_val                       (parser_tcp_rx_hdr_val              )
    ,.recv_header_rdy                       (tcp_parser_rx_rdy                  )
    ,.recv_header                           (parser_tcp_rx_tcp_hdr              )
    ,.recv_payload_val                      (parser_tcp_rx_payload_val          )
    ,.recv_payload_addr                     (parser_tcp_rx_payload_addr         )
    ,.recv_payload_len                      (parser_tcp_rx_payload_len          )
    
    ,.new_idtoaddr_lookup_val               (new_idtoaddr_lookup_val            )
    ,.new_idtoaddr_lookup_flow_id           (new_idtoaddr_lookup_flow_id        )
    ,.new_idtoaddr_lookup_entry             (new_idtoaddr_lookup_entry          )
    ,.new_init_seq_num                      (new_init_seq_num                   )

    ,.curr_recv_state_req_val               (curr_recv_state_req_val            )
    ,.curr_recv_state_req_addr              (curr_recv_state_req_addr           )
    ,.curr_recv_state_req_rdy               (curr_recv_state_req_rdy            )

    ,.curr_recv_state_resp_val              (curr_recv_state_resp_val           )
    ,.curr_recv_state_resp                  (curr_recv_state_resp               )
    ,.curr_recv_state_resp_rdy              (curr_recv_state_resp_rdy           )

    ,.recv_pipe_init_seq_num_rd_req_val     (recv_pipe_init_seq_num_rd_req_val  )
    ,.recv_pipe_init_seq_num_rd_req_addr    (recv_pipe_init_seq_num_rd_req_addr )
    ,.init_seq_num_recv_pipe_rd_req_rdy     (init_seq_num_recv_pipe_rd_req_rdy  )
                                                                                
    ,.init_seq_num_recv_pipe_rd_resp_val    (init_seq_num_recv_pipe_rd_resp_val )
    ,.init_seq_num_recv_pipe_rd_resp_data   (init_seq_num_recv_pipe_rd_resp_data)
    ,.recv_pipe_init_seq_num_rd_resp_rdy    (recv_pipe_init_seq_num_rd_resp_rdy )
    
    ,.next_recv_state_val                   (next_recv_state_val                )
    ,.next_recv_state_addr                  (next_recv_state_addr               )
    ,.next_recv_state                       (next_recv_state                    )

    ,.engine_recv_header_val                (engine_recv_header_val             )
    ,.engine_recv_tcp_hdr                   (engine_recv_tcp_hdr                )
    ,.engine_recv_flowid                    (engine_recv_flowid                 )

    ,.engine_recv_packet_enqueue_val        (engine_recv_packet_enqueue_val     )
    ,.engine_recv_packet_enqueue_entry      (engine_recv_packet_enqueue_entry   )

    ,.recv_set_ack_pending                  (recv_set_ack_pending               )
    ,.recv_set_ack_pending_addr             (recv_set_ack_pending_addr          )
    
    ,.syn_ack_val                           (syn_ack_val                        )
    ,.syn_ack_src_ip                        (syn_ack_src_ip                     )
    ,.syn_ack_dst_ip                        (syn_ack_dst_ip                     )
    ,.syn_ack_hdr                           (syn_ack_hdr                        )
    ,.syn_ack_rdy                           (parser_tcp_tx_rdy                  )

    ,.app_new_flow_notif_val                (app_new_flow_notif_val             )
    ,.app_new_flow_flow_id                  (app_new_flow_flow_id               )
);

/*
ack_pending ack_pending_state (
     .clk(clk)
    ,.rst(rst)

    ,.recv_set_ack_pending_addr     (recv_set_ack_pending_addr      )
    ,.recv_set_ack_pending          (recv_set_ack_pending           )

    ,.send_clear_ack_pending_addr   (send_clear_ack_pending_addr    )
    ,.send_clear_ack_pending        (send_clear_ack_pending         )
    
    ,.read_ack_pending_val          (tonic_flowid_lookup_val        )
    ,.read_ack_pending_addr         (tonic_flowid_lookup_flowid     )
    ,.read_ack_pending              (lookedup_ack_pending           )
);
*/

recv_cntxt_store recv_cntxt_store (
     .clk(clk)
    ,.rst(rst)

    ,.write_recv_state_val          (write_recv_state_val       )
    ,.write_recv_state_addr         (write_recv_state_addr      )
    ,.write_recv_state              (write_recv_state           )

    ,.curr_recv_state_req_val       (curr_recv_state_req_val    )
    ,.curr_recv_state_req_addr      (curr_recv_state_req_addr   )
    ,.curr_recv_state_req_rdy       (curr_recv_state_req_rdy    )
    
    ,.curr_recv_state_resp_val      (curr_recv_state_resp_val   )
    ,.curr_recv_state_resp          (curr_recv_state_resp       )
    ,.curr_recv_state_resp_rdy      (curr_recv_state_resp_rdy   )

    ,.recv_state_for_ack_req_val    (recv_state_for_ack_req_val )
    ,.recv_state_for_ack_req_addr   (recv_state_for_ack_req_addr)
    ,.recv_state_for_ack_resp       (recv_state_for_ack_resp    )

);


logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0]   engine_recv_packet_enqueue_addr;
logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]    engine_recv_packet_enqueue_len;

assign engine_recv_packet_enqueue_addr = engine_recv_packet_enqueue_entry.packet_payload_addr;
assign engine_recv_packet_enqueue_len = engine_recv_packet_enqueue_entry.packet_payload_len;

recv_packet_payload_queues recv_queues (
     .clk(clk)
    ,.rst(rst)

    ,.new_enqueue_val               (reset_tonic_recv_enqueue_val       )
    ,.new_enqueue_addr              (reset_tonic_recv_enqueue_addr      )
    ,.new_enqueue_data              (reset_tonic_recv_enqueue_data      )
    
    ,.new_dequeue_val               (reset_tonic_recv_dequeue_val       )
    ,.new_dequeue_addr              (reset_tonic_recv_dequeue_addr      )
    ,.new_dequeue_data              (reset_tonic_recv_dequeue_data      )

    ,.enqueue_packet_val            (engine_recv_packet_enqueue_val     )
    ,.enqueue_packet_flowid         (engine_recv_flowid                 )
    ,.enqueue_packet_payload_addr   (engine_recv_packet_enqueue_addr    )
    ,.enqueue_packet_payload_len    (engine_recv_packet_enqueue_len     )

    ,.read_payload_req_val          (read_recv_payload_req_val          )
    ,.read_payload_req_flowid       (read_recv_payload_req_flowid       )

    ,.read_payload_resp_val         (read_recv_payload_resp_val         )
    ,.read_payload_resp_empty       (read_recv_payload_resp_empty       )
    ,.read_payload_resp_addr        (read_recv_payload_resp_addr        )
    ,.read_payload_resp_len         (read_recv_payload_resp_len         )
);
endmodule
