module dummy_tonic (
     input clk
    ,input rst

    ,input                               parser_rx_tcp_hdr_val
    ,output                              tcp_parser_rx_rdy
    ,input   [`IP_ADDR_WIDTH-1:0]        parser_rx_tcp_src_ip
    ,input   [`IP_ADDR_WIDTH-1:0]        parser_rx_tcp_dst_ip
    ,input   [`TCP_HEADER_WIDTH-1:0]     parser_rx_tcp_tcp_hdr

    ,input   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] parser_rx_tcp_payload_addr
    ,input   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  parser_rx_tcp_payload_len
    
    
    ,output                                     tcp_parser_tx_val
    ,input                                      parser_tx_tcp_rdy
    ,output [`IP_HEADER_WIDTH-1:0]              tcp_parser_tx_ip_header
    ,output [`TCP_HEADER_WIDTH-1:0]             tcp_parser_tx_tcp_header

    ,output [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] tcp_parser_tx_payload_addr
    ,output [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  tcp_parser_tx_payload_len



);


    logic                               parser_rx_tcp_hdr_val_reg;
    logic   [`IP_ADDR_WIDTH-1:0]        parser_rx_tcp_src_ip_reg;
    logic   [`IP_ADDR_WIDTH-1:0]        parser_rx_tcp_dst_ip_reg;
    logic   [`TCP_HEADER_WIDTH-1:0]     parser_rx_tcp_tcp_hdr_reg;

    logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] parser_rx_tcp_payload_addr_reg;
    logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  parser_rx_tcp_payload_len_reg;
    
    ip_packet_header ip_header;

    assign ip_header.ip_hdr_len = `IHL_WIDTH'd5;
    assign ip_header.ip_version = `IP_VERSION_WIDTH'd4;
    assign ip_header.tos = 'b0;
    assign ip_header.tot_len = `IP_HEADER_BYTES + `TCP_HEADER_BYTES + parser_rx_tcp_payload_len_reg;
    assign ip_header.id = `ID_WIDTH'd54321;
    assign ip_header.frag_offset = 'b0;
    assign ip_header.ttl = {(`TTL_WIDTH){1'b1}};
    assign ip_header.protocol_no = `IPPROTO_TCP;
    assign ip_header.chksum = 'b0;
    assign ip_header.source_addr = parser_rx_tcp_dst_ip_reg;
    assign ip_header.dest_addr = parser_rx_tcp_src_ip_reg;

    tcp_packet_header tcp_header;
    tcp_packet_header rx_tcp_header;

    assign rx_tcp_header = parser_rx_tcp_tcp_hdr_reg;

    assign tcp_header.src_port = rx_tcp_header.dst_port;
    assign tcp_header.dst_port = rx_tcp_header.src_port;
    assign tcp_header.seq_num = rx_tcp_header.ack_num;
    assign tcp_header.ack_num = rx_tcp_header.seq_num + 1;
    assign tcp_header.raw_data_offset = `DATA_OFFSET_WIDTH'd6;
    assign tcp_header.reserved = 'b0;
    assign tcp_header.flags = `TCP_ACK | `TCP_PSH;
    assign tcp_header.win_size = '1;
    assign tcp_header.chksum = 'b0;
    assign tcp_header.urg_pointer = 'b0;
    
    assign tcp_parser_rx_rdy = parser_tx_tcp_rdy;

    
    assign tcp_parser_tx_val = parser_rx_tcp_hdr_val_reg & (parser_rx_tcp_payload_len_reg > 0);
    assign tcp_parser_tx_ip_header = ip_header;
    assign tcp_parser_tx_tcp_header = tcp_header;
    assign tcp_parser_tx_payload_addr = parser_rx_tcp_payload_addr_reg;
    assign tcp_parser_tx_payload_len = parser_rx_tcp_payload_len_reg;


    always_ff @(posedge clk) begin
        if (rst) begin
            parser_rx_tcp_hdr_val_reg <= 1'b0;
            parser_rx_tcp_src_ip_reg <= 'b0;
            parser_rx_tcp_dst_ip_reg <= 'b0;
            parser_rx_tcp_tcp_hdr_reg <= 'b0;
            parser_rx_tcp_payload_addr_reg <= 'b0;
            parser_rx_tcp_payload_len_reg <= 'b0;
        end
        else begin
            if (parser_tx_tcp_rdy) begin
                parser_rx_tcp_hdr_val_reg <= parser_rx_tcp_hdr_val;
                parser_rx_tcp_src_ip_reg <= parser_rx_tcp_src_ip;
                parser_rx_tcp_dst_ip_reg <= parser_rx_tcp_dst_ip;
                parser_rx_tcp_tcp_hdr_reg <= parser_rx_tcp_tcp_hdr;
                parser_rx_tcp_payload_addr_reg <= parser_rx_tcp_payload_addr;
                parser_rx_tcp_payload_len_reg <= parser_rx_tcp_payload_len;
            end
        end
    end

endmodule
