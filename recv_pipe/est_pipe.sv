`include "packet_defs.vh"

// est is short for established. As in an established flow
module est_pipe 
import tcp_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst
    
    ,input                                  est_hdr_val
    ,input  tcp_pkt_hdr                     est_tcp_hdr
    ,input          [FLOWID_W-1:0]          est_flowid
    ,input                                  est_payload_val
    ,input  payload_buf_struct              est_payload_entry
    ,output                                 est_pipe_rdy

    ,output logic                           est_pipe_rx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          est_pipe_rx_state_rd_req_flowid
    ,input                                  rx_state_est_pipe_rd_req_rdy

    ,input                                  rx_state_est_pipe_rd_resp_val
    ,input  recv_state_entry                rx_state_est_pipe_rd_resp_data
    ,output logic                           est_pipe_rx_state_rd_resp_rdy

    ,output logic                           est_pipe_tx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]          est_pipe_tx_state_rd_req_flowid
    ,input                                  tx_state_est_pipe_rd_req_rdy
    
    ,input                                  tx_state_est_pipe_rd_resp_val
    ,input  tx_state_struct                 tx_state_est_pipe_rd_resp_data
    ,output logic                           est_pipe_tx_state_rd_resp_rdy

    ,output                                 next_recv_state_wr_req_val
    ,output         [FLOWID_W-1:0]          next_recv_state_wr_req_addr
    ,output recv_state_entry                next_recv_state_wr_req_data
    ,input                                  next_recv_state_wr_req_rdy
    
    ,output                                 rx_pipe_tx_state_wr_req_val
    ,output         [FLOWID_W-1:0]          rx_pipe_tx_state_wr_req_flowid
    ,output tx_state_struct                 rx_pipe_tx_state_wr_req_data
    ,input                                  tx_state_rx_pipe_wr_req_rdy
    
    ,output                                 set_rt_flag_val
    ,output         [FLOWID_W-1:0]          set_rt_flag_flowid

    ,output                                 rx_pipe_tx_head_ptr_wr_req_val
    ,output         [FLOWID_W-1:0]          rx_pipe_tx_head_ptr_wr_req_flowid
    ,output         [TX_PAYLOAD_PTR_W:0]    rx_pipe_tx_head_ptr_wr_req_data
    ,input                                  tx_head_ptr_rx_pipe_wr_req_rdy
    
    ,output logic                           rx_pipe_rx_head_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_head_ptr_rd_req_addr
    ,input  logic                           rx_head_ptr_rx_pipe_rd_req_rdy

    ,input  logic                           rx_head_ptr_rx_pipe_rd_resp_val
    ,input  logic   [RX_PAYLOAD_PTR_W:0]    rx_head_ptr_rx_pipe_rd_resp_data
    ,output logic                           rx_pipe_rx_head_ptr_rd_resp_rdy
    
    ,output logic                           rx_pipe_rx_tail_ptr_wr_req_val
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_wr_req_addr
    ,output logic   [RX_PAYLOAD_PTR_W:0]    rx_pipe_rx_tail_ptr_wr_req_data
    ,input  logic                           rx_tail_ptr_rx_pipe_wr_req_rdy

    ,output logic                           rx_pipe_rx_tail_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]          rx_pipe_rx_tail_ptr_rd_req_addr
    ,input  logic                           rx_tail_ptr_rx_pipe_rd_req_rdy

    ,input  logic                           rx_tail_ptr_rx_pipe_rd_resp_val
    ,input  logic   [RX_PAYLOAD_PTR_W:0]    rx_tail_ptr_rx_pipe_rd_resp_data
    ,output logic                           rx_pipe_rx_tail_ptr_rd_resp_rdy

    ,output logic                           rx_store_buf_q_wr_req_val
    ,output rx_store_buf_q_struct           rx_store_buf_q_wr_req_data
    ,input  logic                           rx_store_buf_q_full
);

    tcp_pkt_hdr                 est_hdr_struct;
    payload_buf_struct          est_payload_entry_next;

    logic bubble_r;
    logic bubble_c;
    
    logic stall_r;
    logic stall_c;
    logic stall_w;
    
    logic                           est_hdr_val_reg_r;
    tcp_pkt_hdr                     est_hdr_struct_reg_r;
    logic   [FLOWID_W-1:0]          est_flowid_reg_r;
    logic                           est_payload_val_reg_r;
    payload_buf_struct              est_payload_entry_reg_r;


    logic                           est_hdr_val_reg_c;
    tcp_pkt_hdr                     est_hdr_struct_reg_c;
    logic   [FLOWID_W-1:0]          est_flowid_reg_c;
    logic                           est_payload_val_reg_c;
    payload_buf_struct              est_payload_entry_reg_c;
    logic   [RX_PAYLOAD_PTR_W:0]    est_rx_payload_q_head_ptr_reg_c;
    logic   [RX_PAYLOAD_PTR_W:0]    est_rx_payload_q_tail_ptr_reg_c;

    logic   [RX_PAYLOAD_PTR_W:0]    rx_payload_q_space_used_c;
    logic   [RX_PAYLOAD_PTR_W:0]    rx_payload_q_space_left_c;
    logic                           rx_payload_q_has_space_c;

    logic                           byp_state_c;

    tx_state_struct                 curr_tx_state_struct_byp_c;
    tx_ack_state_struct             curr_ack_state_struct_byp_c;
    tx_state_struct                 curr_tx_state_struct_cast_c;
    tx_ack_state_struct             curr_ack_state_struct_cast_c;
    recv_state_entry                curr_recv_state_struct_byp_c;
    logic   [RX_PAYLOAD_PTR_W:0]    est_rx_payload_q_tail_ptr_byp_c;
    
    recv_state_entry                next_recv_state_struct_c;
    logic   [`ACK_NUM_W-1:0]        next_rx_ack_num_c;
    tx_ack_state_struct             next_ack_state_struct_c;
    tx_state_struct                 next_tx_state_struct_c;

    
    

    logic   [RX_PAYLOAD_PTR_W:0]    next_rx_payload_q_tail_ptr_c;
    logic   [TX_PAYLOAD_PTR_W:0]    next_tx_head_ptr_c;

    logic                           ack_good_c;
    logic                           accept_payload_c;
    logic                           set_rt_flag_c;
    
    logic                           est_hdr_val_reg_w;
    logic   [FLOWID_W-1:0]          est_flowid_reg_w;
    logic                           est_payload_val_reg_w;
    payload_buf_struct              est_payload_entry_reg_w;

    tx_state_struct                 next_tx_state_struct_reg_w;
    tx_ack_state_struct             next_ack_state_struct_w;
    recv_state_entry                next_recv_state_struct_reg_w;
    logic   [TX_PAYLOAD_PTR_W:0]    next_tx_head_ptr_reg_w;
    logic   [RX_PAYLOAD_PTR_W:0]    next_rx_payload_q_tail_ptr_reg_w;
    logic   [RX_PAYLOAD_PTR_W:0]    prev_rx_payload_q_tail_ptr_reg_w;

    logic                           accept_payload_reg_w;
    logic                           set_rt_flag_reg_w;
   
    tcp_pkt_hdr                     dbg_est_hdr_struct_reg_w;
    logic   [`PORT_NUM_W-1:0]       dbg_src_port_w;
    logic   [`SEQ_NUM_W-1:0]        dbg_seq_num_w;
    logic   [`ACK_NUM_W-1:0]        dbg_ack_num_w;
    logic   [63:0]                  dropped_pkt_cnt_reg_w;
    logic   [63:0]                  dropped_pkt_cnt_next_w;
    
    rx_store_buf_q_struct rx_store_buf_q_wr_req_data_w;

    assign est_pipe_rdy = ~stall_r 
                        & rx_head_ptr_rx_pipe_rd_req_rdy 
                        & rx_tail_ptr_rx_pipe_rd_req_rdy;

/******************************************************************
 * Inputs
 *****************************************************************/
    assign rx_pipe_rx_head_ptr_rd_req_val = est_hdr_val;
    assign rx_pipe_rx_tail_ptr_rd_req_val = est_hdr_val;

    assign rx_pipe_rx_head_ptr_rd_req_addr = est_flowid;
    assign rx_pipe_rx_tail_ptr_rd_req_addr = est_flowid;

/******************************************************************
 * Inputs -> (R)ead state
 *****************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            est_hdr_val_reg_r <= '0;
            est_hdr_struct_reg_r <= '0;
            est_flowid_reg_r <= '0;
            est_payload_val_reg_r <= '0;
            est_payload_entry_reg_r <= '0;
        end
        else begin
            if (~stall_r) begin
                est_hdr_val_reg_r <= est_hdr_val;
                est_hdr_struct_reg_r <= est_tcp_hdr;
                est_flowid_reg_r <= est_flowid;
                est_payload_val_reg_r <= est_payload_val;
                est_payload_entry_reg_r <= est_payload_entry;
            end
        end
    end

/******************************************************************
 * (R)ead state stage
 *****************************************************************/
    assign bubble_r = stall_r;
    assign stall_r = est_hdr_val_reg_r & 
                   ( stall_c
                   | ~rx_state_est_pipe_rd_req_rdy
                   | ~tx_state_est_pipe_rd_req_rdy
                   | ~rx_head_ptr_rx_pipe_rd_resp_val
                   | ~rx_tail_ptr_rx_pipe_rd_resp_val);

    assign rx_pipe_rx_head_ptr_rd_resp_rdy = ~stall_r;
    assign rx_pipe_rx_tail_ptr_rd_resp_rdy = ~stall_r;

    assign est_pipe_rx_state_rd_req_val = est_hdr_val_reg_r;
    assign est_pipe_tx_state_rd_req_val = est_hdr_val_reg_r;
    
    assign est_pipe_rx_state_rd_req_flowid = est_flowid_reg_r;
    assign est_pipe_tx_state_rd_req_flowid = est_flowid_reg_r;
    
/******************************************************************
 * (R)ead state -> (C)ompute
 *****************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            est_hdr_val_reg_c <= '0;
            est_hdr_struct_reg_c <= '0;
            est_flowid_reg_c <= '0;
            est_payload_val_reg_c <= '0;
            est_payload_entry_reg_c <= '0;
            est_rx_payload_q_head_ptr_reg_c <= '0;
            est_rx_payload_q_tail_ptr_reg_c <= '0;
        end
        else begin
            if (~stall_c) begin
                est_hdr_val_reg_c <= est_hdr_val_reg_r & ~bubble_r;
                est_hdr_struct_reg_c <= est_hdr_struct_reg_r;
                est_flowid_reg_c <= est_flowid_reg_r;
                est_payload_val_reg_c <= est_payload_val_reg_r;
                est_payload_entry_reg_c <= est_payload_entry_reg_r;
                est_rx_payload_q_tail_ptr_reg_c <= rx_tail_ptr_rx_pipe_rd_resp_data;
                est_rx_payload_q_head_ptr_reg_c <= rx_head_ptr_rx_pipe_rd_resp_data;
            end
        end
    end

/******************************************************************
 * (C)ompute stage
 *****************************************************************/
    assign bubble_c = stall_c;
    assign stall_c = est_hdr_val_reg_c &
                   ( stall_w
                   | ~tx_state_est_pipe_rd_resp_val
                   | ~rx_state_est_pipe_rd_resp_val);

    assign est_pipe_tx_state_rd_resp_rdy = ~stall_c;
    assign est_pipe_rx_state_rd_resp_rdy = ~stall_c;

    assign curr_tx_state_struct_cast_c = tx_state_est_pipe_rd_resp_data;
    
    // C stage byp muxes
    assign byp_state_c = est_hdr_val_reg_c 
                       & est_hdr_val_reg_w 
                       & (est_flowid_reg_c == est_flowid_reg_w);

    assign curr_recv_state_struct_byp_c = byp_state_c 
                                        ? next_recv_state_struct_reg_w
                                        : rx_state_est_pipe_rd_resp_data;

    assign curr_ack_state_struct_cast_c = curr_tx_state_struct_cast_c.tx_curr_ack_state;
    assign next_ack_state_struct_w = next_tx_state_struct_reg_w.tx_curr_ack_state;

    assign curr_tx_state_struct_byp_c.tx_curr_seq_num = curr_tx_state_struct_cast_c.tx_curr_seq_num;


    assign curr_ack_state_struct_byp_c.tx_curr_ack_num = byp_state_c
                                                       ? next_ack_state_struct_w.tx_curr_ack_num
                                                       : curr_ack_state_struct_cast_c.tx_curr_ack_num;

    assign curr_ack_state_struct_byp_c.tx_curr_ack_cnt = byp_state_c
                                                       ? next_ack_state_struct_w.tx_curr_ack_cnt
                                                       : curr_ack_state_struct_cast_c.tx_curr_ack_cnt;

    assign curr_tx_state_struct_byp_c.tx_curr_ack_state = curr_ack_state_struct_byp_c;

    assign est_rx_payload_q_tail_ptr_byp_c = byp_state_c 
                                           ? next_rx_payload_q_tail_ptr_reg_w
                                           : est_rx_payload_q_tail_ptr_reg_c;

    assign rx_payload_q_space_used_c = est_rx_payload_q_tail_ptr_byp_c - est_rx_payload_q_head_ptr_reg_c;
    assign rx_payload_q_space_left_c = {1'b1, {(RX_PAYLOAD_PTR_W){1'b0}}} - rx_payload_q_space_used_c;
    assign rx_payload_q_has_space_c = rx_payload_q_space_left_c >= est_payload_entry_reg_c.payload_len;

    assign accept_payload_c = ack_good_c & rx_payload_q_has_space_c;

    assign next_rx_payload_q_tail_ptr_c = accept_payload_c 
                                ? est_rx_payload_q_tail_ptr_byp_c + est_payload_entry_reg_c.payload_len
                                : est_rx_payload_q_tail_ptr_byp_c;
                        
    
    rx_ack_engine rx_ack_engine (
         .curr_ack_num          (curr_recv_state_struct_byp_c.rx_curr_ack_num   )
        ,.packet_seq_num        (est_hdr_struct_reg_c.seq_num                   )
        ,.packet_payload_val    (est_payload_val_reg_c                          )
        ,.packet_payload_len    (est_payload_entry_reg_c.payload_len            )
    
        ,.next_ack_num          (next_rx_ack_num_c                              )
        ,.accept_payload        (ack_good_c                                     )
    );

    assign next_recv_state_struct_c.rx_curr_ack_num = accept_payload_c
                                        ? next_rx_ack_num_c
                                        : curr_recv_state_struct_byp_c.rx_curr_ack_num;
    assign next_recv_state_struct_c.rx_curr_wnd_size = rx_payload_q_space_left_c;

    tx_ack_engine tx_ack_engine (
         .curr_ack_num  (curr_ack_state_struct_byp_c.tx_curr_ack_num)
        ,.pkt_ack_num   (est_hdr_struct_reg_c.ack_num               )
        ,.curr_seq_num  (curr_tx_state_struct_byp_c.tx_curr_seq_num )
        ,.curr_ack_cnt  (curr_ack_state_struct_byp_c.tx_curr_ack_cnt)

        ,.next_ack_cnt  (next_ack_state_struct_c.tx_curr_ack_cnt    )
        ,.next_ack_num  (next_ack_state_struct_c.tx_curr_ack_num    )
        ,.set_rt_flag   (set_rt_flag_c                              )
        ,.next_head_ptr (next_tx_head_ptr_c                         )
    );

    assign next_tx_state_struct_c.tx_curr_seq_num = curr_tx_state_struct_cast_c.tx_curr_seq_num;
    assign next_tx_state_struct_c.tx_curr_ack_state = next_ack_state_struct_c;


/******************************************************************
 * (C)ompute stage -> (W)riteback stage
 *****************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            est_hdr_val_reg_w <= '0;
            est_flowid_reg_w <= '0;
            est_payload_val_reg_w <= '0;
            est_payload_entry_reg_w <= '0;

            next_recv_state_struct_reg_w <= '0;
            next_tx_state_struct_reg_w <= '0;
            next_tx_head_ptr_reg_w <= '0;
            set_rt_flag_reg_w <= '0;
            next_rx_payload_q_tail_ptr_reg_w <= '0;
            prev_rx_payload_q_tail_ptr_reg_w <= '0;
            accept_payload_reg_w <= '0;

            dbg_est_hdr_struct_reg_w <= '0;
        end
        else begin
            if (~stall_w) begin
                est_hdr_val_reg_w <= est_hdr_val_reg_c & ~bubble_c;
                est_flowid_reg_w <= est_flowid_reg_c;
                est_payload_val_reg_w <= est_payload_val_reg_c & accept_payload_c;
                est_payload_entry_reg_w <= est_payload_entry_reg_c; 
                accept_payload_reg_w <= accept_payload_c;

                next_recv_state_struct_reg_w <= next_recv_state_struct_c;
                next_tx_state_struct_reg_w <= next_tx_state_struct_c;

                next_tx_head_ptr_reg_w <= next_tx_head_ptr_c;
                set_rt_flag_reg_w <= set_rt_flag_c;

                next_rx_payload_q_tail_ptr_reg_w <= next_rx_payload_q_tail_ptr_c;
                prev_rx_payload_q_tail_ptr_reg_w <= est_rx_payload_q_tail_ptr_byp_c;

                dbg_est_hdr_struct_reg_w <= est_hdr_struct_reg_c;
            end
        end
    end
/******************************************************************
 * (W)riteback stage
 *****************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            dropped_pkt_cnt_reg_w <= '0;
        end
        else begin
            dropped_pkt_cnt_reg_w <= dropped_pkt_cnt_next_w;
        end
    end

    assign dropped_pkt_cnt_next_w = est_hdr_val_reg_w & ~stall_w & ~accept_payload_reg_w
                                    ? dropped_pkt_cnt_reg_w + 1'b1
                                    : dropped_pkt_cnt_reg_w;

    assign dbg_src_port_w = dbg_est_hdr_struct_reg_w.src_port;
    assign dbg_seq_num_w = dbg_est_hdr_struct_reg_w.seq_num;
    assign dbg_ack_num_w = dbg_est_hdr_struct_reg_w.ack_num;

    assign stall_w = ~next_recv_state_wr_req_rdy
                   | ~tx_state_rx_pipe_wr_req_rdy
                   | ~tx_head_ptr_rx_pipe_wr_req_rdy
                   | rx_store_buf_q_full;

    assign next_recv_state_wr_req_val = est_hdr_val_reg_w;
    assign next_recv_state_wr_req_addr = est_flowid_reg_w;
    assign next_recv_state_wr_req_data = next_recv_state_struct_reg_w;

    assign rx_pipe_tx_state_wr_req_val = est_hdr_val_reg_w;
    assign rx_pipe_tx_state_wr_req_flowid = est_flowid_reg_w;
    assign rx_pipe_tx_state_wr_req_data = next_tx_state_struct_reg_w;

    assign set_rt_flag_val = set_rt_flag_reg_w & est_hdr_val_reg_w;
    assign set_rt_flag_flowid = est_flowid_reg_w;

    assign rx_pipe_tx_head_ptr_wr_req_val = est_hdr_val_reg_w;
    assign rx_pipe_tx_head_ptr_wr_req_flowid = est_flowid_reg_w;
    assign rx_pipe_tx_head_ptr_wr_req_data = next_tx_head_ptr_reg_w;

    assign rx_pipe_rx_tail_ptr_wr_req_val = est_hdr_val_reg_w & accept_payload_reg_w;
    assign rx_pipe_rx_tail_ptr_wr_req_addr = est_flowid_reg_w;
    assign rx_pipe_rx_tail_ptr_wr_req_data = next_rx_payload_q_tail_ptr_reg_w;

    assign rx_store_buf_q_wr_req_val = est_hdr_val_reg_w & ~stall_w
                                     & (est_payload_entry_reg_w.payload_len > 0);

    assign rx_store_buf_q_wr_req_data_w.flowid = est_flowid_reg_w;
    assign rx_store_buf_q_wr_req_data_w.accept_payload = accept_payload_reg_w;
    assign rx_store_buf_q_wr_req_data_w.payload_entry = est_payload_entry_reg_w;

    assign rx_store_buf_q_wr_req_data = rx_store_buf_q_wr_req_data_w;

endmodule
