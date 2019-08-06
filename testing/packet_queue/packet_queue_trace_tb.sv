`include "bsg_defines.v"
module packet_queue_trace_tb();
    
    localparam  CLOCK_PERIOD      = 10000;
    localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
    localparam  RST_TIME = CLOCK_PERIOD * 3;
    
    localparam width_p = 8;
    // rd_req + wr_req + start_frame + end_frame + empty + full + width_p 
    localparam trace_width = 1 + 1 + 1 + 1 + 1 + 1 + width_p;
    localparam num_traces = 45;
    localparam trace_addr_width = `BSG_SAFE_CLOG2(num_traces);

    localparam RD_REQ_IND = trace_width - 1;
    localparam WR_REQ_IND = RD_REQ_IND - 1;
    localparam START_FRAME_IND = WR_REQ_IND - 1;
    localparam END_FRAME_IND = START_FRAME_IND - 1;
    localparam EMPTY_IND = END_FRAME_IND - 1;
    localparam FULL_IND = EMPTY_IND - 1;
    localparam DATA_IND_HI = FULL_IND - 1;


    logic clk;
    logic rst;
    
    logic                   rd_req;
    logic                   empty;
    logic   [width_p-1:0]   rd_data;
    logic   [width_p-1:0]   rd_data_reg;

    logic                   wr_req;
    logic   [width_p-1:0]   wr_data;
    logic                   full;
    logic                   start_frame;
    logic                   end_frame;
    
    logic   en_trace;
    
    logic                           trace_input_val;
    logic   [trace_width-1:0]       trace_input;
    logic                           trace_input_rdy;

    logic                           trace_resp_val;
    logic   [trace_width-1:0]       trace_resp;
    logic                           trace_resp_rdy;


    logic   [trace_width + 4 - 1:0] rom_trace_data;
    logic   [trace_addr_width-1:0]  rom_trace_addr;
    
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
        
        // Try to write a whole line of 512 bits (64 bytes)
        @(posedge clk);
        en_trace = 1;
    end
    
    // Reset generation
    initial begin
        rst = 1'b1;
        #RST_TIME rst = 1'b0; 
    end
    
    bsg_trace_replay #(
         .payload_width_p(trace_width)
        ,.rom_addr_width_p(trace_addr_width)
        ,.debug_p   (2)
    ) trace_replay (
         .clk_i     (clk)
        ,.reset_i   (rst)
        ,.en_i      (en_trace)

        // input channel
        ,.v_i       (1'b1           )
        ,.data_i    (trace_resp     )
        ,.ready_o   (trace_resp_rdy )

        // output channel
        ,.v_o       (trace_input_val)
        ,.data_o    (trace_input    )
        ,.yumi_i    (1'b1           )

        // connection to rom
        // note: asynchronous reads

        ,.rom_addr_o(rom_trace_addr )
        ,.rom_data_i(rom_trace_data )

        // true outputs
        ,.done_o    ()
        ,.error_o   ()
    );
    
    test_rom #(
         .width_p(trace_width + 4)
        ,.addr_width_p(`BSG_SAFE_CLOG2(num_traces))
    ) test_rom (
         .addr_i(rom_trace_addr)
        ,.data_o(rom_trace_data)
    );

    assign wr_req = trace_input[WR_REQ_IND] & trace_input_val;
    assign wr_data = trace_input[DATA_IND_HI -: width_p];
    assign start_frame = trace_input[START_FRAME_IND];
    assign end_frame = trace_input[END_FRAME_IND];

    assign rd_req = trace_input[RD_REQ_IND] & trace_input_val;

    always_comb begin
        trace_resp = '0;
        trace_resp[EMPTY_IND] = empty;
        trace_resp[FULL_IND] = full;
        trace_resp[DATA_IND_HI -: width_p] = rd_data & {width_p{~empty}};
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_data_reg <= '0;
        end
        else begin
            if (rd_req) begin
                rd_data_reg = rd_data;
            end
            else begin
                rd_data_reg <= '0;
            end
        end
    end

    
    packet_queue_controller #(
         .width_p   (width_p)
        ,.log2_els_p(3)
    ) buffer (
         .clk(clk)
        ,.rst(rst)
    
        ,.wr_req        (wr_req         )
        ,.wr_data       (wr_data        )
        ,.full          (full           )
        ,.start_frame   (start_frame    )
        ,.end_frame     (end_frame      )
        
        ,.rd_req        (rd_req         )
        ,.empty         (empty          )
        ,.rd_data       (rd_data        )
    );
endmodule
