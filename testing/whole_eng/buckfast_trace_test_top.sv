`include "packet_defs.vh"
`include "state_defs.vh"
`include "noc_defs.vh"
module buckfast_trace_test_top(
     input clk
    ,input rst
    
    ,input                                      parser_tcp_rx_hdr_val
    ,output                                     tcp_parser_rx_rdy
    ,input  [`IP_ADDR_W-1:0]                    parser_tcp_rx_src_ip
    ,input  [`IP_ADDR_W-1:0]                    parser_tcp_rx_dst_ip
    ,input  [`TCP_HDR_W-1:0]                    parser_tcp_rx_tcp_hdr

    ,input                                      parser_tcp_rx_payload_val
    ,input  [`PAYLOAD_ENTRY_ADDR_W-1:0]         parser_tcp_rx_payload_addr
    ,input  [`PAYLOAD_ENTRY_LEN_W-1:0]          parser_tcp_rx_payload_len
    
    // For sending out a complete packet
    ,output                                     tcp_parser_tx_val
    ,input                                      parser_tcp_tx_rdy
    ,output [`IP_ADDR_W-1:0]                    tcp_parser_tx_src_ip
    ,output [`IP_ADDR_W-1:0]                    tcp_parser_tx_dst_ip
    ,output [`TCP_HDR_W-1:0]                    tcp_parser_tx_tcp_hdr
    ,output [`PAYLOAD_ENTRY_W-1:0]              tcp_parser_tx_payload
);
    logic                               app_new_flow_notif_val;
    logic   [`FLOW_ID_W-1:0]            app_new_flow_flowid;

    logic                               app_tail_ptr_tx_wr_req_val;
    logic   [`FLOW_ID_W-1:0]            app_tail_ptr_tx_wr_req_flowid;
    logic   [`PAYLOAD_PTR_W:0]          app_tail_ptr_tx_wr_req_data;
    logic                               tail_ptr_app_tx_wr_req_rdy;

    logic                               app_tail_ptr_tx_rd_req1_val;
    logic   [`FLOW_ID_W-1:0]            app_tail_ptr_tx_rd_req1_flowid;
    logic                               tail_ptr_app_tx_rd_req1_rdy;

    logic                               tail_ptr_app_tx_rd_resp1_val;
    logic   [`FLOW_ID_W-1:0]            tail_ptr_app_tx_rd_resp1_flowid;
    logic   [`PAYLOAD_PTR_W:0]          tail_ptr_app_tx_rd_resp1_data;
    logic                               app_tail_ptr_tx_rd_resp1_rdy;

    logic                               app_head_ptr_tx_rd_req0_val;
    logic   [`FLOW_ID_W-1:0]            app_head_ptr_tx_rd_req0_flowid;
    logic                               head_ptr_app_tx_rd_req0_rdy;

    logic                               head_ptr_app_tx_rd_resp0_val;
    logic   [`FLOW_ID_W-1:0]            head_ptr_app_tx_rd_resp0_flowid;
    logic   [`PAYLOAD_PTR_W:0]          head_ptr_app_tx_rd_resp0_data;
    logic                               app_head_ptr_tx_rd_resp0_rdy;

    logic                               app_rx_head_ptr_wr_req_val;
    logic   [`FLOW_ID_W-1:0]            app_rx_head_ptr_wr_req_addr;
    logic   [`RX_PAYLOAD_PTR_W:0]       app_rx_head_ptr_wr_req_data;
    logic                               rx_head_ptr_app_wr_req_rdy;

    logic                               app_rx_head_ptr_rd_req_val;
    logic   [`FLOW_ID_W-1:0]            app_rx_head_ptr_rd_req_addr;
    logic                               rx_head_ptr_app_rd_req_rdy;

    logic                               rx_head_ptr_app_rd_resp_val;
    logic   [`RX_PAYLOAD_PTR_W:0]       rx_head_ptr_app_rd_resp_data;
    logic                               app_rx_head_ptr_rd_resp_rdy;

    logic                               app_rx_commit_ptr_rd_req_val;
    logic   [`FLOW_ID_W-1:0]            app_rx_commit_ptr_rd_req_addr;
    logic                               rx_commit_ptr_app_rd_req_rdy;

    logic                               rx_commit_ptr_app_rd_resp_val;
    logic   [`RX_PAYLOAD_PTR_W:0]       rx_commit_ptr_app_rd_resp_data;
    logic                               app_rx_commit_ptr_rd_resp_rdy;
    
    logic                               store_buf_tmp_buf_store_rx_rd_req_val;
    logic   [`PAYLOAD_ENTRY_ADDR_W-1:0] store_buf_tmp_buf_store_rx_rd_req_addr;
    logic                               tmp_buf_store_store_buf_rx_rd_req_rdy;

    logic                               tmp_buf_store_store_buf_rx_rd_resp_val;
    logic   [`MAC_INTERFACE_W-1:0]      tmp_buf_store_store_buf_rx_rd_resp_data;
    logic                               store_buf_tmp_buf_store_rx_rd_resp_rdy;
    
    logic                               rx_pipe_noc0_val;
    logic   [`NOC_DATA_WIDTH-1:0]       rx_pipe_noc0_data;
    logic                               noc0_rx_pipe_rdy;

    logic                               noc0_rx_pipe_val;
    logic   [`NOC_DATA_WIDTH-1:0]       noc0_rx_pipe_data;
    logic                               rx_pipe_noc0_rdy;

    tcp_engine_wrapper #(
         .SRC_X     (0)
        ,.SRC_Y     (0)
        ,.RX_DRAM_X (1)
        ,.RX_DRAM_Y (1)
    ) test_engine (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_recv_hdr_val                          (parser_tcp_rx_hdr_val                      )
        ,.src_recv_src_ip                           (parser_tcp_rx_src_ip                       )
        ,.src_recv_dst_ip                           (parser_tcp_rx_dst_ip                       )
        ,.src_recv_hdr                              (parser_tcp_rx_tcp_hdr                      )
        ,.src_recv_payload_val                      (parser_tcp_rx_payload_val                  )
        ,.src_recv_payload_addr                     (parser_tcp_rx_payload_addr                 )
        ,.src_recv_payload_len                      (parser_tcp_rx_payload_len                  )
        ,.recv_src_hdr_rdy                          (tcp_parser_rx_rdy                          )

        ,.send_dst_tx_val                           (tcp_parser_tx_val                          )
        ,.send_dst_tx_flowid                        (                                           )
        ,.send_dst_tx_src_ip                        (tcp_parser_tx_src_ip                       )
        ,.send_dst_tx_dst_ip                        (tcp_parser_tx_dst_ip                       )
        ,.send_dst_tx_tcp_hdr                       (tcp_parser_tx_tcp_hdr                      )
        ,.send_dst_tx_payload                       (tcp_parser_tx_payload                      )
        ,.dst_send_tx_rdy                           (parser_tcp_tx_rdy                          )

        ,.app_new_flow_notif_val                    (app_new_flow_notif_val                     )
        ,.app_new_flow_flowid                       (app_new_flow_flowid                        )

        ,.rx_pipe_noc0_val                          (rx_pipe_noc0_val                           )
        ,.rx_pipe_noc0_data                         (rx_pipe_noc0_data                          )
        ,.noc0_rx_pipe_rdy                          (noc0_rx_pipe_rdy                           )
                                                                      
        ,.noc0_rx_pipe_val                          (noc0_rx_pipe_val                           )
        ,.noc0_rx_pipe_data                         (noc0_rx_pipe_data                          )
        ,.rx_pipe_noc0_rdy                          (rx_pipe_noc0_rdy                           )

        ,.app_tail_ptr_tx_wr_req_val                (app_tail_ptr_tx_wr_req_val                 )
        ,.app_tail_ptr_tx_wr_req_flowid             (app_tail_ptr_tx_wr_req_flowid              )
        ,.app_tail_ptr_tx_wr_req_data               (app_tail_ptr_tx_wr_req_data                )
        ,.tail_ptr_app_tx_wr_req_rdy                (tail_ptr_app_tx_wr_req_rdy                 )
                                                                                    
        ,.app_tail_ptr_tx_rd_req1_val               (app_tail_ptr_tx_rd_req1_val                )
        ,.app_tail_ptr_tx_rd_req1_flowid            (app_tail_ptr_tx_rd_req1_flowid             )
        ,.tail_ptr_app_tx_rd_req1_rdy               (tail_ptr_app_tx_rd_req1_rdy                )
                                                                                    
        ,.tail_ptr_app_tx_rd_resp1_val              (tail_ptr_app_tx_rd_resp1_val               )
        ,.tail_ptr_app_tx_rd_resp1_flowid           (tail_ptr_app_tx_rd_resp1_flowid            )
        ,.tail_ptr_app_tx_rd_resp1_data             (tail_ptr_app_tx_rd_resp1_data              )
        ,.app_tail_ptr_tx_rd_resp1_rdy              (app_tail_ptr_tx_rd_resp1_rdy               )
                                                                                    
        ,.app_head_ptr_tx_rd_req0_val               (app_head_ptr_tx_rd_req0_val                )
        ,.app_head_ptr_tx_rd_req0_flowid            (app_head_ptr_tx_rd_req0_flowid             )
        ,.head_ptr_app_tx_rd_req0_rdy               (head_ptr_app_tx_rd_req0_rdy                )
                                                                                    
        ,.head_ptr_app_tx_rd_resp0_val              (head_ptr_app_tx_rd_resp0_val               )
        ,.head_ptr_app_tx_rd_resp0_flowid           (head_ptr_app_tx_rd_resp0_flowid            )
        ,.head_ptr_app_tx_rd_resp0_data             (head_ptr_app_tx_rd_resp0_data              )
        ,.app_head_ptr_tx_rd_resp0_rdy              (app_head_ptr_tx_rd_resp0_rdy               )

        ,.store_buf_tmp_buf_store_rx_rd_req_val     (store_buf_tmp_buf_store_rx_rd_req_val      )
        ,.store_buf_tmp_buf_store_rx_rd_req_addr    (store_buf_tmp_buf_store_rx_rd_req_addr     )
        ,.tmp_buf_store_store_buf_rx_rd_req_rdy     (tmp_buf_store_store_buf_rx_rd_req_rdy      )
                                                                                                 
        ,.tmp_buf_store_store_buf_rx_rd_resp_val    (tmp_buf_store_store_buf_rx_rd_resp_val     )
        ,.tmp_buf_store_store_buf_rx_rd_resp_data   (tmp_buf_store_store_buf_rx_rd_resp_data    )
        ,.store_buf_tmp_buf_store_rx_rd_resp_rdy    (store_buf_tmp_buf_store_rx_rd_resp_rdy     )

        ,.store_buf_tmp_buf_free_slab_rx_req_val    (                                           )
        ,.store_buf_tmp_buf_free_slab_rx_req_addr   (                                           )
        ,.tmp_buf_free_slab_store_buf_rx_req_rdy    (1'b1                                       )

        ,.app_rx_head_ptr_wr_req_val                (app_rx_head_ptr_wr_req_val                 )
        ,.app_rx_head_ptr_wr_req_addr               (app_rx_head_ptr_wr_req_addr                )
        ,.app_rx_head_ptr_wr_req_data               (app_rx_head_ptr_wr_req_data                )
        ,.rx_head_ptr_app_wr_req_rdy                (rx_head_ptr_app_wr_req_rdy                 )
                                                                                   
        ,.app_rx_head_ptr_rd_req_val                (app_rx_head_ptr_rd_req_val                 )
        ,.app_rx_head_ptr_rd_req_addr               (app_rx_head_ptr_rd_req_addr                )
        ,.rx_head_ptr_app_rd_req_rdy                (rx_head_ptr_app_rd_req_rdy                 )
                                                                                   
        ,.rx_head_ptr_app_rd_resp_val               (rx_head_ptr_app_rd_resp_val                )
        ,.rx_head_ptr_app_rd_resp_data              (rx_head_ptr_app_rd_resp_data               )
        ,.app_rx_head_ptr_rd_resp_rdy               (app_rx_head_ptr_rd_resp_rdy                )
                                                                                   
        ,.app_rx_commit_ptr_rd_req_val              (app_rx_commit_ptr_rd_req_val               )
        ,.app_rx_commit_ptr_rd_req_addr             (app_rx_commit_ptr_rd_req_addr              )
        ,.rx_commit_ptr_app_rd_req_rdy              (rx_commit_ptr_app_rd_req_rdy               )
                                                                                   
        ,.rx_commit_ptr_app_rd_resp_val             (rx_commit_ptr_app_rd_resp_val              )
        ,.rx_commit_ptr_app_rd_resp_data            (rx_commit_ptr_app_rd_resp_data             )
        ,.app_rx_commit_ptr_rd_resp_rdy             (app_rx_commit_ptr_rd_resp_rdy              )
    );

    fake_noc_sink noc_sink (
         .clk   (clk)
        ,.rst   (rst)

        ,.rx_pipe_noc0_val  (rx_pipe_noc0_val   )
        ,.rx_pipe_noc0_data (rx_pipe_noc0_data  )
        ,.noc0_rx_pipe_rdy  (noc0_rx_pipe_rdy   )
                                                
        ,.noc0_rx_pipe_val  (noc0_rx_pipe_val   )
        ,.noc0_rx_pipe_data (noc0_rx_pipe_data  )
        ,.rx_pipe_noc0_rdy  (rx_pipe_noc0_rdy   )
    );

    fake_tmp_buf fake_tmp_buf (
         .clk   (clk)
        ,.rst   (rst)

        ,.store_buf_tmp_buf_store_rx_rd_req_val     (store_buf_tmp_buf_store_rx_rd_req_val  )
        ,.store_buf_tmp_buf_store_rx_rd_req_addr    (store_buf_tmp_buf_store_rx_rd_req_addr )
        ,.tmp_buf_store_store_buf_rx_rd_req_rdy     (tmp_buf_store_store_buf_rx_rd_req_rdy  )
                                                                                             
        ,.tmp_buf_store_store_buf_rx_rd_resp_val    (tmp_buf_store_store_buf_rx_rd_resp_val )
        ,.tmp_buf_store_store_buf_rx_rd_resp_data   (tmp_buf_store_store_buf_rx_rd_resp_data)
        ,.store_buf_tmp_buf_store_rx_rd_resp_rdy    (store_buf_tmp_buf_store_rx_rd_resp_rdy )
    );

    test_echo_app test_app (
         .clk   (clk)
        ,.rst   (rst)

        ,.app_new_flow_notif_val            (app_new_flow_notif_val             )
        ,.app_new_flow_flowid               (app_new_flow_flowid                )
                                                                                
        ,.app_tail_ptr_tx_wr_req_val        (app_tail_ptr_tx_wr_req_val         )
        ,.app_tail_ptr_tx_wr_req_flowid     (app_tail_ptr_tx_wr_req_flowid      )
        ,.app_tail_ptr_tx_wr_req_data       (app_tail_ptr_tx_wr_req_data        )
        ,.tail_ptr_app_tx_wr_req_rdy        (tail_ptr_app_tx_wr_req_rdy         )
                                                                                
        ,.app_tail_ptr_tx_rd_req1_val       (app_tail_ptr_tx_rd_req1_val        )
        ,.app_tail_ptr_tx_rd_req1_flowid    (app_tail_ptr_tx_rd_req1_flowid     )
        ,.tail_ptr_app_tx_rd_req1_rdy       (tail_ptr_app_tx_rd_req1_rdy        )
                                                                                
        ,.tail_ptr_app_tx_rd_resp1_val      (tail_ptr_app_tx_rd_resp1_val       )
        ,.tail_ptr_app_tx_rd_resp1_flowid   (tail_ptr_app_tx_rd_resp1_flowid    )
        ,.tail_ptr_app_tx_rd_resp1_data     (tail_ptr_app_tx_rd_resp1_data      )
        ,.app_tail_ptr_tx_rd_resp1_rdy      (app_tail_ptr_tx_rd_resp1_rdy       )
                                                                                
        ,.app_head_ptr_tx_rd_req0_val       (app_head_ptr_tx_rd_req0_val        )
        ,.app_head_ptr_tx_rd_req0_flowid    (app_head_ptr_tx_rd_req0_flowid     )
        ,.head_ptr_app_tx_rd_req0_rdy       (head_ptr_app_tx_rd_req0_rdy        )
                                                                                
        ,.head_ptr_app_tx_rd_resp0_val      (head_ptr_app_tx_rd_resp0_val       )
        ,.head_ptr_app_tx_rd_resp0_flowid   (head_ptr_app_tx_rd_resp0_flowid    )
        ,.head_ptr_app_tx_rd_resp0_data     (head_ptr_app_tx_rd_resp0_data      )
        ,.app_head_ptr_tx_rd_resp0_rdy      (app_head_ptr_tx_rd_resp0_rdy       )
                                                                                
        ,.app_rx_head_ptr_wr_req_val        (app_rx_head_ptr_wr_req_val         )
        ,.app_rx_head_ptr_wr_req_addr       (app_rx_head_ptr_wr_req_addr        )
        ,.app_rx_head_ptr_wr_req_data       (app_rx_head_ptr_wr_req_data        )
        ,.rx_head_ptr_app_wr_req_rdy        (rx_head_ptr_app_wr_req_rdy         )
                                                                                
        ,.app_rx_head_ptr_rd_req_val        (app_rx_head_ptr_rd_req_val         )
        ,.app_rx_head_ptr_rd_req_addr       (app_rx_head_ptr_rd_req_addr        )
        ,.rx_head_ptr_app_rd_req_rdy        (rx_head_ptr_app_rd_req_rdy         )
                                                                                
        ,.rx_head_ptr_app_rd_resp_val       (rx_head_ptr_app_rd_resp_val        )
        ,.rx_head_ptr_app_rd_resp_data      (rx_head_ptr_app_rd_resp_data       )
        ,.app_rx_head_ptr_rd_resp_rdy       (app_rx_head_ptr_rd_resp_rdy        )
                                                                                
        ,.app_rx_commit_ptr_rd_req_val      (app_rx_commit_ptr_rd_req_val       )
        ,.app_rx_commit_ptr_rd_req_addr     (app_rx_commit_ptr_rd_req_addr      )
        ,.rx_commit_ptr_app_rd_req_rdy      (rx_commit_ptr_app_rd_req_rdy       )
                                                                                
        ,.rx_commit_ptr_app_rd_resp_val     (rx_commit_ptr_app_rd_resp_val      )
        ,.rx_commit_ptr_app_rd_resp_data    (rx_commit_ptr_app_rd_resp_data     )
        ,.app_rx_commit_ptr_rd_resp_rdy     (app_rx_commit_ptr_rd_resp_rdy      )
    );



endmodule
