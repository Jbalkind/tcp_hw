`include "packet_defs.vh"
`include "soc_defs.vh"
import packet_struct_pkg::*;
module tcp_tx_chksum_output_ctrl #(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
    ,parameter USER_WIDTH = `PKT_TIMESTAMP_W
)(
     input clk
    ,input rst

    /*
     * Data Input
     */ 
    ,input          [DATA_WIDTH-1:0]        resp_tdata
    ,input          [KEEP_WIDTH-1:0]        resp_tkeep
    ,input          [USER_WIDTH-1:0]        resp_tuser
    ,input                                  resp_tval
    ,output logic                           resp_trdy
    ,input                                  resp_tlast
    
    // I/O to the MAC side
    ,output logic                           chksum_dst_tx_hdr_val
    ,input                                  dst_chksum_tx_hdr_rdy
    ,output logic   [`IP_ADDR_W-1:0]        chksum_dst_tx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        chksum_dst_tx_dst_ip
    ,output logic   [`TOT_LEN_W-1:0]        chksum_dst_tx_tcp_len
    ,output logic   [`PKT_TIMESTAMP_W-1:0]  chksum_dst_tx_timestamp

    ,output logic                           chksum_dst_tx_data_val
    ,input                                  dst_chksum_tx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  chksum_dst_tx_data
    ,output logic                           chksum_dst_tx_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   chksum_dst_tx_data_padbytes
);
    localparam USE_BYTES = CHKSUM_PSEUDO_HDR_BYTES;
    localparam USE_W = USE_BYTES * 8;
    localparam HOLD_BYTES = `MAC_INTERFACE_BYTES - USE_BYTES;
    localparam HOLD_W = HOLD_BYTES * 8;

    typedef enum logic[1:0] {
        READY = 2'd0,
        PAYLOAD_OUTPUT = 2'd1,
        PAYLOAD_OUTPUT_LAST = 2'd2,
        PAYLOAD_WAIT_TX_FIN = 2'd3,
        UND = 'X
    } payload_state_e;
    
    typedef enum logic [1:0] {
        WAITING = 2'd0,
        HDR_OUTPUT = 2'd1,
        HDR_WAIT_TX_FIN = 2'd2,
        UNDEF = 'X
    } hdr_state_e;
    
    typedef enum logic {
        INIT = 1'b0,
        DECR = 1'b1
    } bytes_left_mux_e;

    payload_state_e state_reg;
    payload_state_e state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;

    logic   store_timestamp;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_reg;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_next;

    logic store_pseudo_hdr;
    chksum_pseudo_hdr pseudo_hdr_struct_reg;
    chksum_pseudo_hdr pseudo_hdr_struct_next;
    
    logic   store_hold;
    logic   [HOLD_W-1:0]    hold_reg;
    logic   [HOLD_W-1:0]    hold_next;
    
    logic                               update_bytes_left;
    bytes_left_mux_e                    bytes_left_mux_sel;
    logic   [`TOT_LEN_W-1:0]            bytes_left_reg;
    logic   [`TOT_LEN_W-1:0]            bytes_left_next;

    logic   [`MAC_INTERFACE_W-1:0]      output_data;

    logic                               output_metadata;

    assign chksum_dst_tx_src_ip = pseudo_hdr_struct_next.source_addr;
    assign chksum_dst_tx_dst_ip = pseudo_hdr_struct_next.dest_addr;
    assign chksum_dst_tx_tcp_len = pseudo_hdr_struct_next.length;
    assign chksum_dst_tx_timestamp = pkt_timestamp_next;
    
    assign pseudo_hdr_struct_next = store_pseudo_hdr
                                    ? resp_tdata[DATA_WIDTH-1 -: CHKSUM_PSEUDO_HDR_W]
                                    : pseudo_hdr_struct_reg;
    assign pkt_timestamp_next = store_timestamp
                                ? resp_tuser
                                : pkt_timestamp_reg;

    assign hold_next = store_hold
                    ? resp_tdata[HOLD_W-1:0]
                    : hold_reg;

    assign output_data = {hold_reg, resp_tdata[DATA_WIDTH-1 -: USE_W]};
    assign chksum_dst_tx_data_padbytes = chksum_dst_tx_data_last
                                        ? `MAC_INTERFACE_BYTES - bytes_left_reg
                                        : '0;

    data_masker #(
        .width_p    (`MAC_INTERFACE_W   )
    ) data_mask (
         .unmasked_data (output_data)
        ,.padbytes      (chksum_dst_tx_data_padbytes    )
        ,.last          (chksum_dst_tx_data_last        )
    
        ,.masked_data   (chksum_dst_tx_data             )
    );

    always_comb begin
        bytes_left_next = bytes_left_reg;
        if (update_bytes_left) begin
            if (bytes_left_mux_sel == INIT) begin
                bytes_left_next = pseudo_hdr_struct_next.length;
            end
            else begin
                bytes_left_next = bytes_left_reg - `MAC_INTERFACE_BYTES;
            end
        end
        else begin
            bytes_left_next = bytes_left_reg;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            hdr_state_reg <= WAITING;
            pseudo_hdr_struct_reg <= '0;
            hold_reg <= '0;
            bytes_left_reg <= '0;
            pkt_timestamp_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            hdr_state_reg <= hdr_state_next;
            pseudo_hdr_struct_reg <= pseudo_hdr_struct_next;
            hold_reg <= hold_next;
            bytes_left_reg <= bytes_left_next;
            pkt_timestamp_reg <= pkt_timestamp_next;
        end
    end

    always_comb begin
        resp_trdy = 1'b0;

        store_pseudo_hdr = 1'b0;
        update_bytes_left = 1'b0;
        bytes_left_mux_sel = INIT;
        store_hold = 1'b0;
        output_metadata = 1'b0;

        chksum_dst_tx_data_val = 1'b0;
        chksum_dst_tx_data_last = 1'b0;

        store_timestamp = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                resp_trdy = 1'b1;
                store_timestamp = 1'b1;
                store_pseudo_hdr = 1'b1;

                if (resp_tval) begin
                    output_metadata = 1'b1;
                    update_bytes_left = 1'b1;
                    bytes_left_mux_sel = INIT;
                    store_hold = 1'b1;

                    if (resp_tlast) begin
                        state_next = PAYLOAD_OUTPUT_LAST;
                    end
                    else begin
                        state_next = PAYLOAD_OUTPUT;
                    end
                end
            end
            PAYLOAD_OUTPUT: begin
                resp_trdy = dst_chksum_tx_data_rdy;
                chksum_dst_tx_data_val = resp_tval;

                if (resp_tval & dst_chksum_tx_data_rdy) begin
                    store_hold = 1'b1;
                    if (resp_tlast) begin
                        // if we can output everything in this cycle
                        if (bytes_left_reg <= `MAC_INTERFACE_BYTES) begin
                            chksum_dst_tx_data_last = 1'b1;

                            state_next = PAYLOAD_WAIT_TX_FIN;
                        end
                        else begin
                            update_bytes_left = 1'b1;
                            bytes_left_mux_sel = DECR;
                            state_next = PAYLOAD_OUTPUT_LAST;
                        end
                    end
                    else begin
                        update_bytes_left = 1'b1;
                        bytes_left_mux_sel = DECR;

                        state_next = PAYLOAD_OUTPUT;
                    end
                end
            end
            PAYLOAD_OUTPUT_LAST: begin
                resp_trdy = 1'b0;
                chksum_dst_tx_data_val = 1'b1;
                chksum_dst_tx_data_last = 1'b1;

                if (dst_chksum_tx_data_rdy) begin
                    state_next = PAYLOAD_WAIT_TX_FIN;
                end
            end
            PAYLOAD_WAIT_TX_FIN: begin
                resp_trdy = 1'b0;

                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    state_next = READY;
                end
            end
            default: begin
                resp_trdy = 'X;

                store_pseudo_hdr = 'X;
                update_bytes_left = 'X;
                store_hold = 'X;
                output_metadata = 'X;

                chksum_dst_tx_data_val = 'X;
                chksum_dst_tx_data_last = 'X;

                store_timestamp = 'X;
                
                bytes_left_mux_sel = INIT;

                state_next = UND;
            end
        endcase
    end

    always_comb begin
        chksum_dst_tx_hdr_val = 1'b0;

        hdr_state_next = hdr_state_reg;
        case (hdr_state_reg)
            WAITING: begin
                if (output_metadata) begin
                    hdr_state_next = HDR_OUTPUT;
                end
            end
            HDR_OUTPUT: begin
                chksum_dst_tx_hdr_val = 1'b1;
                if (dst_chksum_tx_hdr_rdy) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
            end
            HDR_WAIT_TX_FIN: begin
                if (state_reg == PAYLOAD_WAIT_TX_FIN) begin
                    hdr_state_next = WAITING;
                end
            end
            default: begin
                chksum_dst_tx_hdr_val = 'X;

                hdr_state_next = UNDEF;
            end
        endcase
    end
endmodule
