`include "soc_defs.vh"
`include "noc_defs.vh"
`include "packet_defs.vh"
module ip_hdr_assembler_pipe_in 
import packet_struct_pkg::*;
import ip_hdr_assembler_pkg::*;
import tracker_pkg::*;
#(
     parameter DATA_W = -1
    ,parameter KEEP_W = DATA_W/8
    ,parameter DATA_PADBYTES = DATA_W/8
    ,parameter DATA_PADBYTES_W = $clog2(DATA_PADBYTES)
)(
     input clk
    ,input rst

    ,input                                  src_assembler_req_val
    ,input  [`IP_ADDR_W-1:0]                src_assembler_src_ip_addr
    ,input  [`IP_ADDR_W-1:0]                src_assembler_dst_ip_addr
    ,input  [`TOT_LEN_W-1:0]                src_assembler_data_payload_len
    ,input  [`PROTOCOL_W-1:0]               src_assembler_protocol
    ,input  tracker_stats_struct            src_assembler_timestamp
    ,output logic                           assembler_src_req_rdy 

    ,input  logic                           src_assembler_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]  src_assembler_data
    ,input  logic                           src_assembler_data_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]   src_assembler_data_padbytes
    ,output logic                           assembler_src_data_rdy

    ,output logic                           in_chksum_cmd_enable
    ,output logic   [7:0]                   in_chksum_cmd_start
    ,output logic   [7:0]                   in_chksum_cmd_offset
    ,output logic   [15:0]                  in_chksum_cmd_init
    ,output logic                           in_chksum_cmd_val
    ,input  logic                           chksum_in_cmd_rdy

    ,output logic   [DATA_W-1:0]            in_chksum_req_data
    ,output logic   [KEEP_W-1:0]            in_chksum_req_keep
    ,output tracker_stats_struct            in_chksum_req_user
    ,output logic                           in_chksum_req_val
    ,output logic                           in_chksum_req_last
    ,input  logic                           chksum_in_req_rdy

    ,output logic                           in_data_fifo_wr_req
    ,output fifo_struct                     in_data_fifo_wr_data
    ,input  logic                           data_fifo_in_full
);
    
    localparam DATA_BYTES = DATA_W/8;
    localparam DATA_BYTES_W = $clog2(DATA_BYTES);
    localparam KEEP_SHIFT_W = $clog2(KEEP_W);
    localparam CHKSUM_OFFSET = `MAC_INTERFACE_BYTES - 12;

    typedef enum logic[1:0] {
        READY = 2'd0,
        IP_HDR_IN = 2'd1,
        WAIT_DATA = 2'd2,
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

    ip_pkt_hdr      ip_hdr_reg;
    ip_pkt_hdr      ip_hdr_next;
    logic           store_ip_hdr;

    tracker_stats_struct  timestamp_reg;
    tracker_stats_struct  timestamp_next;

    logic                           data_out;

    assign in_chksum_req_data = {ip_hdr_reg, {(DATA_W-IP_HDR_W){1'b0}}};
    assign in_chksum_req_keep = {KEEP_W{1'b1}} << (DATA_BYTES - IP_HDR_BYTES);
    assign in_chksum_req_last = 1'b1;
    assign in_chksum_req_user = timestamp_next;
                    
    assign in_chksum_cmd_start = '0;
    assign in_chksum_cmd_offset = CHKSUM_OFFSET[7:0];
    assign in_chksum_cmd_init = '0;

    assign in_data_fifo_wr_data.data = src_assembler_data;
    assign in_data_fifo_wr_data.padbytes = src_assembler_data_padbytes;
    assign in_data_fifo_wr_data.last = src_assembler_data_last;

    always_ff @(posedge clk) begin
        if (rst) begin
            chksum_state_reg <= READY;
            data_state_reg <= WAITING;
        end
        else begin
            chksum_state_reg <= chksum_state_next;
            data_state_reg <= data_state_next;
            ip_hdr_reg <= ip_hdr_next;
            timestamp_reg <= timestamp_next;
        end
    end

    assign timestamp_next = store_ip_hdr
                        ? src_assembler_timestamp
                        : timestamp_reg;

    always_comb begin
        ip_hdr_next = ip_hdr_reg;
        if (store_ip_hdr) begin
            // hardwire these
            ip_hdr_next.ip_hdr_len = `IHL_W'd5;
            ip_hdr_next.ip_version = `IP_VERSION_W'd4;
             // not sure why this is 0 but it works
            ip_hdr_next.tos = '0;

            ip_hdr_next.tot_len = IP_HDR_BYTES + src_assembler_data_payload_len;
            // who knows what this is for...it doesn't seem to matter
            // katie: this has to be 0 for demikernel/catnip
            ip_hdr_next.id = `ID_W'd0;
            // this has to do with IP packet fragmentation...we just don't support this
            ip_hdr_next.frag_offset = `FRAG_OFF_W'h4000;
            ip_hdr_next.ttl = `TTL_W'd64;

            ip_hdr_next.protocol_no = src_assembler_protocol;
            ip_hdr_next.chksum = '0;
            ip_hdr_next.source_addr = src_assembler_src_ip_addr;
            ip_hdr_next.dest_addr = src_assembler_dst_ip_addr;
        end
    end

    always_comb begin
        store_ip_hdr = 1'b0;
        
        in_chksum_cmd_val = 1'b0;
        in_chksum_cmd_enable = 1'b0;
        
        in_chksum_req_val = 1'b0;

        assembler_src_req_rdy = 1'b0;

        data_out = 1'b0;

        chksum_state_next = chksum_state_reg;
        case (chksum_state_reg)
            READY: begin
                store_ip_hdr = 1'b1;
                assembler_src_req_rdy = chksum_in_cmd_rdy;
                in_chksum_cmd_val = src_assembler_req_val;
                in_chksum_cmd_enable = src_assembler_req_val;
                if (src_assembler_req_val & chksum_in_cmd_rdy) begin
                    data_out = 1'b1;
                    in_chksum_cmd_val = 1'b1;
                    in_chksum_cmd_enable = 1'b1;
                    chksum_state_next = IP_HDR_IN;
                end
            end
            IP_HDR_IN: begin
                in_chksum_req_val = 1'b1;
                if (chksum_in_req_rdy) begin
                    if (data_state_next == WAITING) begin
                        chksum_state_next = READY;
                    end
                    else begin
                        chksum_state_next = WAIT_DATA;
                    end
                end
            end
            WAIT_DATA: begin
                if (data_state_next == WAITING) begin
                    chksum_state_next = READY;
                end
            end
            default: begin
                store_ip_hdr = 'X;
                
                in_chksum_cmd_val = 'X;
                in_chksum_cmd_enable = 'X;

                assembler_src_req_rdy = 'X;

                data_out = 'X;

                chksum_state_next = UND;
            end
        endcase
    end

    always_comb begin
        in_data_fifo_wr_req = 1'b0;
        assembler_src_data_rdy = 1'b0;

        data_state_next = data_state_reg;
        case (data_state_reg)
            WAITING: begin
                if (data_out) begin
                    in_data_fifo_wr_req = ~data_fifo_in_full & src_assembler_data_val;
                    assembler_src_data_rdy = ~data_fifo_in_full;
                    if (~data_fifo_in_full & src_assembler_data_val) begin
                        if (src_assembler_data_last) begin
                            data_state_next = WAITING;
                        end
                        else begin
                            data_state_next = DATA_OUT;
                        end
                    end
                    else begin
                        data_state_next = DATA_OUT;
                    end
                end
            end
            DATA_OUT: begin
                in_data_fifo_wr_req = ~data_fifo_in_full & src_assembler_data_val;
                assembler_src_data_rdy = ~data_fifo_in_full;
                if (~data_fifo_in_full & src_assembler_data_val) begin
                    if (src_assembler_data_last) begin
                        data_state_next = WAITING;
                    end
                    else begin
                        data_state_next = DATA_OUT;
                    end
                end
            end
            default: begin
                in_data_fifo_wr_req = 'X;
                assembler_src_data_rdy = 'X;

                data_state_next = UNDEF;
            end
        endcase
    end

endmodule
