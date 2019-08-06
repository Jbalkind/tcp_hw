`include "packet_defs.vh"
module send_pipe_wrapper 
import packet_struct_pkg::*;
import tcp_pkg::*;
(
     input clk
    ,input rst
    
    ,input  logic                           src_new_flow_val
    ,input  logic   [FLOWID_W-1:0]          src_new_flow_flowid
    ,input  four_tuple_struct               src_new_flow_lookup_entry
    ,output logic                           new_flow_src_rdy
    
    ,output logic                           send_q_tail_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]          send_q_tail_ptr_rd_req_flowid
    ,input  logic                           send_q_tail_ptr_rd_req_rdy

    ,input  logic                           send_q_tail_ptr_rd_resp_val
    ,input          [TX_PAYLOAD_PTR_W:0]    send_q_tail_ptr_rd_resp_data
    ,output logic                           send_q_tail_ptr_rd_resp_rdy
    
    ,output logic                           send_pipe_tx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          send_pipe_tx_state_rd_req_flowid
    ,input  logic                           tx_state_send_pipe_rd_req_rdy

    ,input  logic                           tx_state_send_pipe_rd_resp_val
    ,input  tx_state_struct                 tx_state_send_pipe_rd_resp_data
    ,output logic                           send_pipe_tx_state_rd_resp_rdy

    ,output logic                           send_pipe_tx_state_wr_req_val
    ,output logic   [FLOWID_W-1:0]          send_pipe_tx_state_wr_req_flowid
    ,output tx_state_struct                 send_pipe_tx_state_wr_req_data
    ,input  logic                           tx_state_send_pipe_wr_req_rdy
    
    ,output logic                           send_pipe_recv_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          send_pipe_recv_state_rd_req_flowid
    ,input  logic                           recv_state_send_pipe_rd_req_rdy

    ,input  logic                           recv_state_send_pipe_rd_resp_val
    ,input  recv_state_entry                recv_state_send_pipe_rd_resp_data
    ,output logic                           send_pipe_recv_state_rd_resp_rdy

    ,input  logic                           rx_pipe_rt_store_set_rt_flag_val
    ,input  logic   [FLOWID_W-1:0]          rx_pipe_rt_store_set_rt_flag_flowid
    
    ,output                                 send_dst_tx_val
    ,output logic   [FLOWID_W-1:0]          send_dst_tx_flowid
    ,output logic   [`IP_ADDR_W-1:0]        send_dst_tx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        send_dst_tx_dst_ip
    ,output tcp_pkt_hdr                     send_dst_tx_tcp_hdr
    ,output payload_buf_struct              send_dst_tx_payload
    ,input                                  dst_send_tx_rdy
    
);

    logic                               main_pipe_sched_fifo_tx_rd_req;
    logic   [FLOWID_W-1:0]              sched_fifo_main_pipe_tx_rd_flowid;
    logic                               sched_fifo_main_pipe_tx_rd_empty;

    logic                               main_pipe_sched_fifo_tx_wr_req;
    logic   [FLOWID_W-1:0]              main_pipe_sched_fifo_tx_wr_flowid;
    logic                               sched_fifo_main_pipe_tx_wr_full;

    logic                               main_pipe_assembler_tx_val;
    logic   [FLOWID_W-1:0]              main_pipe_assembler_tx_flowid;
    logic   [`SEQ_NUM_W-1:0]            main_pipe_assembler_tx_seq_num;
    payload_buf_struct                  main_pipe_assembler_tx_payload;
    logic                               assembler_main_pipe_tx_rdy;
    
    logic                               main_pipe_rt_timeout_rd_req_val;
    logic   [FLOWID_W-1:0]              main_pipe_rt_timeout_rd_req_flowid;
    logic                               rt_timeout_main_pipe_rd_req_rdy;

    logic                               rt_timeout_main_pipe_rd_resp_val;
    logic   [RT_TIMEOUT_FLAGS_W-1:0]    rt_timeout_main_pipe_rd_resp_data;
    logic                               main_pipe_rt_timeout_rd_resp_rdy;

    logic                               main_pipe_rt_timeout_clr_bit_val;
    logic   [FLOWID_W-1:0]              main_pipe_rt_timeout_clr_bit_flowid;

    logic                               timeout_set_bit_val;
    logic   [FLOWID_W-1:0]              timeout_set_bit_flowid;

    logic                               rt_set_bit_val;
    logic   [FLOWID_W-1:0]              rt_set_bit_flowid;
    
    logic                               assembler_flowid_lookup_rd_req_val;
    logic   [FLOWID_W-1:0]              assembler_flowid_lookup_rd_req_flowid;
    logic                               flowid_lookup_assembler_rd_req_rdy;

    logic                               flowid_lookup_assembler_rd_resp_val;
    four_tuple_struct                   flowid_lookup_assembler_rd_resp_data;
    logic                               assembler_flowid_lookup_rd_resp_rdy;

    // Send pipe FIFOs
    scheduling_fifos scheduling_fifos (
         .clk   (clk)
        ,.rst   (rst)

        ,.app_send_tx_wr_req    (src_new_flow_val       )
        ,.app_send_tx_wr_flowid (src_new_flow_flowid    )
        ,.send_app_tx_wr_full   ()

        ,.main_pipe_wr_req      (main_pipe_sched_fifo_tx_wr_req     )
        ,.main_pipe_wr_flowid   (main_pipe_sched_fifo_tx_wr_flowid  )
        ,.main_pipe_wr_full     (sched_fifo_main_pipe_tx_wr_full    )

        ,.main_pipe_rd_req      (main_pipe_sched_fifo_tx_rd_req     )
        ,.main_pipe_flowid      (sched_fifo_main_pipe_tx_rd_flowid  )
        ,.main_pipe_rd_empty    (sched_fifo_main_pipe_tx_rd_empty   )
    );


    protocol_logic_pipe main_pipe (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.main_pipe_sched_fifo_tx_rd_req        (main_pipe_sched_fifo_tx_rd_req         )
        ,.sched_fifo_main_pipe_tx_rd_flowid     (sched_fifo_main_pipe_tx_rd_flowid      )
        ,.sched_fifo_main_pipe_tx_rd_empty      (sched_fifo_main_pipe_tx_rd_empty       )

        ,.rt_timeout_flag_req_val               (main_pipe_rt_timeout_rd_req_val        )
        ,.rt_timeout_flag_req_flowid            (main_pipe_rt_timeout_rd_req_flowid     )
        ,.rt_timeout_flag_req_rdy               (rt_timeout_main_pipe_rd_req_rdy        )

        ,.rt_timeout_flag_resp_val              (rt_timeout_main_pipe_rd_resp_val       )
        ,.rt_timeout_flag_resp_data             (rt_timeout_main_pipe_rd_resp_data      )
        ,.rt_timeout_flag_resp_rdy              (main_pipe_rt_timeout_rd_resp_rdy       )

        ,.send_q_tail_ptr_rd_req_val            (send_q_tail_ptr_rd_req_val             )
        ,.send_q_tail_ptr_rd_req_flowid         (send_q_tail_ptr_rd_req_flowid          )
        ,.send_q_tail_ptr_rd_req_rdy            (send_q_tail_ptr_rd_req_rdy             )
                                                                               
        ,.send_q_tail_ptr_rd_resp_val           (send_q_tail_ptr_rd_resp_val            )
        ,.send_q_tail_ptr_rd_resp_data          (send_q_tail_ptr_rd_resp_data           )
        ,.send_q_tail_ptr_rd_resp_rdy           (send_q_tail_ptr_rd_resp_rdy            )

        ,.tx_state_rd_req_val                   (send_pipe_tx_state_rd_req_val          )
        ,.tx_state_rd_req_flowid                (send_pipe_tx_state_rd_req_flowid       )
        ,.tx_state_rd_req_rdy                   (tx_state_send_pipe_rd_req_rdy          )

        ,.tx_state_rd_resp_val                  (tx_state_send_pipe_rd_resp_val         )
        ,.tx_state_rd_resp_data                 (tx_state_send_pipe_rd_resp_data        )
        ,.tx_state_rd_resp_rdy                  (send_pipe_tx_state_rd_resp_rdy         )

        ,.tx_state_wr_req_val                   (send_pipe_tx_state_wr_req_val          )
        ,.tx_state_wr_req_flowid                (send_pipe_tx_state_wr_req_flowid       )
        ,.tx_state_wr_req_data                  (send_pipe_tx_state_wr_req_data         )
        ,.tx_state_wr_req_rdy                   (tx_state_send_pipe_wr_req_rdy          )
    
        ,.main_pipe_sched_fifo_tx_wr_req        (main_pipe_sched_fifo_tx_wr_req         )
        ,.main_pipe_sched_fifo_tx_wr_flowid     (main_pipe_sched_fifo_tx_wr_flowid      )
        ,.sched_fifo_main_pipe_tx_wr_full       (sched_fifo_main_pipe_tx_wr_full        )

        ,.main_pipe_rt_timeout_clr_bit_val      (main_pipe_rt_timeout_clr_bit_val       )
        ,.main_pipe_rt_timeout_clr_bit_flowid   (main_pipe_rt_timeout_clr_bit_flowid    )
        
        ,.main_pipe_assembler_tx_val            (main_pipe_assembler_tx_val             )
        ,.main_pipe_assembler_tx_flowid         (main_pipe_assembler_tx_flowid          )
        ,.main_pipe_assembler_tx_seq_num        (main_pipe_assembler_tx_seq_num         )
        ,.main_pipe_assembler_tx_payload        (main_pipe_assembler_tx_payload         )
        ,.assembler_main_pipe_tx_rdy            (assembler_main_pipe_tx_rdy             )
    );

    rt_timeout_flag_store rt_timeout_flag_store (
         .clk                       (clk)
        ,.rst                       (rst)

        ,.new_flow_val                          (src_new_flow_val                   )
        ,.new_flow_flowid                       (src_new_flow_flowid                )
    
        ,.main_pipe_rt_timeout_rd_req_val       (main_pipe_rt_timeout_rd_req_val    )
        ,.main_pipe_rt_timeout_rd_req_flowid    (main_pipe_rt_timeout_rd_req_flowid )
        ,.rt_timeout_main_pipe_rd_req_rdy       (rt_timeout_main_pipe_rd_req_rdy    )

        ,.rt_timeout_main_pipe_rd_resp_val      (rt_timeout_main_pipe_rd_resp_val   )
        ,.rt_timeout_main_pipe_rd_resp_data     (rt_timeout_main_pipe_rd_resp_data  )
        ,.main_pipe_rt_timeout_rd_resp_rdy      (main_pipe_rt_timeout_rd_resp_rdy   )

        ,.main_pipe_rt_timeout_clr_bit_val      (main_pipe_rt_timeout_clr_bit_val   )
        ,.main_pipe_rt_timeout_clr_bit_flowid   (main_pipe_rt_timeout_clr_bit_flowid)

        ,.timeout_set_bit_val                   (1'b0)
        ,.timeout_set_bit_flowid                ('0)

        ,.rt_set_bit_val                        (rx_pipe_rt_store_set_rt_flag_val   )
        ,.rt_set_bit_flowid                     (rx_pipe_rt_store_set_rt_flag_flowid)
    );


    // We can put a FIFO here to cut the ready signal critical path if necessary
    
    hdr_assembler_pipe assembler (
         .clk(clk)
        ,.rst(rst)

        ,.main_pipe_assembler_tx_val            (main_pipe_assembler_tx_val             )
        ,.main_pipe_assembler_tx_flowid         (main_pipe_assembler_tx_flowid          )
        ,.main_pipe_assembler_tx_seq_num        (main_pipe_assembler_tx_seq_num         )
        ,.main_pipe_assembler_tx_payload        (main_pipe_assembler_tx_payload         )
        ,.assembler_main_pipe_tx_rdy            (assembler_main_pipe_tx_rdy             )
    
        ,.send_pipe_recv_state_rd_req_val       (send_pipe_recv_state_rd_req_val        )
        ,.send_pipe_recv_state_rd_req_flowid    (send_pipe_recv_state_rd_req_flowid     )
        ,.recv_state_send_pipe_rd_req_rdy       (recv_state_send_pipe_rd_req_rdy        )
                                                                                        
        ,.recv_state_send_pipe_rd_resp_val      (recv_state_send_pipe_rd_resp_val       )
        ,.recv_state_send_pipe_rd_resp_data     (recv_state_send_pipe_rd_resp_data      )
        ,.send_pipe_recv_state_rd_resp_rdy      (send_pipe_recv_state_rd_resp_rdy       )
    
        ,.assembler_flowid_lookup_rd_req_val    (assembler_flowid_lookup_rd_req_val     )
        ,.assembler_flowid_lookup_rd_req_flowid (assembler_flowid_lookup_rd_req_flowid  )
        ,.flowid_lookup_assembler_rd_req_rdy    (flowid_lookup_assembler_rd_req_rdy     )
                                                                                        
        ,.flowid_lookup_assembler_rd_resp_val   (flowid_lookup_assembler_rd_resp_val    )
        ,.flowid_lookup_assembler_rd_resp_data  (flowid_lookup_assembler_rd_resp_data   )
        ,.assembler_flowid_lookup_rd_resp_rdy   (assembler_flowid_lookup_rd_resp_rdy    )

        ,.assembler_dst_tx_val                  (send_dst_tx_val                        )
        ,.assembler_dst_tx_flowid               (send_dst_tx_flowid                     )
        ,.assembler_dst_tx_src_ip               (send_dst_tx_src_ip                     )
        ,.assembler_dst_tx_dst_ip               (send_dst_tx_dst_ip                     )
        ,.assembler_dst_tx_tcp_hdr              (send_dst_tx_tcp_hdr                    )
        ,.assembler_dst_tx_payload              (send_dst_tx_payload                    )
        ,.dst_assembler_tx_rdy                  (dst_send_tx_rdy                        )
    
    );
    
    flowid_to_addr flowid_to_addr_lookup (
         .clk(clk)
        ,.rst(rst)

        ,.wr_req_val        (src_new_flow_val                       )
        ,.wr_req_flowid     (src_new_flow_flowid                    )
        ,.wr_req_rdy        (new_flow_src_rdy                       )

        ,.wr_req_flow_entry (src_new_flow_lookup_entry              )

        ,.rd_req_val        (assembler_flowid_lookup_rd_req_val     )
        ,.rd_req_flowid     (assembler_flowid_lookup_rd_req_flowid  )
        ,.rd_req_rdy        (flowid_lookup_assembler_rd_req_rdy     )

        ,.rd_resp_val       (flowid_lookup_assembler_rd_resp_val    )
        ,.rd_resp_flow_entry(flowid_lookup_assembler_rd_resp_data   )
        ,.rd_resp_rdy       (assembler_flowid_lookup_rd_resp_rdy    )
    );

endmodule
