`include "packet_defs.vh"
module tcp_state_store 
import packet_struct_pkg::*;
import tcp_pkg::*;
#(
     parameter width_p=TCP_STATE_W
    ,parameter els_p=-MAX_FLOW_CNT
)(
     input clk
    ,input rst

    ,input                              fsm_tcp_state_wr_req_val
    ,input          [FLOWID_W-1:0]      fsm_tcp_state_wr_req_addr
    ,input          [TCP_STATE_W-1:0]   fsm_tcp_state_wr_req_state
    ,output logic                       tcp_state_fsm_wr_req_rdy

    ,input                              issue_tcp_state_rd_req_val
    ,input          [FLOWID_W-1:0]      issue_tcp_state_rd_req_addr
    ,output logic                       tcp_state_issue_rd_req_rdy

    ,output logic                       tcp_state_issue_rd_resp_val
    ,output logic   [TCP_STATE_W-1:0]   tcp_state_issue_rd_resp_state
    ,input                              issue_tcp_state_rd_resp_rdy
    
    ,input                              fsm_tcp_state_rd_req_val
    ,input          [FLOWID_W-1:0]      fsm_tcp_state_rd_req_addr
    ,output logic                       tcp_state_fsm_rd_req_rdy

    ,output logic                       tcp_state_fsm_rd_resp_val
    ,output logic   [TCP_STATE_W-1:0]   tcp_state_fsm_rd_resp_state
    ,input                              fsm_tcp_state_rd_resp_rdy
);

    ram_2r1w_sync_backpressure #(
         .width_p   (width_p    )
        ,.els_p     (els_p      )
    ) tcp_state_mem (
         .clk   (clk)
        ,.rst   (rst)

        ,.wr_req_val    (fsm_tcp_state_wr_req_val       )
        ,.wr_req_addr   (fsm_tcp_state_wr_req_addr      )
        ,.wr_req_data   (fsm_tcp_state_wr_req_state     )
        ,.wr_req_rdy    (tcp_state_fsm_wr_req_rdy       )

        ,.rd0_req_val   (issue_tcp_state_rd_req_val     )
        ,.rd0_req_addr  (issue_tcp_state_rd_req_addr    )
        ,.rd0_req_rdy   (tcp_state_issue_rd_req_rdy     )

        ,.rd0_resp_val  (tcp_state_issue_rd_resp_val    )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (tcp_state_issue_rd_resp_state  )
        ,.rd0_resp_rdy  (issue_tcp_state_rd_resp_rdy    )

        ,.rd1_req_val   (fsm_tcp_state_rd_req_val       )
        ,.rd1_req_addr  (fsm_tcp_state_rd_req_addr      )
        ,.rd1_req_rdy   (tcp_state_fsm_rd_req_rdy       )

        ,.rd1_resp_val  (tcp_state_fsm_rd_resp_val      )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (tcp_state_fsm_rd_resp_state    )
        ,.rd1_resp_rdy  (fsm_tcp_state_rd_resp_rdy      )
    );

endmodule
