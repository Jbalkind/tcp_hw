`include "packet_defs.vh"
module hdr_assembler_pipe 
import packet_struct_pkg::*;
import tcp_pkg::*;
(
     input clk
    ,input rst
    
    ,input                              main_pipe_assembler_tx_val
    ,input          [FLOWID_W-1:0]      main_pipe_assembler_tx_flowid
    ,input  logic   [`SEQ_NUM_W-1:0]    main_pipe_assembler_tx_seq_num
    ,input  payload_buf_struct          main_pipe_assembler_tx_payload
    ,output                             assembler_main_pipe_tx_rdy

    ,output logic                       send_pipe_recv_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]      send_pipe_recv_state_rd_req_flowid
    ,input  logic                       recv_state_send_pipe_rd_req_rdy

    ,input  logic                       recv_state_send_pipe_rd_resp_val
    ,input  recv_state_entry            recv_state_send_pipe_rd_resp_data
    ,output logic                       send_pipe_recv_state_rd_resp_rdy
    
    ,output logic                       assembler_flowid_lookup_rd_req_val
    ,output logic   [FLOWID_W-1:0]      assembler_flowid_lookup_rd_req_flowid
    ,input  logic                       flowid_lookup_assembler_rd_req_rdy

    ,input  logic                       flowid_lookup_assembler_rd_resp_val
    ,input  four_tuple_struct           flowid_lookup_assembler_rd_resp_data
    ,output logic                       assembler_flowid_lookup_rd_resp_rdy

    ,output logic                       assembler_dst_tx_val
    ,output logic   [FLOWID_W-1:0]      assembler_dst_tx_flowid
    ,output logic   [`IP_ADDR_W-1:0]    assembler_dst_tx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]    assembler_dst_tx_dst_ip
    ,output tcp_pkt_hdr                 assembler_dst_tx_tcp_hdr
    ,output payload_buf_struct          assembler_dst_tx_payload
    ,input                              dst_assembler_tx_rdy

);

    logic                       val_i;
    logic                       stall_i;
    logic   [FLOWID_W-1:0]      flowid_i;
    logic   [`SEQ_NUM_W-1:0]    tcp_seq_num_i;
    payload_buf_struct          payload_i;
    
    logic                       stall_r;
    logic                       bubble_r;
    logic                       val_reg_r;
    logic   [FLOWID_W-1:0]      flowid_reg_r;
    logic   [`SEQ_NUM_W-1:0]    tcp_seq_num_reg_r;
    payload_buf_struct          payload_reg_r;
   
    logic                       bubble_a;
    logic                       stall_a;
    logic                       val_reg_a;
    logic   [FLOWID_W-1:0]      flowid_reg_a;
    logic   [`SEQ_NUM_W-1:0]    tcp_seq_num_reg_a;
    payload_buf_struct          payload_reg_a;
    recv_state_entry            recv_state_resp_a;


    logic                       bubble_l;
    logic                       stall_l;
    logic                       val_reg_l;
    logic   [FLOWID_W-1:0]      flowid_reg_l;
    logic   [`SEQ_NUM_W-1:0]    tcp_seq_num_reg_l;
    payload_buf_struct          payload_reg_l;
    recv_state_entry            recv_state_reg_l;

    four_tuple_struct           flowid_lookup_resp_data_l;
    
    logic                       stall_t;
    logic                       val_reg_t;
    logic   [FLOWID_W-1:0]      flowid_reg_t;
    logic   [`SEQ_NUM_W-1:0]    tcp_seq_num_reg_t;
    payload_buf_struct          payload_reg_t;
    tcp_pkt_hdr                 assembled_tcp_hdr_t;
    recv_state_entry            recv_state_reg_t;
    four_tuple_struct           flowid_lookup_reg_t;
   
    logic                       stall_o;
    logic                       val_reg_o;
    logic   [FLOWID_W-1:0]      flowid_reg_o;
    payload_buf_struct          payload_reg_o;
    four_tuple_struct           flowid_lookup_data_reg_o;
    tcp_pkt_hdr                 assembled_tcp_hdr_reg_o;

/**************************************************************
 * (I)nput stage
 *************************************************************/
    assign assembler_main_pipe_tx_rdy = ~stall_i;

    assign stall_i = stall_l;
    assign val_i = main_pipe_assembler_tx_val;
    assign flowid_i = main_pipe_assembler_tx_flowid;
    assign tcp_seq_num_i = main_pipe_assembler_tx_seq_num;
    assign payload_i = main_pipe_assembler_tx_payload;

/**************************************************************
 * (I)nput -> ACK (R)ead
 *************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_r <= '0;
            flowid_reg_r <= '0;
            tcp_seq_num_reg_r <= '0;
            payload_reg_r <= '0;
        end
        else begin
            if (~stall_r) begin
                val_reg_r <= val_i;
                flowid_reg_r <= flowid_i;
                tcp_seq_num_reg_r <= tcp_seq_num_i;
                payload_reg_r <= payload_i;
            end
        end
    end

/**************************************************************
 * ACK (R)ead stage
 *************************************************************/
    assign bubble_r = stall_r;
    assign stall_r = val_reg_r & (stall_a | ~recv_state_send_pipe_rd_req_rdy);

    assign send_pipe_recv_state_rd_req_val = val_reg_r;
    assign send_pipe_recv_state_rd_req_flowid = flowid_reg_r;

/**************************************************************
 * ACK (R)ead -> (A)CK
 *************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_a <= '0;
            flowid_reg_a <= '0;
            tcp_seq_num_reg_a <= '0;
            payload_reg_a <= '0;
        end
        else begin
            if (~stall_a) begin
                val_reg_a <= val_reg_r & ~bubble_r;
                flowid_reg_a <= flowid_reg_r;
                tcp_seq_num_reg_a <= tcp_seq_num_reg_r;
                payload_reg_a <= payload_reg_r;
            end
        end
    end

/**************************************************************
 * (A)CK stage
 *************************************************************/
    assign bubble_a = stall_a;
    assign stall_a = val_reg_a & (stall_l 
                                 | ~recv_state_send_pipe_rd_resp_val
                                 | ~flowid_lookup_assembler_rd_req_rdy);

    assign send_pipe_recv_state_rd_resp_rdy = ~stall_a;
    assign recv_state_resp_a = recv_state_send_pipe_rd_resp_data;

    assign assembler_flowid_lookup_rd_req_val = val_reg_a;
    assign assembler_flowid_lookup_rd_req_flowid = flowid_reg_a;

/**************************************************************
 * (A)CK read -> (L)ookup
 *************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_l <= '0;
            flowid_reg_l <= '0;
            tcp_seq_num_reg_l <= '0;
            payload_reg_l <= '0;
            recv_state_reg_l <= '0;
        end
        else begin
            if (~stall_l) begin
                val_reg_l <= val_reg_a & ~bubble_a;
                flowid_reg_l <= flowid_reg_a;
                tcp_seq_num_reg_l <= tcp_seq_num_reg_a;
                payload_reg_l <= payload_reg_a;
                recv_state_reg_l <= recv_state_resp_a;
            end
        end
    end

/**************************************************************
 * (L)ookup stage
 *************************************************************/
    assign bubble_l = stall_l;
    assign stall_l = val_reg_l & (stall_t | ~flowid_lookup_assembler_rd_resp_val);

    assign assembler_flowid_lookup_rd_resp_rdy = ~stall_l;
    assign flowid_lookup_resp_data_l = flowid_lookup_assembler_rd_resp_data;


/**************************************************************
 * (L)ookup -> (T)CP header
 *************************************************************/

    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_t <= '0;
            flowid_reg_t <= '0;
            tcp_seq_num_reg_t <= '0;
            payload_reg_t <= '0;
            recv_state_reg_t <= '0;
            flowid_lookup_reg_t <= '0;
        end
        else begin
            if (~stall_t) begin
                val_reg_t <= val_reg_l & ~bubble_l;
                flowid_reg_t <= flowid_reg_l;
                tcp_seq_num_reg_t <= tcp_seq_num_reg_l;
                payload_reg_t <= payload_reg_l;
                recv_state_reg_t <= recv_state_reg_l;
                flowid_lookup_reg_t <= flowid_lookup_resp_data_l;
            end
        end
    end
    
/**************************************************************
 * (T)CP header stage
 *************************************************************/
    logic  tcp_hdr_req_rdy_t;
    assign stall_t = val_reg_t 
                 & (stall_o 
                   | ~tcp_hdr_req_rdy_t);

    // we need to not ever close the window completely, because updating
    // the rx state and checking the window size requires receiving packets,
    // so we want the other side to always be willing to send
    logic   [`WIN_SIZE_W-1:0] win_size_t;
    assign win_size_t = recv_state_reg_t.rx_curr_wnd_size == 0
                        ? `WIN_SIZE_W'd1
                        : recv_state_reg_t.rx_curr_wnd_size;

    tcp_hdr_assembler tcp_hdr_assembler (
         .tcp_hdr_req_val       (val_reg_t                          )
        ,.host_port             (flowid_lookup_reg_t.host_port      )
        ,.dest_port             (flowid_lookup_reg_t.dest_port      )
        ,.seq_num               (tcp_seq_num_reg_t                  )
        ,.ack_num               (recv_state_reg_t.rx_curr_ack_num   )
        ,.flags                 (`TCP_ACK | `TCP_PSH                )
        ,.window                (win_size_t                         )
        ,.tcp_hdr_req_rdy       (tcp_hdr_req_rdy_t                  )

        ,.outbound_tcp_hdr_val  (                                   )
        ,.outbound_tcp_hdr_rdy  (~stall_o                           )
        ,.outbound_tcp_hdr      (assembled_tcp_hdr_t                )
    );


/**************************************************************
 * (T)CP header -> (O)utput
 *************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_o <= '0;
            flowid_reg_o <= '0;
            payload_reg_o <= '0;
            assembled_tcp_hdr_reg_o <= '0;
            flowid_lookup_data_reg_o <= '0;
        end
        else begin
            if (~stall_o) begin
                val_reg_o <= val_reg_t;
                flowid_reg_o <= flowid_reg_t;
                payload_reg_o <= payload_reg_t;
                assembled_tcp_hdr_reg_o <= assembled_tcp_hdr_t;
                flowid_lookup_data_reg_o <= flowid_lookup_reg_t;
            end
        end
    end
/**************************************************************
 * (O)utput stage
 *************************************************************/
    assign stall_o = ~dst_assembler_tx_rdy;
    assign assembler_dst_tx_val = val_reg_o;
    assign assembler_dst_tx_flowid = flowid_reg_o;
    assign assembler_dst_tx_tcp_hdr = assembled_tcp_hdr_reg_o;
    assign assembler_dst_tx_payload = payload_reg_o;
    assign assembler_dst_tx_src_ip = flowid_lookup_data_reg_o.host_ip;
    assign assembler_dst_tx_dst_ip = flowid_lookup_data_reg_o.dest_ip;
endmodule
