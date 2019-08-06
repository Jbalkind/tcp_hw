`include "state_defs.vh"
module rx_pkt_payload_q_dequeue (
     input clk
    ,input rst
    
    // For reading out a packet from the queue
    ,input                                  read_payload_req_val
    ,input  [`FLOW_ID_W-1:0]                read_payload_req_flowid
    ,output                                 read_payload_req_rdy

    ,output                                 read_payload_resp_val
    ,output                                 read_payload_resp_is_empty
    ,output [`PAYLOAD_ENTRY_W-1:0]          read_payload_resp_entry
    ,input                                  read_payload_resp_rdy
    
    ,output                                 dequeue_head_ptr_mem_rd_req_val
    ,output [`FLOW_ID_W-1:0]                dequeue_head_ptr_mem_rd_req_addr
    ,input                                  head_ptr_mem_dequeue_rd_req_rdy

    ,output                                 dequeue_tail_ptr_mem_rd_req_val
    ,output [`FLOW_ID_W-1:0]                dequeue_tail_ptr_mem_rd_req_addr
    ,input                                  tail_ptr_mem_dequeue_rd_req_rdy
    
    ,input                                  tail_ptr_mem_dequeue_rd_resp_val
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]        tail_ptr_mem_dequeue_rd_resp_data
    ,output                                 dequeue_tail_ptr_mem_rd_resp_rdy
    
    ,input                                  head_ptr_mem_dequeue_rd_resp_val
    ,input  [`RX_PAYLOAD_Q_SIZE_W:0]        head_ptr_mem_dequeue_rd_resp_data
    ,output                                 dequeue_head_ptr_mem_rd_resp_rdy

    ,output                                 dequeue_head_ptr_mem_wr_req_val
    ,output [`FLOW_ID_W-1:0]                dequeue_head_ptr_mem_wr_req_addr
    ,output [`RX_PAYLOAD_Q_SIZE_W:0]        dequeue_head_ptr_mem_wr_req_data
    ,input                                  head_ptr_mem_dequeue_wr_req_rdy
    
    ,output                                 dequeue_payload_buffer_rd_req_val
    ,output [`PAYLOAD_BUF_MEM_ADDR_W-1:0]   dequeue_payload_buffer_rd_req_addr
    ,input                                  payload_buffer_dequeue_rd_req_rdy

    ,input                                  payload_buffer_dequeue_rd_resp_val
    ,input  [`PAYLOAD_ENTRY_W-1:0]          payload_buffer_dequeue_rd_resp_data
    ,output                                 dequeue_payload_buffer_rd_resp_rdy
);

    logic   stall_qp;
    logic   bubble_qp;
    logic   stall_pb;
    logic   bubble_pb;
    logic   stall_o;

    logic                       read_payload_req_val_reg_pb;
    logic   [`FLOW_ID_W-1:0]    read_payload_req_flowid_reg_pb;

    logic   is_empty_pb;

    logic                               read_payload_req_val_reg_o;
    logic   [`FLOW_ID_W-1:0]            read_payload_req_flowid_reg_o;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    head_ptr_mem_rd_resp_reg_o;

    logic   is_empty_reg_o;
    

    assign read_payload_req_rdy = ~stall_qp;

/*************************************************************
 * (Q)ueue (P)ointer read stage
 ************************************************************/
    assign bubble_qp = stall_qp;
    assign stall_qp = read_payload_req_val & (stall_pb
                    | ~head_ptr_mem_dequeue_rd_req_rdy
                    | ~tail_ptr_mem_dequeue_rd_req_rdy);

    assign dequeue_head_ptr_mem_rd_req_val = read_payload_req_val;
    assign dequeue_tail_ptr_mem_rd_req_val = read_payload_req_val;

    assign dequeue_head_ptr_mem_rd_req_addr = read_payload_req_flowid;
    assign dequeue_tail_ptr_mem_rd_req_addr = read_payload_req_flowid;

/*************************************************************
 * (Q)ueue (P)ointer -> (P)ayload (B)uffer
 ************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            read_payload_req_val_reg_pb <= 1'b0;
            read_payload_req_flowid_reg_pb <= '0;
        end
        else begin
            if (~stall_pb) begin
                read_payload_req_val_reg_pb <= read_payload_req_val & ~bubble_qp;
                read_payload_req_flowid_reg_pb <= read_payload_req_flowid;
            end
        end
    end

/*************************************************************
 * (P)ayload (B)uffer stage
 ************************************************************/
    assign bubble_pb = stall_pb;
    assign stall_pb = read_payload_req_val_reg_pb &
                    ( stall_o
                    | ~payload_buffer_dequeue_rd_req_rdy
                    | ~head_ptr_mem_dequeue_rd_resp_val
                    | ~tail_ptr_mem_dequeue_rd_resp_val);

    assign dequeue_payload_buffer_rd_req_val = read_payload_req_val_reg_pb;
    assign dequeue_payload_buffer_rd_req_addr = {read_payload_req_flowid_reg_pb,
                                        head_ptr_mem_dequeue_rd_resp_data[`RX_PAYLOAD_Q_SIZE_W-1:0]};

    assign dequeue_head_ptr_mem_rd_resp_rdy = ~stall_o & payload_buffer_dequeue_rd_req_rdy;
    assign dequeue_tail_ptr_mem_rd_resp_rdy = ~stall_o & payload_buffer_dequeue_rd_req_rdy;
    
    assign is_empty_pb = (head_ptr_mem_dequeue_rd_resp_data[`RX_PAYLOAD_Q_SIZE_W] ==
                          tail_ptr_mem_dequeue_rd_resp_data[`RX_PAYLOAD_Q_SIZE_W]) &
                         (head_ptr_mem_dequeue_rd_resp_data[`RX_PAYLOAD_Q_SIZE_W-1:0] == 
                          tail_ptr_mem_dequeue_rd_resp_data[`RX_PAYLOAD_Q_SIZE_W-1:0]);

/*************************************************************
 * (P)ayload (B)uffer -> (O)utput
 ************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            read_payload_req_val_reg_o <= 1'b0;
            read_payload_req_flowid_reg_o <= '0;
            is_empty_reg_o <= 1'b1;
            head_ptr_mem_rd_resp_reg_o <= '0;
        end
        else begin
            if (~stall_o) begin
                read_payload_req_val_reg_o <= read_payload_req_val_reg_pb & ~bubble_pb;
                read_payload_req_flowid_reg_o <= read_payload_req_flowid_reg_pb;
                is_empty_reg_o <= is_empty_pb;
                head_ptr_mem_rd_resp_reg_o <= head_ptr_mem_dequeue_rd_resp_data;
            end
        end
    end

/*************************************************************
 * (O)utput stage
 ************************************************************/

    assign stall_o = read_payload_req_val_reg_o &
                   (~read_payload_resp_rdy
                   |~head_ptr_mem_dequeue_wr_req_rdy
                   |~payload_buffer_dequeue_rd_resp_val);

    assign read_payload_resp_val = ~stall_o & read_payload_req_val_reg_o;
    assign read_payload_resp_is_empty = is_empty_reg_o;
    assign read_payload_resp_entry = is_empty_reg_o
                                   ? '0
                                   : payload_buffer_dequeue_rd_resp_data;
    assign dequeue_payload_buffer_rd_resp_rdy = ~stall_o;

    assign dequeue_head_ptr_mem_wr_req_val = ~stall_o 
                                           & read_payload_req_val_reg_o 
                                           & ~is_empty_reg_o;
    assign dequeue_head_ptr_mem_wr_req_addr = read_payload_req_flowid_reg_o;
    assign dequeue_head_ptr_mem_wr_req_data = head_ptr_mem_rd_resp_reg_o + 1'b1;


endmodule
