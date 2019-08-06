`include "packet_defs.vh"
module est_pipe_input_merger 
import tcp_pkg::*;
import packet_struct_pkg::*;
(
     input  logic                                       issue_merger_est_hdr_val
    ,input  tcp_pkt_hdr                                 issue_merger_est_tcp_hdr
    ,input  logic   [FLOWID_W-1:0]                      issue_merger_est_flowid
    ,input  logic                                       issue_merger_est_payload_val
    ,input  payload_buf_struct                          issue_merger_est_payload_entry
    ,output logic                                       merger_issue_est_pipe_rdy

    ,output logic                                       merger_fsm_reinject_q_deq_req_val
    ,input  fsm_reinject_queue_struct                   fsm_reinject_q_merger_deq_resp_data
    ,input  logic                                       fsm_reinject_q_merger_empty
    
    ,output logic                                       est_hdr_val
    ,output tcp_pkt_hdr                                 est_tcp_hdr
    ,output logic   [FLOWID_W-1:0]                      est_flowid
    ,output logic                                       est_payload_val
    ,output payload_buf_struct                          est_payload_entry
    ,input  logic                                       est_pipe_rdy
);
    logic use_reinject_q;
    fsm_reinject_queue_struct reinject_struct_cast;
    assign reinject_struct_cast = fsm_reinject_q_merger_deq_resp_data;

    assign use_reinject_q = ~fsm_reinject_q_merger_empty;

    assign merger_fsm_reinject_q_deq_req_val = use_reinject_q & est_pipe_rdy;
    assign merger_issue_est_pipe_rdy = ~use_reinject_q & est_pipe_rdy;


    assign est_hdr_val = use_reinject_q
                       ? ~fsm_reinject_q_merger_empty
                       : issue_merger_est_hdr_val;

    assign est_tcp_hdr = use_reinject_q
                       ? reinject_struct_cast.tcp_hdr
                       : issue_merger_est_tcp_hdr;
    assign est_flowid = use_reinject_q
                      ? reinject_struct_cast.flowid
                      : issue_merger_est_flowid;
    assign est_payload_val = use_reinject_q
                           ? reinject_struct_cast.payload_val
                           : issue_merger_est_payload_val;
    assign est_payload_entry = use_reinject_q
                             ? reinject_struct_cast.payload_entry
                             : issue_merger_est_payload_entry;

endmodule
