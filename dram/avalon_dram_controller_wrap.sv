`include "soc_defs.vh"
`include "noc_defs.vh"
`include "packet_defs.vh"
`include "state_defs.vh"

import noc_struct_pkg::*;
module avalon_dram_controller_wrap #(
     parameter mem_addr_w_p = -1
    ,parameter mem_data_w_p = -1
    ,parameter mem_wr_mask_w_p = mem_data_w_p >> 3
    ,parameter SRC_X = 0
    ,parameter SRC_Y = 0
)(
     input clk
    ,input rst

    ,input                                      noc0_ctovr_controller_val
    ,input          [`NOC_DATA_WIDTH-1:0]       noc0_ctovr_controller_data
    ,output logic                               controller_noc0_ctovr_rdy

    ,output logic                               controller_noc0_vrtoc_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       controller_noc0_vrtoc_data
    ,input                                      noc0_vrtoc_controller_rdy

    ,output logic                               controller_mem_read_en
    ,output logic                               controller_mem_write_en
    ,output logic   [mem_addr_w_p-1:0]          controller_mem_addr
    ,output logic   [mem_data_w_p-1:0]          controller_mem_wr_data
    ,output logic   [mem_wr_mask_w_p-1:0]       controller_mem_byte_en
    ,output logic   [7-1:0]                     controller_mem_burst_cnt
    ,input                                      mem_controller_rdy

    ,input                                      mem_controller_rd_data_val
    ,input          [mem_data_w_p-1:0]          mem_controller_rd_data
);
    
    localparam WR_DRAIN_SRC = 2'd2;
    localparam WR_FIRST_SRC = 2'd1;
    localparam WR_COPY_SRC = 2'd0;
    localparam METADATA_SEL_FULL = 1'd0;
    localparam METADATA_SEL_PART = 1'd1;

    logic                               ctrl_datap_store_hdr_flit;
    logic                               ctrl_datap_init_metadata;
    logic                               ctrl_datap_update_metadata;
    logic                               ctrl_datap_update_metadata_sel;
    logic                               ctrl_datap_send_hdr_flit;
    logic                               ctrl_datap_incr_recv_flits;
    logic                               ctrl_datap_incr_sent_flits;
    logic                               ctrl_datap_store_rd_data;
    logic                               ctrl_datap_store_save1;
    logic   [1:0]                       ctrl_datap_sel_store_src;
    logic                               ctrl_datap_store_msg_len;

    logic   [`MSG_TYPE_WIDTH-1:0]       datap_ctrl_msg_type;
    logic                               datap_ctrl_first_rd;
    logic                               datap_ctrl_last_req_flit;
    logic                               datap_ctrl_last_resp_flit;
    logic                               datap_ctrl_read_new_line;
    logic                               datap_ctrl_last_mem_write;

    avalon_dram_controller_ctrl #(
         .WR_DRAIN_SRC      (WR_DRAIN_SRC       )
        ,.WR_FIRST_SRC      (WR_FIRST_SRC       )
        ,.WR_COPY_SRC       (WR_COPY_SRC        )
        ,.METADATA_SEL_FULL (METADATA_SEL_FULL  )
        ,.METADATA_SEL_PART (METADATA_SEL_PART  )
    ) ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.noc0_ctovr_controller_val         (noc0_ctovr_controller_val      )
        ,.controller_noc0_ctovr_rdy         (controller_noc0_ctovr_rdy      )
                                                                       
        ,.controller_noc0_vrtoc_val         (controller_noc0_vrtoc_val      )
        ,.noc0_vrtoc_controller_rdy         (noc0_vrtoc_controller_rdy      )
                                                                       
        ,.controller_mem_read_en            (controller_mem_read_en         )
        ,.controller_mem_write_en           (controller_mem_write_en        )
        ,.mem_controller_rdy                (mem_controller_rdy             )
                                                                       
        ,.mem_controller_rd_data_val        (mem_controller_rd_data_val     )

        ,.ctrl_datap_store_hdr_flit         (ctrl_datap_store_hdr_flit      )
        ,.ctrl_datap_init_metadata          (ctrl_datap_init_metadata       )
        ,.ctrl_datap_update_metadata        (ctrl_datap_update_metadata     )
        ,.ctrl_datap_update_metadata_sel    (ctrl_datap_update_metadata_sel )
        ,.ctrl_datap_send_hdr_flit          (ctrl_datap_send_hdr_flit       )
        ,.ctrl_datap_incr_recv_flits        (ctrl_datap_incr_recv_flits     )
        ,.ctrl_datap_incr_sent_flits        (ctrl_datap_incr_sent_flits     )
        ,.ctrl_datap_store_rd_data          (ctrl_datap_store_rd_data       )
        ,.ctrl_datap_store_save1            (ctrl_datap_store_save1         )
        ,.ctrl_datap_sel_store_src          (ctrl_datap_sel_store_src       )
        ,.ctrl_datap_store_msg_len          (ctrl_datap_store_msg_len       )
                                                                            
        ,.datap_ctrl_msg_type               (datap_ctrl_msg_type            )
        ,.datap_ctrl_first_rd               (datap_ctrl_first_rd            )
        ,.datap_ctrl_last_req_flit          (datap_ctrl_last_req_flit       )
        ,.datap_ctrl_last_resp_flit         (datap_ctrl_last_resp_flit      )
        ,.datap_ctrl_read_new_line          (datap_ctrl_read_new_line       )
        ,.datap_ctrl_last_mem_write         (datap_ctrl_last_mem_write      )
    );

    avalon_dram_controller_datap #(
         .mem_addr_w_p      (mem_addr_w_p       )
        ,.mem_data_w_p      (mem_data_w_p       )
        ,.SRC_X             (SRC_X              )
        ,.SRC_Y             (SRC_Y              )
        ,.WR_DRAIN_SRC      (WR_DRAIN_SRC       )
        ,.WR_FIRST_SRC      (WR_FIRST_SRC       )
        ,.WR_COPY_SRC       (WR_COPY_SRC        )
        ,.METADATA_SEL_FULL (METADATA_SEL_FULL  )
        ,.METADATA_SEL_PART (METADATA_SEL_PART  )
    ) datapath (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.noc0_ctovr_controller_data        (noc0_ctovr_controller_data     )
                                                                            
        ,.controller_noc0_vrtoc_data        (controller_noc0_vrtoc_data     )
                                                                            
        ,.controller_mem_addr               (controller_mem_addr            )
        ,.controller_mem_wr_data            (controller_mem_wr_data         )
        ,.controller_mem_byte_en            (controller_mem_byte_en         )
        ,.controller_mem_burst_cnt          (controller_mem_burst_cnt       )
                                                                            
        ,.mem_controller_rd_data            (mem_controller_rd_data         )
                                                                            
        ,.ctrl_datap_store_hdr_flit         (ctrl_datap_store_hdr_flit      )
        ,.ctrl_datap_init_metadata          (ctrl_datap_init_metadata       )
        ,.ctrl_datap_update_metadata        (ctrl_datap_update_metadata     )
        ,.ctrl_datap_update_metadata_sel    (ctrl_datap_update_metadata_sel )
        ,.ctrl_datap_send_hdr_flit          (ctrl_datap_send_hdr_flit       )
        ,.ctrl_datap_incr_recv_flits        (ctrl_datap_incr_recv_flits     )
        ,.ctrl_datap_incr_sent_flits        (ctrl_datap_incr_sent_flits     )
        ,.ctrl_datap_store_rd_data          (ctrl_datap_store_rd_data       )
        ,.ctrl_datap_store_save1            (ctrl_datap_store_save1         )
        ,.ctrl_datap_sel_store_src          (ctrl_datap_sel_store_src       )
        ,.ctrl_datap_store_msg_len          (ctrl_datap_store_msg_len       )
                                                                            
        ,.datap_ctrl_msg_type               (datap_ctrl_msg_type            )
        ,.datap_ctrl_first_rd               (datap_ctrl_first_rd            )
        ,.datap_ctrl_last_req_flit          (datap_ctrl_last_req_flit       )
        ,.datap_ctrl_last_resp_flit         (datap_ctrl_last_resp_flit      )
        ,.datap_ctrl_read_new_line          (datap_ctrl_read_new_line       )
        ,.datap_ctrl_last_mem_write         (datap_ctrl_last_mem_write      )
    );

endmodule
