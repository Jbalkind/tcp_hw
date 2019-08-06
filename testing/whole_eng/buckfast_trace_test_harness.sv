`include "packet_defs.vh"
`include "state_defs.vh"
module buckfast_trace_test_harness();

    // Simulation Parameters
    localparam  CLOCK_PERIOD      = 10000;
    localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
    localparam  RST_TIME          = 10 * CLOCK_PERIOD;
    
    // 64 bits payload, 16 bits of addr, 8 bits for memory size, 4 bits for operation
    localparam trace_width = `IP_ADDR_W + `IP_ADDR_W + `TCP_HDR_W
                            + `PAYLOAD_ENTRY_W;
    localparam num_traces = 9;
    localparam trace_addr_width = `BSG_SAFE_CLOG2(num_traces);
    
    logic clk;
    logic rst;
    
    logic                                       parser_tcp_rx_hdr_val;
    logic                                       tcp_parser_rx_rdy;
    logic   [`IP_ADDR_W-1:0]                    parser_tcp_rx_src_ip;
    logic   [`IP_ADDR_W-1:0]                    parser_tcp_rx_dst_ip;
    logic   [`TCP_HDR_W-1:0]                    parser_tcp_rx_tcp_hdr;

    logic                                       parser_tcp_rx_payload_val;
    logic   [`PAYLOAD_ENTRY_ADDR_W-1:0]         parser_tcp_rx_payload_addr;
    logic   [`PAYLOAD_ENTRY_LEN_W-1:0]          parser_tcp_rx_payload_len;
    
    // For sending out a complete packet
    logic                                       tcp_parser_tx_val;
    logic                                       parser_tcp_tx_rdy;
    logic   [`IP_ADDR_W-1:0]                    tcp_parser_tx_src_ip;
    logic   [`IP_ADDR_W-1:0]                    tcp_parser_tx_dst_ip;
    logic   [`TCP_HDR_W-1:0]                    tcp_parser_tx_tcp_hdr;
    payload_buf_entry                           tcp_parser_tx_payload;

    logic   en_trace;
    
    logic                           trace_input_val;
    logic   [trace_width-1:0]       trace_input;
    logic                           trace_input_rdy;

    logic                           trace_resp_val;
    logic   [trace_width-1:0]       trace_resp;
    logic                           trace_resp_rdy;


    logic   [trace_width + 4 - 1:0] rom_trace_data;
    logic   [trace_addr_width-1:0]  rom_trace_addr;

    tcp_pkt_hdr                                 output_tcp_hdr_struct;
    tcp_pkt_hdr                                 expected_tcp_hdr_struct;

    assign output_tcp_hdr_struct = tcp_parser_tx_tcp_hdr;
    assign expected_tcp_hdr_struct = rom_trace_data[trace_width-1-4-(2*`IP_ADDR_W) -: `TCP_HDR_W];
    
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
        
        @(posedge clk);
        en_trace = 1;
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
    
    buckfast_test_rom #(
         .width_p(trace_width + 4)
        ,.addr_width_p(`BSG_SAFE_CLOG2(num_traces))
    ) test_rom(
         .addr_i(rom_trace_addr)
        ,.data_o(rom_trace_data)
    );
    
    assign parser_tcp_rx_hdr_val = trace_input_val;
    assign trace_input_rdy = tcp_parser_rx_rdy;
    assign parser_tcp_rx_src_ip = trace_input[trace_width-1 -: `IP_ADDR_W];
    assign parser_tcp_rx_dst_ip = trace_input[trace_width-1-`IP_ADDR_W -: `IP_ADDR_W];
    assign parser_tcp_rx_tcp_hdr = trace_input[trace_width-1-(2*`IP_ADDR_W) -: `TCP_HDR_W];
    assign parser_tcp_rx_payload_val = parser_tcp_rx_payload_len != 0;
    assign parser_tcp_rx_payload_addr = 
        trace_input[trace_width-1-(2*`IP_ADDR_W)-`TCP_HDR_W 
                     -: `PAYLOAD_ENTRY_ADDR_W];
    assign parser_tcp_rx_payload_len =
        trace_input[trace_width-1-(2*`IP_ADDR_W)-`TCP_HDR_W-`PAYLOAD_ENTRY_ADDR_W
                    -: `PAYLOAD_ENTRY_LEN_W];


    assign trace_resp_val = tcp_parser_tx_val;
    assign parser_tcp_tx_rdy = trace_resp_rdy;
    assign trace_resp = {tcp_parser_tx_src_ip, tcp_parser_tx_dst_ip, tcp_parser_tx_tcp_hdr,
                         tcp_parser_tx_payload.pkt_payload_addr, 
                         tcp_parser_tx_payload.pkt_payload_len};

    buckfast_trace_test_top DUT (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.parser_tcp_rx_hdr_val     (parser_tcp_rx_hdr_val      )
        ,.tcp_parser_rx_rdy         (tcp_parser_rx_rdy          )
        ,.parser_tcp_rx_src_ip      (parser_tcp_rx_src_ip       )
        ,.parser_tcp_rx_dst_ip      (parser_tcp_rx_dst_ip       )
        ,.parser_tcp_rx_tcp_hdr     (parser_tcp_rx_tcp_hdr      )

        ,.parser_tcp_rx_payload_val (parser_tcp_rx_payload_val  )
        ,.parser_tcp_rx_payload_addr(parser_tcp_rx_payload_addr )
        ,.parser_tcp_rx_payload_len (parser_tcp_rx_payload_len  )
        
        // For sending out a complete packet
        ,.tcp_parser_tx_val         (tcp_parser_tx_val          )
        ,.parser_tcp_tx_rdy         (parser_tcp_tx_rdy          )
        ,.tcp_parser_tx_src_ip      (tcp_parser_tx_src_ip       )
        ,.tcp_parser_tx_dst_ip      (tcp_parser_tx_dst_ip       )
        ,.tcp_parser_tx_tcp_hdr     (tcp_parser_tx_tcp_hdr      )
        ,.tcp_parser_tx_payload     (tcp_parser_tx_payload      )
    );

endmodule
