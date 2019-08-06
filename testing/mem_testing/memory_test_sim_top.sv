`include "noc_defs.vh"
`include "soc_defs.vh"
module memory_test_sim_top();

// Simulation Parameters
localparam  CLOCK_PERIOD      = 10000;
localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
localparam  RST_TIME          = (8 / 2 + 10) * CLOCK_PERIOD;

    // 64 bits payload, 16 bits of addr, 8 bits for memory size, 4 bits for operation
    localparam trace_width = 256 + 16 + 8 + 4;
    localparam num_traces = 26;
    localparam trace_addr_width = `BSG_SAFE_CLOG2(num_traces);

`define PAYLOAD_BITS 255:0
`define ADDR_BITS 271:256
`define ADDR_W 16
`define SIZE_BITS 279:272
`define SIZE_W 8
`define OP_BITS 283:280
`define STORE_REQ_BIT 283
`define LOAD_REQ_BIT 282
`define STORE_RESP_BIT 281
`define LOAD_RESP_BIT  280

logic clk;
logic rst;

// Clock generation
initial begin
    clk = 1'b0;
    forever begin
        #(CLOCK_HALF_PERIOD) clk = ~clk;
    end
end

// Reset generation
initial begin
    rst = 1'b1;
    #RST_TIME rst = 1'b0; 
end

    logic mac_val;
    logic [`MAC_INTERFACE_W-1:0] mac_data;
    logic [`MSG_ADDR_WIDTH-1:0] mac_data_addr;
    logic [`MSG_DATA_SIZE_WIDTH-1:0]  mac_data_size;
    logic mac_rdy;
    
    logic                               app_read_req_val;
    logic   [`MSG_ADDR_WIDTH-1:0]       app_read_req_addr;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]  app_read_req_size;
    
    logic                               app_read_resp_val;
    logic   [`NOC_DATA_WIDTH-1:0]       app_read_resp_data;

    logic                               write_complete_notif_val;
    logic   [`MSG_ADDR_WIDTH-1:0]       write_complete_notif_addr;


    logic [`MSG_ADDR_WIDTH-1:0] write_complete_notif_addr_reg;


    logic en_trace;


    logic                           test_trace_val;
    logic   [trace_width-1:0]       test_trace;
    logic   [trace_width-1:0]       trace_resp;
    logic   [trace_width + 4 - 1:0] rom_trace_data;
    logic   [trace_addr_width-1:0]  rom_trace_addr;

    assign trace_resp[`SIZE_BITS] = '0;
    assign trace_resp[`PAYLOAD_BITS] = app_read_resp_val ? app_read_resp_data : '0;
    assign trace_resp[`ADDR_BITS]    = '0;
    assign trace_resp[`STORE_REQ_BIT] = '0;
    assign trace_resp[`LOAD_REQ_BIT] = '0;
    assign trace_resp[`STORE_RESP_BIT] = write_complete_notif_val;
    assign trace_resp[`LOAD_RESP_BIT] = app_read_resp_val;
    

    bsg_trace_replay #(
         .payload_width_p(trace_width)
        ,.rom_addr_width_p(trace_addr_width)
        ,.debug_p   (2)
    ) trace_replay (
         .clk_i     (clk)
        ,.reset_i   (rst)
        ,.en_i      (en_trace)

        // input channel
        ,.v_i       (write_complete_notif_val | app_read_resp_val)
        ,.data_i    (trace_resp)
        ,.ready_o   ()

        // output channel
        ,.v_o       (test_trace_val)
        ,.data_o    (test_trace)
        ,.yumi_i    (mac_rdy)

        // connection to rom
        // note: asynchronous reads

        ,.rom_addr_o(rom_trace_addr)
        ,.rom_data_i(rom_trace_data)

        // true outputs
        ,.done_o    ()
        ,.error_o   ()

    );

    memory_test_trace_rom #(
         .width_p(trace_width + 4)
        ,.addr_width_p(`BSG_SAFE_CLOG2(num_traces))
    ) test_rom(
         .addr_i(rom_trace_addr)
        ,.data_o(rom_trace_data)
    );
initial begin
    @(negedge rst);
    @(posedge clk);
    
    // Try to write a whole line of 512 bits (64 bytes)
    @(posedge clk);
    en_trace = 1'b1;
end

//    // Try to write 16 bytes
//    @(posedge mac_rdy);
//    @(posedge clk);
//    mac_val = 1'b1;
//    mac_data = 64'hbabebabe_00000000;
//    mac_data_size = `MSG_DATA_SIZE_WIDTH'd16;
//    
//    @(posedge clk);
//    mac_val = 1'b0;
//
//    // Try to read back the 16 bytes
//    @(negedge write_complete_notif_val);
//    app_read_req_val = 1'b1;
//    app_read_req_addr = write_complete_notif_addr_reg;
//    app_read_req_size = `MSG_DATA_SIZE_WIDTH'd16;
//
//    @(posedge clk);
//    app_read_req_val = 1'b0;
//
//end

    assign mac_data_size = {{(`MSG_DATA_SIZE_WIDTH-`SIZE_W){1'b0}}, test_trace[`SIZE_BITS]};
    assign mac_data_addr = {{(`MSG_ADDR_WIDTH-`ADDR_W){1'b0}}, test_trace[`ADDR_BITS]};
memory_test_soc_top DUT(
     .clk   (clk)
    ,.rst   (rst)

    ,.mac_val               (test_trace[`STORE_REQ_BIT]  & test_trace_val)
    ,.mac_data              (test_trace[`PAYLOAD_BITS]  )
    ,.mac_data_size         (mac_data_size              )
    ,.mac_data_addr         (mac_data_addr              )
    ,.mac_rdy               (mac_rdy                    )

    ,.app_read_req_val      (test_trace[`LOAD_REQ_BIT]  & test_trace_val)
    ,.app_read_req_addr     (mac_data_addr              )
    ,.app_read_req_size     (mac_data_size              )

    ,.app_read_resp_val     (app_read_resp_val)
    ,.app_read_resp_data    (app_read_resp_data)

    ,.write_complete_notif_val    (write_complete_notif_val )
    ,.write_complete_notif_addr   (write_complete_notif_addr)

);
endmodule
