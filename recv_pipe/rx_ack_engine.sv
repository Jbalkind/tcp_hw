`include "packet_defs.vh"

// This module generates the ACK number for the receiving stream which will be sent with 
// outgoing packets
module rx_ack_engine 
import tcp_pkg::*;
(
     input  logic   [`ACK_NUM_W-1:0]            curr_ack_num
    ,input  logic   [`SEQ_NUM_W-1:0]            packet_seq_num
    ,input  logic                               packet_payload_val
    ,input  logic   [PAYLOAD_ENTRY_LEN_W-1:0]   packet_payload_len

    ,output logic   [`ACK_NUM_W-1:0]            next_ack_num
    ,output logic                               accept_payload
);


// we're calculating ack numbers here by bytes rather than straight packet numbers
// this can be modified later
always_comb begin
    // if we've received the packet we expect, then ack for the next byte
    if (packet_payload_val & (packet_seq_num == curr_ack_num)) begin
    // check if we should actually enqueue the payload or if it's a dup because we didn't
    // ack soon enough
        accept_payload = 1'b1;
        next_ack_num = packet_seq_num + packet_payload_len;
    end
    // we're somehow out of order...just dup ack
    else begin
        accept_payload = 1'b0;
        next_ack_num = curr_ack_num;
    end
end

endmodule
