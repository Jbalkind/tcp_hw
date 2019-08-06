`include "packet_defs.vh"
`include "soc_defs.vh"
module udp_rx_chksum_output_ctrl 
import tracker_pkg::*;
import packet_struct_pkg::*;
#(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
)(
     input clk
    ,input rst
    
    ,input          [DATA_WIDTH-1:0]        resp_tdata
    ,input          [KEEP_WIDTH-1:0]        resp_tkeep
    ,input                                  resp_tval
    ,output logic                           resp_trdy
    ,input                                  resp_tlast
    ,input  tracker_stats_struct            resp_tuser
    ,input          [`UDP_CHKSUM_W-1:0]     resp_csum


    ,output logic                           udp_formatter_dst_rx_hdr_val
    ,output logic   [`IP_ADDR_W-1:0]        udp_formatter_dst_rx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        udp_formatter_dst_rx_dst_ip
    ,output udp_pkt_hdr                     udp_formatter_dst_rx_udp_hdr
    ,output tracker_stats_struct            udp_formatter_dst_rx_timestamp
    ,input                                  dst_udp_formatter_rx_hdr_rdy

    ,output logic                           udp_formatter_dst_rx_data_val
    ,input                                  dst_udp_formatter_rx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  udp_formatter_dst_rx_data
    ,output logic                           udp_formatter_dst_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   udp_formatter_dst_rx_padbytes
);
    
    typedef enum logic[2:0] {
        READY = 3'd0,
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

    typedef enum logic {
        INIT = 1'b0,
        DECR = 1'b1
    } bytes_left_mux_e;
    
    localparam USE_BYTES = CHKSUM_PSEUDO_HDR_BYTES + UDP_HDR_BYTES;
    localparam USE_W = USE_BYTES * 8;
    localparam HOLD_BYTES = `MAC_INTERFACE_BYTES - USE_BYTES;
    localparam HOLD_W = HOLD_BYTES * 8;


    parse_state_e parse_state_reg;
    parse_state_e parse_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;

    udp_pkt_hdr udp_hdr_struct_reg;
    udp_pkt_hdr udp_hdr_struct_next;
    udp_pkt_hdr udp_hdr_struct_cast;
    logic   store_udp_hdr;

    chksum_pseudo_hdr chksum_pseudo_hdr_reg;
    chksum_pseudo_hdr chksum_pseudo_hdr_next;
    chksum_pseudo_hdr chksum_pseudo_hdr_cast;
    logic   store_pseudo_hdr;
    
    logic [`TOT_LEN_W-1:0]  hdr_bytes_rem_reg;
    logic [`TOT_LEN_W-1:0]  hdr_bytes_rem_next;

    logic                           store_timestamp;
    tracker_stats_struct            pkt_timestamp_reg;
    tracker_stats_struct            pkt_timestamp_next;
    
    logic chksum_match;

    bytes_left_mux_e bytes_left_mux_sel;
    logic update_bytes_left;
    
    // because the 256 bits of data might not be aligned exactly, we have to grab data from the end
    // of one data line and the beginning of another
    logic   store_hold;
    logic   [HOLD_W-1:0]    hold_reg;
    logic   [HOLD_W-1:0]    hold_next;
    
    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_next;
    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_reg;

    logic   [`TOT_LEN_W-1:0]            bytes_left_reg;
    logic   [`TOT_LEN_W-1:0]            bytes_left_next;

    // if a checksum is correct, then the checksum calculated with it in the field (instead of
    // zeroes) is all 1s, so the 1's complement (what the module outputs) is all 0s
    assign chksum_match = udp_hdr_struct_cast.chksum == `UDP_CHKSUM_W'd0;

    assign pkt_timestamp_next = store_timestamp
                                ? resp_tuser
                                : pkt_timestamp_reg;

    assign udp_formatter_dst_rx_src_ip = chksum_pseudo_hdr_reg.source_addr;
    assign udp_formatter_dst_rx_dst_ip = chksum_pseudo_hdr_reg.dest_addr;
    assign udp_formatter_dst_rx_udp_hdr = udp_hdr_struct_reg;
    assign udp_formatter_dst_rx_timestamp = pkt_timestamp_reg;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            parse_state_reg <= READY;
            hdr_state_reg <= WAITING;
            udp_hdr_struct_reg <= '0;
            chksum_pseudo_hdr_reg <= '0;
            bytes_left_reg <= '0;
            hold_reg <= '0;
            pkt_timestamp_reg <= '0;
        end
        else begin
            parse_state_reg <= parse_state_next;
            hdr_state_reg <= hdr_state_next;
            udp_hdr_struct_reg <= udp_hdr_struct_next;
            chksum_pseudo_hdr_reg <= chksum_pseudo_hdr_next;
            bytes_left_reg <= bytes_left_next;
            hold_reg <= hold_next;
            pkt_timestamp_reg <= pkt_timestamp_next;
        end
    end
    
    assign chksum_pseudo_hdr_next = store_pseudo_hdr
                                    ? resp_tdata[DATA_WIDTH-1 -: CHKSUM_PSEUDO_HDR_W]
                                    : chksum_pseudo_hdr_reg;
    assign udp_hdr_struct_next = store_udp_hdr
                                ? resp_tdata[HOLD_W +: UDP_HDR_W]
                                : udp_hdr_struct_reg;
    assign udp_hdr_struct_cast = resp_tdata[HOLD_W +: UDP_HDR_W];
    assign hold_next = store_hold
                        ? resp_tdata[HOLD_W-1:0]
                        : hold_reg;

    assign udp_formatter_dst_rx_data = {hold_reg, resp_tdata[DATA_WIDTH-1 -: USE_W]};

    assign udp_formatter_dst_rx_padbytes = udp_formatter_dst_rx_last
                                            ? `MAC_INTERFACE_BYTES - bytes_left_reg
                                            : '0;

    always_comb begin
        if (update_bytes_left) begin
            if (bytes_left_mux_sel == INIT) begin
                bytes_left_next = udp_hdr_struct_next.length - UDP_HDR_BYTES;
            end
            else begin
                bytes_left_next = bytes_left_reg - `MAC_INTERFACE_BYTES;
            end
        end
        else begin
            bytes_left_next = bytes_left_reg;
        end
    end

    always_comb begin
        resp_trdy = 1'b0;

        store_hold  = 1'b0;
        store_udp_hdr = 1'b0;
        store_pseudo_hdr = 1'b0;
        bytes_left_mux_sel = INIT;
        update_bytes_left = 1'b0;

        udp_formatter_dst_rx_data_val = 1'b0;
        udp_formatter_dst_rx_last = 1'b0;

        store_timestamp = 1'b0;
        
        parse_state_next = parse_state_reg;
        case (parse_state_reg)
            READY: begin
                resp_trdy = 1'b1;
                store_timestamp = 1'b1;
                if (resp_tval) begin
                    if (chksum_match) begin
                        store_udp_hdr = 1'b1;
                        store_pseudo_hdr = 1'b1;
                        update_bytes_left = 1'b1;
                        bytes_left_mux_sel = INIT;
                        store_hold = 1'b1;

                        if (bytes_left_next == 0) begin
                            parse_state_next = DATA_WAIT_TX_FIN;
                        end
                        else if (bytes_left_next <= HOLD_BYTES) begin
                            parse_state_next = DATA_OUTPUT_LAST;
                        end
                        else begin
                            parse_state_next = DATA_OUTPUT;
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
            DATA_OUTPUT: begin
                resp_trdy = dst_udp_formatter_rx_data_rdy;
                udp_formatter_dst_rx_data_val =  resp_tval;

                if (resp_tval & dst_udp_formatter_rx_data_rdy) begin
                    store_hold = 1'b1;
                    if (resp_tlast) begin
                        if (bytes_left_reg <= `MAC_INTERFACE_BYTES) begin
                            udp_formatter_dst_rx_last = 1'b1;

                            parse_state_next = DATA_WAIT_TX_FIN;
                        end
                        else begin
                            update_bytes_left = 1'b1;
                            bytes_left_mux_sel = DECR;
                            parse_state_next = DATA_OUTPUT_LAST;
                        end
                    end
                    else begin
                        update_bytes_left = 1'b1;
                        bytes_left_mux_sel = DECR;
                        parse_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    parse_state_next = DATA_OUTPUT;
                end
            end
            DATA_OUTPUT_LAST: begin
                resp_trdy = 0;
                udp_formatter_dst_rx_data_val = 1'b1;
                udp_formatter_dst_rx_last = 1'b1;
                
                if (dst_udp_formatter_rx_data_rdy) begin
                    parse_state_next = DATA_WAIT_TX_FIN;
                end
                else begin
                    parse_state_next = DATA_OUTPUT_LAST;
                end
            end
            DRAIN: begin
                resp_trdy = 1'b1;
                udp_formatter_dst_rx_data_val = 1'b0;

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
                resp_trdy = 'X;

                store_timestamp = 'X;
                store_udp_hdr = 'X;
                store_pseudo_hdr = 'X;
                update_bytes_left = 'X;

                udp_formatter_dst_rx_data_val = 'X;
                udp_formatter_dst_rx_last = 'X;
                
                bytes_left_mux_sel = INIT;
                
                parse_state_next = UNDEF;
            end
        endcase
    end

    always_comb begin
        udp_formatter_dst_rx_hdr_val = 1'b0;

        hdr_state_next = hdr_state_reg;
        case (hdr_state_reg)
            WAITING: begin
                if ((parse_state_reg == READY) & resp_tval) begin
                    if (chksum_match) begin
                        hdr_state_next = OUTPUT;
                    end
                    else begin
                        hdr_state_next = HDR_WAIT_TX_FIN;
                    end
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            OUTPUT: begin
                udp_formatter_dst_rx_hdr_val = 1'b1;
                if (dst_udp_formatter_rx_hdr_rdy) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
                else begin
                    hdr_state_next = OUTPUT;
                end
            end
            HDR_WAIT_TX_FIN: begin
                if (parse_state_reg == DATA_WAIT_TX_FIN) begin
                    hdr_state_next = WAITING;
                end
                else begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
            end
            default: begin
                udp_formatter_dst_rx_hdr_val = 'X;

                hdr_state_next = UND;
            end
        endcase
    end
endmodule
