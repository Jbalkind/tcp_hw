`include "state_defs.vh"
import state_struct_pkg::*;
module full_query_pipe (
     input clk
    ,input rst
    
    ,input                              q_full_req_val
    ,input  [`FLOW_ID_W-1:0]            q_full_req_flowid
    ,output                             q_full_req_rdy
    
    ,output                             q_full_resp_val
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]    q_full_resp_head_index
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]    q_full_resp_tail_index
    ,input                              q_full_resp_rdy
    
    ,output                             enqueue_head_ptr_mem_rd_req_val
    ,output [`FLOW_ID_W-1:0]            enqueue_head_ptr_mem_rd_req_addr
    ,input                              head_ptr_mem_enqueue_rd_req_rdy

    ,output                             enqueue_tail_ptr_mem_rd_req_val
    ,output [`FLOW_ID_W-1:0]            enqueue_tail_ptr_mem_rd_req_addr
    ,input                              tail_ptr_mem_enqueue_rd_req_rdy

    ,input                              tail_ptr_mem_enqueue_rd_resp_val
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]    tail_ptr_mem_enqueue_rd_resp_data
    ,output                             enqueue_tail_ptr_mem_rd_resp_rdy
    
    ,input                              head_ptr_mem_enqueue_rd_resp_val
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]    head_ptr_mem_enqueue_rd_resp_data
    ,output                             enqueue_head_ptr_mem_rd_resp_rdy
);
    logic   stall_qp;
    logic   bubble_qp;
    logic   stall_o;
    
    logic   [`FLOW_ID_W-1:0]            q_full_req_flowid_reg_o;
    logic                               q_full_req_val_reg_o;


    assign q_full_req_rdy = ~stall_qp;

/*************************************************************
 * (Q)ueue (P)ointer read stage
 ************************************************************/
    assign bubble_qp = stall_qp;
    assign stall_qp = q_full_req_val & (stall_o 
                    | ~head_ptr_mem_enqueue_rd_req_rdy
                    | ~tail_ptr_mem_enqueue_rd_req_rdy);


    assign enqueue_head_ptr_mem_rd_req_val = q_full_req_val;
    assign enqueue_head_ptr_mem_rd_req_addr = q_full_req_flowid;

    assign enqueue_tail_ptr_mem_rd_req_val = q_full_req_val;
    assign enqueue_tail_ptr_mem_rd_req_addr = q_full_req_flowid;
    
/*************************************************************
 * (Q)ueue (P)ointer -> (O)utput
 ************************************************************/

    always_ff @(posedge clk) begin
        if (rst) begin
            q_full_req_val_reg_o <= '0;
            q_full_req_flowid_reg_o <= '0;
        end
        else begin
            if (~stall_o) begin
                q_full_req_val_reg_o <= q_full_req_val & ~bubble_qp;
                q_full_req_flowid_reg_o <= q_full_req_flowid;
            end
        end
    end
/*************************************************************
 * (O)utput stage
 ************************************************************/
    assign stall_o = q_full_req_val_reg_o & 
                   (~q_full_resp_rdy
                   | ~head_ptr_mem_enqueue_rd_resp_val
                   | ~tail_ptr_mem_enqueue_rd_resp_val);

    assign enqueue_head_ptr_mem_rd_resp_rdy = q_full_req_val_reg_o 
                                            ? q_full_resp_rdy
                                            : 1'b1;
    assign enqueue_tail_ptr_mem_rd_resp_rdy = q_full_req_val_reg_o 
                                            ? q_full_resp_rdy
                                            : 1'b1;

    assign q_full_resp_tail_index = tail_ptr_mem_enqueue_rd_resp_data;
    assign q_full_resp_head_index = head_ptr_mem_enqueue_rd_resp_data;
    assign q_full_resp_val = head_ptr_mem_enqueue_rd_resp_val 
                           & tail_ptr_mem_enqueue_rd_resp_val
                           & q_full_req_val_reg_o;


endmodule
