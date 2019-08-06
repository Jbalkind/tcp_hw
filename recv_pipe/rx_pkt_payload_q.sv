`include "packet_defs.vh"
`include "state_defs.vh"


// Note that this queue is only designed for one writer. If something else
// enqueues between the querying and the full, there is no guarantee that the queue
// is still able to accept the packet
//
// The val-ready handshakes on this interface are val-THEN-ready.
// As in the using modules should not depend on ready to assert val.
// We do this, because we have to arbitrate between new state and 
// normal requests. New state always takes precedence

module rx_pkt_payload_q (
     input clk
    ,input rst

    // For setting new pointer state
    ,input                              new_head_val
    ,input  [`FLOW_ID_W-1:0]            new_head_addr
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]    new_head_data
    ,output                             new_head_rdy
    ,input                              new_tail_val
    ,input  [`FLOW_ID_W-1:0]            new_tail_addr
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]    new_tail_data
    ,output                             new_tail_rdy
    
    ,input                              q_full_req_val
    ,input  [`FLOW_ID_W-1:0]            q_full_req_flowid
    ,output                             q_full_req_rdy
    
    ,output                             q_full_resp_val
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]    q_full_resp_tail_index
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]    q_full_resp_head_index
    ,input                              q_full_resp_rdy

    ,input                              enqueue_pkt_req_val
    ,input  [`FLOW_ID_W-1:0]            enqueue_pkt_req_flowid
    ,input  [`PAYLOAD_ENTRY_W-1:0]      enqueue_pkt_req_data
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]    enqueue_pkt_req_index
    ,output                             enqueue_pkt_req_rdy

    // For reading out a packet from the queue
    ,input                              read_payload_req_val
    ,input  [`FLOW_ID_W-1:0]            read_payload_req_flowid
    ,output                             read_payload_req_rdy

    ,output                             read_payload_resp_val
    ,output                             read_payload_resp_is_empty
    ,output [`PAYLOAD_ENTRY_W-1:0]      read_payload_resp_entry
    ,input                              read_payload_resp_rdy
);
    
    logic                                   enqueue_head_ptr_mem_rd_req_val;
    logic   [`FLOW_ID_W-1:0]                enqueue_head_ptr_mem_rd_req_addr;
    logic                                   head_ptr_mem_enqueue_rd_req_rdy;

    logic                                   enqueue_tail_ptr_mem_rd_req_val;
    logic   [`FLOW_ID_W-1:0]                enqueue_tail_ptr_mem_rd_req_addr;
    logic                                   tail_ptr_mem_enqueue_rd_req_rdy;

    logic                                   tail_ptr_mem_enqueue_rd_resp_val;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        tail_ptr_mem_enqueue_rd_resp_data;
    logic                                   enqueue_tail_ptr_mem_rd_resp_rdy;

    logic                                   head_ptr_mem_enqueue_rd_resp_val;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        head_ptr_mem_enqueue_rd_resp_data;
    logic                                   enqueue_head_ptr_mem_rd_resp_rdy;

    logic                                   enqueue_tail_ptr_mem_wr_req_val;
    logic   [`FLOW_ID_W-1:0]                enqueue_tail_ptr_mem_wr_req_addr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        enqueue_tail_ptr_mem_wr_req_data;
    logic                                   tail_ptr_mem_enqueue_wr_req_rdy;
    
    logic                                   tail_ptr_mem_wr_req_val;
    logic   [`FLOW_ID_W-1:0]                tail_ptr_mem_wr_req_addr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        tail_ptr_mem_wr_req_data;
    logic                                   tail_ptr_mem_wr_req_rdy;
    
    logic                                   head_ptr_mem_wr_req_val;
    logic   [`FLOW_ID_W-1:0]                head_ptr_mem_wr_req_addr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        head_ptr_mem_wr_req_data;
    logic                                   head_ptr_mem_wr_req_rdy;

    logic                                   enqueue_payload_buffer_wr_req_val;
    logic   [`PAYLOAD_BUF_MEM_ADDR_W-1:0]   enqueue_payload_buffer_wr_req_addr;
    logic   [`PAYLOAD_ENTRY_W-1:0]          enqueue_payload_buffer_wr_req_data;
    logic                                   payload_buffer_enqueue_wr_req_rdy;
    
    logic                                   dequeue_head_ptr_mem_rd_req_val;
    logic   [`FLOW_ID_W-1:0]                dequeue_head_ptr_mem_rd_req_addr;
    logic                                   head_ptr_mem_dequeue_rd_req_rdy;

    logic                                   dequeue_tail_ptr_mem_rd_req_val;
    logic   [`FLOW_ID_W-1:0]                dequeue_tail_ptr_mem_rd_req_addr;
    logic                                   tail_ptr_mem_dequeue_rd_req_rdy;

    logic                                   tail_ptr_mem_dequeue_rd_resp_val;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        tail_ptr_mem_dequeue_rd_resp_data;
    logic                                   dequeue_tail_ptr_mem_rd_resp_rdy;

    logic                                   head_ptr_mem_dequeue_rd_resp_val;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        head_ptr_mem_dequeue_rd_resp_data;
    logic                                   dequeue_head_ptr_mem_rd_resp_rdy;

    logic                                   dequeue_head_ptr_mem_wr_req_val;
    logic   [`FLOW_ID_W-1:0]                dequeue_head_ptr_mem_wr_req_addr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]        dequeue_head_ptr_mem_wr_req_data;
    logic                                   head_ptr_mem_dequeue_wr_req_rdy;

    logic                                   dequeue_payload_buffer_rd_req_val;
    logic   [`PAYLOAD_BUF_MEM_ADDR_W-1:0]   dequeue_payload_buffer_rd_req_addr;
    logic                                   payload_buffer_dequeue_rd_req_rdy;

    logic                                   payload_buffer_dequeue_rd_resp_val;
    logic   [`PAYLOAD_ENTRY_W-1:0]          payload_buffer_dequeue_rd_resp_data;
    logic                                   dequeue_payload_buffer_rd_resp_rdy;


    rx_pkt_payload_q_enqueue enqueue_if_pipeline (
         .clk   (clk)
        ,.rst   (rst)

        ,.q_full_req_val                        (q_full_req_val                     )
        ,.q_full_req_flowid                     (q_full_req_flowid                  )
        ,.q_full_req_rdy                        (q_full_req_rdy                     )
                                                                        
        ,.q_full_resp_val                       (q_full_resp_val                    )
        ,.q_full_resp_tail_index                (q_full_resp_tail_index             )
        ,.q_full_resp_head_index                (q_full_resp_head_index             )
        ,.q_full_resp_rdy                       (q_full_resp_rdy                    )

        ,.enqueue_pkt_req_val                   (enqueue_pkt_req_val                )
        ,.enqueue_pkt_req_flowid                (enqueue_pkt_req_flowid             )
        ,.enqueue_pkt_req_index                 (enqueue_pkt_req_index              )
        ,.enqueue_pkt_req_data                  (enqueue_pkt_req_data               )
        ,.enqueue_pkt_req_rdy                   (enqueue_pkt_req_rdy                )

        ,.enqueue_head_ptr_mem_rd_req_val       (enqueue_head_ptr_mem_rd_req_val    )
        ,.enqueue_head_ptr_mem_rd_req_addr      (enqueue_head_ptr_mem_rd_req_addr   )
        ,.head_ptr_mem_enqueue_rd_req_rdy       (head_ptr_mem_enqueue_rd_req_rdy    )
                                                                                    
        ,.enqueue_tail_ptr_mem_rd_req_val       (enqueue_tail_ptr_mem_rd_req_val    )
        ,.enqueue_tail_ptr_mem_rd_req_addr      (enqueue_tail_ptr_mem_rd_req_addr   )
        ,.tail_ptr_mem_enqueue_rd_req_rdy       (tail_ptr_mem_enqueue_rd_req_rdy    )
                                                                                    
        ,.tail_ptr_mem_enqueue_rd_resp_val      (tail_ptr_mem_enqueue_rd_resp_val   )
        ,.tail_ptr_mem_enqueue_rd_resp_data     (tail_ptr_mem_enqueue_rd_resp_data  )
        ,.enqueue_tail_ptr_mem_rd_resp_rdy      (enqueue_tail_ptr_mem_rd_resp_rdy   )
                                                                                    
        ,.head_ptr_mem_enqueue_rd_resp_val      (head_ptr_mem_enqueue_rd_resp_val   )
        ,.head_ptr_mem_enqueue_rd_resp_data     (head_ptr_mem_enqueue_rd_resp_data  )
        ,.enqueue_head_ptr_mem_rd_resp_rdy      (enqueue_head_ptr_mem_rd_resp_rdy   )
                                                                                    
        ,.enqueue_tail_ptr_mem_wr_req_val       (enqueue_tail_ptr_mem_wr_req_val    )
        ,.enqueue_tail_ptr_mem_wr_req_addr      (enqueue_tail_ptr_mem_wr_req_addr   )
        ,.enqueue_tail_ptr_mem_wr_req_data      (enqueue_tail_ptr_mem_wr_req_data   )
        ,.tail_ptr_mem_enqueue_wr_req_rdy       (tail_ptr_mem_enqueue_wr_req_rdy    )
                                                                                    
        ,.enqueue_payload_buffer_wr_req_val     (enqueue_payload_buffer_wr_req_val  )
        ,.enqueue_payload_buffer_wr_req_addr    (enqueue_payload_buffer_wr_req_addr )
        ,.enqueue_payload_buffer_wr_req_data    (enqueue_payload_buffer_wr_req_data )
        ,.payload_buffer_enqueue_wr_req_rdy     (payload_buffer_enqueue_wr_req_rdy  )
    );

    rx_pkt_payload_q_dequeue dequeue_if_pipeline (
         .clk   (clk)
        ,.rst   (rst)

        // For reading out a packet from the queue()
        ,.read_payload_req_val                  (read_payload_req_val                   )
        ,.read_payload_req_flowid               (read_payload_req_flowid                )
        ,.read_payload_req_rdy                  (read_payload_req_rdy                   )

        ,.read_payload_resp_val                 (read_payload_resp_val                  )
        ,.read_payload_resp_is_empty            (read_payload_resp_is_empty             )
        ,.read_payload_resp_entry               (read_payload_resp_entry                )
        ,.read_payload_resp_rdy                 (read_payload_resp_rdy                  )

        ,.dequeue_head_ptr_mem_rd_req_val       (dequeue_head_ptr_mem_rd_req_val        )
        ,.dequeue_head_ptr_mem_rd_req_addr      (dequeue_head_ptr_mem_rd_req_addr       )
        ,.head_ptr_mem_dequeue_rd_req_rdy       (head_ptr_mem_dequeue_rd_req_rdy        )
                                                                                        
        ,.dequeue_tail_ptr_mem_rd_req_val       (dequeue_tail_ptr_mem_rd_req_val        )
        ,.dequeue_tail_ptr_mem_rd_req_addr      (dequeue_tail_ptr_mem_rd_req_addr       )
        ,.tail_ptr_mem_dequeue_rd_req_rdy       (tail_ptr_mem_dequeue_rd_req_rdy        )
                                                                                        
        ,.tail_ptr_mem_dequeue_rd_resp_val      (tail_ptr_mem_dequeue_rd_resp_val       )
        ,.tail_ptr_mem_dequeue_rd_resp_data     (tail_ptr_mem_dequeue_rd_resp_data      )
        ,.dequeue_tail_ptr_mem_rd_resp_rdy      (dequeue_tail_ptr_mem_rd_resp_rdy       )
                                                                                        
        ,.head_ptr_mem_dequeue_rd_resp_val      (head_ptr_mem_dequeue_rd_resp_val       )
        ,.head_ptr_mem_dequeue_rd_resp_data     (head_ptr_mem_dequeue_rd_resp_data      )
        ,.dequeue_head_ptr_mem_rd_resp_rdy      (dequeue_head_ptr_mem_rd_resp_rdy       )
                                                                                        
        ,.dequeue_head_ptr_mem_wr_req_val       (dequeue_head_ptr_mem_wr_req_val        )
        ,.dequeue_head_ptr_mem_wr_req_addr      (dequeue_head_ptr_mem_wr_req_addr       )
        ,.dequeue_head_ptr_mem_wr_req_data      (dequeue_head_ptr_mem_wr_req_data       )
        ,.head_ptr_mem_dequeue_wr_req_rdy       (head_ptr_mem_dequeue_wr_req_rdy        )
                                                                                        
        ,.dequeue_payload_buffer_rd_req_val     (dequeue_payload_buffer_rd_req_val      )
        ,.dequeue_payload_buffer_rd_req_addr    (dequeue_payload_buffer_rd_req_addr     )
        ,.payload_buffer_dequeue_rd_req_rdy     (payload_buffer_dequeue_rd_req_rdy      )
                                                                                        
        ,.payload_buffer_dequeue_rd_resp_val    (payload_buffer_dequeue_rd_resp_val     )
        ,.payload_buffer_dequeue_rd_resp_data   (payload_buffer_dequeue_rd_resp_data    )
        ,.dequeue_payload_buffer_rd_resp_rdy    (dequeue_payload_buffer_rd_resp_rdy     )
    );


    assign new_head_rdy = head_ptr_mem_wr_req_rdy;
    assign head_ptr_mem_dequeue_wr_req_rdy = head_ptr_mem_wr_req_rdy & ~new_head_val;

    assign head_ptr_mem_wr_req_val = new_head_val | dequeue_head_ptr_mem_wr_req_val;
    assign head_ptr_mem_wr_req_addr = new_head_val ? new_head_addr : dequeue_head_ptr_mem_wr_req_addr;
    assign head_ptr_mem_wr_req_data = new_head_val ? new_head_data : dequeue_head_ptr_mem_wr_req_data;

    ram_2r1w_sync_backpressure #(
        .width_p      (`RX_PAYLOAD_Q_SIZE_W+1)
       ,.els_p        (`MAX_FLOW_CNT)
    )
    head_pointers (
         .clk           (clk)
        ,.rst           (rst)

        ,.wr_req_val    (head_ptr_mem_wr_req_val            )
        ,.wr_req_addr   (head_ptr_mem_wr_req_addr           )
        ,.wr_req_data   (head_ptr_mem_wr_req_data           )
        ,.wr_req_rdy    (head_ptr_mem_wr_req_rdy            )

        ,.rd0_req_val   (enqueue_head_ptr_mem_rd_req_val    )
        ,.rd0_req_addr  (enqueue_head_ptr_mem_rd_req_addr   )
        ,.rd0_req_rdy   (head_ptr_mem_enqueue_rd_req_rdy    )

        ,.rd0_resp_val  (head_ptr_mem_enqueue_rd_resp_val   )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (head_ptr_mem_enqueue_rd_resp_data  )
        ,.rd0_resp_rdy  (enqueue_head_ptr_mem_rd_resp_rdy   )

        ,.rd1_req_val   (dequeue_head_ptr_mem_rd_req_val    )
        ,.rd1_req_addr  (dequeue_head_ptr_mem_rd_req_addr   )
        ,.rd1_req_rdy   (head_ptr_mem_dequeue_rd_req_rdy    )

        ,.rd1_resp_val  (head_ptr_mem_dequeue_rd_resp_val   )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (head_ptr_mem_dequeue_rd_resp_data  )
        ,.rd1_resp_rdy  (dequeue_head_ptr_mem_rd_resp_rdy   )
    );

    assign new_tail_rdy = tail_ptr_mem_wr_req_rdy;
    assign tail_ptr_mem_enqueue_wr_req_rdy = tail_ptr_mem_wr_req_rdy & ~new_tail_val;

    assign tail_ptr_mem_wr_req_val = new_tail_val | enqueue_tail_ptr_mem_wr_req_val;
    assign tail_ptr_mem_wr_req_addr = new_tail_val ? new_tail_addr : enqueue_tail_ptr_mem_wr_req_addr;
    assign tail_ptr_mem_wr_req_data = new_tail_val ? new_tail_data : enqueue_tail_ptr_mem_wr_req_data;

    ram_2r1w_sync_backpressure #(
         .width_p      (`RX_PAYLOAD_Q_SIZE_W+1)
        ,.els_p        (`MAX_FLOW_CNT)
    )
    tail_pointers (
         .clk     (clk)
        ,.rst     (rst)
        
        ,.wr_req_val    (tail_ptr_mem_wr_req_val            )
        ,.wr_req_addr   (tail_ptr_mem_wr_req_addr           )
        ,.wr_req_data   (tail_ptr_mem_wr_req_data           )
        ,.wr_req_rdy    (tail_ptr_mem_wr_req_rdy            )

        ,.rd0_req_val   (enqueue_tail_ptr_mem_rd_req_val    )
        ,.rd0_req_addr  (enqueue_tail_ptr_mem_rd_req_addr   )
        ,.rd0_req_rdy   (tail_ptr_mem_enqueue_rd_req_rdy    )

        ,.rd0_resp_val  (tail_ptr_mem_enqueue_rd_resp_val   )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (tail_ptr_mem_enqueue_rd_resp_data  )
        ,.rd0_resp_rdy  (enqueue_tail_ptr_mem_rd_resp_rdy   )

        ,.rd1_req_val   (dequeue_tail_ptr_mem_rd_req_val    )
        ,.rd1_req_addr  (dequeue_tail_ptr_mem_rd_req_addr   )
        ,.rd1_req_rdy   (tail_ptr_mem_dequeue_rd_req_rdy    )

        ,.rd1_resp_val  (tail_ptr_mem_dequeue_rd_resp_val   )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (tail_ptr_mem_dequeue_rd_resp_data  )
        ,.rd1_resp_rdy  (dequeue_tail_ptr_mem_rd_resp_rdy   )
    );

    ram_1r1w_sync_backpressure #(
         .width_p   (`PAYLOAD_ENTRY_W    )
        ,.els_p     (`PAYLOAD_BUF_MEM_ELS)
    )   payload_ring_buffers (
         .clk(clk)
        ,.rst(rst)

        ,.wr_req_val    (enqueue_payload_buffer_wr_req_val  )
        ,.wr_req_addr   (enqueue_payload_buffer_wr_req_addr )
        ,.wr_req_data   (enqueue_payload_buffer_wr_req_data )
        ,.wr_req_rdy    (payload_buffer_enqueue_wr_req_rdy  )

        ,.rd_req_val    (dequeue_payload_buffer_rd_req_val  )
        ,.rd_req_addr   (dequeue_payload_buffer_rd_req_addr )
        ,.rd_req_rdy    (payload_buffer_dequeue_rd_req_rdy  )

        ,.rd_resp_val   (payload_buffer_dequeue_rd_resp_val )
        ,.rd_resp_data  (payload_buffer_dequeue_rd_resp_data)
        ,.rd_resp_rdy   (dequeue_payload_buffer_rd_resp_rdy )
    );

endmodule
