module handshake_trace_test_top (
     input clk
    ,input rst
    
    ,input                                      parser_tcp_rx_hdr_val
    ,output                                     tcp_parser_rx_rdy
    ,input  [`IP_ADDR_WIDTH-1:0]                parser_tcp_rx_src_ip
    ,input  [`IP_ADDR_WIDTH-1:0]                parser_tcp_rx_dst_ip
    ,input  [`TCP_HEADER_WIDTH-1:0]             parser_tcp_rx_tcp_hdr

    ,input                                      parser_tcp_rx_payload_val
    ,input  [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] parser_tcp_rx_payload_addr
    ,input  [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  parser_tcp_rx_payload_len
    
    // For sending out a complete packet
    ,output                                     tcp_parser_tx_val
    ,input                                      parser_tcp_tx_rdy
    ,output [`IP_ADDR_WIDTH-1:0]                tcp_parser_tx_src_ip
    ,output [`IP_ADDR_WIDTH-1:0]                tcp_parser_tx_dst_ip
    ,output [`TCP_HEADER_WIDTH-1:0]             tcp_parser_tx_tcp_hdr
    ,output [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] tcp_parser_tx_payload_addr
    ,output [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  tcp_parser_tx_payload_len
);

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

    logic                                       recv_pipe_init_seq_num_rd_req_val;
    logic   [`FLOW_ID_W-1:0]                    recv_pipe_init_seq_num_rd_req_addr;
    logic                                       init_seq_num_recv_pipe_rd_req_rdy;
    
    logic                                       init_seq_num_recv_pipe_rd_resp_val;
    logic   [`SEQ_NUM_WIDTH-1:0]                init_seq_num_recv_pipe_rd_resp_data;
    logic                                       recv_pipe_init_seq_num_rd_resp_rdy;

    logic                                       syn_ack_val;
    logic   [`IP_ADDR_WIDTH-1:0]                syn_ack_src_ip;
    logic   [`IP_ADDR_WIDTH-1:0]                syn_ack_dst_ip;
    tcp_packet_header                           syn_ack_hdr;
    
    logic                                       engine_recv_header_val;
    logic   [`TCP_HEADER_WIDTH-1:0]             engine_recv_tcp_hdr;
    logic   [`FLOW_ID_W-1:0]                    engine_recv_flowid;
    
    logic                                       tx_tcp_hdr_val;
    logic   [`IP_ADDR_WIDTH-1:0]                tx_src_ip;
    logic   [`IP_ADDR_WIDTH-1:0]                tx_dst_ip;
    logic   [`TCP_HEADER_WIDTH-1:0]             tx_tcp_hdr;
    logic                                       tx_tcp_hdr_rdy;

    init_seq_num_mem #(
        .width_p   (`SEQ_NUM_WIDTH)
        ,.els_p     (`MAX_FLOW_CNT)
    ) tx_init_seq_num_mem (
         .clk   (clk)
        ,.rst   (rst)
    
        ,.init_seq_num_wr_req_val   (new_idtoaddr_lookup_val        )
        ,.init_seq_num_wr_req_addr  (new_idtoaddr_lookup_flow_id    )
        ,.init_seq_num_wr_num       (new_init_seq_num               )
        ,.init_seq_num_wr_req_rdy   ()
    
        ,.init_seq_num_rd0_req_val  (1'b0)
        ,.init_seq_num_rd0_req_addr ()
        ,.init_seq_num_rd0_req_rdy  ()
    
        ,.init_seq_num_rd0_resp_val ()
        ,.init_seq_num_rd0_resp     ()
        ,.init_seq_num_rd0_resp_rdy (1'b1)
        
        ,.init_seq_num_rd1_req_val  (recv_pipe_init_seq_num_rd_req_val  )
        ,.init_seq_num_rd1_req_addr (recv_pipe_init_seq_num_rd_req_addr )
        ,.init_seq_num_rd1_req_rdy  (init_seq_num_recv_pipe_rd_req_rdy  )
    
        ,.init_seq_num_rd1_resp_val (init_seq_num_recv_pipe_rd_resp_val )
        ,.init_seq_num_rd1_resp     (init_seq_num_recv_pipe_rd_resp_data)
        ,.init_seq_num_rd1_resp_rdy (recv_pipe_init_seq_num_rd_resp_rdy )
    );

    assign tcp_parser_tx_val = syn_ack_val ? 1'b1 : tx_tcp_hdr_val;
    assign tcp_parser_tx_src_ip = syn_ack_val ? syn_ack_src_ip : tx_src_ip;
    assign tcp_parser_tx_dst_ip = syn_ack_val ? syn_ack_dst_ip : tx_dst_ip;
    assign tcp_parser_tx_tcp_hdr = syn_ack_val ? syn_ack_hdr : tx_tcp_hdr;
    assign tcp_parser_tx_payload_addr = '0;
    assign tcp_parser_tx_payload_len = '0;

    assign tx_tcp_hdr_rdy = ~syn_ack_val;

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
    
        ,.engine_recv_packet_enqueue_val        ()
        ,.engine_recv_packet_enqueue_entry      ()
    
        ,.recv_set_ack_pending                  ()
        ,.recv_set_ack_pending_addr             ()
        
        ,.syn_ack_val                           (syn_ack_val                        )
        ,.syn_ack_src_ip                        (syn_ack_src_ip                     )
        ,.syn_ack_dst_ip                        (syn_ack_dst_ip                     )
        ,.syn_ack_hdr                           (syn_ack_hdr                        )
        ,.syn_ack_rdy                           (parser_tcp_tx_rdy                  )
    
        ,.app_new_flow_notif_val                ()
        ,.app_new_flow_flow_id                  ()
    );

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
    
        ,.recv_state_for_ack_req_val    (1'b0)
        ,.recv_state_for_ack_req_addr   ()
        ,.recv_state_for_ack_resp       ()
    
    );

    handshake_trace_echo_app echo_app(
         .clk   (clk)
        ,.rst   (rst)

        ,.engine_recv_header_val        (engine_recv_header_val         )
        ,.engine_recv_tcp_hdr           (engine_recv_tcp_hdr            )
        ,.engine_recv_flowid            (engine_recv_flowid             )

        ,.new_idtoaddr_lookup_val       (new_idtoaddr_lookup_val        )
        ,.new_idtoaddr_lookup_flow_id   (new_idtoaddr_lookup_flow_id    )
        ,.new_idtoaddr_lookup_entry     (new_idtoaddr_lookup_entry      )
        
        ,.tx_tcp_hdr_val                (tx_tcp_hdr_val                 )
        ,.tx_src_ip                     (tx_src_ip                      )
        ,.tx_dst_ip                     (tx_dst_ip                      )
        ,.tx_tcp_hdr                    (tx_tcp_hdr                     )
        ,.tx_tcp_hdr_rdy                (tx_tcp_hdr_rdy                 )
    );

endmodule
