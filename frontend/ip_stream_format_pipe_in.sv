`include "packet_defs.vh"
module ip_stream_format_pipe_in 
import packet_struct_pkg::*;
import ip_stream_format_pkg::*;
import tracker_pkg::*;
#(
     parameter DATA_WIDTH = -1
    ,parameter DATA_BYTES = DATA_WIDTH/8
    ,parameter KEEP_WIDTH = DATA_BYTES
    ,parameter PADBYTES_WIDTH = $clog2(DATA_BYTES)
)(
     input clk
    ,input rst
    
    // Data stream in from MAC
    ,input                                  src_ip_format_rx_val
    ,input  tracker_stats_struct            src_ip_format_rx_timestamp
    ,output logic                           ip_format_src_rx_rdy
    ,input          [DATA_WIDTH-1:0]        src_ip_format_rx_data
    ,input                                  src_ip_format_rx_last
    ,input          [PADBYTES_WIDTH-1:0]    src_ip_format_rx_padbytes
    
    ,output logic                           ip_chksum_cmd_val
    ,output logic                           ip_chksum_cmd_enable
    ,output logic   [7:0]                   ip_chksum_cmd_start
    ,output logic   [7:0]                   ip_chksum_cmd_offset
    ,output logic   [15:0]                  ip_chksum_cmd_init
    ,input  logic                           ip_chksum_cmd_rdy

    ,output logic   [DATA_WIDTH-1:0]        ip_chksum_req_data
    ,output logic   [KEEP_WIDTH-1:0]        ip_chksum_req_keep
    ,output logic                           ip_chksum_req_val
    ,output logic                           ip_chksum_req_last
    ,input  logic                           ip_chksum_req_rdy

    ,output logic                           in_data_fifo_wr_req
    ,output fifo_struct                     in_data_fifo_wr_data
    ,input  logic                           data_fifo_in_full
);

    localparam DATA_BYTES_W = $clog2(DATA_BYTES);
    localparam KEEP_SHIFT_W = $clog2(KEEP_WIDTH);
    localparam CHKSUM_OFFSET = `NOC_DATA_BYTES - 12;

    typedef enum logic[1:0] {
        READY = 2'd0,
        IP_HDR_FIRST = 2'd1,
        IP_HDR_REM = 2'd2,
        WAIT_DATA = 2'd3,
        UND = 'X
    } chksum_state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        DATA_OUT = 2'd1,
        UNDEF = 'X
    } data_state_e;

    chksum_state_e chksum_state_reg;
    chksum_state_e chksum_state_next;

    data_state_e    data_state_reg;
    data_state_e    data_state_next;

    logic           chksum_advance;
    logic           data_advance;
    logic           data_out;

    logic   [DATA_WIDTH-1:0]    chksum_data_reg;
    logic   [DATA_WIDTH-1:0]    chksum_data_next;
    logic                       store_data_line;
    
    logic   [`TOT_LEN_W-1:0]        ip_hdr_len;
    ip_pkt_hdr                      ip_hdr_reg;
    ip_pkt_hdr                      ip_hdr_next;
    ip_pkt_hdr                      ip_hdr_cast;
    logic                           store_ip_hdr;

    logic   [KEEP_SHIFT_W:0]      keep_shift;

    assign in_data_fifo_wr_data.data = src_ip_format_rx_data;
    assign in_data_fifo_wr_data.padbytes = src_ip_format_rx_padbytes;
    assign in_data_fifo_wr_data.last = src_ip_format_rx_last;
    assign in_data_fifo_wr_data.timestamp = src_ip_format_rx_timestamp;

    assign ip_chksum_req_keep = ip_chksum_req_last
                            ? {KEEP_WIDTH{1'b1}} << keep_shift
                            : '1;
    assign ip_chksum_req_data = chksum_data_reg;

    assign ip_chksum_cmd_start = '0;
    assign ip_chksum_cmd_offset = CHKSUM_OFFSET[7:0];
    assign ip_chksum_cmd_init = '0;

    
    assign ip_hdr_cast = chksum_data_reg[DATA_WIDTH - 1 -: IP_HDR_W];
    assign ip_hdr_len = ip_hdr_reg.ip_hdr_len << 2;
    assign keep_shift = DATA_BYTES - ip_hdr_len[DATA_BYTES_W-1:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            chksum_state_reg <= READY;
            data_state_reg <= WAITING;
        end
        else begin
            chksum_state_reg <= chksum_state_next;
            data_state_reg <= data_state_next;
            chksum_data_reg <= chksum_data_next;
            ip_hdr_reg <= ip_hdr_next;
        end
    end

    assign ip_hdr_next = store_ip_hdr
                        ? src_ip_format_rx_data[`MAC_INTERFACE_W - 1 -: IP_HDR_W]
                        : ip_hdr_reg;

    assign chksum_data_next = store_data_line
                            ? src_ip_format_rx_data
                            : chksum_data_reg;

    always_comb begin
        chksum_advance = 1'b0;
        data_out = 1'b0;
        store_data_line = 1'b0;
        store_ip_hdr = 1'b0;
        ip_chksum_cmd_val = 1'b0;
        ip_chksum_cmd_enable = 1'b0;
        ip_chksum_req_last = 1'b0;
        ip_chksum_req_val = 1'b0;

        chksum_state_next = chksum_state_reg;
        case (chksum_state_reg)
            READY: begin
                chksum_advance = ip_chksum_cmd_rdy;
                store_data_line = 1'b1;
                store_ip_hdr = 1'b1;

                if (src_ip_format_rx_val & ip_format_src_rx_rdy) begin
                    data_out = 1;
                    ip_chksum_cmd_val = 1'b1;
                    ip_chksum_cmd_enable = 1'b1;
                    chksum_state_next = IP_HDR_FIRST;
                end
            end
            IP_HDR_FIRST: begin
                ip_chksum_req_val = 1'b1;
                // do we need the next line?
                if (ip_hdr_len > DATA_BYTES) begin
                    if (src_ip_format_rx_val & ip_format_src_rx_rdy) begin
                        store_data_line = 1'b1;
                        chksum_state_next = IP_HDR_REM; 
                    end

                end
                // we don't need it...
                else begin
                    ip_chksum_req_last = 1'b1;
                    if (ip_chksum_req_rdy) begin
                        if (data_state_next == WAITING) begin
                            chksum_state_next = READY;
                        end
                        else begin
                            chksum_state_next = WAIT_DATA;
                        end
                    end
                end
            end
            IP_HDR_REM: begin
                chksum_advance = 1'b1;
                ip_chksum_req_val = 1'b1;
                ip_chksum_req_last = 1'b1;
                if (ip_chksum_req_rdy) begin
                    if (data_state_next == WAITING) begin
                        chksum_state_next = READY;
                    end
                    else begin
                        chksum_state_next = WAIT_DATA;
                    end
                end
            end
            WAIT_DATA: begin
                chksum_advance = 1'b1;
                if (data_state_next == WAITING) begin
                    chksum_state_next = READY;
                end
            end
        endcase
    end

    always_comb begin
        ip_format_src_rx_rdy = 1'b0;
        case (chksum_state_reg)
            READY: begin
                ip_format_src_rx_rdy = ~data_fifo_in_full & ip_chksum_cmd_rdy;
            end
            IP_HDR_FIRST: begin
                if (src_ip_format_rx_val) begin
                    if (ip_hdr_len > DATA_BYTES) begin
                        ip_format_src_rx_rdy = ip_chksum_req_rdy & ~data_fifo_in_full;
                    end
                    else begin
                        // if the state is WAITING here, it means we passed the
                        // last line of the packet already and we need to wait
                        // until we come back around to checksum again
                        ip_format_src_rx_rdy = ~data_fifo_in_full & (data_state_reg == DATA_OUT);
                    end
                end
            end
            IP_HDR_REM: begin
                ip_format_src_rx_rdy = ~data_fifo_in_full & (data_state_reg == DATA_OUT);
            end
            WAIT_DATA: begin
                ip_format_src_rx_rdy = ~data_fifo_in_full & (data_state_reg == DATA_OUT);
            end
        endcase
    end

    always_comb begin
        in_data_fifo_wr_req = 1'b0;
        data_advance = 1'b0;

        data_state_next = data_state_reg;
        case (data_state_reg)
            WAITING: begin
                if (data_out) begin
                    if (ip_format_src_rx_rdy & src_ip_format_rx_val) begin
                        in_data_fifo_wr_req = 1'b1;
                        if (src_ip_format_rx_last) begin
                            data_state_next = WAITING;
                        end
                        else begin
                            data_state_next = DATA_OUT;
                        end
                    end
                end
            end
            DATA_OUT: begin
                if (ip_format_src_rx_rdy & src_ip_format_rx_val) begin
                    in_data_fifo_wr_req = 1'b1;
                    if (src_ip_format_rx_last) begin
                        data_state_next = WAITING;
                    end
                    else begin
                        data_state_next = DATA_OUT;
                    end
                end
            end
            default: begin
                in_data_fifo_wr_req = 'X;
                data_advance = 'X;

                data_state_next = UNDEF;
            end
        endcase
    end
    
endmodule
