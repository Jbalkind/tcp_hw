`include "packet_defs.vh"
module ip_stream_format_pipe_out 
import packet_struct_pkg::*;
import ip_stream_format_pkg::*;
import tracker_pkg::*;
#(
    parameter DATA_WIDTH = -1
    ,parameter DATA_BYTES = DATA_WIDTH/8
    ,parameter PADBYTES_WIDTH = $clog2(DATA_BYTES)
)(
     input clk
    ,input rst

    ,output logic                           ip_chksum_resp_rdy
    ,input  logic   [DATA_WIDTH-1:0]        ip_chksum_resp_data
    ,input  logic                           ip_chksum_resp_last
    ,input  logic                           ip_chksum_resp_val

    ,output logic                           out_data_fifo_rd_req
    ,input  logic                           data_fifo_out_empty
    ,input  fifo_struct                     data_fifo_out_data
    
    // Header and data out
    ,output logic                           ip_format_dst_rx_hdr_val
    ,input                                  dst_ip_format_rx_hdr_rdy
    ,output ip_pkt_hdr                      ip_format_dst_rx_ip_hdr
    ,output tracker_stats_struct            ip_format_dst_rx_timestamp

    ,output logic                           ip_format_dst_rx_data_val
    ,input                                  dst_ip_format_rx_data_rdy
    ,output logic   [DATA_WIDTH-1:0]        ip_format_dst_rx_data
    ,output logic                           ip_format_dst_rx_last
    ,output logic   [PADBYTES_WIDTH-1:0]    ip_format_dst_rx_padbytes
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        IP_HDR_DRAIN = 3'd1,
        PASS_DATA = 3'd2,
        WAIT_META = 3'd3,
        DATA_DRAIN = 3'd4,
        UND = 'X
    } data_state_e;

    typedef enum logic {
        WAITING = 1'b0,
        META_OUT = 1'b1,
        UNDEF = 'X
    } meta_state_e;

    data_state_e data_state_reg;
    data_state_e data_state_next;

    meta_state_e meta_state_reg;
    meta_state_e meta_state_next;
    logic   output_meta;

    ip_pkt_hdr  pkt_hdr_cast;
    ip_pkt_hdr  pkt_hdr_reg;
    ip_pkt_hdr  pkt_hdr_next;
    logic   store_pkt_hdr;

    tracker_stats_struct  timestamp_reg;
    tracker_stats_struct  timestamp_next;

    logic chksum_good;
    logic chksum_good_reg;
    logic chksum_good_next;

    logic   data_ctrl_realign_val;
    logic   realign_data_ctrl_rdy;

    logic   [`TOT_LEN_W-1:0]        ip_hdr_len;
    logic   [PADBYTES_WIDTH-1:0]    realign_shift;

    assign realign_shift = ip_hdr_len[PADBYTES_WIDTH-1:0];

    assign ip_hdr_len = pkt_hdr_reg.ip_hdr_len << 2;

    
    assign ip_format_dst_rx_ip_hdr = pkt_hdr_next;
    assign ip_format_dst_rx_timestamp = timestamp_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            meta_state_reg <= WAITING;
        end
        else begin
            data_state_reg <= data_state_next;
            meta_state_reg <= meta_state_next;
            pkt_hdr_reg <= pkt_hdr_next;
            chksum_good_reg <= chksum_good_next;
            timestamp_reg <= timestamp_next;
        end
    end

    assign pkt_hdr_cast = ip_chksum_resp_data[DATA_WIDTH-1 -: IP_HDR_W];

    assign chksum_good = pkt_hdr_cast.chksum == '0;

    assign chksum_good_next = store_pkt_hdr
                        ? chksum_good
                        : chksum_good_reg;

    assign pkt_hdr_next = store_pkt_hdr
                        ? data_fifo_out_data.data[DATA_WIDTH - 1 -: IP_HDR_W]
                        : pkt_hdr_reg;

    assign timestamp_next = store_pkt_hdr
                            ? data_fifo_out_data.timestamp
                            : timestamp_reg;

    always_comb begin
        store_pkt_hdr = 1'b0;
        ip_chksum_resp_rdy = 1'b0;
        out_data_fifo_rd_req = 1'b0;
        output_meta = 1'b0;
        data_ctrl_realign_val = 1'b0;

        data_state_next = data_state_reg;
        case (data_state_reg) 
            READY: begin
                store_pkt_hdr = 1'b1;
                if (~data_fifo_out_empty & ip_chksum_resp_val) begin
                    ip_chksum_resp_rdy = 1'b1;
                    output_meta = chksum_good;
                    if (ip_chksum_resp_last) begin
                        // is the checksum good
                        if (chksum_good) begin
                            data_state_next = PASS_DATA;
                        end
                        else begin
                            data_state_next = DATA_DRAIN;
                        end
                    end
                    else begin
                        data_state_next = IP_HDR_DRAIN;
                    end
                end
            end
            IP_HDR_DRAIN: begin
                if (~data_fifo_out_empty & ip_chksum_resp_val) begin
                    // read out the line with just IP header as well as the remaining IP header
                    // since the IP hdr can be at most 60 bytes, the end must be in the second 
                    // line of data
                    out_data_fifo_rd_req = 1'b1;
                    ip_chksum_resp_rdy = 1'b1;
                    if (chksum_good_reg) begin
                        data_state_next = PASS_DATA;
                    end
                    else begin
                        data_state_next = DATA_DRAIN;
                    end
                end
            end
            PASS_DATA: begin
                data_ctrl_realign_val = ~data_fifo_out_empty;
                out_data_fifo_rd_req = ~data_fifo_out_empty & realign_data_ctrl_rdy;

                if (~data_fifo_out_empty & realign_data_ctrl_rdy) begin
                    if (data_fifo_out_data.last) begin
                        if (meta_state_next == WAITING) begin
                            data_state_next = READY;
                        end
                        else begin
                            data_state_next = WAIT_META;
                        end
                    end
                end
            end
            DATA_DRAIN: begin
                if (~data_fifo_out_empty) begin
                    out_data_fifo_rd_req = 1'b1;
                    if (data_fifo_out_data.last) begin
                        if (meta_state_next == WAITING) begin
                            data_state_next = READY;
                        end
                        else begin
                            data_state_next = WAIT_META;
                        end
                    end
                end
            end
            WAIT_META: begin
                if (meta_state_next == WAITING) begin
                    data_state_next = READY;
                end
            end
        endcase
    end

    always_comb begin
        ip_format_dst_rx_hdr_val = 1'b0;

        meta_state_next = meta_state_reg;
        case (meta_state_reg)
            WAITING: begin
                if (output_meta) begin
                    ip_format_dst_rx_hdr_val = 1'b1;
                    if (dst_ip_format_rx_hdr_rdy) begin
                        meta_state_next = WAITING;
                    end
                    else begin
                        meta_state_next = META_OUT;
                    end
                end
            end
            META_OUT: begin
                ip_format_dst_rx_hdr_val = 1'b1;
                if (dst_ip_format_rx_hdr_rdy) begin
                    meta_state_next = WAITING;
                end
            end
            default: begin
                ip_format_dst_rx_hdr_val = 'X;

                meta_state_next = UNDEF;
            end
        endcase
    end
    
    realign_runtime #(
         .DATA_W         (DATA_WIDTH    )
        ,.BUF_STAGES     (4             )
    ) ip_hdr_realign (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.realign_bytes             (realign_shift              )

        ,.src_realign_data_val      (data_ctrl_realign_val      )
        ,.src_realign_data          (data_fifo_out_data.data    )
        ,.src_realign_data_padbytes (data_fifo_out_data.padbytes)
        ,.src_realign_data_last     (data_fifo_out_data.last    )
        ,.realign_src_data_rdy      (realign_data_ctrl_rdy      )

        ,.realign_dst_data_val      (ip_format_dst_rx_data_val  )
        ,.realign_dst_data          (ip_format_dst_rx_data      )
        ,.realign_dst_data_padbytes (ip_format_dst_rx_padbytes  )
        ,.realign_dst_data_last     (ip_format_dst_rx_last      )
        ,.dst_realign_data_rdy      (dst_ip_format_rx_data_rdy  )

        ,.full_line                 ()
    );
endmodule
