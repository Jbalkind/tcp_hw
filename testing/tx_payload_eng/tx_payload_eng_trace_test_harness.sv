`include "noc_defs.vh"
`include "soc_defs.vh"
`include "test.vh"
module tx_payload_eng_trace_test_harness ();
    // Simulation Parameters
    localparam  CLOCK_PERIOD      = 10000;
    localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
    localparam  RST_TIME          = 10 * CLOCK_PERIOD;
    
    logic clk;
    logic rst;
    logic en_trace;

    // Clock generation
    initial begin
        clk = 0;
        forever begin
            #(CLOCK_HALF_PERIOD) clk = ~clk;
        end
    end
    
    // Reset generation
    initial begin
        rst = 1'b1;
        #RST_TIME rst = 1'b0; 
    end

    initial begin
        @(negedge rst);
        @(posedge clk);
        
        // Try to write a whole line of 512 bits (64 bytes)
        @(posedge clk);
        en_trace = 1;
    end
    
    logic                               trace_tester_tile_wr_mem_req_val;
    logic   [`TRACE_ADDR_W-1:0]         trace_tester_tile_wr_mem_req_addr;
    logic   [`TRACE_SIZE_W-1:0]         trace_tester_tile_wr_mem_req_size;
    logic                               tester_tile_trace_wr_mem_req_rdy;

    logic                               trace_tester_tile_data_val;
    logic   [`MAC_INTERFACE_W-1:0]      trace_tester_tile_data;
    logic                               trace_tester_tile_data_last;
    logic   [`MAC_PADBYTES_W-1:0]       trace_tester_tile_data_padbytes;
    logic                               tester_tile_trace_data_rdy;

    logic                               trace_tester_tile_rd_mem_req_val;
    logic   [`TRACE_ADDR_W-1:0]         trace_tester_tile_rd_mem_req_addr;
    logic   [`TRACE_SIZE_W-1:0]         trace_tester_tile_rd_mem_req_size;
    logic                               tester_tile_trace_rd_mem_req_rdy;

    logic                               tester_tile_trace_data_val;
    logic   [`MAC_INTERFACE_W-1:0]      tester_tile_trace_data;
    logic                               tester_tile_trace_data_last;
    logic   [`MAC_PADBYTES_W-1:0]       tester_tile_trace_data_padbytes;
    logic                               trace_tester_tile_data_rdy;
   

    logic                                       input_cmd_trace_val;
    logic                                       input_cmd_trace_rdy;
    cmd_trace_struct                            input_cmd_struct;
    logic   [`INPUT_CMD_ROM_ADDR_W-1:0]         input_cmd_rom_addr;
    logic   [(`CMD_TRACE_STRUCT_W + 4)-1:0]     input_cmd_rom_data;
    logic                                       input_cmd_done;
    
    logic                                       input_data_trace_val;
    logic                                       input_data_trace_rdy;
    data_trace_struct                           input_data_struct;
    logic   [`INPUT_DATA_ROM_ADDR_W-1:0]        input_data_rom_addr;
    logic   [(`DATA_TRACE_STRUCT_W + 4)-1:0]    input_data_rom_data;
    logic                                       input_data_done;
    
    logic                                       output_data_trace_val;
    logic                                       output_data_trace_rdy;
    data_trace_struct                           output_data_struct;
    data_trace_struct                           output_data_expected_struct;
    logic   [`OUTPUT_DATA_ROM_ADDR_W-1:0]       output_data_rom_addr;
    logic   [(`DATA_TRACE_STRUCT_W + 4)-1:0]    output_data_rom_data;
    logic                                       output_data_done;

    bsg_trace_replay #(
         .payload_width_p   (`CMD_TRACE_STRUCT_W    )
        ,.rom_addr_width_p  (`INPUT_CMD_ROM_ADDR_W  )
        ,.debug_p           (2)
    ) input_cmd_trace_replay (
         .clk_i     (clk)
        ,.reset_i   (rst)
        ,.en_i      (en_trace)

        // input channel
        ,.v_i       ('0)
        ,.data_i    ('0)
        ,.ready_o   ()

        // output channel
        ,.v_o       (input_cmd_trace_val    )
        ,.data_o    (input_cmd_struct       )
        ,.yumi_i    (input_cmd_trace_rdy    )

        // connection to rom
        // note: asynchronous reads

        ,.rom_addr_o(input_cmd_rom_addr     )
        ,.rom_data_i(input_cmd_rom_data     )

        // true outputs
        ,.done_o    (input_cmd_done         )
        ,.error_o   ()
    );
    
    input_cmd_rom #(
         .width_p       (`CMD_TRACE_STRUCT_W + 4)
        ,.addr_width_p  (`INPUT_CMD_ROM_ADDR_W  )
    ) input_cmd_rom (
         .addr_i(input_cmd_rom_addr )
        ,.data_o(input_cmd_rom_data )
    );
    
    bsg_trace_replay #(
         .payload_width_p   (`DATA_TRACE_STRUCT_W   )
        ,.rom_addr_width_p  (`INPUT_DATA_ROM_ADDR_W )
        ,.debug_p           (2)
    ) input_data_trace_replay (
         .clk_i     (clk)
        ,.reset_i   (rst)
        ,.en_i      (en_trace)

        // input channel
        ,.v_i       ('0)
        ,.data_i    ('0)
        ,.ready_o   ()

        // output channel
        ,.v_o       (input_data_trace_val   )
        ,.data_o    (input_data_struct      )
        ,.yumi_i    (input_data_trace_rdy   )

        // connection to rom
        // note: asynchronous reads

        ,.rom_addr_o(input_data_rom_addr    )
        ,.rom_data_i(input_data_rom_data    )

        // true outputs
        ,.done_o    (input_data_done        )
        ,.error_o   ()
    );
    
    input_data_rom #(
         .width_p       (`DATA_TRACE_STRUCT_W + 4   )
        ,.addr_width_p  (`INPUT_DATA_ROM_ADDR_W     )
    ) input_data_rom (
         .addr_i(input_data_rom_addr    )
        ,.data_o(input_data_rom_data    )
    );
    
    bsg_trace_replay #(
         .payload_width_p   (`DATA_TRACE_STRUCT_W   )
        ,.rom_addr_width_p  (`OUTPUT_DATA_ROM_ADDR_W)
        ,.debug_p           (2)
    ) output_data_trace_replay (
         .clk_i     (clk)
        ,.reset_i   (rst)
        ,.en_i      (en_trace)

        // input channel
        ,.v_i       (output_data_trace_val  )
        ,.data_i    (output_data_struct     )
        ,.ready_o   (output_data_trace_rdy  )

        // output channel
        ,.v_o       ()
        ,.data_o    ()
        ,.yumi_i    ('0)

        // connection to rom
        // note: asynchronous reads

        ,.rom_addr_o(output_data_rom_addr   )
        ,.rom_data_i(output_data_rom_data   )

        // true outputs
        ,.done_o    (output_data_done       )
        ,.error_o   ()
    );
    
    output_data_rom #(
         .width_p       (`DATA_TRACE_STRUCT_W + 4   )
        ,.addr_width_p  (`OUTPUT_DATA_ROM_ADDR_W    )
    ) output_data_rom (
         .addr_i(output_data_rom_addr   )
        ,.data_o(output_data_rom_data   )
    );

    assign output_data_expected_struct = output_data_rom_data[0 +: `DATA_TRACE_STRUCT_W];

    assign input_cmd_trace_rdy = tester_tile_trace_wr_mem_req_rdy 
                               & tester_tile_trace_rd_mem_req_rdy;
    assign trace_tester_tile_wr_mem_req_val = input_cmd_trace_val 
                                            & (input_cmd_struct.trace_cmd == `CMD_WR);
    assign trace_tester_tile_wr_mem_req_addr = input_cmd_struct.trace_addr;
    assign trace_tester_tile_wr_mem_req_size = input_cmd_struct.trace_size;

    assign trace_tester_tile_rd_mem_req_val = input_cmd_trace_val
                                            & (input_cmd_struct.trace_cmd == `CMD_RD);
    assign trace_tester_tile_rd_mem_req_addr = input_cmd_struct.trace_addr;
    assign trace_tester_tile_rd_mem_req_size = input_cmd_struct.trace_size;

    assign trace_tester_tile_data_val = input_data_trace_val;
    assign trace_tester_tile_data = input_data_struct.trace_data;
    assign trace_tester_tile_data_last = input_data_struct.trace_data_last;
    assign trace_tester_tile_data_padbytes = input_data_struct.trace_data_padbytes;
    assign input_data_trace_rdy = tester_tile_trace_data_rdy;

    assign output_data_trace_val = tester_tile_trace_data_val;
    assign output_data_struct.trace_data = tester_tile_trace_data;
    assign output_data_struct.trace_data_last = tester_tile_trace_data_last;
    assign output_data_struct.trace_data_padbytes = tester_tile_trace_data_padbytes;
    assign trace_tester_tile_data_rdy = output_data_trace_rdy;

    tx_payload_eng_trace_test_top DUT (
         .clk   (clk)
        ,.rst   (rst)

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
                                                                                
        ,.tester_tile_trace_data_val        (tester_tile_trace_data_val         )
        ,.tester_tile_trace_data            (tester_tile_trace_data             )
        ,.tester_tile_trace_data_last       (tester_tile_trace_data_last        )
        ,.tester_tile_trace_data_padbytes   (tester_tile_trace_data_padbytes    )
        ,.trace_tester_tile_data_rdy        (trace_tester_tile_data_rdy         )
    );

    always_ff @(posedge clk) begin
        if (input_cmd_done & input_data_done & output_data_done) begin
            $finish;
        end
    end
endmodule
