`include "noc_defs.vh"
`include "soc_defs.vh"
module memory_test_tile(
     input clk
    ,input rst

    ,input                              mac_val
    ,input  [`MAC_INTERFACE_W-1:0]      mac_data
    ,input  [`MSG_DATA_SIZE_WIDTH-1:0]  mac_data_size
    ,input  [`MSG_ADDR_WIDTH-1:0]       mac_data_addr
    ,output                             mac_rdy
    
    ,input                                      app_read_req_val
    ,input  [`MSG_ADDR_WIDTH-1:0]               app_read_req_addr
    ,input  [`MSG_DATA_SIZE_WIDTH-1:0]          app_read_req_size

    ,output logic                               write_complete_notif_val
    ,output logic   [`MSG_ADDR_WIDTH-1:0]       write_complete_notif_addr
    
    ,output logic                               app_read_resp_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       app_read_resp_data
    
    ,input [`NOC_DATA_WIDTH-1:0]    src_tcp_tile_noc0_data_N // data inputs from neighboring tiles
    ,input [`NOC_DATA_WIDTH-1:0]    src_tcp_tile_noc0_data_E 
    ,input [`NOC_DATA_WIDTH-1:0]    src_tcp_tile_noc0_data_S 
    ,input [`NOC_DATA_WIDTH-1:0]    src_tcp_tile_noc0_data_W 
                                                             
    ,input                          src_tcp_tile_noc0_val_N  // valid signals from neighboring tiles
    ,input                          src_tcp_tile_noc0_val_E  
    ,input                          src_tcp_tile_noc0_val_S  
    ,input                          src_tcp_tile_noc0_val_W  
                                                             
    ,output                         tcp_tile_src_noc0_yummy_N// yummy signal to neighbors' output buffers
    ,output                         tcp_tile_src_noc0_yummy_E
    ,output                         tcp_tile_src_noc0_yummy_S
    ,output                         tcp_tile_src_noc0_yummy_W
                                                             
    ,output [`NOC_DATA_WIDTH-1:0]   tcp_tile_dst_noc0_data_N // data outputs to neighbors
    ,output [`NOC_DATA_WIDTH-1:0]   tcp_tile_dst_noc0_data_E 
    ,output [`NOC_DATA_WIDTH-1:0]   tcp_tile_dst_noc0_data_S 
    ,output [`NOC_DATA_WIDTH-1:0]   tcp_tile_dst_noc0_data_W 
                                                             
    ,output                         tcp_tile_dst_noc0_val_N  // valid outputs to neighbors
    ,output                         tcp_tile_dst_noc0_val_E  
    ,output                         tcp_tile_dst_noc0_val_S  
    ,output                         tcp_tile_dst_noc0_val_W  
                                                             
    ,input                          dst_tcp_tile_noc0_yummy_N// neighbor consumed output data
    ,input                          dst_tcp_tile_noc0_yummy_E
    ,input                          dst_tcp_tile_noc0_yummy_S
    ,input                          dst_tcp_tile_noc0_yummy_W
    
);
    logic                           parser_noc0_vrtoc_val;
    logic   [`NOC_DATA_WIDTH-1:0]   parser_noc0_vrtoc_data;    
    logic                           noc0_vrtoc_parser_rdy;
    
    logic                           noc0_ctovr_parser_val;
    logic   [`NOC_DATA_WIDTH-1:0]   noc0_ctovr_parser_data;
    logic                           parser_noc0_ctovr_rdy;     

    logic                           noc0_vrtoc_router_val;
    logic   [`NOC_DATA_WIDTH-1:0]   noc0_vrtoc_router_data;
    logic                           router_noc0_vrtoc_yummy;

    logic                           router_noc0_ctovr_val;
    logic   [`NOC_DATA_WIDTH-1:0]   router_noc0_ctovr_data;
    logic                           noc0_ctovr_router_yummy;
   

    dynamic_node_top_wrap noc0_router(

     .clk                   (clk)
    ,.reset_in              (rst)
    
    ,.src_router_data_N     (src_tcp_tile_noc0_data_N   )  // data inputs from neighboring tiles
    ,.src_router_data_E     (src_tcp_tile_noc0_data_E   )
    ,.src_router_data_S     (src_tcp_tile_noc0_data_S   )
    ,.src_router_data_W     (src_tcp_tile_noc0_data_W   )
    ,.src_router_data_P     (noc0_vrtoc_router_data     )  // data input from processor
                            
    ,.src_router_val_N      (src_tcp_tile_noc0_val_N    )  // valid signals from neighboring tiles
    ,.src_router_val_E      (src_tcp_tile_noc0_val_E    )
    ,.src_router_val_S      (src_tcp_tile_noc0_val_S    )
    ,.src_router_val_W      (src_tcp_tile_noc0_val_W    )
    ,.src_router_val_P      (noc0_vrtoc_router_val      )  // valid signal from processor
                            
    ,.router_src_yummy_N    (tcp_tile_src_noc0_yummy_N  ) // yummy signal to neighbors' output buffers
    ,.router_src_yummy_E    (tcp_tile_src_noc0_yummy_E  )
    ,.router_src_yummy_S    (tcp_tile_src_noc0_yummy_S  )
    ,.router_src_yummy_W    (tcp_tile_src_noc0_yummy_W  )
    ,.router_src_yummy_P    (router_noc0_vrtoc_yummy    ) // yummy signal to processor's output buffer
    
    ,.myLocX                (`XY_WIDTH'd0)  // this tile's position
    ,.myLocY                (`XY_WIDTH'd0)
    ,.myChipID              (`CHIP_ID_WIDTH'd0)

    ,.router_dst_data_N     (tcp_tile_dst_noc0_data_N   )  // data outputs to neighbors
    ,.router_dst_data_E     (tcp_tile_dst_noc0_data_E   )  
    ,.router_dst_data_S     (tcp_tile_dst_noc0_data_S   )
    ,.router_dst_data_W     (tcp_tile_dst_noc0_data_W   )
    ,.router_dst_data_P     (router_noc0_ctovr_data     )  // data output to processor
                        
    ,.router_dst_val_N      (tcp_tile_dst_noc0_val_N    )  // valid outputs to neighbors
    ,.router_dst_val_E      (tcp_tile_dst_noc0_val_E    )  
    ,.router_dst_val_S      (tcp_tile_dst_noc0_val_S    )
    ,.router_dst_val_W      (tcp_tile_dst_noc0_val_W    )
    ,.router_dst_val_P      (router_noc0_ctovr_val      )  // valid output to processor
                        
    ,.dst_router_yummy_N    (dst_tcp_tile_noc0_yummy_N  )  // neighbor consumed output data
    ,.dst_router_yummy_E    (dst_tcp_tile_noc0_yummy_E  )
    ,.dst_router_yummy_S    (dst_tcp_tile_noc0_yummy_S  )
    ,.dst_router_yummy_W    (dst_tcp_tile_noc0_yummy_W  )
    ,.dst_router_yummy_P    (noc0_ctovr_router_yummy    )  // processor consumed output data
    
    
    ,.router_src_thanks_P   ()  // thanksIn to processor's space_avail

    );

    credit_to_valrdy noc0_credit_to_valrdy (
         .clk   (clk)
        ,.reset (rst)
        //credit based interface 
        ,.src_ctovr_data    (router_noc0_ctovr_data )
        ,.src_ctovr_val     (router_noc0_ctovr_val  )
        ,.ctovr_src_yummy   (noc0_ctovr_router_yummy)

        //val/rdy interface
        ,.ctovr_dst_data    (noc0_ctovr_parser_data )
        ,.ctovr_dst_val     (noc0_ctovr_parser_val  )
        ,.dst_ctovr_rdy     (parser_noc0_ctovr_rdy  )
    );

    valrdy_to_credit noc0_valrdy_to_credit (
         .clk       (clk)
        ,.reset     (rst)

        //val/rdy interface
        ,.src_vrtoc_data    (parser_noc0_vrtoc_data )
        ,.src_vrtoc_val     (parser_noc0_vrtoc_val  )
        ,.vrtoc_src_rdy     (noc0_vrtoc_parser_rdy  )

		//credit based interface	
        ,.vrtoc_dst_data    (noc0_vrtoc_router_data )
        ,.vrtoc_dst_val     (noc0_vrtoc_router_val  )
		,.dst_vrtoc_yummy   (router_noc0_vrtoc_yummy)
    );

    

    memory_tester memory_tester (
     .clk               (clk)
    ,.rst               (rst)
    
    // I/O for the MAC
    ,.mac_val                       (mac_val            )
    ,.mac_data                      (mac_data           )
    ,.mac_data_size                 (mac_data_size      )
    ,.mac_data_addr                 (mac_data_addr      )
    ,.mac_rdy                       (mac_rdy            )

    ,.app_read_req_val              (app_read_req_val   )
    ,.app_read_req_addr             (app_read_req_addr  )
    ,.app_read_req_size             (app_read_req_size  )

    ,.write_complete_notif_val      (write_complete_notif_val )
    ,.write_complete_notif_addr     (write_complete_notif_addr)

    ,.app_read_resp_val             (app_read_resp_val)
    ,.app_read_resp_data            (app_read_resp_data)

    // I/O for the NoC
    ,.parser_noc0_val               (parser_noc0_vrtoc_val  )
    ,.parser_noc0_data              (parser_noc0_vrtoc_data )
    ,.noc0_parser_rdy               (noc0_vrtoc_parser_rdy  )
    
    ,.noc0_parser_val               (noc0_ctovr_parser_val  )
    ,.noc0_parser_data              (noc0_ctovr_parser_data )
    ,.parser_noc0_rdy               (parser_noc0_ctovr_rdy  )

    
    );


endmodule
