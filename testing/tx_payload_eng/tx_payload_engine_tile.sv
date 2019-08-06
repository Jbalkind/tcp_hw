module tx_rd_mem_eng_tile #(
     parameter SRC_X = 0
    ,parameter SRC_Y = 0
    ,parameter DST_DRAM_X = 0
    ,parameter DST_DRAM_Y = 0
) (
     input clk
    ,input rst
    
    ,input [`NOC_DATA_WIDTH-1:0]                src_rd_mem_eng_tile_noc0_data_N 
    ,input [`NOC_DATA_WIDTH-1:0]                src_rd_mem_eng_tile_noc0_data_E 
    ,input [`NOC_DATA_WIDTH-1:0]                src_rd_mem_eng_tile_noc0_data_S 
    ,input [`NOC_DATA_WIDTH-1:0]                src_rd_mem_eng_tile_noc0_data_W 

    ,input                                      src_rd_mem_eng_tile_noc0_val_N  
    ,input                                      src_rd_mem_eng_tile_noc0_val_E  
    ,input                                      src_rd_mem_eng_tile_noc0_val_S  
    ,input                                      src_rd_mem_eng_tile_noc0_val_W  
                                                                         
    ,output                                     rd_mem_eng_tile_src_noc0_yummy_N
    ,output                                     rd_mem_eng_tile_src_noc0_yummy_E
    ,output                                     rd_mem_eng_tile_src_noc0_yummy_S
    ,output                                     rd_mem_eng_tile_src_noc0_yummy_W
                                                                         
    ,output [`NOC_DATA_WIDTH-1:0]               rd_mem_eng_tile_dst_noc0_data_N 
    ,output [`NOC_DATA_WIDTH-1:0]               rd_mem_eng_tile_dst_noc0_data_E 
    ,output [`NOC_DATA_WIDTH-1:0]               rd_mem_eng_tile_dst_noc0_data_S 
    ,output [`NOC_DATA_WIDTH-1:0]               rd_mem_eng_tile_dst_noc0_data_W 

    ,output                                     rd_mem_eng_tile_dst_noc0_val_N  
    ,output                                     rd_mem_eng_tile_dst_noc0_val_E  
    ,output                                     rd_mem_eng_tile_dst_noc0_val_S  
    ,output                                     rd_mem_eng_tile_dst_noc0_val_W  
                                                                         
    ,input                                      dst_rd_mem_eng_tile_noc0_yummy_N
    ,input                                      dst_rd_mem_eng_tile_noc0_yummy_E
    ,input                                      dst_rd_mem_eng_tile_noc0_yummy_S
    ,input                                      dst_rd_mem_eng_tile_noc0_yummy_W
    
    ,input                                      src_rd_mem_tx_req_val
    ,input          [`FLOW_ID_W-1:0]            src_rd_mem_tx_req_flowid
    ,input          [`PAYLOAD_PTR_W-1:0]        src_rd_mem_tx_req_offset
    ,input          [`MSG_DATA_SIZE_WIDTH-1:0]  src_rd_mem_tx_req_size
    ,output logic                               rd_mem_src_tx_req_rdy

    ,output logic                               rd_mem_dst_tx_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      rd_mem_dst_tx_data
    ,output logic                               rd_mem_dst_tx_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]       rd_mem_dst_tx_data_padbytes
    ,input                                      dst_rd_mem_tx_data_rdy
);
    logic                           rd_mem_eng_noc0_vrtoc_val;
    logic   [`NOC_DATA_WIDTH-1:0]   rd_mem_eng_noc0_vrtoc_data;    
    logic                           noc0_vrtoc_rd_mem_eng_rdy;
    
    logic                           noc0_ctovr_rd_mem_eng_val;
    logic   [`NOC_DATA_WIDTH-1:0]   noc0_ctovr_rd_mem_eng_data;
    logic                           rd_mem_eng_noc0_ctovr_rdy;     

    logic                           noc0_vrtoc_router_val;
    logic   [`NOC_DATA_WIDTH-1:0]   noc0_vrtoc_router_data;
    logic                           router_noc0_vrtoc_yummy;

    logic                           router_noc0_ctovr_val;
    logic   [`NOC_DATA_WIDTH-1:0]   router_noc0_ctovr_data;
    logic                           noc0_ctovr_router_yummy;
    
    dynamic_node_top_wrap noc0_router(

         .clk                   (clk)
        ,.reset_in              (rst)
        
        ,.src_router_data_N     (src_rd_mem_eng_tile_noc0_data_N    )
        ,.src_router_data_E     (src_rd_mem_eng_tile_noc0_data_E    )
        ,.src_router_data_S     (src_rd_mem_eng_tile_noc0_data_S    )
        ,.src_router_data_W     (src_rd_mem_eng_tile_noc0_data_W    )
        ,.src_router_data_P     (noc0_vrtoc_router_data             )
                                
        ,.src_router_val_N      (src_rd_mem_eng_tile_noc0_val_N     )
        ,.src_router_val_E      (src_rd_mem_eng_tile_noc0_val_E     )
        ,.src_router_val_S      (src_rd_mem_eng_tile_noc0_val_S     )
        ,.src_router_val_W      (src_rd_mem_eng_tile_noc0_val_W     )
        ,.src_router_val_P      (noc0_vrtoc_router_val              )
                                
        ,.router_src_yummy_N    (rd_mem_eng_tile_src_noc0_yummy_N   )
        ,.router_src_yummy_E    (rd_mem_eng_tile_src_noc0_yummy_E   )
        ,.router_src_yummy_S    (rd_mem_eng_tile_src_noc0_yummy_S   )
        ,.router_src_yummy_W    (rd_mem_eng_tile_src_noc0_yummy_W   )
        ,.router_src_yummy_P    (router_noc0_vrtoc_yummy            )
        
        ,.myLocX                (SRC_X[`XY_WIDTH-1:0])  
        ,.myLocY                (SRC_Y[`XY_WIDTH-1:0])
        ,.myChipID              (`CHIP_ID_WIDTH'd0)

        ,.router_dst_data_N     (rd_mem_eng_tile_dst_noc0_data_N    )
        ,.router_dst_data_E     (rd_mem_eng_tile_dst_noc0_data_E    )
        ,.router_dst_data_S     (rd_mem_eng_tile_dst_noc0_data_S    )
        ,.router_dst_data_W     (rd_mem_eng_tile_dst_noc0_data_W    )
        ,.router_dst_data_P     (router_noc0_ctovr_data             )
                            
        ,.router_dst_val_N      (rd_mem_eng_tile_dst_noc0_val_N     )
        ,.router_dst_val_E      (rd_mem_eng_tile_dst_noc0_val_E     )
        ,.router_dst_val_S      (rd_mem_eng_tile_dst_noc0_val_S     )
        ,.router_dst_val_W      (rd_mem_eng_tile_dst_noc0_val_W     )
        ,.router_dst_val_P      (router_noc0_ctovr_val              )
                            
        ,.dst_router_yummy_N    (dst_rd_mem_eng_tile_noc0_yummy_N   )
        ,.dst_router_yummy_E    (dst_rd_mem_eng_tile_noc0_yummy_E   )
        ,.dst_router_yummy_S    (dst_rd_mem_eng_tile_noc0_yummy_S   )
        ,.dst_router_yummy_W    (dst_rd_mem_eng_tile_noc0_yummy_W   )
        ,.dst_router_yummy_P    (noc0_ctovr_router_yummy            )
        
        
        ,.router_src_thanks_P   ()  

    );

    credit_to_valrdy noc0_credit_to_valrdy (
         .clk   (clk)
        ,.reset (rst)
        //credit based interface 
        ,.src_ctovr_data    (router_noc0_ctovr_data     )
        ,.src_ctovr_val     (router_noc0_ctovr_val      )
        ,.ctovr_src_yummy   (noc0_ctovr_router_yummy    )

        //val/rdy interface
        ,.ctovr_dst_data    (noc0_ctovr_rd_mem_eng_data )
        ,.ctovr_dst_val     (noc0_ctovr_rd_mem_eng_val  )
        ,.dst_ctovr_rdy     (rd_mem_eng_noc0_ctovr_rdy  )
    );

    valrdy_to_credit noc0_valrdy_to_credit (
         .clk       (clk)
        ,.reset     (rst)

        //val/rdy interface
        ,.src_vrtoc_data    (rd_mem_eng_noc0_vrtoc_data )
        ,.src_vrtoc_val     (rd_mem_eng_noc0_vrtoc_val  )
        ,.vrtoc_src_rdy     (noc0_vrtoc_rd_mem_eng_rdy  )

		//credit based interface	
        ,.vrtoc_dst_data    (noc0_vrtoc_router_data     )
        ,.vrtoc_dst_val     (noc0_vrtoc_router_val      )
		,.dst_vrtoc_yummy   (router_noc0_vrtoc_yummy    )
    );

    tx_rd_mem_wrap #(
         .SRC_X      (SRC_X      )
        ,.SRC_Y      (SRC_Y      )
        ,.DST_DRAM_X (DST_DRAM_X )
        ,.DST_DRAM_Y (DST_DRAM_Y )

    ) rd_mem_engine (
         .clk   (clk)
        ,.rst   (rst)

        ,.tx_payload_noc0_val           (rd_mem_eng_noc0_vrtoc_val  )
        ,.tx_payload_noc0_data          (rd_mem_eng_noc0_vrtoc_data )
        ,.noc0_tx_payload_rdy           (noc0_vrtoc_rd_mem_eng_rdy  )

        ,.noc0_tx_payload_val           (noc0_ctovr_rd_mem_eng_val  )
        ,.noc0_tx_payload_data          (noc0_ctovr_rd_mem_eng_data )
        ,.tx_payload_noc0_rdy           (rd_mem_eng_noc0_ctovr_rdy  )

        ,.src_rd_mem_tx_req_val         (src_rd_mem_tx_req_val      )
        ,.src_rd_mem_tx_req_flowid      (src_rd_mem_tx_req_flowid   )
        ,.src_rd_mem_tx_req_offset      (src_rd_mem_tx_req_offset   )
        ,.src_rd_mem_tx_req_size        (src_rd_mem_tx_req_size     )
        ,.rd_mem_src_tx_req_rdy         (rd_mem_src_tx_req_rdy      )
                                                                    
        ,.rd_mem_dst_tx_data_val        (rd_mem_dst_tx_data_val     )
        ,.rd_mem_dst_tx_data            (rd_mem_dst_tx_data         )
        ,.rd_mem_dst_tx_data_last       (rd_mem_dst_tx_data_last    )
        ,.rd_mem_dst_tx_data_padbytes   (rd_mem_dst_tx_data_padbytes)
        ,.dst_rd_mem_tx_data_rdy        (dst_rd_mem_tx_data_rdy     )
    );

endmodule
