`include "packet_defs.vh"
`include "soc_defs.vh"

import packet_struct_pkg::*;
module rx_tcp_format_input_ctrl #(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
)(
     input clk
    ,input rst
    
    // I/O from the MAC side
    ,input                                      src_tcp_format_rx_hdr_val
    ,output logic                               tcp_format_src_rx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]            src_tcp_format_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]            src_tcp_format_rx_dst_ip
    ,input          [`TOT_LEN_W-1:0]            src_tcp_format_rx_tcp_len
    
    ,input                                      src_tcp_format_rx_data_val
    ,input          [`MAC_INTERFACE_W-1:0]      src_tcp_format_rx_data
    ,output logic                               tcp_format_src_rx_data_rdy
    ,input                                      src_tcp_format_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]       src_tcp_format_rx_padbytes
    
    // I/O to the checksum engine
    
    /*
     * Control
     */
    ,output logic                           req_cmd_val
    ,output logic                           req_cmd_csum_enable
    ,output logic   [7:0]                   req_cmd_csum_start
    ,output logic   [7:0]                   req_cmd_csum_offset
    ,output logic   [15:0]                  req_cmd_csum_init
    ,input                                  req_cmd_rdy
    
    /*
     * Data Output
     */
    ,output logic   [DATA_WIDTH-1:0]        req_tdata
    ,output logic   [KEEP_WIDTH-1:0]        req_tkeep
    ,output logic                           req_tval
    ,input                                  req_trdy
    ,output logic                           req_tlast
);

    localparam USE_BYTES = `MAC_INTERFACE_BYTES - CHKSUM_PSEUDO_HDR_BYTES;
    localparam USE_W = USE_BYTES * 8;
    localparam HOLD_BYTES = CHKSUM_PSEUDO_HDR_BYTES;
    localparam HOLD_W = CHKSUM_PSEUDO_HDR_W;
    localparam CHKSUM_OFFSET_BYTES = `MAC_INTERFACE_BYTES - CHKSUM_PSEUDO_HDR_BYTES - TCP_HDR_BYTES + 2;

    typedef enum logic [1:0] {
        READY = 2'd0,
        CHKSUM_DATA_INPUT = 2'd1,
        CHKSUM_DATA_LAST = 2'd2,
        UND = 'X
    } chksum_state_e;

    chksum_state_e state_reg;
    chksum_state_e state_next;

    chksum_pseudo_hdr pseudo_hdr_cast;
    
    logic   [HOLD_W-1:0]    hold_reg;
    logic   [HOLD_W-1:0]    hold_next;

    logic   [`MAC_PADBYTES_W-1:0]   padbytes_reg;
    logic   [`MAC_PADBYTES_W-1:0]   padbytes_next;

    logic   [`MAC_PADBYTES_W-1:0]   padbytes_output;
    logic   [$clog2(KEEP_WIDTH)-1:0]    keep_mask_shift;

    assign pseudo_hdr_cast.source_addr = src_tcp_format_rx_src_ip;
    assign pseudo_hdr_cast.dest_addr = src_tcp_format_rx_dst_ip;
    assign pseudo_hdr_cast.length = src_tcp_format_rx_tcp_len;
                                       
    assign pseudo_hdr_cast.zeros = '0;
    assign pseudo_hdr_cast.protocol = `IPPROTO_TCP;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            hold_reg <= '0;
            padbytes_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            hold_reg <= hold_next;
            padbytes_reg <= padbytes_next;
        end
    end

    always_comb begin
        if (state_reg == CHKSUM_DATA_INPUT) begin
            padbytes_output = src_tcp_format_rx_padbytes + USE_BYTES;
        end
        else if (state_reg == CHKSUM_DATA_LAST) begin
            padbytes_output = padbytes_reg + USE_BYTES;
        end
        else begin
            padbytes_output = '0;
        end
    end
    assign keep_mask_shift = padbytes_output;
    
    assign req_cmd_csum_start = '0;
    assign req_cmd_csum_init = '0;
    assign req_cmd_csum_offset = CHKSUM_OFFSET_BYTES;

    always_comb begin
        tcp_format_src_rx_hdr_rdy = 1'b0;
        tcp_format_src_rx_data_rdy = 1'b0;
        req_cmd_val = 1'b0;
        req_cmd_csum_enable = 1'b0;

        req_tval = 1'b0;
        req_tdata = '0;
        req_tlast = 1'b0;
        req_tkeep = '0;

        hold_next = hold_reg;
        padbytes_next = padbytes_reg;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                tcp_format_src_rx_hdr_rdy = req_cmd_rdy;
                tcp_format_src_rx_data_rdy = 1'b0;

                if (src_tcp_format_rx_hdr_val & req_cmd_rdy) begin
                    hold_next = pseudo_hdr_cast;
                    req_cmd_csum_enable = 1'b1;
                    req_cmd_val = 1'b1;
                    state_next = CHKSUM_DATA_INPUT;
                end
                else begin
                    req_cmd_val = 1'b0;
                    state_next = READY;
                end
            end
            CHKSUM_DATA_INPUT: begin
                tcp_format_src_rx_hdr_rdy = 1'b0;
                tcp_format_src_rx_data_rdy = req_trdy;

                req_tval = 1'b1;
                req_tdata = {hold_reg, src_tcp_format_rx_data[`MAC_INTERFACE_W-1 -: USE_W]};
                
                if (src_tcp_format_rx_data_val & req_trdy) begin
                    // if we're on the last packet
                    if (src_tcp_format_rx_last) begin
                        // if we can't send everything this cycle, we have to go
                        // to the last drain cycle
                        if (src_tcp_format_rx_padbytes < HOLD_BYTES) begin
                            padbytes_next = src_tcp_format_rx_padbytes;
                            hold_next = src_tcp_format_rx_data[HOLD_W-1:0];
                            state_next = CHKSUM_DATA_LAST;
                            req_tkeep = '1;
                        end
                        else begin
                            req_tlast = 1'b1;
                            req_tkeep = {KEEP_WIDTH{1'b1}} << keep_mask_shift;
                            hold_next = '0;
                            state_next = READY;
                        end
                    end
                    else begin
                        req_tkeep = '1;
                        hold_next = src_tcp_format_rx_data[HOLD_W-1:0];
                        state_next = CHKSUM_DATA_INPUT;
                    end
                end
                else begin
                    state_next = CHKSUM_DATA_INPUT;
                end
            end
            CHKSUM_DATA_LAST: begin
                tcp_format_src_rx_hdr_rdy = 1'b0;
                tcp_format_src_rx_data_rdy = 1'b0;
                req_tval = 1'b1;
                req_tlast = 1'b1;
                req_tdata = {hold_reg, {USE_W{1'b0}}};
                req_tkeep = {KEEP_WIDTH{1'b1}} << keep_mask_shift;

                if (req_trdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = CHKSUM_DATA_LAST;
                end
            end
            default: begin
                state_next = UND;

                tcp_format_src_rx_hdr_rdy = 1'bX;
                tcp_format_src_rx_data_rdy = 1'bX;
                req_cmd_val = 1'bX;

                req_tval = 1'bX;
                req_tdata = 'X;
                req_tlast = 1'bX;
                req_tkeep = 'X;

                hold_next = 'X;
                padbytes_next = 'X;
            end
        endcase
    end
endmodule
