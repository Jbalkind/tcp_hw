module tester_tile #(
     parameter SRC_X = 0
    ,parameter SRC_Y = 0
    ,parameter DST_DRAM_X = 0
    ,parameter DST_DRAM_Y = 0
) (
     input clk
    ,input rst

    // trace tester's control interface
    ,input                                      trace_tester_tile_wr_mem_req_val
    ,input          [`TRACE_ADDR_W-1:0]         trace_tester_tile_wr_mem_req_addr
    ,input          [`TRACE_SIZE_W-1:0]         trace_tester_tile_wr_mem_req_size
    ,output                                     tester_tile_trace_wr_mem_req_rdy
    
    ,input  logic                               trace_tester_tile_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]      trace_tester_tile_data
    ,input  logic                               trace_tester_tile_data_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]       trace_tester_tile_data_padbytes
    ,output                                     tester_tile_trace_data_rdy

    ,input                                      trace_tester_tile_rd_mem_req_val
    ,input          [`TRACE_ADDR_W-1:0]         trace_tester_tile_rd_mem_req_addr
    ,input          [`TRACE_SIZE_W-1:0]         trace_tester_tile_rd_mem_req_size
    ,output                                     tester_tile_trace_rd_mem_req_rdy
   
     // control to the rd mem engine
    ,output logic                               tester_tile_rd_mem_req_val
    ,output logic   [`FLOW_ID_W-1:0]            tester_tile_rd_mem_req_flowid
    ,output logic   [`PAYLOAD_PTR_W-1:0]        tester_tile_rd_mem_req_offset
    ,output logic   [`MSG_DATA_SIZE_WIDTH-1:0]  tester_tile_rd_mem_req_size
    ,input  logic                               rd_mem_tester_tile_req_rdy
    
    ,input  logic                               rd_mem_tester_tile_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]      rd_mem_tester_tile_data
    ,input  logic                               rd_mem_tester_tile_data_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]       rd_mem_tester_tile_data_padbytes
    ,output                                     tester_tile_rd_mem_data_rdy
    
    ,output logic                               tester_tile_trace_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      tester_tile_trace_data
    ,output logic                               tester_tile_trace_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]       tester_tile_trace_data_padbytes
    ,input                                      trace_tester_tile_data_rdy
    
    // NoC I/O
    ,input [`NOC_DATA_WIDTH-1:0]                src_tester_tile_noc0_data_N 
    ,input [`NOC_DATA_WIDTH-1:0]                src_tester_tile_noc0_data_E 
    ,input [`NOC_DATA_WIDTH-1:0]                src_tester_tile_noc0_data_S 
    ,input [`NOC_DATA_WIDTH-1:0]                src_tester_tile_noc0_data_W 

    ,input                                      src_tester_tile_noc0_val_N  
    ,input                                      src_tester_tile_noc0_val_E  
    ,input                                      src_tester_tile_noc0_val_S  
    ,input                                      src_tester_tile_noc0_val_W  
                                                                         
    ,output                                     tester_tile_src_noc0_yummy_N
    ,output                                     tester_tile_src_noc0_yummy_E
    ,output                                     tester_tile_src_noc0_yummy_S
    ,output                                     tester_tile_src_noc0_yummy_W
                                                                         
    ,output [`NOC_DATA_WIDTH-1:0]               tester_tile_dst_noc0_data_N 
    ,output [`NOC_DATA_WIDTH-1:0]               tester_tile_dst_noc0_data_E 
    ,output [`NOC_DATA_WIDTH-1:0]               tester_tile_dst_noc0_data_S 
    ,output [`NOC_DATA_WIDTH-1:0]               tester_tile_dst_noc0_data_W 

    ,output                                     tester_tile_dst_noc0_val_N  
    ,output                                     tester_tile_dst_noc0_val_E  
    ,output                                     tester_tile_dst_noc0_val_S  
    ,output                                     tester_tile_dst_noc0_val_W  
                                                                         
    ,input                                      dst_tester_tile_noc0_yummy_N
    ,input                                      dst_tester_tile_noc0_yummy_E
    ,input                                      dst_tester_tile_noc0_yummy_S
    ,input                                      dst_tester_tile_noc0_yummy_W
);
    
    logic                           tester_noc0_vrtoc_val;
    logic   [`NOC_DATA_WIDTH-1:0]   tester_noc0_vrtoc_data;    
    logic                           noc0_vrtoc_tester_rdy;
    
    logic                           noc0_ctovr_tester_val;
    logic   [`NOC_DATA_WIDTH-1:0]   noc0_ctovr_tester_data;
    logic                           tester_noc0_ctovr_rdy;     

    logic                           noc0_vrtoc_router_val;
    logic   [`NOC_DATA_WIDTH-1:0]   noc0_vrtoc_router_data;
    logic                           router_noc0_vrtoc_yummy;

    logic                           router_noc0_ctovr_val;
    logic   [`NOC_DATA_WIDTH-1:0]   router_noc0_ctovr_data;
    logic                           noc0_ctovr_router_yummy;
    
    dynamic_node_top_wrap noc0_router(

         .clk                   (clk)
        ,.reset_in              (rst)
        
        ,.src_router_data_N     (src_tester_tile_noc0_data_N    )
        ,.src_router_data_E     (src_tester_tile_noc0_data_E    )
        ,.src_router_data_S     (src_tester_tile_noc0_data_S    )
        ,.src_router_data_W     (src_tester_tile_noc0_data_W    )
        ,.src_router_data_P     (noc0_vrtoc_router_data         )
                                  
        ,.src_router_val_N      (src_tester_tile_noc0_val_N     )
        ,.src_router_val_E      (src_tester_tile_noc0_val_E     )
        ,.src_router_val_S      (src_tester_tile_noc0_val_S     )
        ,.src_router_val_W      (src_tester_tile_noc0_val_W     )
        ,.src_router_val_P      (noc0_vrtoc_router_val          )
                                  
        ,.router_src_yummy_N    (tester_tile_src_noc0_yummy_N   )
        ,.router_src_yummy_E    (tester_tile_src_noc0_yummy_E   )
        ,.router_src_yummy_S    (tester_tile_src_noc0_yummy_S   )
        ,.router_src_yummy_W    (tester_tile_src_noc0_yummy_W   )
        ,.router_src_yummy_P    (router_noc0_vrtoc_yummy        )
        
        ,.myLocX                (SRC_X[`XY_WIDTH-1:0]           )
        ,.myLocY                (SRC_Y[`XY_WIDTH-1:0]           )
        ,.myChipID              (`CHIP_ID_WIDTH'd0              )

        ,.router_dst_data_N     (tester_tile_dst_noc0_data_N    )
        ,.router_dst_data_E     (tester_tile_dst_noc0_data_E    )
        ,.router_dst_data_S     (tester_tile_dst_noc0_data_S    )
        ,.router_dst_data_W     (tester_tile_dst_noc0_data_W    )
        ,.router_dst_data_P     (router_noc0_ctovr_data         )
                            
        ,.router_dst_val_N      (tester_tile_dst_noc0_val_N     )
        ,.router_dst_val_E      (tester_tile_dst_noc0_val_E     )
        ,.router_dst_val_S      (tester_tile_dst_noc0_val_S     )
        ,.router_dst_val_W      (tester_tile_dst_noc0_val_W     )
        ,.router_dst_val_P      (router_noc0_ctovr_val          )
                            
        ,.dst_router_yummy_N    (dst_tester_tile_noc0_yummy_N   )
        ,.dst_router_yummy_E    (dst_tester_tile_noc0_yummy_E   )
        ,.dst_router_yummy_S    (dst_tester_tile_noc0_yummy_S   )
        ,.dst_router_yummy_W    (dst_tester_tile_noc0_yummy_W   )
        ,.dst_router_yummy_P    (noc0_ctovr_router_yummy        )
        
        ,.router_src_thanks_P   (                          )
    );
    
    credit_to_valrdy noc0_credit_to_valrdy (
         .clk   (clk)
        ,.reset (rst)
        //credit based interface 
        ,.src_ctovr_data    (router_noc0_ctovr_data     )
        ,.src_ctovr_val     (router_noc0_ctovr_val      )
        ,.ctovr_src_yummy   (noc0_ctovr_router_yummy    )

        //val/rdy interface
        ,.ctovr_dst_data    (noc0_ctovr_tester_data     )
        ,.ctovr_dst_val     (noc0_ctovr_tester_val      )
        ,.dst_ctovr_rdy     (tester_noc0_ctovr_rdy      )
    );

    valrdy_to_credit noc0_valrdy_to_credit (
         .clk       (clk)
        ,.reset     (rst)

        //val/rdy interface
        ,.src_vrtoc_data    (tester_noc0_vrtoc_data     )
        ,.src_vrtoc_val     (tester_noc0_vrtoc_val      )
        ,.vrtoc_src_rdy     (noc0_vrtoc_tester_rdy      )

		//credit based interface	
        ,.vrtoc_dst_data    (noc0_vrtoc_router_data     )
        ,.vrtoc_dst_val     (noc0_vrtoc_router_val      )
		,.dst_vrtoc_yummy   (router_noc0_vrtoc_yummy    )
    );

    tester_wrap #(
         .SRC_X         (SRC_X      )
        ,.SRC_Y         (SRC_Y      )
        ,.DST_DRAM_X    (DST_DRAM_X )
        ,.DST_DRAM_Y    (DST_DRAM_Y )
    ) tester_wrap (
         .clk   (clk)
        ,.rst   (rst)

        ,.tester_noc0_val                   (tester_noc0_vrtoc_val              )
        ,.tester_noc0_data                  (tester_noc0_vrtoc_data             )
        ,.noc0_tester_rdy                   (noc0_vrtoc_tester_rdy              )

        ,.noc0_tester_val                   (noc0_ctovr_tester_val              )
        ,.noc0_tester_data                  (noc0_ctovr_tester_data             )
        ,.tester_noc0_rdy                   (tester_noc0_ctovr_rdy              )

        ,.trace_tester_tile_wr_mem_req_val  (trace_tester_tile_wr_mem_req_val   )
        ,.trace_tester_tile_wr_mem_req_addr (trace_tester_tile_wr_mem_req_addr  )
        ,.trace_tester_tile_wr_mem_req_size (trace_tester_tile_wr_mem_req_size  )
        ,.tester_tile_trace_wr_mem_req_rdy  (tester_tile_trace_wr_mem_req_rdy   )

        ,.trace_tester_tile_data_val        (trace_tester_tile_data_val         )
        ,.trace_tester_tile_data            (trace_tester_tile_data             )
        ,.trace_tester_tile_data_last       (trace_tester_tile_data_last        )
        ,.trace_tester_tile_data_padbytes   (trace_tester_tile_data_padbytes    )
        ,.tester_tile_trace_data_rdy        (tester_tile_trace_data_rdy         )

        ,.trace_tester_tile_rd_mem_req_val  (trace_tester_tile_rd_mem_req_val   )
        ,.trace_tester_tile_rd_mem_req_addr (trace_tester_tile_rd_mem_req_addr  )
        ,.trace_tester_tile_rd_mem_req_size (trace_tester_tile_rd_mem_req_size  )
        ,.tester_tile_trace_rd_mem_req_rdy  (tester_tile_trace_rd_mem_req_rdy   )

        ,.tester_tile_rd_mem_req_val        (tester_tile_rd_mem_req_val         )
        ,.tester_tile_rd_mem_req_flowid     (tester_tile_rd_mem_req_flowid      )
        ,.tester_tile_rd_mem_req_offset     (tester_tile_rd_mem_req_offset      )
        ,.tester_tile_rd_mem_req_size       (tester_tile_rd_mem_req_size        )
        ,.rd_mem_tester_tile_req_rdy        (rd_mem_tester_tile_req_rdy         )
                                                                             
        ,.rd_mem_tester_tile_data_val       (rd_mem_tester_tile_data_val        )
        ,.rd_mem_tester_tile_data           (rd_mem_tester_tile_data            )
        ,.rd_mem_tester_tile_data_last      (rd_mem_tester_tile_data_last       )
        ,.rd_mem_tester_tile_data_padbytes  (rd_mem_tester_tile_data_padbytes   )
        ,.tester_tile_rd_mem_data_rdy       (tester_tile_rd_mem_data_rdy        )
                                                                             
        ,.tester_tile_trace_data_val        (tester_tile_trace_data_val         )
        ,.tester_tile_trace_data            (tester_tile_trace_data             )
        ,.tester_tile_trace_data_last       (tester_tile_trace_data_last        )
        ,.tester_tile_trace_data_padbytes   (tester_tile_trace_data_padbytes    )
        ,.trace_tester_tile_data_rdy        (trace_tester_tile_data_rdy         )
    );

endmodule
