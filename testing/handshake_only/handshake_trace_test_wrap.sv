`include "packet_defs.vh"
module handshake_trace_test_wrap (
     input  clk
    ,input  rst_n
    ,output done
);
    parameter SRC_BIT_WIDTH = `IP_ADDR_WIDTH 
                              + `IP_ADDR_WIDTH + `TCP_HEADER_WIDTH;
    parameter SRC_ENTRIES = 3;
    parameter SRC_LOG2_ENTRIES = $clog2(SRC_ENTRIES + 1);
    
    parameter SINK_BIT_WIDTH = `IP_ADDR_WIDTH 
                               + `IP_ADDR_WIDTH + `TCP_HEADER_WIDTH;
    parameter SINK_ENTRIES = 2;
    parameter SINK_LOG2_ENTRIES = $clog2(SINK_ENTRIES + 1);

    logic                                       parser_tcp_rx_hdr_val;
    logic                                       tcp_parser_rx_rdy;
    logic   [`IP_ADDR_WIDTH-1:0]                parser_tcp_rx_src_ip;
    logic   [`IP_ADDR_WIDTH-1:0]                parser_tcp_rx_dst_ip;
    logic   [`TCP_HEADER_WIDTH-1:0]             parser_tcp_rx_tcp_hdr;

    logic                                       parser_tcp_rx_payload_val;
    logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] parser_tcp_rx_payload_addr;
    logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  parser_tcp_rx_payload_len;
    
    logic                                       tcp_parser_tx_val;
    logic                                       parser_tcp_tx_rdy;
    logic   [`IP_ADDR_WIDTH-1:0]                tcp_parser_tx_src_ip;
    logic   [`IP_ADDR_WIDTH-1:0]                tcp_parser_tx_dst_ip;
    logic   [`TCP_HEADER_WIDTH-1:0]             tcp_parser_tx_tcp_hdr;
    logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] tcp_parser_tx_payload_addr;
    logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  tcp_parser_tx_payload_len;
    
    logic                           src_rdy;
    logic   [SRC_BIT_WIDTH-1:0]     src_bits;
    logic                           src_val;
    logic                           src_done;

    logic   [SINK_BIT_WIDTH-1:0]    sink_bits;
    logic                           sink_val;
    logic                           sink_rdy;
    logic                           sink_done;

    assign done = src_done & sink_done;  

    // Source module
    test_src
    #(
        .BIT_WIDTH (SRC_BIT_WIDTH),
        .ENTRIES (SRC_ENTRIES),
        .LOG2_ENTRIES (SRC_LOG2_ENTRIES)
    ) src
    (
         .clk   (clk        )
        ,.rst_n (rst_n      )
        ,.rdy   (src_rdy    )
        ,.bits  (src_bits   )
        ,.val   (src_val    )
        ,.done  (src_done   )
    );
    
    assign parser_tcp_rx_hdr_val = src_val;
    assign src_rdy = tcp_parser_rx_rdy;
    assign parser_tcp_rx_src_ip = src_bits[SRC_BIT_WIDTH-1 -: `IP_ADDR_WIDTH];
    assign parser_tcp_rx_dst_ip = src_bits[SRC_BIT_WIDTH-1-`IP_ADDR_WIDTH -: `IP_ADDR_WIDTH];
    assign parser_tcp_rx_tcp_hdr = src_bits[SRC_BIT_WIDTH-1-(2*`IP_ADDR_WIDTH) -: `TCP_HEADER_WIDTH];
    
    assign parser_tcp_rx_payload_val = 1'b0;
    assign parser_tcp_rx_payload_len = '0;
    assign parser_tcp_rx_payload_addr = '0;

    handshake_trace_test_top DUT (
         .clk   (clk)
        ,.rst   (~rst_n)
        
        ,.parser_tcp_rx_hdr_val         (parser_tcp_rx_hdr_val      )
        ,.tcp_parser_rx_rdy             (tcp_parser_rx_rdy          )
        ,.parser_tcp_rx_src_ip          (parser_tcp_rx_src_ip       )
        ,.parser_tcp_rx_dst_ip          (parser_tcp_rx_dst_ip       )
        ,.parser_tcp_rx_tcp_hdr         (parser_tcp_rx_tcp_hdr      )
                                                                    
        ,.parser_tcp_rx_payload_val     (parser_tcp_rx_payload_val  )
        ,.parser_tcp_rx_payload_addr    (parser_tcp_rx_payload_addr )
        ,.parser_tcp_rx_payload_len     (parser_tcp_rx_payload_len  )
        
        // For sending out a complete packet
        ,.tcp_parser_tx_val             (tcp_parser_tx_val          )
        ,.parser_tcp_tx_rdy             (parser_tcp_tx_rdy          )
        ,.tcp_parser_tx_src_ip          (tcp_parser_tx_src_ip       )
        ,.tcp_parser_tx_dst_ip          (tcp_parser_tx_dst_ip       )
        ,.tcp_parser_tx_tcp_hdr         (tcp_parser_tx_tcp_hdr      )
        ,.tcp_parser_tx_payload_addr    (tcp_parser_tx_payload_addr )
        ,.tcp_parser_tx_payload_len     (tcp_parser_tx_payload_len  )
    );

    assign sink_val = tcp_parser_tx_val;
    assign parser_tcp_tx_rdy = sink_rdy;
    assign sink_bits = {tcp_parser_tx_src_ip, tcp_parser_tx_dst_ip, tcp_parser_tx_tcp_hdr};

    // Sink module
    test_sink
    #(
        .VERBOSITY (1),
        .BIT_WIDTH (SINK_BIT_WIDTH),
        .ENTRIES (SINK_ENTRIES),
        .LOG2_ENTRIES (SINK_LOG2_ENTRIES)
    ) sink
    (
         .clk               (clk        )
        ,.rst_n             (rst_n      )
        ,.bits              (sink_bits  )
        ,.val               (sink_val   )
        ,.rdy               (sink_rdy   )
        ,.out_data_popped   (           )
        ,.done              (sink_done  )
    );
endmodule
