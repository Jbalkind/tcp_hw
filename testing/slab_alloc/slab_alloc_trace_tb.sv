`include "bsg_defines.v"
`include "test_defs.vh"
module slab_alloc_trace_tb ();
    
    localparam  CLOCK_PERIOD      = 10000;
    localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
    localparam  RST_TIME = CLOCK_PERIOD * 3;
    
    localparam num_traces = 39;
    localparam trace_addr_w = `BSG_SAFE_CLOG2(num_traces);
    
    logic   clk;
    logic   rst;
    logic   en_trace;
    
    logic                           trace_input_val;
    logic   [`TRACE_W-1:0]          trace_input;
    logic                           trace_input_rdy;

    logic                           trace_resp_val;
    logic   [`TRACE_W-1:0   ]       trace_resp;
    logic                           trace_resp_rdy;


    logic   [`TRACE_W + 4 - 1:0]    rom_trace_data;
    logic   [trace_addr_w-1:0]      rom_trace_addr;

    slab_free_req_struct            free_req;
    logic                           alloc_req_val;
    slab_alloc_resp_struct          alloc_resp;
    
    logic   [`IF_SELECT_W-1:0]      if_select;
    logic   [`IF_SELECT_W-1:0]      resp_if_select;

    logic   [`CMD_TRACE_W-1:0]      input_cmd_trace;
    
    logic                       trace_free_slab_req_val;
    logic   [`TEST_ADDR_W-1:0]  trace_free_slab_req_addr;
    logic                       free_slab_trace_req_rdy;

    logic                       trace_alloc_slab_consume_val;
    logic                       alloc_slab_trace_resp_error;
    logic   [`TEST_ADDR_W-1:0]  alloc_slab_trace_resp_addr;
    
    // Clock generation
    initial begin
        clk = 0;
        forever begin
            #(CLOCK_HALF_PERIOD) clk = ~clk;
        end
    end
    
    initial begin
        @(negedge rst);
        @(posedge clk);
        
        @(posedge clk);
        en_trace = 1;
    end
    
    // Reset generation
    initial begin
        rst = 1'b1;
        #RST_TIME rst = 1'b0; 
    end
    
    assign input_cmd_trace = trace_input[`CMD_TRACE_W-1:0];
    assign if_select = trace_input[`TRACE_W-1 -: `IF_SELECT_W];

    always_comb begin
        trace_input_rdy = 1'b0;
        if (trace_input_val) begin
            if (if_select == `FREE_REQ) begin
                trace_input_rdy = free_slab_trace_req_rdy;
            end
            else if (if_select == `ALLOC_REQ) begin
                trace_input_rdy = 1'b1;
            end
            else begin
                trace_input_rdy = 'X;
            end
        end
        else begin
            trace_input_rdy = 1'b0;
        end
    end

    assign trace_resp_val = 1'b1;
    assign resp_if_select = rom_trace_data[`TRACE_W - 1 -: `IF_SELECT_W];

    assign trace_resp = {resp_if_select, 
                         alloc_resp, 
                        {(`CMD_TRACE_W - `SLAB_ALLOC_RESP_STRUCT_W){1'b0}}};

    bsg_trace_replay #(
         .payload_width_p   (`TRACE_W           )
        ,.rom_addr_width_p  (trace_addr_w       )
        ,.debug_p   (2)
    ) trace_replay (
         .clk_i     (clk)
        ,.reset_i   (rst)
        ,.en_i      (en_trace)

        // input channel
        ,.v_i       (trace_resp_val )
        ,.data_i    (trace_resp     )
        ,.ready_o   (trace_resp_rdy )

        // output channel
        ,.v_o       (trace_input_val)
        ,.data_o    (trace_input    )
        ,.yumi_i    (trace_input_rdy)

        // connection to rom
        // note: asynchronous reads

        ,.rom_addr_o(rom_trace_addr )
        ,.rom_data_i(rom_trace_data )

        // true outputs
        ,.done_o    ()
        ,.error_o   ()
    );
    
    test_rom #(
         .width_p(`TRACE_W + 4)
        ,.addr_width_p(`BSG_SAFE_CLOG2(num_traces))
    ) test_rom (
         .addr_i(rom_trace_addr)
        ,.data_o(rom_trace_data)
    );

    assign trace_free_slab_req_val = trace_input_val & (if_select == `FREE_REQ);
    assign trace_alloc_slab_consume_val = trace_input_val & (if_select == `ALLOC_REQ);

    assign free_req = input_cmd_trace[`CMD_TRACE_W-1 -: `SLAB_FREE_REQ_STRUCT_W];
    assign trace_free_slab_req_addr = free_req.addr;

    assign alloc_resp.error = alloc_slab_trace_resp_error;
    assign alloc_resp.addr = alloc_slab_trace_resp_error
                           ? '0
                           : alloc_slab_trace_resp_addr;

    slab_alloc_tracker #(
         .NUM_SLABS     (`TEST_NUM_SLABS    )
        ,.SLAB_BYTES    (`TEST_SLAB_BYTES   )
    ) DUT (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.src_free_slab_req_val     (trace_free_slab_req_val        )
        ,.src_free_slab_req_addr    (trace_free_slab_req_addr       )
        ,.free_slab_src_req_rdy     (free_slab_trace_req_rdy        )
                                                              
        ,.src_alloc_slab_consume_val(trace_alloc_slab_consume_val   )
        ,.alloc_slab_src_resp_error (alloc_slab_trace_resp_error    )
        ,.alloc_slab_src_resp_addr  (alloc_slab_trace_resp_addr     )
    );

endmodule
