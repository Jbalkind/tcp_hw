`include "noc_defs.vh"
module rx_payload_store_buf_cp 
import tcp_pkg::*;
#(
     parameter SRC_X = 0
    ,parameter SRC_Y = 0
    ,parameter RX_DRAM_X = 0
    ,parameter RX_DRAM_Y = 0
    ,parameter FBITS = 0
)(
     input clk
    ,input rst
    
    // I/O for the NoC
    ,output logic                                   rx_payload_noc0_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]           rx_payload_noc0_data
    ,input                                          noc0_rx_payload_rdy
    
    ,input                                          noc_rx_payload_val
    ,input          [`NOC_DATA_WIDTH-1:0]           noc_rx_payload_data
    ,output logic                                   rx_payload_noc_rdy
    
    // For reading out a packet from the queue
    ,output logic                                   read_store_buf_q_req_val
    ,input  rx_store_buf_q_struct                   read_store_buf_q_req_data
    ,input  logic                                   read_store_buf_q_empty

    // for getting stuff from the temp buffer
    ,output logic                                   store_buf_tmp_buf_store_rx_rd_req_val
    ,output logic   [PAYLOAD_ENTRY_ADDR_W-1:0]      store_buf_tmp_buf_store_rx_rd_req_addr
    ,input  logic                                   tmp_buf_store_store_buf_rx_rd_req_rdy

    ,input  logic                                   tmp_buf_store_store_buf_rx_rd_resp_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]          tmp_buf_store_store_buf_rx_rd_resp_data
    ,output logic                                   store_buf_tmp_buf_store_rx_rd_resp_rdy

    ,output logic                                   store_buf_tmp_buf_free_slab_rx_req_val
    ,output logic   [RX_TMP_BUF_ADDR_W-1:0]         store_buf_tmp_buf_free_slab_rx_req_addr
    ,input  logic                                   tmp_buf_free_slab_store_buf_rx_req_rdy

    ,output logic                                   store_buf_commit_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]                  store_buf_commit_ptr_rd_req_flowid
    ,input  logic                                   commit_ptr_store_buf_rd_req_rdy
                                                                            
    ,input  logic                                   commit_ptr_store_buf_rd_resp_val
    ,input  logic   [RX_PAYLOAD_PTR_W:0]            commit_ptr_store_buf_rd_resp_data
    ,output logic                                   store_buf_commit_ptr_rd_resp_rdy
    
    ,output logic                                   store_buf_commit_ptr_wr_req_val
    ,output logic   [FLOWID_W-1:0]                  store_buf_commit_ptr_wr_req_flowid
    ,output logic   [RX_PAYLOAD_PTR_W:0]            store_buf_commit_ptr_wr_req_data
    ,input  logic                                   commit_ptr_store_buf_wr_req_rdy
);
    
    logic                                   ctrl_wr_buf_req_val;
    logic                                   wr_buf_ctrl_req_rdy;

    logic                                   ctrl_wr_buf_req_data_val;
    logic                                   wr_buf_ctrl_req_data_rdy;

    logic                                   wr_buf_ctrl_wr_req_done;
    logic                                   ctrl_wr_buf_wr_req_done_rdy;

    logic                                   save_q_entry;
    logic                                   save_commit_ptr;
    logic                                   init_tmp_buf_rd_metadata;
    logic                                   update_tmp_buf_rd_metadata;

    logic                                   last_transfer;
    logic                                   accept_payload;
    logic                                   pkt_len_0;
    
    logic   [FLOWID_W-1:0]                  datapath_wr_buf_req_flowid;
    logic   [RX_PAYLOAD_PTR_W-1:0]          datapath_wr_buf_req_wr_ptr;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]      datapath_wr_buf_req_size;
    
    logic   [`NOC_DATA_WIDTH-1:0]           datapath_wr_buf_req_data;
    
    logic                                   store_buf_fifo_wr_val;
    logic   [`NOC_DATA_WIDTH-1:0]           store_buf_fifo_wr_data;
    logic                                   fifo_store_buf_wr_rdy;

    logic                                   fifo_wr_buf_rd_val;
    logic   [`NOC_DATA_WIDTH-1:0]           fifo_wr_buf_rd_data;
    logic                                   wr_buf_fifo_rd_rdy;
    logic                                   wr_buf_fifo_rd_yumi;


    rx_payload_store_buf_cp_ctrl ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.read_store_buf_q_req_val                  (read_store_buf_q_req_val               )
        ,.read_store_buf_q_empty                    (read_store_buf_q_empty                 )

        ,.store_buf_tmp_buf_store_rx_rd_req_val     (store_buf_tmp_buf_store_rx_rd_req_val  )
        ,.tmp_buf_store_store_buf_rx_rd_req_rdy     (tmp_buf_store_store_buf_rx_rd_req_rdy  )

        ,.tmp_buf_store_store_buf_rx_rd_resp_val    (tmp_buf_store_store_buf_rx_rd_resp_val )
        ,.store_buf_tmp_buf_store_rx_rd_resp_rdy    (store_buf_tmp_buf_store_rx_rd_resp_rdy )

        ,.store_buf_tmp_buf_free_slab_rx_req_val    (store_buf_tmp_buf_free_slab_rx_req_val )
        ,.tmp_buf_free_slab_store_buf_rx_req_rdy    (tmp_buf_free_slab_store_buf_rx_req_rdy )

        ,.store_buf_commit_ptr_rd_req_val           (store_buf_commit_ptr_rd_req_val        )
        ,.commit_ptr_store_buf_rd_req_rdy           (commit_ptr_store_buf_rd_req_rdy        )

        ,.commit_ptr_store_buf_rd_resp_val          (commit_ptr_store_buf_rd_resp_val       )
        ,.store_buf_commit_ptr_rd_resp_rdy          (store_buf_commit_ptr_rd_resp_rdy       )

        ,.store_buf_commit_ptr_wr_req_val           (store_buf_commit_ptr_wr_req_val        )
        ,.commit_ptr_store_buf_wr_req_rdy           (commit_ptr_store_buf_wr_req_rdy        )

        ,.ctrl_wr_buf_req_val                       (ctrl_wr_buf_req_val                    )
        ,.wr_buf_ctrl_req_rdy                       (wr_buf_ctrl_req_rdy                    )
                                                                                
        ,.ctrl_wr_buf_req_data_val                  (store_buf_fifo_wr_val  )
        ,.wr_buf_ctrl_req_data_rdy                  (fifo_store_buf_wr_rdy  )
                                                                                
        ,.wr_buf_ctrl_wr_req_done                   (wr_buf_ctrl_wr_req_done                )
        ,.ctrl_wr_buf_wr_req_done_rdy               (ctrl_wr_buf_wr_req_done_rdy            )
                                                                                
        ,.save_q_entry                              (save_q_entry                           )
        ,.save_commit_ptr                           (save_commit_ptr                        )
        ,.init_tmp_buf_rd_metadata                  (init_tmp_buf_rd_metadata               )
        ,.update_tmp_buf_rd_metadata                (update_tmp_buf_rd_metadata             )
                                                                                
        ,.last_transfer                             (last_transfer                          )
        ,.accept_payload                            (accept_payload                         )
        ,.pkt_len_0                                 (pkt_len_0                              )
    );

    rx_payload_store_buf_cp_datapath datapath (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.read_store_buf_q_req_data                 (read_store_buf_q_req_data                  )

        ,.store_buf_tmp_buf_store_rx_rd_req_addr    (store_buf_tmp_buf_store_rx_rd_req_addr     )

        ,.tmp_buf_store_store_buf_rx_rd_resp_data   (tmp_buf_store_store_buf_rx_rd_resp_data    )

        ,.store_buf_tmp_buf_free_slab_rx_req_addr   (store_buf_tmp_buf_free_slab_rx_req_addr    )

        ,.store_buf_commit_ptr_rd_req_flowid        (store_buf_commit_ptr_rd_req_flowid         )

        ,.commit_ptr_store_buf_rd_resp_data         (commit_ptr_store_buf_rd_resp_data          )

        ,.store_buf_commit_ptr_wr_req_flowid        (store_buf_commit_ptr_wr_req_flowid         )
        ,.store_buf_commit_ptr_wr_req_data          (store_buf_commit_ptr_wr_req_data           )

        ,.save_q_entry                              (save_q_entry                               )
        ,.save_commit_ptr                           (save_commit_ptr                            )
        ,.init_tmp_buf_rd_metadata                  (init_tmp_buf_rd_metadata                   )
        ,.update_tmp_buf_rd_metadata                (update_tmp_buf_rd_metadata                 )
        ,.last_transfer                             (last_transfer                              )
        ,.accept_payload                            (accept_payload                             )
        ,.pkt_len_0                                 (pkt_len_0                                  )

        ,.datapath_wr_buf_req_flowid                (datapath_wr_buf_req_flowid                 )
        ,.datapath_wr_buf_req_wr_ptr                (datapath_wr_buf_req_wr_ptr                 )
        ,.datapath_wr_buf_req_size                  (datapath_wr_buf_req_size                   )
                                                                               
        ,.datapath_wr_buf_req_data                  (store_buf_fifo_wr_data )
    );

    bsg_fifo_1r1w_small #( 
         .width_p   (`NOC_DATA_WIDTH    )
        ,.els_p     (4                  )
        ,.harden_p  (1                  )
    ) store_buf_fifo ( 
         .clk_i     (clk    )
        ,.reset_i   (rst    )
    
        ,.v_i       (store_buf_fifo_wr_val  )
        ,.data_i    (store_buf_fifo_wr_data )
        ,.ready_o   (fifo_store_buf_wr_rdy  )
    
        ,.v_o       (fifo_wr_buf_rd_val     )
        ,.data_o    (fifo_wr_buf_rd_data    )
        ,.yumi_i    (wr_buf_fifo_rd_yumi    )
    );

    assign wr_buf_fifo_rd_yumi = wr_buf_fifo_rd_rdy & fifo_wr_buf_rd_val;

    wr_circ_buf #(
         .BUF_PTR_W     (RX_PAYLOAD_PTR_W   )
        ,.SRC_X         (SRC_X              )
        ,.SRC_Y         (SRC_Y              )
        ,.DST_DRAM_X    (RX_DRAM_X          )
        ,.DST_DRAM_Y    (RX_DRAM_Y          )
        ,.FBITS         (FBITS              )
    ) store_buf_writer (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.wr_buf_noc_req_noc_val    (rx_payload_noc0_val            )
        ,.wr_buf_noc_req_noc_data   (rx_payload_noc0_data           )
        ,.noc_wr_buf_req_noc_rdy    (noc0_rx_payload_rdy            )

        ,.noc_wr_buf_resp_noc_val   (noc_rx_payload_val             )
        ,.noc_wr_buf_resp_noc_data  (noc_rx_payload_data            )
        ,.wr_buf_noc_resp_noc_rdy   (rx_payload_noc_rdy             )

        ,.src_wr_buf_req_val        (ctrl_wr_buf_req_val            )
        ,.src_wr_buf_req_flowid     (datapath_wr_buf_req_flowid     )
        ,.src_wr_buf_req_wr_ptr     (datapath_wr_buf_req_wr_ptr     )
        ,.src_wr_buf_req_size       (datapath_wr_buf_req_size       )
        ,.wr_buf_src_req_rdy        (wr_buf_ctrl_req_rdy            )

        ,.src_wr_buf_req_data_val   (fifo_wr_buf_rd_val             )
        ,.src_wr_buf_req_data       (fifo_wr_buf_rd_data            )
        ,.wr_buf_src_req_data_rdy   (wr_buf_fifo_rd_rdy             )

        ,.wr_buf_src_req_done       (wr_buf_ctrl_wr_req_done        )
        ,.src_wr_buf_done_rdy       (ctrl_wr_buf_wr_req_done_rdy    )
    );

endmodule
