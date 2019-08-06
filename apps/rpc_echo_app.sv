/* 
 * Logic: reads out the header which has amount of data to send, amount of data
 *        to receive in the first 32 bytes of a request
 * Writer: writes out the data to the send buffer 
 */
`include "noc_defs.vh"
`include "noc_struct_defs.vh"
`include "bsg_defines.v"
`include "state_defs.vh"
module rpc_echo_app (
     input clk
    ,input rst
    
    ,output logic                           tx_app_noc0_vrtoc_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]   tx_app_noc0_vrtoc_data    
    ,input  logic                           noc0_vrtoc_tx_app_rdy

    ,input  logic                           noc0_ctovr_tx_app_val
    ,input  logic   [`NOC_DATA_WIDTH-1:0]   noc0_ctovr_tx_app_data
    ,output logic                           tx_app_noc0_ctovr_rdy     

    ,output logic                           rx_app_noc0_vrtoc_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]   rx_app_noc0_vrtoc_data    
    ,input  logic                           noc0_vrtoc_rx_app_rdy

    ,input  logic                           noc0_ctovr_rx_app_val
    ,input  logic   [`NOC_DATA_WIDTH-1:0]   noc0_ctovr_rx_app_data
    ,output logic                           rx_app_noc0_ctovr_rdy     
    
    ,input  logic                           new_flow_notif_val
    ,input  logic   [`FLOW_ID_W-1:0]        new_flow_flow_id
    
    ,output logic                           app_tail_ptr_tx_wr_req_val
    ,output logic   [`FLOW_ID_W-1:0]        app_tail_ptr_tx_wr_req_flowid
    ,output logic   [`PAYLOAD_PTR_W:0]      app_tail_ptr_tx_wr_req_data
    ,input  logic                           tail_ptr_app_tx_wr_req_rdy

    ,output logic                           app_tail_ptr_tx_rd_req1_val
    ,output logic   [`FLOW_ID_W-1:0]        app_tail_ptr_tx_rd_req1_flowid
    ,input  logic                           tail_ptr_app_tx_rd_req1_rdy

    ,input  logic                           tail_ptr_app_tx_rd_resp1_val
    ,input  logic   [`PAYLOAD_PTR_W:0]      tail_ptr_app_tx_rd_resp1_data
    ,output logic                           app_tail_ptr_tx_rd_resp1_rdy

    ,output logic                           app_head_ptr_tx_rd_req0_val
    ,output logic   [`FLOW_ID_W-1:0]        app_head_ptr_tx_rd_req0_flowid
    ,input  logic                           head_ptr_app_tx_rd_req0_rdy

    ,input  logic                           head_ptr_app_tx_rd_resp0_val
    ,input  logic   [`PAYLOAD_PTR_W:0]      head_ptr_app_tx_rd_resp0_data
    ,output logic                           app_head_ptr_tx_rd_resp0_rdy
    
    ,output logic                           app_rx_head_ptr_wr_req_val
    ,output logic   [`FLOW_ID_W-1:0]        app_rx_head_ptr_wr_req_addr
    ,output logic   [`RX_PAYLOAD_PTR_W:0]   app_rx_head_ptr_wr_req_data
    ,input  logic                           rx_head_ptr_app_wr_req_rdy

    ,output logic                           app_rx_head_ptr_rd_req_val
    ,output logic   [`FLOW_ID_W-1:0]        app_rx_head_ptr_rd_req_addr
    ,input  logic                           rx_head_ptr_app_rd_req_rdy

    ,input  logic                           rx_head_ptr_app_rd_resp_val
    ,input  logic   [`RX_PAYLOAD_PTR_W:0]   rx_head_ptr_app_rd_resp_data
    ,output logic                           app_rx_head_ptr_rd_resp_rdy

    ,output logic                           app_rx_commit_ptr_rd_req_val
    ,output logic   [`FLOW_ID_W-1:0]        app_rx_commit_ptr_rd_req_addr
    ,input  logic                           rx_commit_ptr_app_rd_req_rdy

    ,input  logic                           rx_commit_ptr_app_rd_resp_val
    ,input  logic   [`RX_PAYLOAD_PTR_W:0]   rx_commit_ptr_app_rd_resp_data
    ,output logic                           app_rx_commit_ptr_rd_resp_rdy
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
    
    logic                                       store_req_hdr;
    logic                                       ctrl_datap_decr_bytes_left;

    logic                                       datap_ctrl_hdr_arrived;
    logic                                       datap_ctrl_rd_sat;
    logic                                       datap_ctrl_wr_sat;
    logic                                       datap_ctrl_last_wr;
    
    logic                                       ctrl_wr_buf_req_val;
    logic   [`FLOW_ID_W-1:0]                    datapath_wr_buf_req_flowid;
    logic   [`PAYLOAD_PTR_W:0]                  datapath_wr_buf_req_wr_ptr;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]          datapath_wr_buf_req_size;
    logic                                       wr_buf_ctrl_req_rdy;

    logic                                       ctrl_wr_buf_req_data_val;
    logic   [`NOC_DATA_WIDTH-1:0]               datapath_wr_buf_req_data;
    logic                                       datapath_wr_buf_req_data_last;
    logic   [`NOC_PADBYTES_WIDTH-1:0]           datapath_wr_buf_req_data_padbytes;
    logic                                       wr_buf_ctrl_req_data_rdy;

    logic                                       wr_buf_ctrl_req_done;
    logic                                       ctrl_wr_buf_done_rdy;
    
    logic                                   ctrl_rd_buf_req_val;
    logic   [`FLOW_ID_W-1:0]                datapath_rd_buf_req_flowid;
    logic   [`RX_PAYLOAD_PTR_W:0]           datapath_rd_buf_req_offset;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]      datapath_rd_buf_req_size;
    logic                                   rd_buf_ctrl_req_rdy;
    
    logic                                   rd_buf_ctrl_resp_data_val;
    logic   [`NOC_DATA_WIDTH-1:0]           rd_buf_datapath_resp_data;
    logic                                   rd_buf_datapath_resp_data_last;
    logic   [`NOC_PADBYTES_WIDTH-1:0]       rd_buf_datapath_resp_data_padbytes;
    logic                                   ctrl_rd_buf_resp_data_rdy;

    rpc_echo_app_ctrl ctrl (
         .clk    (clk)
        ,.rst    (rst)

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
        ,.store_req_hdr                 (store_req_hdr                  )
        ,.ctrl_datap_decr_bytes_left    (ctrl_datap_decr_bytes_left     )
                                                                     
        ,.datap_ctrl_hdr_arrived        (datap_ctrl_hdr_arrived         )
        ,.datap_ctrl_rd_sat             (datap_ctrl_rd_sat              )
        ,.datap_ctrl_wr_sat             (datap_ctrl_wr_sat              )
        ,.datap_ctrl_last_wr            (datap_ctrl_last_wr             )
                                                                        
        ,.ctrl_wr_buf_req_val           (ctrl_wr_buf_req_val            )
        ,.wr_buf_ctrl_req_rdy           (wr_buf_ctrl_req_rdy            )
                                                                        
        ,.ctrl_wr_buf_req_data_val      (ctrl_wr_buf_req_data_val       )
        ,.wr_buf_ctrl_req_data_rdy      (wr_buf_ctrl_req_data_rdy       )
                                                                        
        ,.wr_buf_ctrl_req_done          (wr_buf_ctrl_req_done           )
        ,.ctrl_wr_buf_done_rdy          (ctrl_wr_buf_done_rdy           )
                                                                        
        ,.ctrl_rd_buf_req_val           (ctrl_rd_buf_req_val            )
        ,.rd_buf_ctrl_req_rdy           (rd_buf_ctrl_req_rdy            )
                                                                        
        ,.rd_buf_ctrl_resp_data_val     (rd_buf_ctrl_resp_data_val      )
        ,.ctrl_rd_buf_resp_data_rdy     (ctrl_rd_buf_resp_data_rdy      )
    );

    rpc_echo_app_datap datap (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.app_tail_ptr_tx_wr_req_flowid         (app_tail_ptr_tx_wr_req_flowid      )
        ,.app_tail_ptr_tx_wr_req_data           (app_tail_ptr_tx_wr_req_data        )
                                                                                    
        ,.app_tail_ptr_tx_rd_req1_flowid        (app_tail_ptr_tx_rd_req1_flowid     )
                                                                                    
        ,.tail_ptr_app_tx_rd_resp1_data         (tail_ptr_app_tx_rd_resp1_data      )
                                                                                    
        ,.app_head_ptr_tx_rd_req0_flowid        (app_head_ptr_tx_rd_req0_flowid     )
                                                                                    
        ,.head_ptr_app_tx_rd_resp0_data         (head_ptr_app_tx_rd_resp0_data      )
                                                                                    
        ,.app_rx_head_ptr_wr_req_addr           (app_rx_head_ptr_wr_req_addr        )
        ,.app_rx_head_ptr_wr_req_data           (app_rx_head_ptr_wr_req_data        )
                                                                                    
        ,.app_rx_head_ptr_rd_req_addr           (app_rx_head_ptr_rd_req_addr        )
                                                                                    
        ,.rx_head_ptr_app_rd_resp_data          (rx_head_ptr_app_rd_resp_data       )
                                                                                    
        ,.app_rx_commit_ptr_rd_req_addr         (app_rx_commit_ptr_rd_req_addr      )
                                                                                    
        ,.rx_commit_ptr_app_rd_resp_data        (rx_commit_ptr_app_rd_resp_data     )
                                                                                    
        ,.flow_fifo_datapath_flowid             (flow_fifo_datapath_flowid          )
        ,.datapath_requeue_flowid               (datapath_requeue_flowid            )
                                                                                    
        ,.datapath_wr_buf_req_flowid            (datapath_wr_buf_req_flowid         )
        ,.datapath_wr_buf_req_wr_ptr            (datapath_wr_buf_req_wr_ptr         )
        ,.datapath_wr_buf_req_size              (datapath_wr_buf_req_size           )
                                                                                    
        ,.datapath_wr_buf_req_data              (datapath_wr_buf_req_data           )
        ,.datapath_wr_buf_req_data_last         (datapath_wr_buf_req_data_last      )
        ,.datapath_wr_buf_req_data_padbytes     (datapath_wr_buf_req_data_padbytes  )
                                                                                    
        ,.datapath_rd_buf_req_flowid            (datapath_rd_buf_req_flowid         )
        ,.datapath_rd_buf_req_offset            (datapath_rd_buf_req_offset         )
        ,.datapath_rd_buf_req_size              (datapath_rd_buf_req_size           )
                                                                                    
        ,.rd_buf_datapath_resp_data             (rd_buf_datapath_resp_data          )
        ,.rd_buf_datapath_resp_data_last        (rd_buf_datapath_resp_data_last     )
        ,.rd_buf_datapath_resp_data_padbytes    (rd_buf_datapath_resp_data_padbytes )
                                                                                    
        ,.store_curr_flowid                     (store_curr_flowid                  )
        ,.store_rx_ptrs                         (store_rx_ptrs                      )
        ,.store_tx_ptrs                         (store_tx_ptrs                      )
        ,.store_req_hdr                         (store_req_hdr                      )
        ,.ctrl_datap_decr_bytes_left            (ctrl_datap_decr_bytes_left         )
                                                                                    
        ,.datap_ctrl_hdr_arrived                (datap_ctrl_hdr_arrived             )
        ,.datap_ctrl_rd_sat                     (datap_ctrl_rd_sat                  )
        ,.datap_ctrl_wr_sat                     (datap_ctrl_wr_sat                  )
        ,.datap_ctrl_last_wr                    (datap_ctrl_last_wr                 )
    );



    /*********************************************************************
     * Buffer helper modules
     ********************************************************************/

    wr_circ_buf #(
         .BUF_PTR_W     (`PAYLOAD_PTR_W )
        ,.SRC_X         (2)
        ,.SRC_Y         (0)
        ,.DST_DRAM_X    (1)
        ,.DST_DRAM_Y    (0)
    ) wr_to_tx_mem (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.wr_buf_noc_req_noc0_val   (tx_app_noc0_vrtoc_val      )
        ,.wr_buf_noc_req_noc0_data  (tx_app_noc0_vrtoc_data     )
        ,.noc_wr_buf_req_noc0_rdy   (noc0_vrtoc_tx_app_rdy      )

        ,.noc_wr_buf_resp_noc0_val  (noc0_ctovr_tx_app_val      )
        ,.noc_wr_buf_resp_noc0_data (noc0_ctovr_tx_app_data     )
        ,.wr_buf_noc_resp_noc0_rdy  (tx_app_noc0_ctovr_rdy      )

        ,.src_wr_buf_req_val        (ctrl_wr_buf_req_val        )
        ,.src_wr_buf_req_flowid     (datapath_wr_buf_req_flowid )
        ,.src_wr_buf_req_wr_ptr     (datapath_wr_buf_req_wr_ptr[`PAYLOAD_PTR_W-1:0] )
        ,.src_wr_buf_req_size       (datapath_wr_buf_req_size   )
        ,.wr_buf_src_req_rdy        (wr_buf_ctrl_req_rdy        )

        ,.src_wr_buf_req_data_val   (ctrl_wr_buf_req_data_val   )
        ,.src_wr_buf_req_data       (datapath_wr_buf_req_data   )
        ,.wr_buf_src_req_data_rdy   (wr_buf_ctrl_req_data_rdy   )

        ,.wr_buf_src_req_done       (wr_buf_ctrl_req_done       )
        ,.src_wr_buf_done_rdy       (ctrl_wr_buf_done_rdy       )
    );

    
    rd_circ_buf #(
         .BUF_PTR_W     (`RX_PAYLOAD_PTR_W  )
        ,.SRC_X         (2)
        ,.SRC_Y         (1)
        ,.DST_DRAM_X    (1)
        ,.DST_DRAM_Y    (1)
    ) rd_from_rx_mem (
         .clk    (clk    )
        ,.rst    (rst    )

        ,.rd_buf_noc0_val           (rx_app_noc0_vrtoc_val              )
        ,.rd_buf_noc0_data          (rx_app_noc0_vrtoc_data             )
        ,.noc0_rd_buf_rdy           (noc0_vrtoc_tx_app_rdy              )

        ,.noc0_rd_buf_val           (noc0_ctovr_rx_app_val              )
        ,.noc0_rd_buf_data          (noc0_ctovr_rx_app_data             )
        ,.rd_buf_noc0_rdy           (rx_app_noc0_ctovr_rdy              )

        ,.src_rd_buf_req_val        (ctrl_rd_buf_req_val                )
        ,.src_rd_buf_req_flowid     (datapath_rd_buf_req_flowid         )
        ,.src_rd_buf_req_offset     (datapath_rd_buf_req_offset[`RX_PAYLOAD_PTR_W-1:0])
        ,.src_rd_buf_req_size       (datapath_rd_buf_req_size           )
        ,.rd_buf_src_req_rdy        (rd_buf_ctrl_req_rdy                )

        ,.rd_buf_src_data_val       (rd_buf_ctrl_resp_data_val          )
        ,.rd_buf_src_data           (rd_buf_datapath_resp_data          )
        ,.rd_buf_src_data_last      (rd_buf_datapath_resp_data_last     )
        ,.rd_buf_src_data_padbytes  (rd_buf_datapath_resp_data_padbytes )
        ,.src_rd_buf_data_rdy       (ctrl_rd_buf_resp_data_rdy          )
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
            new_flow_notif_val_reg <= new_flow_notif_val;
            new_flow_flow_id_reg <= new_flow_flow_id;
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
