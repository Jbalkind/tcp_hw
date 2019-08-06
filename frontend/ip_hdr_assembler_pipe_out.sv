`include "soc_defs.vh"
`include "packet_defs.vh"
module ip_hdr_assembler_pipe_out
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
    
    ,input  logic   [DATA_W-1:0]            chksum_out_resp_data
    ,input  tracker_stats_struct            chksum_out_resp_user
    ,input  logic                           chksum_out_resp_val
    ,output logic                           out_chksum_resp_rdy

    ,output logic                           out_data_fifo_rd_req
    ,input  logic                           data_fifo_out_empty
    ,input  fifo_struct                     data_fifo_out_data

    ,output logic                           assembler_dst_hdr_val
    ,output tracker_stats_struct            assembler_dst_timestamp
    ,output ip_pkt_hdr                      assembler_dst_ip_hdr
    ,input                                  dst_assembler_hdr_rdy

    ,output logic                           assembler_dst_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]  assembler_dst_data
    ,output logic   [`MAC_PADBYTES_W-1:0]   assembler_dst_data_padbytes
    ,output logic                           assembler_dst_data_last
    ,input  logic                           dst_assembler_data_rdy
);

    assign assembler_dst_hdr_val = chksum_out_resp_val;
    assign assembler_dst_ip_hdr = chksum_out_resp_data[DATA_W - 1 -: IP_HDR_W];
    assign assembler_dst_timestamp = chksum_out_resp_user;
    assign out_chksum_resp_rdy = dst_assembler_hdr_rdy;

    assign out_data_fifo_rd_req = ~data_fifo_out_empty & dst_assembler_data_rdy;
    assign assembler_dst_data_val = ~data_fifo_out_empty;

    assign assembler_dst_data = data_fifo_out_data.data;
    assign assembler_dst_data_padbytes = data_fifo_out_data.padbytes;
    assign assembler_dst_data_last = data_fifo_out_data.last;
    
endmodule
