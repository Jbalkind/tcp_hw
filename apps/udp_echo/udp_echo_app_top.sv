`include "packet_defs.vh"
`include "soc_defs.vh"
import packet_struct_pkg::*;
module udp_echo_app_top (
     input clk
    ,input rst
    
    ,input  logic                               src_udp_echo_app_rx_hdr_val
    ,input  logic   [`IP_ADDR_W-1:0]            src_udp_echo_app_rx_src_ip
    ,input  logic   [`IP_ADDR_W-1:0]            src_udp_echo_app_rx_dst_ip
    ,input  udp_pkt_hdr                         src_udp_echo_app_rx_udp_hdr
    ,input          [`PKT_TIMESTAMP_W-1:0]      src_udp_echo_app_rx_timestamp
    ,output logic                               udp_echo_app_src_rx_hdr_rdy

    ,input  logic                               src_udp_echo_app_rx_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]      src_udp_echo_app_rx_data
    ,input  logic                               src_udp_echo_app_rx_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]       src_udp_echo_app_rx_padbytes
    ,output logic                               udp_echo_app_src_rx_data_rdy
    
    ,output logic                               udp_echo_app_dst_hdr_val
    ,output logic   [`IP_ADDR_W-1:0]            udp_echo_app_dst_src_ip_addr
    ,output logic   [`IP_ADDR_W-1:0]            udp_echo_app_dst_dst_ip_addr
    ,output udp_pkt_hdr                         udp_echo_app_dst_udp_hdr
    ,output logic   [`PKT_TIMESTAMP_W-1:0]      udp_echo_app_dst_timestamp
    ,input  logic                               dst_udp_echo_app_hdr_rdy
    
    ,output logic                               udp_echo_app_dst_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      udp_echo_app_dst_data
    ,output logic                               udp_echo_app_dst_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]       udp_echo_app_dst_data_padbytes
    ,input  logic                               dst_udp_echo_app_data_rdy
   
    ,output logic                               app_stats_do_log
    ,output logic                               app_stats_incr_bytes_sent
    ,output logic   [`MAC_INTERFACE_BYTES_W:0]  app_stats_num_bytes_sent
);

    logic   do_log_reg;
    logic   do_log_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            do_log_reg <= '0;
        end
        else begin
            do_log_reg <= do_log_next;
        end
    end

    assign do_log_next = src_udp_echo_app_rx_hdr_val
                        ? 1'b1
                        : do_log_reg;
    
    assign udp_echo_app_dst_hdr_val = src_udp_echo_app_rx_hdr_val;
    assign udp_echo_app_src_rx_hdr_rdy = dst_udp_echo_app_hdr_rdy;

    assign app_stats_do_log = do_log_reg;
    assign app_stats_incr_bytes_sent = src_udp_echo_app_rx_data_val 
                                       & dst_udp_echo_app_data_rdy;

    always_comb begin
        if (src_udp_echo_app_rx_last) begin
            app_stats_num_bytes_sent = `MAC_INTERFACE_BYTES - src_udp_echo_app_rx_padbytes;
        end
        else begin
            app_stats_num_bytes_sent = `MAC_INTERFACE_BYTES;
        end
    end

    always_comb begin
        udp_echo_app_dst_udp_hdr = src_udp_echo_app_rx_udp_hdr;
        udp_echo_app_dst_udp_hdr.src_port = src_udp_echo_app_rx_udp_hdr.dst_port;
        udp_echo_app_dst_udp_hdr.dst_port = src_udp_echo_app_rx_udp_hdr.src_port;
        udp_echo_app_dst_udp_hdr.chksum = '0;
    end

    assign udp_echo_app_dst_src_ip_addr = src_udp_echo_app_rx_dst_ip;
    assign udp_echo_app_dst_dst_ip_addr = src_udp_echo_app_rx_src_ip;
    assign udp_echo_app_dst_timestamp = src_udp_echo_app_rx_timestamp;

    assign udp_echo_app_dst_data_val = src_udp_echo_app_rx_data_val;
    assign udp_echo_app_src_rx_data_rdy = dst_udp_echo_app_data_rdy;

    assign udp_echo_app_dst_data = src_udp_echo_app_rx_data;
    assign udp_echo_app_dst_data_last = src_udp_echo_app_rx_last;
    assign udp_echo_app_dst_data_padbytes = src_udp_echo_app_rx_padbytes;


endmodule
