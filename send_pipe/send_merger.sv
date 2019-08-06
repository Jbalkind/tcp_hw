`include "packet_defs.vh"
module send_merger 
import packet_struct_pkg::*;
import tcp_pkg::*;
(
     input  logic                       tx_pipe_merger_tx_val
    ,input  logic   [FLOWID_W-1:0]      tx_pipe_merger_tx_flowid
    ,input  logic   [`IP_ADDR_W-1:0]    tx_pipe_merger_tx_src_ip
    ,input  logic   [`IP_ADDR_W-1:0]    tx_pipe_merger_tx_dst_ip
    ,input  tcp_pkt_hdr                 tx_pipe_merger_tx_tcp_hdr
    ,input  payload_buf_struct          tx_pipe_merger_tx_payload
    ,output logic                       merger_tx_pipe_tx_rdy
    
    ,output logic                       rx_pipe_merger_tx_deq_req_val
    ,input  rx_send_queue_struct        rx_pipe_merger_tx_deq_resp_data
    ,input  logic                       rx_pipe_merger_tx_empty
    
    ,output                             send_dst_tx_val
    ,output logic   [FLOWID_W-1:0]      send_dst_tx_flowid
    ,output logic   [`IP_ADDR_W-1:0]    send_dst_tx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]    send_dst_tx_dst_ip
    ,output tcp_pkt_hdr                 send_dst_tx_tcp_hdr
    ,output payload_buf_struct          send_dst_tx_payload
    ,input                              dst_send_tx_rdy

);

    logic use_rx_pipe_send;
    rx_send_queue_struct rx_send_queue_cast;

    assign rx_send_queue_cast = rx_pipe_merger_tx_deq_resp_data;

    assign use_rx_pipe_send = ~rx_pipe_merger_tx_empty;

    assign rx_pipe_merger_tx_deq_req_val = use_rx_pipe_send & dst_send_tx_rdy;
    assign merger_tx_pipe_tx_rdy = ~use_rx_pipe_send & dst_send_tx_rdy;





    assign send_dst_tx_val = use_rx_pipe_send
                           ? rx_pipe_merger_tx_deq_req_val
                           : tx_pipe_merger_tx_val;

    assign send_dst_tx_flowid = use_rx_pipe_send 
                              ? rx_send_queue_cast.flowid
                              : tx_pipe_merger_tx_flowid;
    assign send_dst_tx_src_ip = use_rx_pipe_send 
                              ? rx_send_queue_cast.src_ip
                              : tx_pipe_merger_tx_src_ip;
    assign send_dst_tx_dst_ip = use_rx_pipe_send 
                              ? rx_send_queue_cast.dst_ip
                              : tx_pipe_merger_tx_dst_ip;
    assign send_dst_tx_tcp_hdr = use_rx_pipe_send
                               ? rx_send_queue_cast.tcp_hdr
                               : tx_pipe_merger_tx_tcp_hdr;
    assign send_dst_tx_payload = use_rx_pipe_send
                               ? '0
                               : tx_pipe_merger_tx_payload;


endmodule
