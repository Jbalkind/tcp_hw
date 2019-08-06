`include "soc_defs.vh"
`include "packet_defs.vh"

import packet_struct_pkg::*;
module rx_tcp_format_output_ctrl #(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
)(
     input clk
    ,input rst
    
    /*
     * Data Input
     */ 
    ,input          [DATA_WIDTH-1:0]        resp_tdata
    ,input          [KEEP_WIDTH-1:0]        resp_tkeep
    ,input                                  resp_tval
    ,output logic                           resp_trdy
    ,input                                  resp_tlast
    ,input          [`TCP_CHKSUM_W-1:0]     resp_csum
    
    ,output logic                           tcp_format_dst_rx_hdr_val
    ,input                                  dst_tcp_format_rx_hdr_rdy
    ,output logic   [`IP_ADDR_W-1:0]        tcp_format_dst_rx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        tcp_format_dst_rx_dst_ip
    ,output logic   [`TOT_LEN_W-1:0]        tcp_format_dst_rx_tcp_tot_len
    ,output tcp_pkt_hdr                     tcp_format_dst_rx_tcp_hdr
    
    ,output logic                           tcp_format_dst_rx_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]  tcp_format_dst_rx_data
    ,output logic                           tcp_format_dst_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   tcp_format_dst_rx_padbytes
    ,input                                  dst_tcp_format_rx_data_rdy
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        TCP_HDR_DRAIN = 3'd1,
        FIRST_DATA = 3'd2,
        DATA_OUTPUT = 3'd3,
        DATA_OUTPUT_LAST = 3'd4,
        DRAIN = 3'd5,
        DATA_WAIT_TX_FIN = 3'd6,
        UNDEF = 'X
    } parse_state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        OUTPUT = 2'd1,
        HDR_WAIT_TX_FIN = 2'd2,
        UND = 'X
    } hdr_state_e;

    parse_state_e parse_state_reg;
    parse_state_e parse_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;

    tcp_pkt_hdr tcp_hdr_struct_reg;
    tcp_pkt_hdr tcp_hdr_struct_next;
    tcp_pkt_hdr tcp_hdr_struct_cast;

    chksum_pseudo_hdr chksum_pseudo_hdr_reg;
    chksum_pseudo_hdr chksum_pseudo_hdr_next;
    chksum_pseudo_hdr chksum_pseudo_hdr_cast;
    
    logic [`TOT_LEN_W-1:0]  hdr_bytes_rem_reg;
    logic [`TOT_LEN_W-1:0]  hdr_bytes_rem_next;
    
    logic chksum_match;
    
    // because the 256 bits of data might not be aligned exactly, we have to grab data from the end
    // of one data line and the beginning of another
    logic   [`MAC_INTERFACE_W -1:0]  realign_upper_reg;
    logic   [`MAC_INTERFACE_W -1:0]  realign_upper_next;
    logic   [`MAC_INTERFACE_W -1:0]  realign_lower_reg;
    logic   [`MAC_INTERFACE_W -1:0]  realign_lower_next;
    
    logic   [(`MAC_INTERFACE_W * 2)-1:0]  realigned_data;
    logic   [`TOT_LEN_W-1:0]   realign_shift;
    
    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_next;
    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_reg;

    logic   [`TOT_LEN_W-1:0]            bytes_left_reg;
    logic   [`TOT_LEN_W-1:0]            bytes_left_next;
    logic   [`TOT_LEN_W-1:0]            payload_size_calc;

    assign tcp_hdr_struct_cast = 
                    resp_tdata[(DATA_WIDTH - CHKSUM_PSEUDO_HDR_W)-1 -: TCP_HDR_W];
    assign chksum_pseudo_hdr_cast = resp_tdata[DATA_WIDTH-1 -: CHKSUM_PSEUDO_HDR_W];

    // if a checksum is correct, then the checksum calculated with it in the field (instead of
    // zeroes) is all 1s, so the 1's complement (what the module outputs) is all 0s
    assign chksum_match = tcp_hdr_struct_cast.chksum == 0;
    
    assign realign_shift = hdr_bytes_rem_reg << 3;
    assign realigned_data = {realign_upper_reg, realign_lower_reg} << realign_shift;

    assign payload_size_calc = chksum_pseudo_hdr_cast.length - 
                              (tcp_hdr_struct_cast.raw_data_offset << 2);

    always_ff @(posedge clk) begin
        if (rst) begin
            parse_state_reg <= READY;
            hdr_state_reg <= WAITING;
            tcp_hdr_struct_reg <= '0;
            chksum_pseudo_hdr_reg <= '0;
            hdr_bytes_rem_reg <= '0;
            bytes_left_reg <= '0;
            realign_upper_reg <= '0;
            realign_lower_reg <= '0;
        end
        else begin
            parse_state_reg <= parse_state_next;
            hdr_state_reg <= hdr_state_next;
            tcp_hdr_struct_reg <= tcp_hdr_struct_next;
            chksum_pseudo_hdr_reg <= chksum_pseudo_hdr_next;
            hdr_bytes_rem_reg <= hdr_bytes_rem_next;
            bytes_left_reg <= bytes_left_next;
            realign_upper_reg <= realign_upper_next;
            realign_lower_reg <= realign_lower_next;
        end
    end

    always_comb begin
        resp_trdy = 1'b0;
        parse_state_next = parse_state_reg;

        tcp_hdr_struct_next = tcp_hdr_struct_reg;
        chksum_pseudo_hdr_next = chksum_pseudo_hdr_reg;

        hdr_bytes_rem_next = hdr_bytes_rem_reg;

        realign_upper_next = realign_upper_reg;
        realign_lower_next = realign_lower_reg;
                
        tcp_format_dst_rx_data_val = 1'b0;
        tcp_format_dst_rx_last = 1'b0;
        tcp_format_dst_rx_padbytes = '0;
        tcp_format_dst_rx_data = '0;

        bytes_left_next = bytes_left_reg;
        case (parse_state_reg) 
            READY: begin
                resp_trdy = 1'b1;
                if (resp_tval) begin
                    if (chksum_match) begin
                        tcp_hdr_struct_next = tcp_hdr_struct_cast;
                        chksum_pseudo_hdr_next = chksum_pseudo_hdr_cast;
                        bytes_left_next = payload_size_calc;

                        // if the tcp header isn't completely contained in the first line
                        if ((tcp_hdr_struct_cast.raw_data_offset << 2) > 
                            (`MAC_INTERFACE_BYTES - CHKSUM_PSEUDO_HDR_BYTES)) begin
                            hdr_bytes_rem_next = (CHKSUM_PSEUDO_HDR_BYTES +
                                                 (tcp_hdr_struct_cast.raw_data_offset << 2)) - 
                                                 `MAC_INTERFACE_BYTES;
                            parse_state_next = TCP_HDR_DRAIN;
                        end
                        else begin
                            hdr_bytes_rem_next = CHKSUM_PSEUDO_HDR_BYTES + 
                                                 (tcp_hdr_struct_cast.raw_data_offset << 2);
                            realign_upper_next = resp_tdata;
                            // if this is also the last line
                            if (resp_tlast) begin
                                if (payload_size_calc == 0) begin
                                    parse_state_next = DATA_WAIT_TX_FIN;
                                end
                                else begin
                                    parse_state_next = DATA_OUTPUT_LAST;
                                end
                            end
                            else begin
                                parse_state_next = FIRST_DATA;
                            end
                        end
                    end
                    else begin
                        parse_state_next = DRAIN;
                    end
                end
                else begin
                    parse_state_next = READY;
                end
            end
            TCP_HDR_DRAIN: begin
                resp_trdy = 1'b1;
                
                if (resp_tval) begin
                    realign_upper_next = resp_tdata;
                    // if the header will end in this line
                    if (hdr_bytes_rem_reg <= `MAC_INTERFACE_BYTES) begin
                        // if this is also the last line and there's no data to send
                        if (resp_tlast) begin
                            parse_state_next = bytes_left_reg > 0 
                                               ? DATA_OUTPUT_LAST
                                               : DATA_WAIT_TX_FIN;
                        end
                        else begin
                            parse_state_next = FIRST_DATA;
                        end
                    end
                    // otherwise, we need to consume yet another line
                    else begin
                        hdr_bytes_rem_next = hdr_bytes_rem_reg - `MAC_INTERFACE_BYTES;
                        parse_state_next = TCP_HDR_DRAIN;
                    end
                end
                else begin
                    parse_state_next = TCP_HDR_DRAIN;
                end
            end
            FIRST_DATA: begin
                resp_trdy = 1'b1;
                if (resp_tval) begin
                    realign_lower_next = resp_tdata;
                    
                    if (resp_tlast) begin
                        parse_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        parse_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    parse_state_next = FIRST_DATA;
                end
            end
            DATA_OUTPUT: begin
                resp_trdy = dst_tcp_format_rx_data_rdy;

                tcp_format_dst_rx_data = 
                    realigned_data[(`MAC_INTERFACE_W*2)-1 -: `MAC_INTERFACE_W];

                tcp_format_dst_rx_data_val = resp_tval;

                if (dst_tcp_format_rx_data_rdy & resp_tval) begin
                    realign_upper_next = realign_lower_reg;
                    realign_lower_next = resp_tdata;
                    bytes_left_next = bytes_left_reg - (`MAC_INTERFACE_BYTES);

                    if (resp_tlast) begin
                        parse_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        parse_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    parse_state_next = DATA_OUTPUT;
                end
            end
            DATA_OUTPUT_LAST: begin
                resp_trdy = 1'b0;

                tcp_format_dst_rx_data_val = 1'b1;
                tcp_format_dst_rx_last = bytes_left_reg <= (`MAC_INTERFACE_BYTES);
                tcp_format_dst_rx_padbytes = bytes_left_reg <= (`MAC_INTERFACE_BYTES)
                                                 ? `MAC_INTERFACE_BYTES - bytes_left_reg
                                                 : '0;
                tcp_format_dst_rx_data = 
                    realigned_data[(`MAC_INTERFACE_W*2)-1 -: `MAC_INTERFACE_W];

                if (dst_tcp_format_rx_data_rdy) begin
                    // if the number of bytes left is greater than the bus width, we have to
                    // go around again
                    if (bytes_left_reg > `MAC_INTERFACE_BYTES) begin
                        realign_upper_next = realign_lower_reg;
                        realign_lower_next = '0;

                        bytes_left_next = bytes_left_reg - (`MAC_INTERFACE_BYTES);
                        parse_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        bytes_left_next = '0;
                        parse_state_next = DATA_WAIT_TX_FIN;
                    end
                end
                else begin
                    parse_state_next = DATA_OUTPUT_LAST;
                end
            end
            // the checksum was wrong, so we just want to drain the unit of data
            DRAIN: begin
                resp_trdy = 1'b1;
                tcp_format_dst_rx_data_val = 1'b0;

                if (resp_tval & resp_tlast) begin
                    parse_state_next = DATA_WAIT_TX_FIN;
                end
                else begin
                    parse_state_next = DRAIN;
                end
            end
            DATA_WAIT_TX_FIN: begin
                resp_trdy = 1'b0;

                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    parse_state_next = READY;
                end
                else begin
                    parse_state_next = DATA_WAIT_TX_FIN;
                end
            end
            default: begin
            end
        endcase
    end

    always_comb begin
        hdr_state_next = hdr_state_reg;

        tcp_format_dst_rx_hdr_val = 1'b0;
        tcp_format_dst_rx_src_ip = '0;
        tcp_format_dst_rx_dst_ip = '0;
        tcp_format_dst_rx_tcp_tot_len = '0;
        tcp_format_dst_rx_tcp_hdr = '0;
        case (hdr_state_reg) 
            WAITING: begin
                if ((parse_state_reg == READY) & resp_tval) begin
                    // if the chksums match, go to output
                    if (chksum_match) begin
                        hdr_state_next = OUTPUT;
                    end
                    // otherwise, just wait for the parsing state machine to finish draining
                    // the checksum unit
                    else begin
                        hdr_state_next = HDR_WAIT_TX_FIN;
                    end
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            OUTPUT: begin
                tcp_format_dst_rx_hdr_val = 1'b1;
                tcp_format_dst_rx_src_ip = chksum_pseudo_hdr_reg.source_addr;
                tcp_format_dst_rx_dst_ip = chksum_pseudo_hdr_reg.dest_addr;
                tcp_format_dst_rx_tcp_tot_len = chksum_pseudo_hdr_reg.length;
                tcp_format_dst_rx_tcp_hdr = tcp_hdr_struct_reg;
                
                if (dst_tcp_format_rx_hdr_rdy) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
                else begin
                    hdr_state_next = OUTPUT;
                end
            end
            HDR_WAIT_TX_FIN: begin
                tcp_format_dst_rx_hdr_val = 1'b0;
                if (parse_state_reg == DATA_WAIT_TX_FIN) begin
                    hdr_state_next = WAITING;
                end
                else begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
            end
            default: begin
                hdr_state_next = UND;

                tcp_format_dst_rx_hdr_val = 1'bX;
                tcp_format_dst_rx_src_ip = 'X;
                tcp_format_dst_rx_dst_ip = 'X;
                tcp_format_dst_rx_tcp_tot_len = 'X;
                tcp_format_dst_rx_tcp_hdr = 'X;
            end
        endcase
    end

endmodule
