`include "state_defs.vh"
module test_echo_app (
     input clk
    ,input rst
    
    ,input                                          app_new_flow_notif_val
    ,input  [`FLOW_ID_W-1:0]                        app_new_flow_flowid

    ,output logic                                   app_tail_ptr_tx_wr_req_val
    ,output logic   [`FLOW_ID_W-1:0]                app_tail_ptr_tx_wr_req_flowid
    ,output logic   [`PAYLOAD_PTR_W:0]              app_tail_ptr_tx_wr_req_data
    ,input                                          tail_ptr_app_tx_wr_req_rdy
    
    ,output logic                                   app_tail_ptr_tx_rd_req1_val
    ,output logic   [`FLOW_ID_W-1:0]                app_tail_ptr_tx_rd_req1_flowid
    ,input                                          tail_ptr_app_tx_rd_req1_rdy

    ,input                                          tail_ptr_app_tx_rd_resp1_val
    ,input          [`FLOW_ID_W-1:0]                tail_ptr_app_tx_rd_resp1_flowid
    ,input          [`PAYLOAD_PTR_W:0]              tail_ptr_app_tx_rd_resp1_data
    ,output logic                                   app_tail_ptr_tx_rd_resp1_rdy

    ,output logic                                   app_head_ptr_tx_rd_req0_val
    ,output logic   [`FLOW_ID_W-1:0]                app_head_ptr_tx_rd_req0_flowid
    ,input  logic                                   head_ptr_app_tx_rd_req0_rdy

    ,input  logic                                   head_ptr_app_tx_rd_resp0_val
    ,input  logic   [`FLOW_ID_W-1:0]                head_ptr_app_tx_rd_resp0_flowid
    ,input  logic   [`PAYLOAD_PTR_W:0]              head_ptr_app_tx_rd_resp0_data
    ,output logic                                   app_head_ptr_tx_rd_resp0_rdy
    
    ,output logic                                   app_rx_head_ptr_wr_req_val
    ,output logic   [`FLOW_ID_W-1:0]                app_rx_head_ptr_wr_req_addr
    ,output logic   [`RX_PAYLOAD_PTR_W:0]           app_rx_head_ptr_wr_req_data
    ,input  logic                                   rx_head_ptr_app_wr_req_rdy

    ,output logic                                   app_rx_head_ptr_rd_req_val
    ,output logic   [`FLOW_ID_W-1:0]                app_rx_head_ptr_rd_req_addr
    ,input  logic                                   rx_head_ptr_app_rd_req_rdy
    
    ,input  logic                                   rx_head_ptr_app_rd_resp_val
    ,input  logic   [`RX_PAYLOAD_PTR_W:0]           rx_head_ptr_app_rd_resp_data
    ,output logic                                   app_rx_head_ptr_rd_resp_rdy

    ,output logic                                   app_rx_commit_ptr_rd_req_val
    ,output logic   [`FLOW_ID_W-1:0]                app_rx_commit_ptr_rd_req_addr
    ,input  logic                                   rx_commit_ptr_app_rd_req_rdy

    ,input  logic                                   rx_commit_ptr_app_rd_resp_val
    ,input  logic   [`RX_PAYLOAD_PTR_W:0]           rx_commit_ptr_app_rd_resp_data
    ,output logic                                   app_rx_commit_ptr_rd_resp_rdy
);
    
    logic                                       enqueue_flow;
    logic   [`FLOW_ID_W-1:0]                    enqueue_flow_id;
    logic                                       enqueue_flow_rdy;
    logic                                       ctrl_requeue_flow_val;
    logic   [`FLOW_ID_W-1:0]                    datapath_requeue_flowid;
    
    logic                                       flow_fifo_ctrl_flowid_val;
    logic   [`FLOW_ID_W-1:0]                    flow_fifo_datapath_flowid;
    logic                                       ctrl_flow_fifo_flowid_yumi;
    
    logic                                       new_flow_notif_val_reg;
    logic   [`FLOW_ID_W-1:0]                    new_flow_flow_id_reg;

    logic                                       flow_fifo_ctrl_enqueue_rdy;
    

    logic                                       store_curr_flowid;
    logic                                       store_rx_ptrs;
    logic                                       store_tx_ptrs;
    logic                                       update_q_space;

    logic                                       rx_buf_empty;
    logic                                       rx_buf_full;
    logic                                       tx_buf_full;

    test_echo_app_copy_ctrl control (
         .clk   (clk)
        ,.rst   (rst)

        ,.app_tail_ptr_tx_wr_req_val    (app_tail_ptr_tx_wr_req_val     )
        ,.tail_ptr_app_tx_wr_req_rdy    (tail_ptr_app_tx_wr_req_rdy     )
                                                                        
        ,.app_tail_ptr_tx_rd_req1_val   (app_tail_ptr_tx_rd_req1_val    )
        ,.tail_ptr_app_tx_rd_req1_rdy   (tail_ptr_app_tx_rd_req1_rdy    )
                                                                        
        ,.tail_ptr_app_tx_rd_resp1_val  (tail_ptr_app_tx_rd_resp1_val   )
        ,.app_tail_ptr_tx_rd_resp1_rdy  (app_tail_ptr_tx_rd_resp1_rdy   )
                                                                        
        ,.app_head_ptr_tx_rd_req0_val   (app_head_ptr_tx_rd_req0_val    )
        ,.head_ptr_app_tx_rd_req0_rdy   (head_ptr_app_tx_rd_req0_rdy    )
                                                                        
        ,.head_ptr_app_tx_rd_resp0_val  (head_ptr_app_tx_rd_resp0_val   )
        ,.app_head_ptr_tx_rd_resp0_rdy  (app_head_ptr_tx_rd_resp0_rdy   )
                                                                        
        ,.app_rx_head_ptr_wr_req_val    (app_rx_head_ptr_wr_req_val     )
        ,.rx_head_ptr_app_wr_req_rdy    (rx_head_ptr_app_wr_req_rdy     )
                                                                        
        ,.app_rx_head_ptr_rd_req_val    (app_rx_head_ptr_rd_req_val     )
        ,.rx_head_ptr_app_rd_req_rdy    (rx_head_ptr_app_rd_req_rdy     )
                                                                        
        ,.rx_head_ptr_app_rd_resp_val   (rx_head_ptr_app_rd_resp_val    )
        ,.app_rx_head_ptr_rd_resp_rdy   (app_rx_head_ptr_rd_resp_rdy    )
                                                                        
        ,.app_rx_commit_ptr_rd_req_val  (app_rx_commit_ptr_rd_req_val   )
        ,.rx_commit_ptr_app_rd_req_rdy  (rx_commit_ptr_app_rd_req_rdy   )
                                                                        
        ,.rx_commit_ptr_app_rd_resp_val (rx_commit_ptr_app_rd_resp_val  )
        ,.app_rx_commit_ptr_rd_resp_rdy (app_rx_commit_ptr_rd_resp_rdy  )
                                                                        
        ,.flow_fifo_ctrl_flowid_val     (flow_fifo_ctrl_flowid_val      )
        ,.ctrl_flow_fifo_flowid_yumi    (ctrl_flow_fifo_flowid_yumi     )
                                                                        
        ,.ctrl_requeue_flow_val         (ctrl_requeue_flow_val          )
        ,.flow_fifo_ctrl_enqueue_rdy    (flow_fifo_ctrl_enqueue_rdy     )
                                                                        
        ,.store_curr_flowid             (store_curr_flowid              )
        ,.store_rx_ptrs                 (store_rx_ptrs                  )
        ,.store_tx_ptrs                 (store_tx_ptrs                  )
        ,.update_q_space                (update_q_space                 )
                                                                        
        ,.rx_buf_empty                  (rx_buf_empty                   )
        ,.rx_buf_full                   (rx_buf_full                    )
        ,.tx_buf_full                   (tx_buf_full                    )
    );

    test_echo_app_datap datapath (
         .clk   (clk)
        ,.rst   (rst)

        ,.app_tail_ptr_tx_wr_req_flowid     (app_tail_ptr_tx_wr_req_flowid  )
        ,.app_tail_ptr_tx_wr_req_data       (app_tail_ptr_tx_wr_req_data    )
                                                                            
        ,.app_tail_ptr_tx_rd_req1_flowid    (app_tail_ptr_tx_rd_req1_flowid )
                                                                            
        ,.tail_ptr_app_tx_rd_resp1_data     (tail_ptr_app_tx_rd_resp1_data  )
                                                                            
        ,.app_head_ptr_tx_rd_req0_flowid    (app_head_ptr_tx_rd_req0_flowid )
                                                                            
        ,.head_ptr_app_tx_rd_resp0_data     (head_ptr_app_tx_rd_resp0_data  )
                                                                            
        ,.app_rx_head_ptr_wr_req_addr       (app_rx_head_ptr_wr_req_addr    )
        ,.app_rx_head_ptr_wr_req_data       (app_rx_head_ptr_wr_req_data    )
                                                                            
        ,.app_rx_head_ptr_rd_req_addr       (app_rx_head_ptr_rd_req_addr    )
                                                                            
        ,.rx_head_ptr_app_rd_resp_data      (rx_head_ptr_app_rd_resp_data   )
                                                                            
        ,.app_rx_commit_ptr_rd_req_addr     (app_rx_commit_ptr_rd_req_addr  )
                                                                            
        ,.rx_commit_ptr_app_rd_resp_data    (rx_commit_ptr_app_rd_resp_data )

        ,.flow_fifo_datapath_flowid         (flow_fifo_datapath_flowid      )
        ,.datapath_requeue_flowid           (datapath_requeue_flowid        )
                                                                            
        ,.store_curr_flowid                 (store_curr_flowid              )
        ,.store_rx_ptrs                     (store_rx_ptrs                  )
        ,.store_tx_ptrs                     (store_tx_ptrs                  )
        ,.update_q_space                    (update_q_space                 )

        ,.rx_buf_empty                      (rx_buf_empty                   )
        ,.rx_buf_full                       (rx_buf_full                    )
        ,.tx_buf_full                       (tx_buf_full                    )
    );

    
    /*********************************************************************
     * Active flows to check for data
     ********************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            new_flow_notif_val_reg <= 1'b0;
            new_flow_flow_id_reg <= '0;
        end
        else begin
            new_flow_notif_val_reg <= app_new_flow_notif_val;
            new_flow_flow_id_reg <= app_new_flow_flowid;
        end
    end
    
    assign enqueue_flow = new_flow_notif_val_reg | ctrl_requeue_flow_val;
    assign enqueue_flow_id = new_flow_notif_val_reg ? new_flow_flow_id_reg : datapath_requeue_flowid;

    assign flow_fifo_ctrl_enqueue_rdy = ~new_flow_notif_val_reg & enqueue_flow_rdy;
    
    bsg_fifo_1r1w_small #(
         .width_p(`FLOW_ID_W)
        ,.els_p  (`MAX_FLOW_CNT)
    ) flowid_fifo (
        .clk_i      (clk)
       ,.reset_i    (rst)

       ,.v_i        (enqueue_flow               )
       ,.ready_o    (enqueue_flow_rdy           )
       ,.data_i     (enqueue_flow_id            )

       ,.v_o        (flow_fifo_ctrl_flowid_val  )
       ,.data_o     (flow_fifo_datapath_flowid  )
       ,.yumi_i     (ctrl_flow_fifo_flowid_yumi )
    );


endmodule
