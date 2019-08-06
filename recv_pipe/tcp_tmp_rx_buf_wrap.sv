`include "packet_defs.vh"

module tcp_tmp_rx_buf_wrap 
import tcp_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst
    
    // Write req inputs
    ,input                                      src_tmp_buf_rx_hdr_val
    ,output logic                               tmp_buf_src_rx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]            src_tmp_buf_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]            src_tmp_buf_rx_dst_ip
    ,input          [`TOT_LEN_W-1:0]            src_tmp_buf_rx_tcp_payload_len
    ,input  tcp_pkt_hdr                         src_tmp_buf_rx_tcp_hdr
    
    ,input                                      src_tmp_buf_rx_data_val
    ,input          [`MAC_INTERFACE_W-1:0]      src_tmp_buf_rx_data
    ,input                                      src_tmp_buf_rx_data_last
    ,input          [`MAC_PADBYTES_W-1:0]       src_tmp_buf_rx_data_padbytes
    ,output logic                               tmp_buf_src_rx_data_rdy
    
    // Write resp
    ,output logic                               tmp_buf_dst_rx_hdr_val
    ,input                                      dst_tmp_buf_rx_rdy
    ,output logic   [`IP_ADDR_W-1:0]            tmp_buf_dst_rx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]            tmp_buf_dst_rx_dst_ip
    ,output tcp_pkt_hdr                         tmp_buf_dst_rx_tcp_hdr

    ,output logic                               tmp_buf_dst_rx_payload_val
    ,output payload_buf_struct                  tmp_buf_dst_rx_payload_entry

    ,input  logic                               src_tmp_buf_store_rd_req_val
    ,input  logic   [PAYLOAD_ENTRY_ADDR_W-1:0]  src_tmp_buf_store_rd_req_addr
    ,output logic                               tmp_buf_store_src_rd_req_rdy

    ,output logic                               tmp_buf_store_src_rd_resp_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      tmp_buf_store_src_rd_resp_data
    ,input  logic                               src_tmp_buf_store_rd_resp_rdy

    ,input  logic                               src_tmp_buf_free_slab_req_val
    ,input  logic   [RX_TMP_BUF_ADDR_W-1:0]     src_tmp_buf_free_slab_req_addr
    ,output logic                               tmp_buf_free_slab_src_req_rdy
);
    
    logic                                   tmp_buf_alloc_slab_consume_val;
    logic   [RX_TMP_BUF_ADDR_W-1:0]         alloc_slab_tmp_buf_resp_addr;
    logic                                   alloc_slab_tmp_buf_resp_error;

    logic                                   tmp_buf_buf_store_val;
    logic   [RX_TMP_BUF_MEM_ADDR_W-1:0]     tmp_buf_buf_store_addr;
    logic   [`MAC_INTERFACE_W-1:0]          tmp_buf_buf_store_data;
    logic                                   buf_store_tmp_buf_rdy;
    
    logic                                   load_hdr_state;
    logic                                   store_entry_addr;
    logic                                   incr_store_addr;

    payload_buf_struct   output_payload_entry;
    assign output_payload_entry = tmp_buf_dst_rx_payload_entry;

    assign tmp_buf_dst_rx_payload_val = tmp_buf_dst_rx_hdr_val & (output_payload_entry.payload_len != '0);



   tcp_tmp_rx_buf_ctrl ctrl (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_tmp_buf_rx_hdr_val                    (src_tmp_buf_rx_hdr_val         )
        ,.tmp_buf_src_rx_hdr_rdy                    (tmp_buf_src_rx_hdr_rdy         )
        ,.src_tmp_buf_rx_tcp_payload_len            (src_tmp_buf_rx_tcp_payload_len )

        ,.src_tmp_buf_rx_data_val                   (src_tmp_buf_rx_data_val        )
        ,.tmp_buf_src_rx_data_rdy                   (tmp_buf_src_rx_data_rdy        )

        ,.tmp_buf_dst_rx_hdr_val                    (tmp_buf_dst_rx_hdr_val         )
        ,.dst_tmp_buf_rx_rdy                        (dst_tmp_buf_rx_rdy             )

        ,.tmp_buf_alloc_slab_consume_val            (tmp_buf_alloc_slab_consume_val )
        ,.alloc_slab_tmp_buf_resp_error             (alloc_slab_tmp_buf_resp_error  )
                                                                                              
        ,.tmp_buf_buf_store_val                     (tmp_buf_buf_store_val          )
        ,.buf_store_tmp_buf_rdy                     (buf_store_tmp_buf_rdy          )
                                                                                              
        ,.load_hdr_state                            (load_hdr_state                 )
        ,.store_entry_addr                          (store_entry_addr               )
        ,.incr_store_addr                           (incr_store_addr                )
    );

    tcp_tmp_rx_buf_datapath datapath (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_tmp_buf_rx_src_ip             (src_tmp_buf_rx_src_ip          )
        ,.src_tmp_buf_rx_dst_ip             (src_tmp_buf_rx_dst_ip          )
        ,.src_tmp_buf_rx_tcp_payload_len    (src_tmp_buf_rx_tcp_payload_len )
        ,.src_tmp_buf_rx_tcp_hdr            (src_tmp_buf_rx_tcp_hdr         )

        ,.src_tmp_buf_rx_data               (src_tmp_buf_rx_data            )
        ,.src_tmp_buf_rx_data_last          (src_tmp_buf_rx_data_last       )
        ,.src_tmp_buf_rx_data_padbytes      (src_tmp_buf_rx_data_padbytes   )
                                                                         
        ,.load_hdr_state                    (load_hdr_state                 )
        ,.store_entry_addr                  (store_entry_addr               )
        ,.incr_store_addr                   (incr_store_addr                )

        ,.alloc_slab_tmp_buf_resp_addr      (alloc_slab_tmp_buf_resp_addr   )
                                                                          
        ,.tmp_buf_buf_store_addr            (tmp_buf_buf_store_addr         )
        ,.tmp_buf_buf_store_data            (tmp_buf_buf_store_data         )
                                                                          
                                                                          
        ,.tmp_buf_dst_rx_src_ip             (tmp_buf_dst_rx_src_ip          )
        ,.tmp_buf_dst_rx_dst_ip             (tmp_buf_dst_rx_dst_ip          )
        ,.tmp_buf_dst_rx_tcp_hdr            (tmp_buf_dst_rx_tcp_hdr         )
                                                                          
        ,.tmp_buf_dst_rx_payload_entry      (tmp_buf_dst_rx_payload_entry   )
    );

    slab_alloc_tracker #(
         .NUM_SLABS     (RX_TMP_BUF_NUM_SLABS   )
        ,.SLAB_BYTES    (RX_TMP_BUF_SLAB_BYTES  )
    ) rx_buf_alloc (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_free_slab_req_val         (src_tmp_buf_free_slab_req_val  )
        ,.src_free_slab_req_addr        (src_tmp_buf_free_slab_req_addr )
        ,.free_slab_src_req_rdy         (tmp_buf_free_slab_src_req_rdy  )

        ,.src_alloc_slab_consume_val    (tmp_buf_alloc_slab_consume_val )

        ,.alloc_slab_src_resp_error     (alloc_slab_tmp_buf_resp_error  )
        ,.alloc_slab_src_resp_addr      (alloc_slab_tmp_buf_resp_addr   )
    );

    ram_1r1w_sync_backpressure #(
         .width_p   (`MAC_INTERFACE_W   )
        ,.els_p     (RX_TMP_BUF_MEM_ELS )
    ) rx_tmp_buf_ram (
         .clk   (clk)
        ,.rst   (rst)
    
        ,.wr_req_val    (tmp_buf_buf_store_val          )
        ,.wr_req_addr   (tmp_buf_buf_store_addr         )
        ,.wr_req_data   (tmp_buf_buf_store_data         )
        ,.wr_req_rdy    (buf_store_tmp_buf_rdy          )

        ,.rd_req_val    (src_tmp_buf_store_rd_req_val   )
        ,.rd_req_addr   (src_tmp_buf_store_rd_req_addr[RX_TMP_BUF_MEM_ADDR_W-1:0])
        ,.rd_req_rdy    (tmp_buf_store_src_rd_req_rdy   )

        ,.rd_resp_val   (tmp_buf_store_src_rd_resp_val  )
        ,.rd_resp_data  (tmp_buf_store_src_rd_resp_data )
        ,.rd_resp_rdy   (src_tmp_buf_store_rd_resp_rdy  )  
    );

endmodule
