module tx_state_store 
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input                          send_pipe_rd_req_val
    ,input          [FLOWID_W-1:0]  send_pipe_rd_req_flowid
    ,output logic                   send_pipe_rd_req_rdy

    ,output logic                   send_pipe_rd_resp_val
    ,output logic   [FLOWID_W-1:0]  send_pipe_rd_resp_flowid
    ,output tx_state_struct         send_pipe_rd_resp_data
    ,input  logic                   send_pipe_rd_resp_rdy

    ,input                          recv_pipe_rd_req_val
    ,input          [FLOWID_W-1:0]  recv_pipe_rd_req_flowid
    ,output logic                   recv_pipe_rd_req_rdy

    ,output logic                   recv_pipe_rd_resp_val
    ,output logic   [FLOWID_W-1:0]  recv_pipe_rd_resp_flowid
    ,output tx_state_struct         recv_pipe_rd_resp_data
    ,input  logic                   recv_pipe_rd_resp_rdy

    ,input                          send_pipe_wr_req_val
    ,input          [FLOWID_W-1:0]  send_pipe_wr_req_flowid
    ,input  tx_state_struct         send_pipe_wr_req_data
    ,output logic                   send_pipe_wr_req_rdy

    ,input                          recv_pipe_wr_req_val
    ,input          [FLOWID_W-1:0]  recv_pipe_wr_req_flowid
    ,input  tx_state_struct         recv_pipe_wr_req_data
    ,output logic                   recv_pipe_wr_req_rdy

    ,input                          new_flow_val
    ,input          [FLOWID_W-1:0]  new_flow_flowid
    ,input  tx_state_struct         new_flow_tx_state
    ,output                         new_flow_rdy
);

    typedef struct packed {
        tx_ack_timer                timer;
        logic   [`SEQ_NUM_W-1:0]    tx_curr_seq_num;
    } tx_emit_mem_struct;
    localparam TX_EMIT_MEM_STRUCT_W = TX_ACK_TIMER_W + `SEQ_NUM_W;

    tx_state_struct send_pipe_wr_req_data_cast;
    tx_state_struct recv_pipe_wr_req_data_cast;
    tx_state_struct new_flow_wr_data_cast;

    tx_state_struct send_pipe_rd_resp_data_cast;
    tx_state_struct recv_pipe_rd_resp_data_cast;
    
    logic                   tx_emit_wr_req_val;
    logic   [FLOWID_W-1:0]  tx_emit_wr_req_addr;
    tx_emit_mem_struct      tx_emit_wr_req_data;
    logic                   tx_emit_wr_req_rdy;

    logic                   tx_emit_rd0_req_val;
    logic   [FLOWID_W-1:0]  tx_emit_rd0_req_addr;
    logic                   tx_emit_rd0_req_rdy;

    logic                   tx_emit_rd0_resp_val;
    logic   [FLOWID_W-1:0]  tx_emit_rd0_resp_addr;
    tx_emit_mem_struct      tx_emit_rd0_resp_data;
    logic                   tx_emit_rd0_resp_rdy;

    logic                   tx_emit_rd1_req_val;
    logic   [FLOWID_W-1:0]  tx_emit_rd1_req_addr;
    logic                   tx_emit_rd1_req_rdy;

    logic                   tx_emit_rd1_resp_val;
    logic   [FLOWID_W-1:0]  tx_emit_rd1_resp_addr;
    tx_emit_mem_struct      tx_emit_rd1_resp_data;
    logic                   tx_emit_rd1_resp_rdy;
    
    logic                   tx_ack_state_wr_req_val;
    logic   [FLOWID_W-1:0]  tx_ack_state_wr_req_addr;
    tx_ack_state_struct     tx_ack_state_wr_req_data;
    logic                   tx_ack_state_wr_req_rdy;

    logic                   tx_ack_state_rd0_req_val;
    logic   [FLOWID_W-1:0]  tx_ack_state_rd0_req_addr;
    logic                   tx_ack_state_rd0_req_rdy;

    logic                   tx_ack_state_rd0_resp_val;
    logic   [FLOWID_W-1:0]  tx_ack_state_rd0_resp_addr;
    tx_ack_state_struct     tx_ack_state_rd0_resp_data;
    logic                   tx_ack_state_rd0_resp_rdy;

    logic                   tx_ack_state_rd1_req_val;
    logic   [FLOWID_W-1:0]  tx_ack_state_rd1_req_addr;
    logic                   tx_ack_state_rd1_req_rdy;

    logic                   tx_ack_state_rd1_resp_val;
    logic   [FLOWID_W-1:0]  tx_ack_state_rd1_resp_addr;
    tx_ack_state_struct     tx_ack_state_rd1_resp_data;
    logic                   tx_ack_state_rd1_resp_rdy;

    assign send_pipe_wr_req_data_cast = send_pipe_wr_req_data;
    assign recv_pipe_wr_req_data_cast = recv_pipe_wr_req_data;
    assign new_flow_wr_data_cast = new_flow_tx_state;

    assign send_pipe_rd_resp_data = send_pipe_rd_resp_data_cast;
    assign recv_pipe_rd_resp_data = recv_pipe_rd_resp_data_cast;

    assign send_pipe_rd_resp_data_cast.tx_curr_seq_num = 
        tx_emit_rd0_resp_data.tx_curr_seq_num;
    assign send_pipe_rd_resp_data_cast.timer = tx_emit_rd0_resp_data.timer;
    assign send_pipe_rd_resp_data_cast.tx_curr_ack_state = tx_ack_state_rd0_resp_data;

    assign recv_pipe_rd_resp_data_cast.tx_curr_seq_num = 
        tx_emit_rd1_resp_data.tx_curr_seq_num;
    assign recv_pipe_rd_resp_data_cast.timer = tx_emit_rd1_resp_data.timer;
    assign recv_pipe_rd_resp_data_cast.tx_curr_ack_state = tx_ack_state_rd1_resp_data;

    // we always take the new state over the current state
    assign send_pipe_wr_req_rdy = ~new_flow_val & tx_emit_wr_req_rdy;
    assign recv_pipe_wr_req_rdy = ~new_flow_val & tx_ack_state_wr_req_rdy;
    assign new_flow_rdy = tx_emit_wr_req_rdy & tx_ack_state_wr_req_rdy;

    assign tx_emit_wr_req_val = new_flow_val | send_pipe_wr_req_val;
    assign tx_emit_wr_req_addr = new_flow_val
                                  ? new_flow_flowid
                                  : send_pipe_wr_req_flowid;

    always_comb begin
        tx_emit_wr_req_data = '0;
        if (new_flow_val) begin
            tx_emit_wr_req_data.tx_curr_seq_num = new_flow_wr_data_cast.tx_curr_seq_num;
            tx_emit_wr_req_data.timer = new_flow_wr_data_cast.timer;
        end
        else begin
            tx_emit_wr_req_data.tx_curr_seq_num = 
                send_pipe_wr_req_data_cast.tx_curr_seq_num;
            tx_emit_wr_req_data.timer = send_pipe_wr_req_data_cast.timer;
        end
    end

    assign tx_ack_state_wr_req_val = new_flow_val | recv_pipe_wr_req_val;
    assign tx_ack_state_wr_req_addr = new_flow_val
                                  ? new_flow_flowid
                                  : recv_pipe_wr_req_flowid;
    assign tx_ack_state_wr_req_data = new_flow_val
                                  ? new_flow_wr_data_cast.tx_curr_ack_state
                                  : recv_pipe_wr_req_data_cast.tx_curr_ack_state;
    assign send_pipe_rd_req_rdy = tx_emit_rd0_req_rdy & tx_ack_state_rd0_req_rdy;
    assign recv_pipe_rd_req_rdy = tx_emit_rd1_req_rdy & tx_ack_state_rd1_req_rdy;

    
    assign tx_emit_rd0_req_val = send_pipe_rd_req_val;
    assign tx_emit_rd0_req_addr = send_pipe_rd_req_flowid;

    assign tx_emit_rd0_resp_rdy = send_pipe_rd_resp_rdy & send_pipe_rd_resp_val;

    assign tx_emit_rd1_req_val = recv_pipe_rd_req_val;
    assign tx_emit_rd1_req_addr = recv_pipe_rd_req_flowid;

    assign tx_emit_rd1_resp_rdy = recv_pipe_rd_resp_rdy & recv_pipe_rd_resp_val;

    assign tx_ack_state_rd0_req_val = send_pipe_rd_req_val;
    assign tx_ack_state_rd0_req_addr = send_pipe_rd_req_flowid;
    
    assign tx_ack_state_rd0_resp_rdy = send_pipe_rd_resp_rdy & send_pipe_rd_resp_val;

    assign tx_ack_state_rd1_req_val = recv_pipe_rd_req_val;
    assign tx_ack_state_rd1_req_addr = recv_pipe_rd_req_flowid;

    assign tx_ack_state_rd1_resp_rdy = recv_pipe_rd_resp_rdy & recv_pipe_rd_resp_val;

    assign send_pipe_rd_resp_val = tx_emit_rd0_resp_val & tx_ack_state_rd0_resp_val;
    assign send_pipe_rd_resp_flowid = tx_emit_rd0_resp_addr;

    assign recv_pipe_rd_resp_val = tx_emit_rd1_resp_val & tx_ack_state_rd1_resp_val;
    assign recv_pipe_rd_resp_flowid = tx_emit_rd1_resp_addr;

    ram_2r1w_sync_backpressure #(
         .width_p   (`SEQ_NUM_W + TX_ACK_TIMER_W    )
        ,.els_p     (MAX_FLOW_CNT                   )
    ) tx_emit_state (
         .clk   (clk)
        ,.rst   (rst)

        ,.wr_req_val    (tx_emit_wr_req_val      )
        ,.wr_req_addr   (tx_emit_wr_req_addr     )
        ,.wr_req_data   (tx_emit_wr_req_data     )
        ,.wr_req_rdy    (tx_emit_wr_req_rdy      )
                                                      
        ,.rd0_req_val   (tx_emit_rd0_req_val     )
        ,.rd0_req_addr  (tx_emit_rd0_req_addr    )
        ,.rd0_req_rdy   (tx_emit_rd0_req_rdy     )
                                                      
        ,.rd0_resp_val  (tx_emit_rd0_resp_val    )
        ,.rd0_resp_addr (tx_emit_rd0_resp_addr   )
        ,.rd0_resp_data (tx_emit_rd0_resp_data   )
        ,.rd0_resp_rdy  (tx_emit_rd0_resp_rdy    )
                                                      
        ,.rd1_req_val   (tx_emit_rd1_req_val     )
        ,.rd1_req_addr  (tx_emit_rd1_req_addr    )
        ,.rd1_req_rdy   (tx_emit_rd1_req_rdy     )
                                                      
        ,.rd1_resp_val  (tx_emit_rd1_resp_val    )
        ,.rd1_resp_addr (tx_emit_rd1_resp_addr   )
        ,.rd1_resp_data (tx_emit_rd1_resp_data   )
        ,.rd1_resp_rdy  (tx_emit_rd1_resp_rdy    )
    );

    ram_2r1w_sync_backpressure #(
         .width_p   (TX_ACK_STATE_STRUCT_W  )
        ,.els_p     (MAX_FLOW_CNT           )
    ) tx_ack_state (
         .clk   (clk)
        ,.rst   (rst)

        ,.wr_req_val    (tx_ack_state_wr_req_val      )
        ,.wr_req_addr   (tx_ack_state_wr_req_addr     )
        ,.wr_req_data   (tx_ack_state_wr_req_data     )
        ,.wr_req_rdy    (tx_ack_state_wr_req_rdy      )

        ,.rd0_req_val   (tx_ack_state_rd0_req_val     )
        ,.rd0_req_addr  (tx_ack_state_rd0_req_addr    )
        ,.rd0_req_rdy   (tx_ack_state_rd0_req_rdy     )

        ,.rd0_resp_val  (tx_ack_state_rd0_resp_val    )
        ,.rd0_resp_addr (tx_ack_state_rd0_resp_addr   )
        ,.rd0_resp_data (tx_ack_state_rd0_resp_data   )
        ,.rd0_resp_rdy  (tx_ack_state_rd0_resp_rdy    )

        ,.rd1_req_val   (tx_ack_state_rd1_req_val     )
        ,.rd1_req_addr  (tx_ack_state_rd1_req_addr    )
        ,.rd1_req_rdy   (tx_ack_state_rd1_req_rdy     )

        ,.rd1_resp_val  (tx_ack_state_rd1_resp_val    )
        ,.rd1_resp_addr (tx_ack_state_rd1_resp_addr   )
        ,.rd1_resp_data (tx_ack_state_rd1_resp_data   )
        ,.rd1_resp_rdy  (tx_ack_state_rd1_resp_rdy    )
    );


endmodule
