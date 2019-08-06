`include "packet_defs.vh"
module protocol_logic_pipe 
import packet_struct_pkg::*;
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,output logic                               main_pipe_sched_fifo_tx_rd_req
    ,input          [FLOWID_W-1:0]              sched_fifo_main_pipe_tx_rd_flowid
    ,input                                      sched_fifo_main_pipe_tx_rd_empty

    ,output logic                               rt_timeout_flag_req_val
    ,output logic   [FLOWID_W-1:0]              rt_timeout_flag_req_flowid
    ,input  logic                               rt_timeout_flag_req_rdy

    ,input  logic                               rt_timeout_flag_resp_val
    ,input  logic   [RT_TIMEOUT_FLAGS_W-1:0]    rt_timeout_flag_resp_data
    ,output logic                               rt_timeout_flag_resp_rdy
    
    ,output logic                               send_q_tail_ptr_rd_req_val
    ,output logic   [FLOWID_W-1:0]              send_q_tail_ptr_rd_req_flowid
    ,input  logic                               send_q_tail_ptr_rd_req_rdy

    ,input  logic                               send_q_tail_ptr_rd_resp_val
    ,input          [TX_PAYLOAD_PTR_W:0]        send_q_tail_ptr_rd_resp_data
    ,output logic                               send_q_tail_ptr_rd_resp_rdy

    ,output logic                               tx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]              tx_state_rd_req_flowid
    ,input  logic                               tx_state_rd_req_rdy

    ,input  logic                               tx_state_rd_resp_val
    ,input  tx_state_struct                     tx_state_rd_resp_data
    ,output logic                               tx_state_rd_resp_rdy

    ,output logic                               tx_state_wr_req_val
    ,output logic   [FLOWID_W-1:0]              tx_state_wr_req_flowid
    ,output tx_state_struct                     tx_state_wr_req_data
    ,input  logic                               tx_state_wr_req_rdy

    ,output logic                               main_pipe_sched_fifo_tx_wr_req
    ,output logic   [FLOWID_W-1:0]              main_pipe_sched_fifo_tx_wr_flowid
    ,input  logic                               sched_fifo_main_pipe_tx_wr_full

    ,output logic                               main_pipe_rt_timeout_clr_bit_val
    ,output logic   [FLOWID_W-1:0]              main_pipe_rt_timeout_clr_bit_flowid

    ,output                                     main_pipe_assembler_tx_val
    ,output         [FLOWID_W-1:0]              main_pipe_assembler_tx_flowid
    ,output logic   [`SEQ_NUM_W-1:0]            main_pipe_assembler_tx_seq_num
    ,output payload_buf_struct                  main_pipe_assembler_tx_payload
    ,input                                      assembler_main_pipe_tx_rdy
);

    logic                           stall_s;
    logic                           val_s;
    logic                           bubble_s;
    logic                           sched_fifo_rd_req_s;
    logic                           sched_fifo_rd_empty_s;
    logic   [FLOWID_W-1:0]          sched_fifo_rd_flowid_s;

    logic                           stall_rt;
    logic                           bubble_rt;
    logic                           val_reg_rt;
    logic   [FLOWID_W-1:0]          flowid_reg_rt;
    rt_timeout_flag_struct          rt_timeout_flags_rt;
    
    logic                           rt_timeout_flags_stall_val_reg_rt;
    logic                           rt_timeout_flags_stall_val_next_rt;
    rt_timeout_flag_struct          rt_timeout_flags_stall_data_reg_rt;

    logic                           tx_state_byp_val_rt;
    tx_state_struct                 tx_state_byp_data_rt;

    logic                           bubble_n;
    logic                           val_reg_n;
    logic                           stall_n;
    logic   [FLOWID_W-1:0]          flowid_reg_n;
    rt_timeout_flag_struct          rt_timeout_flags_reg_n;
    
    logic                           tx_state_byp_val_reg_n;
    tx_state_struct                 tx_state_byp_data_reg_n;

    logic                           send_q_tail_ptr_stall_val_reg_n;
    logic                           send_q_tail_ptr_stall_val_next_n;
    logic   [TX_PAYLOAD_PTR_W:0]    send_q_tail_ptr_stall_data_reg_n;

    logic                           tx_state_stall_val_reg_n;
    logic                           tx_state_stall_val_next_n;
    tx_state_struct                 tx_state_stall_data_reg_n;

    tx_state_struct                 tx_state_resp_data_cast_n;

    tx_state_struct                 tx_state_next_data_n;
    tx_state_struct                 tx_data_byp_n;
    logic   [TX_PAYLOAD_PTR_W:0]    send_q_tail_ptr_byp_n;

    logic   [TX_PAYLOAD_PTR_W:0]    rt_seg_size_n;
    logic   [TX_PAYLOAD_PTR_W:0]    new_seg_size_n;
    payload_buf_struct              payload_buf_n;

    tx_state_struct                 next_tx_data_n;
    logic   [`SEQ_NUM_W-1:0]        tx_pkt_seq_num_n;
    logic                           generate_pkt_n;

    logic                           val_reg_w;
    logic                           stall_w;
    logic   [FLOWID_W-1:0]          flowid_reg_w;
    tx_state_struct                 next_tx_data_reg_w;
    payload_buf_struct              payload_buf_reg_w;
    rt_timeout_flag_struct          rt_timeout_flags_reg_w;
    logic                           generate_pkt_reg_w;
    logic   [`SEQ_NUM_W-1:0]        tx_pkt_seq_num_reg_w;


    assign main_pipe_sched_fifo_tx_rd_req = sched_fifo_rd_req_s;
    assign sched_fifo_rd_empty_s = sched_fifo_main_pipe_tx_rd_empty;

    assign tx_state_resp_data_cast_n = tx_state_rd_resp_data;

/**********************************************************
 * (S)cheduling stage
 *********************************************************/
    assign val_s = ~sched_fifo_rd_empty_s; 
    assign stall_s = val_s & (stall_rt | ~rt_timeout_flag_req_rdy);
    assign bubble_s = stall_s;

    assign sched_fifo_rd_req_s = ~stall_s & ~sched_fifo_rd_empty_s;
    assign sched_fifo_rd_flowid_s = sched_fifo_main_pipe_tx_rd_flowid;

    assign rt_timeout_flag_req_val = val_s;
    assign rt_timeout_flag_req_flowid = sched_fifo_rd_flowid_s;

/**********************************************************
 * (S)cheduling -> (R)X/(T)imeout
 *********************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_rt <= '0;
            flowid_reg_rt <= '0;
        end
        else begin
            if (~stall_rt) begin
                val_reg_rt <= val_s & ~bubble_s;
                flowid_reg_rt <= sched_fifo_rd_flowid_s;
            end
        end
    end

/**********************************************************
 * (R)X/(T)imeout stage
 *********************************************************/
    assign bubble_rt = stall_rt;
    assign stall_rt = val_reg_rt & 
                      (stall_n 
                      | (~rt_timeout_flag_resp_val & ~rt_timeout_flags_stall_val_reg_rt)
                      | ~send_q_tail_ptr_rd_req_rdy
                      | ~rt_timeout_flag_resp_val
                      | ~tx_state_rd_req_rdy);

    assign rt_timeout_flag_resp_rdy = 1'b1;
    assign rt_timeout_flags_rt = rt_timeout_flag_resp_data;
   
    assign tx_state_rd_req_val = val_reg_rt;
    assign tx_state_rd_req_flowid = flowid_reg_rt;

    assign send_q_tail_ptr_rd_req_val = val_reg_rt;
    assign send_q_tail_ptr_rd_req_flowid = flowid_reg_rt;

    always_ff @(posedge clk) begin
        if (rst) begin
            rt_timeout_flags_stall_val_reg_rt <= '0;
        end
        else begin
            rt_timeout_flags_stall_val_reg_rt <= rt_timeout_flags_stall_val_next_rt;
        end
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            rt_timeout_flags_stall_data_reg_rt <= '0;
        end
        else begin
            if (rt_timeout_flag_resp_val & ~rt_timeout_flags_stall_val_reg_rt) begin
                rt_timeout_flags_stall_data_reg_rt <= rt_timeout_flag_resp_data;
            end
        end
    end

    always_comb begin
        rt_timeout_flags_stall_val_next_rt = rt_timeout_flags_stall_val_reg_rt;
        if (stall_rt) begin
            rt_timeout_flags_stall_val_next_rt = rt_timeout_flags_stall_val_reg_rt 
                                                 | rt_timeout_flag_resp_val;
        end
        else begin
            rt_timeout_flags_stall_val_next_rt = 1'b0;
        end
    end

/*********************************************************
 * (R)X/(T)imeout -> (N)umbering
 ********************************************************/ 
    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_n <= '0;
            flowid_reg_n <= '0;
            rt_timeout_flags_reg_n <= '0;
        end
        else begin
            if (~stall_n) begin
                val_reg_n <= val_reg_rt & ~bubble_rt;
                flowid_reg_n <= flowid_reg_rt;
                rt_timeout_flags_reg_n <= rt_timeout_flags_stall_val_reg_rt 
                                          ? rt_timeout_flags_stall_data_reg_rt
                                          : rt_timeout_flags_rt;
            end
        end
    end

/*********************************************************
 * (N)umbering stage
 ********************************************************/ 
    logic   [TIMESTAMP_W-1:0]   timestamp_reg_n;
    logic                       tx_timer_exp_n;
    assign bubble_n = stall_n;
    assign stall_n = val_reg_n & 
                     (stall_w 
                     | (~send_q_tail_ptr_rd_resp_val & ~send_q_tail_ptr_stall_val_reg_n)
                     | (~tx_state_rd_resp_val & ~tx_state_stall_val_reg_n));

    assign send_q_tail_ptr_rd_resp_rdy = 1'b1;
    assign tx_state_rd_resp_rdy = 1'b1;

    always_ff @(posedge clk) begin
        if (rst) begin
            timestamp_reg_n <= '0;
        end
        else begin
            timestamp_reg_n <= timestamp_reg_n + 1'b1;
        end
    end

    // these are just here to catch values in case of stall
    always_ff @(posedge clk) begin
        if (rst) begin
            send_q_tail_ptr_stall_val_reg_n <= '0;
            tx_state_stall_val_reg_n <= '0;
        end
        else begin
            send_q_tail_ptr_stall_val_reg_n <= send_q_tail_ptr_stall_val_next_n;
            tx_state_stall_val_reg_n <= tx_state_stall_val_next_n;
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            send_q_tail_ptr_stall_data_reg_n <= '0;
        end
        else begin
            if (send_q_tail_ptr_rd_resp_val & ~send_q_tail_ptr_stall_val_reg_n) begin
                send_q_tail_ptr_stall_data_reg_n <= send_q_tail_ptr_rd_resp_data;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            tx_state_stall_data_reg_n <= '0;
        end
        else begin
            if (tx_state_rd_resp_val & ~tx_state_stall_val_reg_n) begin
                tx_state_stall_data_reg_n <= tx_state_resp_data_cast_n;
            end
        end
    end

    always_comb begin
        send_q_tail_ptr_stall_val_next_n = send_q_tail_ptr_stall_val_reg_n;
        if (stall_n) begin
            send_q_tail_ptr_stall_val_next_n = send_q_tail_ptr_stall_val_reg_n
                                             | send_q_tail_ptr_rd_resp_val;
        end
        else begin
            send_q_tail_ptr_stall_val_next_n = 1'b0;
        end
    end

    always_comb begin
        tx_state_stall_val_next_n = tx_state_stall_val_reg_n;
        if (stall_n) begin
            tx_state_stall_val_next_n = tx_state_stall_val_reg_n
                                           | tx_state_rd_resp_val;
        end
        else begin
            tx_state_stall_val_next_n = 1'b0;
        end
    end

    // should we bypass from writeback?
    // otherwise, take stall data if valid, otherwise take the normal data
    assign tx_data_byp_n = ((flowid_reg_w == flowid_reg_n) & val_reg_w & val_reg_n)
                         ? next_tx_data_reg_w
                         : tx_state_stall_val_reg_n
                           ? tx_state_stall_data_reg_n
                           : tx_state_rd_resp_data;

    assign send_q_tail_ptr_byp_n = send_q_tail_ptr_stall_val_reg_n
                                 ? send_q_tail_ptr_stall_data_reg_n
                                 : send_q_tail_ptr_rd_resp_data;

    assign tx_timer_exp_n = tx_data_byp_n.timer.timer_armed 
                          & (tx_data_byp_n.timer.timestamp < timestamp_reg_n);

    // we don't bother doing bypassing for retransmit or timeout flags. these should be rare
    // anyways and in that case, we're already suffering
    
    segment_calculator #(
        .ptr_w(TX_PAYLOAD_PTR_W)
    ) rt_segment (
         .trail_ptr (tx_data_byp_n.tx_curr_ack_state.tx_curr_ack_num[TX_PAYLOAD_PTR_W:0]   )
        ,.lead_ptr  (send_q_tail_ptr_byp_n                             )
        ,.seg_size  (rt_seg_size_n                                     )
    );

    segment_calculator #(
        .ptr_w(TX_PAYLOAD_PTR_W)
    ) new_segment (
         .trail_ptr  (tx_data_byp_n.tx_curr_seq_num[TX_PAYLOAD_PTR_W:0]  )
        ,.lead_ptr   (send_q_tail_ptr_byp_n                            )
        ,.seg_size   (new_seg_size_n                                   )
    );

    always_comb begin
        next_tx_data_n = tx_data_byp_n;
        payload_buf_n = '0;
        tx_pkt_seq_num_n = '0;

        next_tx_data_n.timer.timer_armed = tx_data_byp_n.timer.timer_armed | generate_pkt_n;
        next_tx_data_n.timer.timestamp = generate_pkt_n 
                                       ? timestamp_reg_n + TX_TIMER_LEN
                                       : tx_data_byp_n.timer.timestamp; 
        // do we have a retransmit or timeout? If so, take the resegment from the head (ACK index)
        // and set the current sequence number back to head + resegment size
        if (rt_timeout_flags_reg_n.timeout_pending | rt_timeout_flags_reg_n.rt_pending) begin
            next_tx_data_n.tx_curr_seq_num = tx_data_byp_n.tx_curr_ack_state.tx_curr_ack_num 
                                             + rt_seg_size_n;
            payload_buf_n.payload_addr = 
                tx_data_byp_n.tx_curr_ack_state.tx_curr_ack_num[TX_PAYLOAD_PTR_W-1:0];
            payload_buf_n.payload_len = rt_seg_size_n;
            
            tx_pkt_seq_num_n = tx_data_byp_n.tx_curr_ack_state.tx_curr_ack_num;
        end
        // otherwise, take a segment from the sequence number to the tail (or less)
        // and add the size of the segment onto the sequence number
        else begin
            next_tx_data_n.tx_curr_seq_num = tx_data_byp_n.tx_curr_seq_num + new_seg_size_n;
            payload_buf_n.payload_addr = tx_data_byp_n.tx_curr_seq_num[TX_PAYLOAD_PTR_W-1:0];
            payload_buf_n.payload_len = new_seg_size_n;

            tx_pkt_seq_num_n = tx_data_byp_n.tx_curr_seq_num;
        end
    end

    // actually send a packet if we have payload or if we've timed out
    // or do we need to send a zero len ack?
    assign generate_pkt_n = (rt_timeout_flags_reg_n.timeout_pending 
                            | rt_timeout_flags_reg_n.rt_pending
                            | tx_timer_exp_n
                            | (payload_buf_n.payload_len != 0));
/*********************************************************
 * (N)umbering -> (W)riteback
 ********************************************************/ 
    always_ff @(posedge clk) begin
        if (rst) begin
            val_reg_w <= '0;
            flowid_reg_w <= '0;
            next_tx_data_reg_w <= '0;
            payload_buf_reg_w <= '0;
            generate_pkt_reg_w <= '0;
            tx_pkt_seq_num_reg_w <= '0;
        end
        else begin
            if (~stall_w) begin
                val_reg_w <= val_reg_n & ~bubble_n;
                flowid_reg_w <= flowid_reg_n;
                next_tx_data_reg_w <= next_tx_data_n;
                payload_buf_reg_w <= payload_buf_n;
                generate_pkt_reg_w <= generate_pkt_n;
                tx_pkt_seq_num_reg_w <= tx_pkt_seq_num_n;
            end
        end
    end

/*********************************************************
 * (W)riteback stage
 ********************************************************/ 
    assign stall_w = ~assembler_main_pipe_tx_rdy | ~tx_state_wr_req_rdy;

    assign main_pipe_assembler_tx_val = val_reg_w & ~stall_w & generate_pkt_reg_w;
    assign main_pipe_assembler_tx_flowid = flowid_reg_w;
    assign main_pipe_assembler_tx_seq_num = tx_pkt_seq_num_reg_w;
    assign main_pipe_assembler_tx_payload = payload_buf_reg_w;

    assign tx_state_wr_req_val = val_reg_w & ~stall_w;
    assign tx_state_wr_req_flowid = flowid_reg_w;
    assign tx_state_wr_req_data = next_tx_data_reg_w;

    // we can do something here like not reenqueueing if there was no payload or something
    assign main_pipe_sched_fifo_tx_wr_req = ~stall_w & val_reg_w & ~sched_fifo_main_pipe_tx_wr_full;
    assign main_pipe_sched_fifo_tx_wr_flowid = flowid_reg_w;

    assign main_pipe_rt_timeout_clr_bit_val = val_reg_w & generate_pkt_reg_w;
    assign main_pipe_rt_timeout_clr_bit_flowid = flowid_reg_w;

endmodule
