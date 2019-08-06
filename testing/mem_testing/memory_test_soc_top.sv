`include "packet_defs.vh"
`include "state_defs.vh"
`include "noc_defs.vh"
`include "soc_defs.vh"
module memory_test_soc_top (
     input clk
    ,input rst
    
    // placeholder interface for now
    ,input                              mac_val
    ,input  [`MAC_INTERFACE_W-1:0]      mac_data
    ,input  [`MSG_DATA_SIZE_WIDTH-1:0]  mac_data_size
    ,input  [`MSG_ADDR_WIDTH-1:0]       mac_data_addr
    ,output                             mac_rdy
    
    ,input                                      app_read_req_val
    ,input  [`MSG_ADDR_WIDTH-1:0]               app_read_req_addr
    ,input  [`MSG_DATA_SIZE_WIDTH-1:0]          app_read_req_size

    ,output logic                               app_read_resp_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       app_read_resp_data

    ,output logic                               write_complete_notif_val
    ,output logic   [`MSG_ADDR_WIDTH-1:0]       write_complete_notif_addr
    
);
    logic                           tcp_tile_dram_tile_noc0_val;
    logic   [`NOC_DATA_WIDTH-1:0]   tcp_tile_dram_tile_noc0_data;
    logic                           dram_tile_tcp_tile_noc0_yummy;
    
    logic                           dram_tile_tcp_tile_noc0_val;
    logic   [`NOC_DATA_WIDTH-1:0]   dram_tile_tcp_tile_noc0_data;
    logic                           tcp_tile_dram_tile_noc0_yummy;
    
    logic                           controller_mem_read_en;
    logic                           controller_mem_write_en;
    logic   [`MEM_ADDR_W-1:0]       controller_mem_addr;
    logic   [`MEM_DATA_W-1:0]       controller_mem_wr_data;
    logic   [`MEM_WR_MASK_W-1:0]    controller_mem_byte_en;
    logic   [`MEM_BURST_CNT_W-1:0]  controller_mem_burst_cnt;
    logic                           mem_controller_rdy;

    logic                           mem_controller_rd_data_val;
    logic   [`MEM_DATA_W-1:0]       mem_controller_rd_data;

    logic                           mem_controller_rd_data_val_reg; 
    
    bsg_mem_1rw_sync_mask_write_byte #( 
         .els_p         (2 ** `MEM_ADDR_W)
        ,.data_width_p  (`MEM_DATA_W     )
    ) memA ( 
         .clk_i         (clk    )
        ,.reset_i       (rst    )

        ,.v_i           (controller_mem_read_en | controller_mem_write_en   )
        ,.w_i           (controller_mem_write_en)

        ,.addr_i        (controller_mem_addr    )
        ,.data_i        (controller_mem_wr_data )
         // for each bit set in the mask, a byte is written
        ,.write_mask_i  (controller_mem_byte_en )
        ,.data_o        (mem_controller_rd_data )
    );
    
    assign mem_controller_rd_data_val = mem_controller_rd_data_val_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            mem_controller_rd_data_val_reg <= 1'b0;
        end
        else begin
            mem_controller_rd_data_val_reg <= controller_mem_read_en & mem_controller_rdy;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mem_controller_rdy <= '0;
        end
        else begin
            mem_controller_rdy <= ~mem_controller_rdy;
        end
    end


    memory_test_tile tile0_0(
         .clk                   (clk)
        ,.rst                   (rst)
    
        ,.mac_val               (mac_val            )
        ,.mac_data              (mac_data           )
        ,.mac_data_size         (mac_data_size      )
        ,.mac_data_addr         (mac_data_addr      )
        ,.mac_rdy               (mac_rdy            )
    
        ,.app_read_req_val      (app_read_req_val   )
        ,.app_read_req_addr     (app_read_req_addr  )
        ,.app_read_req_size     (app_read_req_size  )
    
        ,.app_read_resp_val     (app_read_resp_val)
        ,.app_read_resp_data    (app_read_resp_data)
    
        ,.write_complete_notif_val    (write_complete_notif_val )
        ,.write_complete_notif_addr   (write_complete_notif_addr)
    
        ,.src_tcp_tile_noc0_data_N      () // data inputs from neighboring tiles
        ,.src_tcp_tile_noc0_data_E      (dram_tile_tcp_tile_noc0_data   ) 
        ,.src_tcp_tile_noc0_data_S      ()
        ,.src_tcp_tile_noc0_data_W      ()
        
        ,.src_tcp_tile_noc0_val_N       ()// valid signals from neighboring tiles
        ,.src_tcp_tile_noc0_val_E       (dram_tile_tcp_tile_noc0_val    )
        ,.src_tcp_tile_noc0_val_S       ()
        ,.src_tcp_tile_noc0_val_W       ()
        
        ,.tcp_tile_src_noc0_yummy_N     () // yummy signal to neighbors' output buffers
        ,.tcp_tile_src_noc0_yummy_E     (tcp_tile_dram_tile_noc0_yummy  )
        ,.tcp_tile_src_noc0_yummy_S     ()
        ,.tcp_tile_src_noc0_yummy_W     ()
        
        ,.tcp_tile_dst_noc0_data_N      ()  // data outputs to neighbors
        ,.tcp_tile_dst_noc0_data_E      (tcp_tile_dram_tile_noc0_data   )  
        ,.tcp_tile_dst_noc0_data_S      () 
        ,.tcp_tile_dst_noc0_data_W      () 
        
        ,.tcp_tile_dst_noc0_val_N       () // valid outputs to neighbors
        ,.tcp_tile_dst_noc0_val_E       (tcp_tile_dram_tile_noc0_val    ) 
        ,.tcp_tile_dst_noc0_val_S       ()
        ,.tcp_tile_dst_noc0_val_W       ()
        
        ,.dst_tcp_tile_noc0_yummy_N     () // neighbor consumed output data
        ,.dst_tcp_tile_noc0_yummy_E     (dram_tile_tcp_tile_noc0_yummy  )
        ,.dst_tcp_tile_noc0_yummy_S     ()
        ,.dst_tcp_tile_noc0_yummy_W     ()
    );
    
    dram_tile #(
         .SRC_X             (1)
        ,.SRC_Y             (0)
        ,.MEM_ADDR_W        (`MEM_ADDR_W     )
        ,.MEM_DATA_W        (`MEM_DATA_W     )
        ,.MEM_WR_MASK_W     (`MEM_WR_MASK_W  )
        ,.MEM_BURST_CNT_W   (`MEM_BURST_CNT_W)
    ) tile1_0(
        .clk                       (clk)
       ,.rst                       (rst)
    
       ,.src_dram_tile_noc0_data_N     ()  // data inputs from neighboring tiles
       ,.src_dram_tile_noc0_data_E     ()
       ,.src_dram_tile_noc0_data_S     ()
       ,.src_dram_tile_noc0_data_W     (tcp_tile_dram_tile_noc0_data   )
       
       ,.src_dram_tile_noc0_val_N      ()// valid signals from neighboring tiles
       ,.src_dram_tile_noc0_val_E      ()
       ,.src_dram_tile_noc0_val_S      ()
       ,.src_dram_tile_noc0_val_W      (tcp_tile_dram_tile_noc0_val    )
           
       ,.dram_tile_src_noc0_yummy_N    ()// yummy signal to neighbors' output buffers
       ,.dram_tile_src_noc0_yummy_E    ()
       ,.dram_tile_src_noc0_yummy_S    ()
       ,.dram_tile_src_noc0_yummy_W    (dram_tile_tcp_tile_noc0_yummy  )
       
       ,.dram_tile_dst_noc0_data_N     ()// data outputs to neighbors
       ,.dram_tile_dst_noc0_data_E     ()
       ,.dram_tile_dst_noc0_data_S     ()
       ,.dram_tile_dst_noc0_data_W     (dram_tile_tcp_tile_noc0_data   )
       
       ,.dram_tile_dst_noc0_val_N      ()// valid outputs to neighbors
       ,.dram_tile_dst_noc0_val_E      ()
       ,.dram_tile_dst_noc0_val_S      ()
       ,.dram_tile_dst_noc0_val_W      (dram_tile_tcp_tile_noc0_val    )
       
       ,.dst_dram_tile_noc0_yummy_N    ()// neighbor consumed output data
       ,.dst_dram_tile_noc0_yummy_E    ()
       ,.dst_dram_tile_noc0_yummy_S    ()
       ,.dst_dram_tile_noc0_yummy_W    (tcp_tile_dram_tile_noc0_yummy  )
    
       ,.controller_mem_read_en        (controller_mem_read_en          )
       ,.controller_mem_write_en       (controller_mem_write_en         )
       ,.controller_mem_addr           (controller_mem_addr             )
       ,.controller_mem_wr_data        (controller_mem_wr_data          )
       ,.controller_mem_byte_en        (controller_mem_byte_en          )
       ,.controller_mem_burst_cnt      (controller_mem_burst_cnt        )
       ,.mem_controller_rdy            (mem_controller_rdy              )
                                                                        
       ,.mem_controller_rd_data_val    (mem_controller_rd_data_val      )
       ,.mem_controller_rd_data        (mem_controller_rd_data          )
    );
    


    //cpu_tile tile1_0();

    //app_tile tile1_1();

endmodule

