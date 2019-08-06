`include "packet_defs.vh"
`include "soc_defs.vh"

import packet_struct_pkg::*;
module tx_chksum_input_controller #(
         parameter DATA_WIDTH = 256
        ,parameter KEEP_WIDTH = DATA_WIDTH/8
    )(
     input clk
    ,input rst
    
    // I/O from the payload engine
    ,input                                  src_chksum_tx_hdr_val
    ,output logic                           chksum_src_tx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]        src_chksum_tx_src_ip
    ,input          [`IP_ADDR_W-1:0]        src_chksum_tx_dst_ip
    ,input          [`TOT_LEN_W-1:0]        src_chksum_tx_payload_len
    ,input  tcp_pkt_hdr                     src_chksum_tx_tcp_hdr

    ,input                                  src_chksum_tx_data_val
    ,output logic                           chksum_src_tx_data_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_chksum_tx_data
    ,input                                  src_chksum_tx_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_chksum_tx_data_padbytes

    // I/O to the checksum engine
    
    /*
     * Control
     */
    ,output logic                           req_cmd_csum_enable
    ,output logic   [7:0]                   req_cmd_csum_start
    ,output logic   [7:0]                   req_cmd_csum_offset
    ,output logic   [15:0]                  req_cmd_csum_init
    ,output logic                           req_cmd_valid
    ,input                                  req_cmd_ready
    
    /*
     * Data Output
     */
    ,output logic   [DATA_WIDTH-1:0]        req_tdata
    ,output logic   [KEEP_WIDTH-1:0]        req_tkeep
    ,output logic                           req_tvalid
    ,input                                  req_tready
    ,output logic                           req_tlast

);
    typedef enum logic [1:0] {
        READY = 2'd0,
        PSEUDO_HDR_TCP_HDR = 2'd1,
        PAYLOAD = 2'd2,
        UND = 'X
    } states_e;

    states_e state_reg;
    states_e state_next;
    
    logic   [`IP_ADDR_W-1:0]    src_ip_reg;
    logic   [`IP_ADDR_W-1:0]    src_ip_next;
    logic   [`IP_ADDR_W-1:0]    dst_ip_reg;
    logic   [`IP_ADDR_W-1:0]    dst_ip_next;

    logic   [`TOT_LEN_W-1:0]    payload_len_reg;
    logic   [`TOT_LEN_W-1:0]    payload_len_next;
    
    logic   [`MAC_INTERFACE_W-1:0]  masked_input_data;
    logic   [`MAC_INTERFACE_W-1:0]  input_data_mask;
    logic   [`MAC_INTERFACE_BITS_W-1:0] mask_shift;


    tcp_pkt_hdr tcp_hdr_struct_reg;
    tcp_pkt_hdr tcp_hdr_struct_next;
    tcp_pkt_hdr tcp_hdr_struct_cast;
    
    chksum_pseudo_hdr pseudo_hdr_struct_reg;
    chksum_pseudo_hdr pseudo_hdr_struct_next;

    assign mask_shift = src_chksum_tx_data_padbytes << 3;
    assign input_data_mask = src_chksum_tx_data_last
                           ? {(`MAC_INTERFACE_W){1'b1}} << mask_shift
                           : {(`MAC_INTERFACE_W){1'b1}};
    assign masked_input_data = src_chksum_tx_data & input_data_mask;
    assign tcp_hdr_struct_cast = src_chksum_tx_tcp_hdr;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            src_ip_reg <= '0;
            dst_ip_reg <= '0;
            payload_len_reg <= '0;
            tcp_hdr_struct_reg <= '0;
            pseudo_hdr_struct_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            src_ip_reg <= src_ip_next;
            dst_ip_reg <= dst_ip_next;
            payload_len_reg <= payload_len_next;
            tcp_hdr_struct_reg <= tcp_hdr_struct_next;
            pseudo_hdr_struct_reg <= pseudo_hdr_struct_next;
        end
    end

    assign req_cmd_csum_start = '0;
    assign req_cmd_csum_init = '0;
    assign req_cmd_csum_offset = 7'd2;

    always_comb begin
        state_next = state_reg;
        chksum_src_tx_hdr_rdy = 1'b0;
        chksum_src_tx_data_rdy = 1'b0;
                    
        src_ip_next = src_ip_reg;
        dst_ip_next = dst_ip_reg;
        payload_len_next = payload_len_reg;
        tcp_hdr_struct_next = tcp_hdr_struct_reg;
        pseudo_hdr_struct_next = pseudo_hdr_struct_reg;
                    
        req_cmd_csum_enable = 1'b0;
        req_cmd_valid = 1'b0;
                
        req_tvalid = 1'b0;
        req_tdata = '0;
        req_tkeep = '0;
        req_tlast = 1'b0;

        case (state_reg)
            READY: begin
                chksum_src_tx_hdr_rdy = req_cmd_ready;
                
                if (src_chksum_tx_hdr_val & req_cmd_ready) begin
                    src_ip_next = src_chksum_tx_src_ip;
                    dst_ip_next = src_chksum_tx_dst_ip;
                    payload_len_next = src_chksum_tx_payload_len;
                    tcp_hdr_struct_next = src_chksum_tx_tcp_hdr;

                    pseudo_hdr_struct_next.source_addr = src_chksum_tx_src_ip;
                    pseudo_hdr_struct_next.dest_addr = src_chksum_tx_dst_ip;
                    pseudo_hdr_struct_next.length = src_chksum_tx_payload_len +
                                                        (tcp_hdr_struct_cast.raw_data_offset << 2);
                    pseudo_hdr_struct_next.zeros = '0;
                    pseudo_hdr_struct_next.protocol = `IPPROTO_TCP;

                    state_next = PSEUDO_HDR_TCP_HDR;
                    
                    req_cmd_csum_enable = 1'b1;
                    req_cmd_valid = 1'b1;
                end
                else begin
                    state_next = READY;
                end
            end
            PSEUDO_HDR_TCP_HDR: begin
                req_tvalid = 1'b1;
                req_tdata = {pseudo_hdr_struct_reg, tcp_hdr_struct_reg};
                req_tkeep = '1;
                req_tlast = payload_len_reg == 0;

                if (req_tready) begin
                    if (payload_len_reg == 0) begin
                        state_next = READY;
                    end
                    else begin
                        state_next = PAYLOAD;
                    end
                end
                else begin
                    state_next = PSEUDO_HDR_TCP_HDR;
                end
            end
            PAYLOAD: begin
                chksum_src_tx_data_rdy = 1'b1;
                
                req_tvalid = src_chksum_tx_data_val;
                req_tdata = masked_input_data;
                req_tlast = src_chksum_tx_data_last;
                req_tkeep = src_chksum_tx_data_last
                            ? {KEEP_WIDTH{1'b1}} << src_chksum_tx_data_padbytes
                            : {KEEP_WIDTH{1'b1}};
                if (req_tready & src_chksum_tx_data_val) begin
                    if (src_chksum_tx_data_last) begin
                        state_next = READY;
                    end
                    else begin
                        state_next = PAYLOAD;
                    end
                end
                else begin
                    state_next = PAYLOAD;
                end
            end
            default: begin
                state_next = UND;
                chksum_src_tx_hdr_rdy = 1'bX;
                chksum_src_tx_data_rdy = 1'bX;
                            
                src_ip_next = 'X;
                dst_ip_next = 'X;
                payload_len_next = 'X;
                tcp_hdr_struct_next = 'X;
                pseudo_hdr_struct_next = 'X;
                            
                req_cmd_csum_enable = 1'bX;
                req_cmd_valid = 1'bX;
                        
                req_tvalid = 1'bX;
                req_tdata = 'X;
                req_tkeep = 'X;
                req_tlast = 1'bX;
            end
        endcase
    end


endmodule
