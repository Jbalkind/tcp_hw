module rx_state_store 
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input                      recv_state_wr_req_val
    ,input  [FLOWID_W-1:0]      recv_state_wr_req_addr
    ,input  recv_state_entry    recv_state_wr_req_data
    ,output                     recv_state_wr_req_rdy

    ,input                      curr_recv_state_rd_req_val
    ,input  [FLOWID_W-1:0]      curr_recv_state_rd_req_addr
    ,output                     curr_recv_state_rd_req_rdy

    ,output                     curr_recv_state_rd_resp_val
    ,output recv_state_entry    curr_recv_state_rd_resp_data
    ,input                      curr_recv_state_rd_resp_rdy

    ,input                      send_pipe_recv_state_rd_req_val
    ,input  [FLOWID_W-1:0]      send_pipe_recv_state_rd_req_addr
    ,output                     recv_state_send_pipe_rd_req_rdy

    ,output                     recv_state_send_pipe_rd_resp_val
    ,output recv_state_entry    recv_state_send_pipe_rd_resp_data
    ,input                      send_pipe_recv_state_rd_resp_rdy

    ,input                      new_flow_val
    ,input  [FLOWID_W-1:0]      new_flow_flowid
    ,input  recv_state_entry    new_flow_recv_state
    ,output                     new_flow_rdy
);

    logic                   mem_wr_req_val;
    logic   [FLOWID_W-1:0]  mem_wr_req_addr;
    recv_state_entry        mem_wr_req_data;
    logic                   mem_wr_req_rdy;

    logic                   mem_rd0_req_val;
    logic   [FLOWID_W-1:0]  mem_rd0_req_addr;
    logic                   mem_rd0_req_rdy;

    logic                   mem_rd0_resp_val;
    recv_state_entry        mem_rd0_resp_data;
    logic                   mem_rd0_resp_rdy;
    
    logic                   mem_rd1_req_val;
    logic   [FLOWID_W-1:0]  mem_rd1_req_addr;
    logic                   mem_rd1_req_rdy;

    logic                   mem_rd1_resp_val;
    recv_state_entry        mem_rd1_resp_data;
    logic                   mem_rd1_resp_rdy;
    
    assign new_flow_rdy = mem_wr_req_rdy;

    assign mem_wr_req_val = new_flow_val | recv_state_wr_req_val;
    assign mem_wr_req_addr = new_flow_val
                           ? new_flow_flowid
                           : recv_state_wr_req_addr;
    assign mem_wr_req_data = new_flow_val
                           ? new_flow_recv_state
                           : recv_state_wr_req_data;
    assign recv_state_wr_req_rdy = ~new_flow_val & mem_wr_req_rdy;


    assign mem_rd0_req_val = curr_recv_state_rd_req_val;
    assign mem_rd0_req_addr = curr_recv_state_rd_req_addr;
    assign curr_recv_state_rd_req_rdy = mem_rd0_req_rdy;

    assign curr_recv_state_rd_resp_val = mem_rd0_resp_val;
    assign curr_recv_state_rd_resp_data = mem_rd0_resp_data;
    assign mem_rd0_resp_rdy = curr_recv_state_rd_resp_rdy;

    assign mem_rd1_req_val = send_pipe_recv_state_rd_req_val;
    assign mem_rd1_req_addr = send_pipe_recv_state_rd_req_addr;
    assign recv_state_send_pipe_rd_req_rdy = mem_rd1_req_rdy;

    assign recv_state_send_pipe_rd_resp_val = mem_rd1_resp_val;
    assign recv_state_send_pipe_rd_resp_data = mem_rd1_resp_data;
    assign mem_rd1_resp_rdy = send_pipe_recv_state_rd_resp_rdy;


    ram_2r1w_sync_backpressure #(
         .width_p   (RECV_STATE_ENTRY_W)
        ,.els_p     (MAX_FLOW_CNT)
    ) rx_state_ram (
         .clk   (clk)
        ,.rst   (rst)
    
        ,.wr_req_val    (mem_wr_req_val     )
        ,.wr_req_addr   (mem_wr_req_addr    )
        ,.wr_req_data   (mem_wr_req_data    )
        ,.wr_req_rdy    (mem_wr_req_rdy     )

        ,.rd0_req_val   (mem_rd0_req_val    )
        ,.rd0_req_addr  (mem_rd0_req_addr   )
        ,.rd0_req_rdy   (mem_rd0_req_rdy    )

        ,.rd0_resp_val  (mem_rd0_resp_val   )
        ,.rd0_resp_addr ()
        ,.rd0_resp_data (mem_rd0_resp_data  )
        ,.rd0_resp_rdy  (mem_rd0_resp_rdy   )

        ,.rd1_req_val   (mem_rd1_req_val    )
        ,.rd1_req_addr  (mem_rd1_req_addr   )
        ,.rd1_req_rdy   (mem_rd1_req_rdy    )

        ,.rd1_resp_val  (mem_rd1_resp_val   )
        ,.rd1_resp_addr ()
        ,.rd1_resp_data (mem_rd1_resp_data  )
        ,.rd1_resp_rdy  (mem_rd1_resp_rdy   )
    );
endmodule
