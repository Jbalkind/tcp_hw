`include "packet_defs.vh"
`include "soc_defs.vh"

import packet_struct_pkg::*;
module tx_chksum_output_controller #(
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
    ,input                                  resp_tvalid
    ,output logic                           resp_tready
    ,input                                  resp_tlast
    
    // I/O to the MAC side
    ,output logic                           chksum_dst_tx_hdr_val
    ,input                                  dst_chksum_tx_hdr_rdy
    ,output logic   [`IP_ADDR_W-1:0]        chksum_dst_tx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        chksum_dst_tx_dst_ip
    ,output logic   [`TOT_LEN_W-1:0]        chksum_dst_tx_tcp_len
    ,output tcp_pkt_hdr                     chksum_dst_tx_tcp_hdr

    ,output logic                           chksum_dst_tx_data_val
    ,input                                  dst_chksum_tx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  chksum_dst_tx_data
    ,output logic                           chksum_dst_tx_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   chksum_dst_tx_data_padbytes
);
    typedef enum logic [1:0] {
        READY = 2'd0,
        PAYLOAD = 2'd1,
        PAYLOAD_WAIT_TX_FIN = 2'd2,
        UND = 'X
    } chksum_state_e;

    typedef enum logic [1:0] {
        WAITING = 2'd0,
        OUTPUT = 2'd1,
        HDR_WAIT_TX_FIN = 2'd2,
        UNDEF = 'X
    } hdr_state_e;

    chksum_state_e chksum_state_reg;
    chksum_state_e chksum_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;
    
    chksum_pseudo_hdr pseudo_hdr_struct_reg;
    chksum_pseudo_hdr pseudo_hdr_struct_next;

    tcp_pkt_hdr output_tcp_hdr_struct;

    tcp_pkt_hdr resp_tcp_hdr_struct_reg;
    tcp_pkt_hdr resp_tcp_hdr_struct_next;

    logic   [`TOT_LEN_W-1:0]    payload_len;
    
    logic   [DATA_WIDTH-1:0]        masked_data;
    logic   [DATA_WIDTH-1:0]        data_mask;

    genvar mask_index;
    generate
        for (mask_index = 0; mask_index < KEEP_WIDTH; mask_index = mask_index + 1) begin: gen_data_mask
            always_comb begin
                if (resp_tlast) begin
                    data_mask[mask_index << 3 +: 8] = {8{resp_tkeep[mask_index]}};
                end
                else begin
                    data_mask[mask_index << 3 +: 8] = {8{1'b1}};
                end
            end
        end
    endgenerate

    assign masked_data = data_mask & resp_tdata;

    assign chksum_dst_tx_tcp_hdr = resp_tcp_hdr_struct_reg;
    assign chksum_dst_tx_src_ip = pseudo_hdr_struct_reg.source_addr;
    assign chksum_dst_tx_dst_ip = pseudo_hdr_struct_reg.dest_addr;
    assign chksum_dst_tx_tcp_len = pseudo_hdr_struct_reg.length;

    assign payload_len = pseudo_hdr_struct_reg.length - 
                         (resp_tcp_hdr_struct_reg.raw_data_offset << 2);

    always_ff @(posedge clk) begin
        if (rst) begin
            chksum_state_reg <= READY;
            hdr_state_reg <= WAITING;

            pseudo_hdr_struct_reg <= '0;
            resp_tcp_hdr_struct_reg <= '0;
        end
        else begin
            chksum_state_reg <= chksum_state_next;
            hdr_state_reg <= hdr_state_next;

            pseudo_hdr_struct_reg <= pseudo_hdr_struct_next;
            resp_tcp_hdr_struct_reg <= resp_tcp_hdr_struct_next;
        end
    end

    always_comb begin
        chksum_state_next = chksum_state_reg;
        resp_tready = 1'b0;

        pseudo_hdr_struct_next = pseudo_hdr_struct_reg;
        resp_tcp_hdr_struct_next = resp_tcp_hdr_struct_reg;

        chksum_dst_tx_data_val = 1'b0;
        chksum_dst_tx_data = '0;
        chksum_dst_tx_data_last = 1'b0;
        chksum_dst_tx_data_padbytes = '0;
        
        case (chksum_state_reg)
            READY: begin
                resp_tready = 1'b1;

                if (resp_tvalid) begin
                    pseudo_hdr_struct_next = resp_tdata[DATA_WIDTH-1 -: CHKSUM_PSEUDO_HDR_W];
                    resp_tcp_hdr_struct_next = resp_tdata[TCP_HDR_W-1:0];

                    if (resp_tlast) begin
                        chksum_state_next = PAYLOAD_WAIT_TX_FIN;
                    end
                    else begin
                        chksum_state_next = PAYLOAD;
                    end
                end
                else begin
                    chksum_state_next = READY;
                end
            end
            PAYLOAD: begin
                chksum_dst_tx_data_val = resp_tvalid;
                chksum_dst_tx_data = masked_data;
                chksum_dst_tx_data_last = resp_tlast;
                chksum_dst_tx_data_padbytes = resp_tlast
                                            ? '0
                                            : payload_len[`MAC_PADBYTES_W-1:0];

                resp_tready = dst_chksum_tx_data_rdy;

                if (resp_tvalid & dst_chksum_tx_data_rdy) begin
                    if (resp_tlast) begin
                        chksum_state_next = PAYLOAD_WAIT_TX_FIN;
                    end
                    else begin
                        chksum_state_next = PAYLOAD;
                    end
                end
                else begin
                    chksum_state_next = PAYLOAD;
                end
            end
            PAYLOAD_WAIT_TX_FIN: begin
                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    chksum_state_next = READY;
                end
                else begin
                    chksum_state_next = PAYLOAD_WAIT_TX_FIN;
                end
            end
            default: begin
            end
        endcase
    end

    always_comb begin
        hdr_state_next = hdr_state_reg;
        chksum_dst_tx_hdr_val = 1'b0;
        case (hdr_state_reg)
            WAITING: begin
                if ((chksum_state_reg == READY) & resp_tvalid) begin
                    hdr_state_next = OUTPUT;
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            OUTPUT: begin
                chksum_dst_tx_hdr_val = 1'b1;

                if (dst_chksum_tx_hdr_rdy) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
                else begin
                    hdr_state_next = OUTPUT;
                end
            end
            HDR_WAIT_TX_FIN: begin
                if (chksum_state_reg == PAYLOAD_WAIT_TX_FIN) begin
                    hdr_state_next = WAITING;
                end
                else begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
            end
            default: begin
                hdr_state_next = UNDEF;
                chksum_dst_tx_hdr_val = 1'bX;
            end
        endcase
    end



endmodule
