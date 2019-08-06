`include "packet_defs.vh"
`include "state_defs.vh"
`include "soc_defs.vh"

module tcp_stream_formatter (
     input clk
    ,input rst

    // IP header in
    ,input                                  src_tcp_formatter_rx_hdr_val
    ,input          [`IP_HDR_W-1:0]         src_tcp_formatter_rx_ip_hdr
    ,output logic                           tcp_formatter_src_rx_hdr_rdy

    // Data stream in from MAC-side
    ,input                                  src_tcp_formatter_rx_data_val
    ,output logic                           tcp_formatter_src_rx_data_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_tcp_formatter_rx_data
    ,input                                  src_tcp_formatter_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_tcp_formatter_rx_padbytes
    
    // Headers and data out
    ,output logic                           tcp_formatter_dst_rx_hdr_val
    ,output logic   [`IP_HDR_W-1:0]         tcp_formatter_dst_rx_ip_hdr
    ,output logic   [`TCP_HDR_W-1:0]        tcp_formatter_dst_rx_tcp_hdr
    ,output logic   [`TOT_LEN_W-1:0]        tcp_formatter_dst_rx_tcp_payload_len
    ,input                                  dst_tcp_formatter_rx_hdr_rdy

    ,output logic                           tcp_formatter_dst_rx_data_val
    ,input                                  dst_tcp_formatter_rx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  tcp_formatter_dst_rx_data
    ,output logic                           tcp_formatter_dst_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   tcp_formatter_dst_rx_padbytes
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        TCP_HDR_DRAIN = 3'd1,
        FIRST_DATA = 3'd2,
        DATA_OUTPUT = 3'd3,
        DATA_OUTPUT_LAST = 3'd4,
        DATA_WAIT_TX_FIN = 3'd5,
        UNDEF = 'X
    } data_state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        HDR_OUTPUT = 2'd1,
        HDR_WAIT_TX_FIN = 2'd2,
        UND = 'X
    } hdr_state_e;
    
    data_state_e data_state_reg;
    data_state_e data_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;
    
    ip_pkt_hdr ip_hdr_struct_reg;
    ip_pkt_hdr ip_hdr_struct_next;
    ip_pkt_hdr ip_hdr_cast;

    tcp_pkt_hdr tcp_hdr_struct_reg;
    tcp_pkt_hdr tcp_hdr_struct_next;
    tcp_pkt_hdr tcp_hdr_cast;
    
    logic   [`TOT_LEN_W-1:0]    tcp_hdr_bytes_left_reg;
    logic   [`TOT_LEN_W-1:0]    tcp_hdr_bytes_left_next;
    
    // because the 256 bits of data won't be aligned exactly, we have to grab data from the end
    // of one data line and the beginning of another
    logic   [`MAC_INTERFACE_W -1:0]  realign_upper_reg;
    logic   [`MAC_INTERFACE_W -1:0]  realign_upper_next;
    logic   [`MAC_INTERFACE_W -1:0]  realign_lower_reg;
    logic   [`MAC_INTERFACE_W -1:0]  realign_lower_next;

    logic   [(`MAC_INTERFACE_W * 2)-1:0]  realigned_data;
    logic   [`TOT_LEN_W-1:0]   realign_shift;
    logic   [`TOT_LEN_W-1:0]   padbytes_temp;

    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_next;
    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_reg;

    logic   [`TOT_LEN_W-1:0]            bytes_left_reg;
    logic   [`TOT_LEN_W-1:0]            bytes_left_next;

    logic   [`TOT_LEN_W-1:0]            tcp_payload_len;

    assign ip_hdr_cast = src_tcp_formatter_rx_ip_hdr;
    assign tcp_payload_len = ip_hdr_cast.tot_len - (ip_hdr_cast.ip_hdr_len << 2) 
                                - (tcp_hdr_cast.raw_data_offset << 2);

    assign realign_shift = tcp_hdr_bytes_left_reg << 3;
    assign realigned_data = {realign_upper_reg, realign_lower_reg} << realign_shift;

    assign padbytes_temp = tcp_hdr_bytes_left_reg + data_padbytes_reg;
    
    assign tcp_hdr_cast = src_tcp_formatter_rx_data[`MAC_INTERFACE_W-1 -: `TCP_HDR_W];

    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            hdr_state_reg <= WAITING;
            ip_hdr_struct_reg <= '0;
            tcp_hdr_struct_reg <= '0;
            realign_upper_reg <= '0;
            realign_lower_reg <= '0;
            tcp_hdr_bytes_left_reg <= '0;
            data_padbytes_reg <= '0;
            bytes_left_reg <= '0;
        end
        else begin
            data_state_reg <= data_state_next;
            hdr_state_reg <= hdr_state_next;
            ip_hdr_struct_reg <= ip_hdr_struct_next;
            tcp_hdr_struct_reg <= tcp_hdr_struct_next;
            realign_upper_reg <= realign_upper_next;
            realign_lower_reg <= realign_lower_next;
            tcp_hdr_bytes_left_reg <= tcp_hdr_bytes_left_next;
            data_padbytes_reg <= data_padbytes_next;
            bytes_left_reg <= bytes_left_next;
        end
    end

    always_comb begin
        data_state_next = data_state_reg;
        tcp_formatter_src_rx_data_rdy = 1'b0;
        realign_upper_next = realign_upper_reg;
        realign_lower_next = realign_lower_reg;
        tcp_hdr_bytes_left_next = tcp_hdr_bytes_left_reg;
        tcp_hdr_struct_next = tcp_hdr_struct_reg;

        tcp_formatter_dst_rx_data = '0;
        tcp_formatter_dst_rx_data_val = 1'b0;
        tcp_formatter_dst_rx_last = 1'b0;
        tcp_formatter_dst_rx_padbytes = '0;

        bytes_left_next = bytes_left_reg;
        data_padbytes_next = data_padbytes_reg;
        case (data_state_reg)
            READY: begin
                tcp_formatter_src_rx_data_rdy = 1'b1;
                tcp_hdr_bytes_left_next = tcp_hdr_cast.raw_data_offset << 2;

                if (src_tcp_formatter_rx_data_val) begin
                    tcp_hdr_struct_next = tcp_hdr_cast;
                    // if the tcp header doesn't end in the first line
                    if (tcp_hdr_cast.raw_data_offset > ((`MAC_INTERFACE_W/8)/4)) begin
                        data_state_next = TCP_HDR_DRAIN;
                    end
                    else begin
                        realign_upper_next = src_tcp_formatter_rx_data;
                        if (src_tcp_formatter_rx_last) begin
                            if (tcp_payload_len == 0) begin
                                data_state_next = DATA_WAIT_TX_FIN;
                            end
                            else begin
                                data_padbytes_next = src_tcp_formatter_rx_padbytes;
                                bytes_left_next = (`MAC_INTERFACE_W/8) - tcp_hdr_cast.raw_data_offset << 2
                                                + (`MAC_INTERFACE_W/8) - src_tcp_formatter_rx_padbytes;
                                data_state_next = DATA_OUTPUT_LAST;    
                            end
                        end
                        else begin
                            data_state_next = FIRST_DATA;
                        end
                    end
                end
                else begin
                    data_state_next = READY;
                end
            end
            TCP_HDR_DRAIN: begin
                tcp_formatter_src_rx_data_rdy = 1'b1;

                // since the TCP header can be at most 60 bytes, the end must be in the second
                // line of data
                if (src_tcp_formatter_rx_data_val) begin
                    tcp_hdr_bytes_left_next = tcp_hdr_bytes_left_reg - (`MAC_INTERFACE_W/8);
                    if (src_tcp_formatter_rx_last) begin
                        data_state_next = DATA_WAIT_TX_FIN;    
                    end
                    else begin
                        realign_upper_next = src_tcp_formatter_rx_data;
                        data_state_next = FIRST_DATA;
                    end
                end
                else begin
                    data_state_next = TCP_HDR_DRAIN;
                end
            end
            FIRST_DATA: begin
                tcp_formatter_src_rx_data_rdy = 1'b1;

                if (src_tcp_formatter_rx_data_val) begin
                    realign_lower_next = src_tcp_formatter_rx_data;

                    if (src_tcp_formatter_rx_last) begin
                        data_padbytes_next = src_tcp_formatter_rx_padbytes;
                        bytes_left_next = (`MAC_INTERFACE_W/8) - tcp_hdr_bytes_left_reg
                                        + (`MAC_INTERFACE_W/8) - src_tcp_formatter_rx_padbytes;
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        data_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    data_state_next = FIRST_DATA;
                end
            end
            DATA_OUTPUT: begin
                tcp_formatter_src_rx_data_rdy = dst_tcp_formatter_rx_data_rdy;

                tcp_formatter_dst_rx_data = 
                    realigned_data[(`MAC_INTERFACE_W*2)-1 -: `MAC_INTERFACE_W];
                tcp_formatter_dst_rx_data_val = src_tcp_formatter_rx_data_val;

                if (dst_tcp_formatter_rx_data_rdy & src_tcp_formatter_rx_data_val) begin
                    realign_upper_next = realign_lower_reg;
                    realign_lower_next = src_tcp_formatter_rx_data;
                    if (src_tcp_formatter_rx_last) begin
                        data_padbytes_next = src_tcp_formatter_rx_padbytes;
                        bytes_left_next = (`MAC_INTERFACE_W/8) - tcp_hdr_bytes_left_reg
                                        + (`MAC_INTERFACE_W/8) - src_tcp_formatter_rx_padbytes;
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        data_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    data_state_next = DATA_OUTPUT;
                end
            end
            DATA_OUTPUT_LAST: begin
                tcp_formatter_src_rx_data_rdy = 1'b0;

                tcp_formatter_dst_rx_last = bytes_left_reg <= (`MAC_INTERFACE_W/8);
                tcp_formatter_dst_rx_padbytes = padbytes_temp[`MAC_PADBYTES_W-1:0];
                tcp_formatter_dst_rx_data_val = 1'b1;
                tcp_formatter_dst_rx_data = 
                    realigned_data[(`MAC_INTERFACE_W*2)-1 -: `MAC_INTERFACE_W];

                if (dst_tcp_formatter_rx_data_rdy) begin
                    // if the number of bytes left is greater than the bus width, we have to go
                    // around again
                    if (bytes_left_reg > (`MAC_INTERFACE_W/8)) begin
                        realign_upper_next = realign_lower_reg;
                        realign_lower_next = '0;

                        bytes_left_next = bytes_left_reg - (`MAC_INTERFACE_W/8);
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        bytes_left_next = '0;
                        data_state_next = DATA_WAIT_TX_FIN;
                    end
                end
                else begin
                    data_state_next = DATA_OUTPUT_LAST;
                end
            end
            DATA_WAIT_TX_FIN: begin
                tcp_formatter_src_rx_data_rdy = 1'b0;
                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    data_state_next = READY;
                end
                else begin
                    data_state_next = DATA_WAIT_TX_FIN;
                end
            end
            default: begin
                data_state_next = UNDEF;
                tcp_formatter_src_rx_data_rdy = 'X;
                realign_upper_next = 'X;
                realign_lower_next = 'X;
                tcp_hdr_bytes_left_next = 'X;

                tcp_formatter_dst_rx_data = 'X;
                tcp_formatter_dst_rx_data_val = 'X;
                tcp_formatter_dst_rx_last = 'X;
                tcp_formatter_dst_rx_padbytes = 'X;

                bytes_left_next = 'X;
                data_padbytes_next = 'X;
            end
        endcase
    end


    always_comb begin
        ip_hdr_struct_next = ip_hdr_struct_reg;
        tcp_formatter_src_rx_hdr_rdy = 1'b0;
        hdr_state_next = hdr_state_reg;
        tcp_formatter_dst_rx_hdr_val = 1'b0;
        tcp_formatter_dst_rx_ip_hdr = '0;
        tcp_formatter_dst_rx_tcp_hdr = '0;
        tcp_formatter_dst_rx_tcp_payload_len = '0;
        case (hdr_state_reg)
            WAITING: begin
                tcp_formatter_src_rx_hdr_rdy = 1'b1;
                
                if (src_tcp_formatter_rx_hdr_val) begin
                    ip_hdr_struct_next = src_tcp_formatter_rx_ip_hdr;
                    hdr_state_next = HDR_OUTPUT;
                end
                else begin
                    ip_hdr_struct_next = ip_hdr_struct_reg;
                    hdr_state_next = hdr_state_reg;
                end
            end
            HDR_OUTPUT: begin
                tcp_formatter_src_rx_hdr_rdy = 1'b0;
                // don't assert valid until we've captured the TCP hdr
                tcp_formatter_dst_rx_hdr_val = data_state_reg != READY;

                tcp_formatter_dst_rx_ip_hdr = ip_hdr_struct_reg;
                tcp_formatter_dst_rx_tcp_hdr = tcp_hdr_struct_reg;

                // TODO: do this somewhere else once we do checksum properly
                // the length of the payload is the total length of the ip packet minus 
                // the length of the ip header and the length of the tcp header. 
                // ip and tcp header lengths are given in multiples of 4 bytes
                tcp_formatter_dst_rx_tcp_payload_len = ip_hdr_struct_reg.tot_len - 
                                                  (ip_hdr_struct_reg.ip_hdr_len << 2) -
                                                  (tcp_hdr_struct_reg.raw_data_offset << 2);

                if (dst_tcp_formatter_rx_hdr_rdy & (data_state_reg != READY)) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
                else begin
                    hdr_state_next = HDR_OUTPUT;
                end
            end
            HDR_WAIT_TX_FIN: begin
                tcp_formatter_src_rx_hdr_rdy = 1'b0;
                if (data_state_reg == DATA_WAIT_TX_FIN) begin
                    hdr_state_next = WAITING;
                end
                else begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
            end
            default: begin
                hdr_state_next = UND;
                ip_hdr_struct_next = 'X;
                tcp_formatter_src_rx_hdr_rdy = 'X;
                tcp_formatter_dst_rx_ip_hdr = 'X;
                tcp_formatter_dst_rx_tcp_hdr = 'X;
            end
        endcase
    end

endmodule
