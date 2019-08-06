`include "noc_defs.vh"
`include "soc_defs.vh"
`include "test.vh"

module tx_payload_eng_trace_test_top (
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
    
    ,output logic                               tester_tile_trace_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      tester_tile_trace_data
    ,output logic                               tester_tile_trace_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]       tester_tile_trace_data_padbytes
    ,input                                      trace_tester_tile_data_rdy
);
    
    logic                               tester_tile_rd_mem_req_val;
    logic   [`FLOW_ID_W-1:0]            tester_tile_rd_mem_req_flowid;
    logic   [`PAYLOAD_PTR_W-1:0]        tester_tile_rd_mem_req_offset;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]  tester_tile_rd_mem_req_size;
    logic                               rd_mem_tester_tile_req_rdy;

    logic                               rd_mem_tester_tile_data_val;
    logic   [`MAC_INTERFACE_W-1:0]      rd_mem_tester_tile_data;
    logic                               rd_mem_tester_tile_data_last;
    logic   [`MAC_PADBYTES_W-1:0]       rd_mem_tester_tile_data_padbytes;
    logic                               tester_tile_rd_mem_data_rdy;

    logic   [`NOC_DATA_WIDTH-1:0]       tester_tile_dram_tile_noc0_data;
    logic   [`NOC_DATA_WIDTH-1:0]       rd_mem_eng_tile_dram_tile_noc0_data;

    logic                               tester_tile_dram_tile_noc0_val;
    logic                               rd_mem_eng_tile_dram_tile_noc0_val;

    logic                               dram_tile_tester_tile_noc0_yummy;
    logic                               dram_tile_rd_mem_eng_tile_noc0_yummy;

    logic   [`NOC_DATA_WIDTH-1:0]       dram_tile_tester_tile_noc0_data;
    logic   [`NOC_DATA_WIDTH-1:0]       dram_tile_rd_mem_eng_tile_noc0_data;

    logic                               dram_tile_tester_tile_noc0_val;
    logic                               dram_tile_rd_mem_eng_tile_noc0_val;

    logic                               tester_tile_dram_tile_noc0_yummy;
    logic                               rd_mem_eng_tile_dram_tile_noc0_yummy;

    tx_rd_mem_eng_tile #(
         .SRC_X         (0)
        ,.SRC_Y         (0)
        ,.DST_DRAM_X    (1)
        ,.DST_DRAM_Y    (0)
    ) tile_0_0 (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_rd_mem_eng_tile_noc0_data_N   ('0)
        ,.src_rd_mem_eng_tile_noc0_data_E   (dram_tile_rd_mem_eng_tile_noc0_data    )
        ,.src_rd_mem_eng_tile_noc0_data_S   ('0)
        ,.src_rd_mem_eng_tile_noc0_data_W   ('0)

        ,.src_rd_mem_eng_tile_noc0_val_N    ('0)
        ,.src_rd_mem_eng_tile_noc0_val_E    (dram_tile_rd_mem_eng_tile_noc0_val     )
        ,.src_rd_mem_eng_tile_noc0_val_S    ('0)
        ,.src_rd_mem_eng_tile_noc0_val_W    ('0)

        ,.rd_mem_eng_tile_src_noc0_yummy_N  ()
        ,.rd_mem_eng_tile_src_noc0_yummy_E  (rd_mem_eng_tile_dram_tile_noc0_yummy   )
        ,.rd_mem_eng_tile_src_noc0_yummy_S  ()
        ,.rd_mem_eng_tile_src_noc0_yummy_W  ()

        ,.rd_mem_eng_tile_dst_noc0_data_N   ()
        ,.rd_mem_eng_tile_dst_noc0_data_E   (rd_mem_eng_tile_dram_tile_noc0_data    )
        ,.rd_mem_eng_tile_dst_noc0_data_S   ()
        ,.rd_mem_eng_tile_dst_noc0_data_W   ()

        ,.rd_mem_eng_tile_dst_noc0_val_N    ()
        ,.rd_mem_eng_tile_dst_noc0_val_E    (rd_mem_eng_tile_dram_tile_noc0_val     )
        ,.rd_mem_eng_tile_dst_noc0_val_S    ()
        ,.rd_mem_eng_tile_dst_noc0_val_W    ()

        ,.dst_rd_mem_eng_tile_noc0_yummy_N  ('0)
        ,.dst_rd_mem_eng_tile_noc0_yummy_E  (dram_tile_rd_mem_eng_tile_noc0_yummy   )
        ,.dst_rd_mem_eng_tile_noc0_yummy_S  ('0)
        ,.dst_rd_mem_eng_tile_noc0_yummy_W  ('0)

        ,.src_rd_mem_tx_req_val             (tester_tile_rd_mem_req_val             )
        ,.src_rd_mem_tx_req_flowid          (tester_tile_rd_mem_req_flowid          )
        ,.src_rd_mem_tx_req_offset          (tester_tile_rd_mem_req_offset          )
        ,.src_rd_mem_tx_req_size            (tester_tile_rd_mem_req_size            )
        ,.rd_mem_src_tx_req_rdy             (rd_mem_tester_tile_req_rdy             )

        ,.rd_mem_dst_tx_data_val            (rd_mem_tester_tile_data_val            )
        ,.rd_mem_dst_tx_data                (rd_mem_tester_tile_data                )
        ,.rd_mem_dst_tx_data_last           (rd_mem_tester_tile_data_last           )
        ,.rd_mem_dst_tx_data_padbytes       (rd_mem_tester_tile_data_padbytes       )
        ,.dst_rd_mem_tx_data_rdy            (tester_tile_rd_mem_data_rdy            )
    );

    dram_tile #(
         .SRC_X (1)
        ,.SRC_Y (0)
    ) tile_1_0 (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_dram_tile_noc0_data_N     ('0)
        ,.src_dram_tile_noc0_data_E     (tester_tile_dram_tile_noc0_data        )
        ,.src_dram_tile_noc0_data_S     ('0)
        ,.src_dram_tile_noc0_data_W     (rd_mem_eng_tile_dram_tile_noc0_data    )

        ,.src_dram_tile_noc0_val_N      ('0)
        ,.src_dram_tile_noc0_val_E      (tester_tile_dram_tile_noc0_val         )
        ,.src_dram_tile_noc0_val_S      ('0)
        ,.src_dram_tile_noc0_val_W      (rd_mem_eng_tile_dram_tile_noc0_val     )

        ,.dram_tile_src_noc0_yummy_N    ()
        ,.dram_tile_src_noc0_yummy_E    (dram_tile_tester_tile_noc0_yummy       )
        ,.dram_tile_src_noc0_yummy_S    ()
        ,.dram_tile_src_noc0_yummy_W    (dram_tile_rd_mem_eng_tile_noc0_yummy   )

        ,.dram_tile_dst_noc0_data_N     ()
        ,.dram_tile_dst_noc0_data_E     (dram_tile_tester_tile_noc0_data        )
        ,.dram_tile_dst_noc0_data_S     ()
        ,.dram_tile_dst_noc0_data_W     (dram_tile_rd_mem_eng_tile_noc0_data    )

        ,.dram_tile_dst_noc0_val_N      ()
        ,.dram_tile_dst_noc0_val_E      (dram_tile_tester_tile_noc0_val         )
        ,.dram_tile_dst_noc0_val_S      ()
        ,.dram_tile_dst_noc0_val_W      (dram_tile_rd_mem_eng_tile_noc0_val     )

        ,.dst_dram_tile_noc0_yummy_N    ('0)
        ,.dst_dram_tile_noc0_yummy_E    (tester_tile_dram_tile_noc0_yummy       )
        ,.dst_dram_tile_noc0_yummy_S    ('0)
        ,.dst_dram_tile_noc0_yummy_W    (rd_mem_eng_tile_dram_tile_noc0_yummy   )
    );

    tester_tile #(
         .SRC_X         (2)
        ,.SRC_Y         (0)
        ,.DST_DRAM_X    (1)
        ,.DST_DRAM_Y    (0)
    ) tile_2_0 (
         .clk   (clk)
        ,.rst   (rst)
    
        // trace tester's control interface
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

        ,.src_tester_tile_noc0_data_N       ('0)
        ,.src_tester_tile_noc0_data_E       ('0)
        ,.src_tester_tile_noc0_data_S       ('0)
        ,.src_tester_tile_noc0_data_W       (dram_tile_tester_tile_noc0_data    )

        ,.src_tester_tile_noc0_val_N        ('0)
        ,.src_tester_tile_noc0_val_E        ('0)
        ,.src_tester_tile_noc0_val_S        ('0)
        ,.src_tester_tile_noc0_val_W        (dram_tile_tester_tile_noc0_val     )

        ,.tester_tile_src_noc0_yummy_N      ()
        ,.tester_tile_src_noc0_yummy_E      ()
        ,.tester_tile_src_noc0_yummy_S      ()
        ,.tester_tile_src_noc0_yummy_W      (tester_tile_dram_tile_noc0_yummy   )

        ,.tester_tile_dst_noc0_data_N       ()
        ,.tester_tile_dst_noc0_data_E       ()
        ,.tester_tile_dst_noc0_data_S       ()
        ,.tester_tile_dst_noc0_data_W       (tester_tile_dram_tile_noc0_data    )

        ,.tester_tile_dst_noc0_val_N        ()
        ,.tester_tile_dst_noc0_val_E        ()
        ,.tester_tile_dst_noc0_val_S        ()
        ,.tester_tile_dst_noc0_val_W        (tester_tile_dram_tile_noc0_val     )

        ,.dst_tester_tile_noc0_yummy_N      ('0)
        ,.dst_tester_tile_noc0_yummy_E      ('0)
        ,.dst_tester_tile_noc0_yummy_S      ('0)
        ,.dst_tester_tile_noc0_yummy_W      (dram_tile_tester_tile_noc0_yummy   )
    );
endmodule
