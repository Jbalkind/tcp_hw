`include "state_defs.vh"
module rx_pkt_payload_q_enqueue (
     input clk
    ,input rst

    ,input                                  q_full_req_val
    ,input  [`FLOW_ID_W-1:0]                q_full_req_flowid
    ,output                                 q_full_req_rdy
    
    ,output                                 q_full_resp_val
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]        q_full_resp_tail_index
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]        q_full_resp_head_index
    ,input                                  q_full_resp_rdy

    ,input                                  enqueue_pkt_req_val
    ,input  [`FLOW_ID_W-1:0]                enqueue_pkt_req_flowid
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]        enqueue_pkt_req_index
    ,input  [`PAYLOAD_ENTRY_W-1:0]          enqueue_pkt_req_data
    ,output                                 enqueue_pkt_req_rdy

    ,output                                 enqueue_head_ptr_mem_rd_req_val
    ,output [`FLOW_ID_W-1:0]                enqueue_head_ptr_mem_rd_req_addr
    ,input                                  head_ptr_mem_enqueue_rd_req_rdy

    ,output                                 enqueue_tail_ptr_mem_rd_req_val
    ,output [`FLOW_ID_W-1:0]                enqueue_tail_ptr_mem_rd_req_addr
    ,input                                  tail_ptr_mem_enqueue_rd_req_rdy
    
    ,input                                  tail_ptr_mem_enqueue_rd_resp_val
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]        tail_ptr_mem_enqueue_rd_resp_data
    ,output                                 enqueue_tail_ptr_mem_rd_resp_rdy
    
    ,input                                  head_ptr_mem_enqueue_rd_resp_val
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]        head_ptr_mem_enqueue_rd_resp_data
    ,output                                 enqueue_head_ptr_mem_rd_resp_rdy

    ,output                                 enqueue_tail_ptr_mem_wr_req_val
    ,output [`FLOW_ID_W-1:0]                enqueue_tail_ptr_mem_wr_req_addr
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]        enqueue_tail_ptr_mem_wr_req_data
    ,input                                  tail_ptr_mem_enqueue_wr_req_rdy
    
    ,output                                 enqueue_payload_buffer_wr_req_val
    ,output [`PAYLOAD_BUF_MEM_ADDR_W-1:0]   enqueue_payload_buffer_wr_req_addr
    ,output [`PAYLOAD_ENTRY_W-1:0]          enqueue_payload_buffer_wr_req_data
    ,input                                  payload_buffer_enqueue_wr_req_rdy
);
    

    full_query_pipe full_req_pipe (
         .clk   (clk)
        ,.rst   (rst)

        ,.q_full_req_val                    (q_full_req_val                     )
        ,.q_full_req_flowid                 (q_full_req_flowid                  )
        ,.q_full_req_rdy                    (q_full_req_rdy                     )
                                                                   
        ,.q_full_resp_val                   (q_full_resp_val                    )
        ,.q_full_resp_tail_index            (q_full_resp_tail_index             )
        ,.q_full_resp_head_index            (q_full_resp_head_index             )
        ,.q_full_resp_rdy                   (q_full_resp_rdy                    )

        ,.enqueue_head_ptr_mem_rd_req_val   (enqueue_head_ptr_mem_rd_req_val    )
        ,.enqueue_head_ptr_mem_rd_req_addr  (enqueue_head_ptr_mem_rd_req_addr   )
        ,.head_ptr_mem_enqueue_rd_req_rdy   (head_ptr_mem_enqueue_rd_req_rdy    )
                                                                                
        ,.enqueue_tail_ptr_mem_rd_req_val   (enqueue_tail_ptr_mem_rd_req_val    )
        ,.enqueue_tail_ptr_mem_rd_req_addr  (enqueue_tail_ptr_mem_rd_req_addr   )
        ,.tail_ptr_mem_enqueue_rd_req_rdy   (tail_ptr_mem_enqueue_rd_req_rdy    )

        ,.tail_ptr_mem_enqueue_rd_resp_val  (tail_ptr_mem_enqueue_rd_resp_val   )
        ,.tail_ptr_mem_enqueue_rd_resp_data (tail_ptr_mem_enqueue_rd_resp_data  )
        ,.enqueue_tail_ptr_mem_rd_resp_rdy  (enqueue_tail_ptr_mem_rd_resp_rdy   )
                                                                                
        ,.head_ptr_mem_enqueue_rd_resp_val  (head_ptr_mem_enqueue_rd_resp_val   )
        ,.head_ptr_mem_enqueue_rd_resp_data (head_ptr_mem_enqueue_rd_resp_data  )
        ,.enqueue_head_ptr_mem_rd_resp_rdy  (enqueue_head_ptr_mem_rd_resp_rdy   )
    );

    

    // we're ready to enqueue if we can update the tail pointer 
    // and we can write to the payload buffer
    assign enqueue_pkt_req_rdy = tail_ptr_mem_enqueue_wr_req_rdy 
                               & payload_buffer_enqueue_wr_req_rdy;

    assign enqueue_payload_buffer_wr_req_val = enqueue_pkt_req_val;
    assign enqueue_payload_buffer_wr_req_addr = {enqueue_pkt_req_flowid, 
                                                 enqueue_pkt_req_index[`RX_PAYLOAD_Q_SIZE_W-1:0]};
    assign enqueue_payload_buffer_wr_req_data = enqueue_pkt_req_data;

    assign enqueue_tail_ptr_mem_wr_req_val = enqueue_pkt_req_val;
    assign enqueue_tail_ptr_mem_wr_req_addr = enqueue_pkt_req_flowid;
    assign enqueue_tail_ptr_mem_wr_req_data = enqueue_pkt_req_index + 1'b1;




endmodule
