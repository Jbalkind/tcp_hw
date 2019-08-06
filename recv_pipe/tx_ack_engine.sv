// This module processes the ACKs for the transmitted stream
// These are received on incoming packets
`include "packet_defs.vh"
module tx_ack_engine 
import tcp_pkg::*;
(
     input  logic   [`ACK_NUM_W-1:0]            curr_ack_num
    ,input  logic   [`ACK_NUM_W-1:0]            pkt_ack_num
    ,input  logic   [`SEQ_NUM_W-1:0]            curr_seq_num
    ,input  logic   [RT_ACK_THRESHOLD_W-1:0]    curr_ack_cnt

    ,output logic   [RT_ACK_THRESHOLD_W-1:0]    next_ack_cnt
    ,output logic   [`ACK_NUM_W-1:0]            next_ack_num
    ,output logic                               set_rt_flag
    
    ,output logic   [TX_PAYLOAD_PTR_W:0]        next_head_ptr
);
    logic   dup_ack;
    logic   data_unacked;

    assign dup_ack = (curr_ack_num == pkt_ack_num) & data_unacked;
    assign data_unacked = ~(curr_seq_num == curr_ack_num);
    always_comb begin
        next_ack_num = curr_ack_num;
        // if the sequence number has wrapped, but the ack number hasn't yet
        // if there's actually data waiting to be ACKed, the ACK is valid if
        // it is either greater than the current ACK num (so between ACK and max
        // SEQ num) or less than or equal to the current SEQ num plus 1
        // (so between 0 and the current SEQ num)
        if (curr_seq_num < curr_ack_num) begin
            if (data_unacked 
             & ((pkt_ack_num > curr_ack_num)
             |  (pkt_ack_num < curr_seq_num + 1))) begin
                next_ack_num = pkt_ack_num;
            end
        end
        else begin
            // if there's actually data waiting to be ACKed and the ACK is
            // valid (greater than last received ACK, less than sent SEQ num + 1)
            if (data_unacked 
             & ((pkt_ack_num > curr_ack_num) 
             & (pkt_ack_num <= curr_seq_num + 1))) begin
                next_ack_num = pkt_ack_num;
            end
        end
    end

    // we know this won't trigger if there's no data outstanding, because the ACK count 
    // is set to 0 when there's no data outstanding
    assign set_rt_flag = (curr_ack_cnt + dup_ack) == RT_ACK_THRESHOLD;

    always_comb begin
        next_ack_cnt = curr_ack_cnt;
        // clear the dup ack count if we're setting a retransmit, there was no data to ack
        // or we've gotten a fresh, new ACK
        if (~data_unacked | set_rt_flag | ~dup_ack) begin
            next_ack_cnt = '0;
        end
        else begin
            next_ack_cnt = curr_ack_cnt + dup_ack;
        end
    end

    assign next_head_ptr = next_ack_num[TX_PAYLOAD_PTR_W:0];
endmodule
