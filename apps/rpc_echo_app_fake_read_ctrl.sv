`include "state_defs.vh"
`include "noc_defs.vh"
`include "noc_struct_defs.vh"
module rpc_echo_app_fake_read_ctrl (
     input clk
    ,input rst

    ,output logic                                       app_tail_ptr_tx_wr_req_val
    ,input  logic                                       tail_ptr_app_tx_wr_req_rdy

    ,output logic                                       app_tail_ptr_tx_rd_req1_val
    ,input  logic                                       tail_ptr_app_tx_rd_req1_rdy

    ,input  logic                                       tail_ptr_app_tx_rd_resp1_val
    ,output logic                                       app_tail_ptr_tx_rd_resp1_rdy

    ,output logic                                       app_head_ptr_tx_rd_req0_val
    ,input  logic                                       head_ptr_app_tx_rd_req0_rdy

    ,input  logic                                       head_ptr_app_tx_rd_resp0_val
    ,output logic                                       app_head_ptr_tx_rd_resp0_rdy
    
    ,output logic                                       app_rx_head_ptr_wr_req_val
    ,input  logic                                       rx_head_ptr_app_wr_req_rdy

    ,output logic                                       app_rx_head_ptr_rd_req_val
    ,input  logic                                       rx_head_ptr_app_rd_req_rdy

    ,input  logic                                       rx_head_ptr_app_rd_resp_val
    ,output logic                                       app_rx_head_ptr_rd_resp_rdy

    ,output logic                                       app_rx_commit_ptr_rd_req_val
    ,input  logic                                       rx_commit_ptr_app_rd_req_rdy

    ,input  logic                                       rx_commit_ptr_app_rd_resp_val
    ,output logic                                       app_rx_commit_ptr_rd_resp_rdy
    
    ,input  logic                                       flow_fifo_ctrl_flowid_val
    ,output logic                                       ctrl_flow_fifo_flowid_yumi

    ,output logic                                       ctrl_requeue_flow_val
    ,input  logic                                       flow_fifo_ctrl_enqueue_rdy

    ,output logic                                       store_curr_flowid
    ,output logic                                       store_rx_ptrs
    ,output logic                                       store_tx_ptrs
    ,output logic                                       store_req_hdr
    ,output logic                                       ctrl_datap_decr_bytes_left

    ,input                                              datap_ctrl_hdr_arrived
    ,input                                              datap_ctrl_rd_sat
    ,input                                              datap_ctrl_wr_sat
    ,input                                              datap_ctrl_last_wr

    ,output logic                                       ctrl_wr_buf_req_val
    ,input  logic                                       wr_buf_ctrl_req_rdy

    ,output logic                                       ctrl_wr_buf_req_data_val
    ,input  logic                                       wr_buf_ctrl_req_data_rdy

    ,input  logic                                       wr_buf_ctrl_req_done
    ,output logic                                       ctrl_wr_buf_done_rdy

    ,output logic                                       ctrl_rd_buf_req_val
    ,input  logic                                       rd_buf_ctrl_req_rdy

    ,input  logic                                       rd_buf_ctrl_resp_data_val
    ,output logic                                       ctrl_rd_buf_resp_data_rdy
);

    typedef enum logic[3:0] {
        READY = 4'd0,
        // get pointers, figure out how much data we can copy
        RX_PTRS_REQ = 4'd1,
        RX_PTRS_RESP = 4'd2,
        CHECK_RECVED = 4'd3,

        TX_PTRS_REQ = 4'd5,
        TX_PTRS_RESP = 4'd6,

        CHECK_WR_DATA = 4'd7,

        // okay write the amount of data we're supposed to transmit
        TX_WR_MEM_REQ = 4'd8,
        PAYLOAD_COPY = 4'd9,
        WAIT_WR_RESP = 4'd10,

        // update pointers
        ADJUST_RX_HEAD = 4'd11,
        ADJUST_TX_TAIL = 4'd12,

        // write active flows to the queue
        REQUEUE_FLOW = 4'd13,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;
    
    assign app_rx_head_ptr_rd_resp_rdy = rx_head_ptr_app_rd_resp_val & rx_commit_ptr_app_rd_resp_val;
    assign app_rx_commit_ptr_rd_resp_rdy = rx_head_ptr_app_rd_resp_val & rx_commit_ptr_app_rd_resp_val;

    assign app_head_ptr_tx_rd_resp0_rdy = head_ptr_app_tx_rd_resp0_val & tail_ptr_app_tx_rd_resp1_val;
    assign app_tail_ptr_tx_rd_resp1_rdy = head_ptr_app_tx_rd_resp0_val & tail_ptr_app_tx_rd_resp1_val;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    always_comb begin
        ctrl_flow_fifo_flowid_yumi = 1'b0;

        ctrl_rd_buf_req_val = 1'b0;
        ctrl_wr_buf_req_val = 1'b0;
        ctrl_wr_buf_req_data_val = 1'b0;

        ctrl_wr_buf_done_rdy = 1'b0;
        ctrl_requeue_flow_val = 1'b0;

        app_rx_head_ptr_rd_req_val = 1'b0;
        app_rx_commit_ptr_rd_req_val = 1'b0;
        app_rx_head_ptr_wr_req_val = 1'b0;

        app_head_ptr_tx_rd_req0_val = 1'b0;
        app_tail_ptr_tx_rd_req1_val = 1'b0;
        app_tail_ptr_tx_wr_req_val = 1'b0;

        store_curr_flowid = 1'b0;
        store_rx_ptrs = 1'b0;
        store_tx_ptrs = 1'b0;
        store_req_hdr = 1'b0;
        ctrl_datap_decr_bytes_left = 1'b0;

        ctrl_rd_buf_resp_data_rdy = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                if (flow_fifo_ctrl_flowid_val) begin
                    store_curr_flowid = 1'b1;
                    ctrl_flow_fifo_flowid_yumi = 1'b1;

                    state_next =  RX_PTRS_REQ;
                end
                else begin
                    state_next = READY;
                end
            end
            RX_PTRS_REQ: begin
                // we don't need to check readys because it doesn't matter if we issue multiple read requests
                app_rx_head_ptr_rd_req_val = 1'b1;
                app_rx_commit_ptr_rd_req_val = 1'b1;
                if (rx_head_ptr_app_rd_req_rdy & rx_commit_ptr_app_rd_req_rdy) begin
                    state_next = RX_PTRS_RESP;
                end
                else begin
                    state_next = RX_PTRS_REQ;
                end
            end
            RX_PTRS_RESP: begin
                if (rx_head_ptr_app_rd_resp_val & rx_commit_ptr_app_rd_resp_val) begin
                    store_rx_ptrs = 1'b1;
                    state_next = CHECK_RECVED;
                end
                else begin
                    state_next = RX_PTRS_RESP;
                end
            end
            CHECK_RECVED: begin
                if (datap_ctrl_rd_sat) begin
                    store_req_hdr = 1'b1;
                    state_next = TX_PTRS_REQ;
                end
                else begin
                    state_next = REQUEUE_FLOW;
                end
            end
            TX_PTRS_REQ: begin
                app_head_ptr_tx_rd_req0_val = 1'b1;
                app_tail_ptr_tx_rd_req1_val = 1'b1;
                if (tail_ptr_app_tx_rd_req1_rdy & head_ptr_app_tx_rd_req0_rdy) begin
                    state_next = TX_PTRS_RESP;
                end
                else begin
                    state_next = TX_PTRS_REQ;
                end
            end
            TX_PTRS_RESP: begin
                if (tail_ptr_app_tx_rd_resp1_val & head_ptr_app_tx_rd_resp0_val) begin
                    store_tx_ptrs = 1'b1;
                    state_next = CHECK_WR_DATA;
                end
                else begin
                    state_next = TX_PTRS_RESP;
                end
            end
            CHECK_WR_DATA: begin
                if (datap_ctrl_wr_sat) begin
                    state_next = TX_WR_MEM_REQ;
                end
                else begin
                    state_next = REQUEUE_FLOW;
                end
            end
            TX_WR_MEM_REQ: begin
                ctrl_wr_buf_req_val = 1'b1;
                if (wr_buf_ctrl_req_rdy) begin
                    state_next = PAYLOAD_COPY;
                end
                else begin
                    state_next = TX_WR_MEM_REQ;
                end
            end
            PAYLOAD_COPY: begin
                ctrl_wr_buf_req_data_val = 1'b1;
                if (wr_buf_ctrl_req_data_rdy) begin
                    ctrl_datap_decr_bytes_left = 1'b1;
                    if (datap_ctrl_last_wr) begin
                        state_next = WAIT_WR_RESP;
                    end
                    else begin
                        state_next = PAYLOAD_COPY;
                    end
                end
                else begin
                    state_next = PAYLOAD_COPY;
                end
            end
            WAIT_WR_RESP: begin
                ctrl_wr_buf_done_rdy = 1'b1;
                if (wr_buf_ctrl_req_done) begin
                    state_next = ADJUST_RX_HEAD;
                end
                else begin
                    state_next = WAIT_WR_RESP;
                end
            end
            ADJUST_RX_HEAD: begin
                app_rx_head_ptr_wr_req_val = 1'b1;
                if (rx_head_ptr_app_wr_req_rdy) begin
                    state_next = ADJUST_TX_TAIL;
                end
                else begin
                    state_next = ADJUST_RX_HEAD;
                end
            end
            ADJUST_TX_TAIL: begin
                app_tail_ptr_tx_wr_req_val = 1'b1;
                if (tail_ptr_app_tx_wr_req_rdy) begin
                    state_next = REQUEUE_FLOW;
                end
                else begin
                    state_next = ADJUST_TX_TAIL;
                end
            end
            REQUEUE_FLOW: begin
                ctrl_requeue_flow_val = 1'b1;
                if (flow_fifo_ctrl_enqueue_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = REQUEUE_FLOW;
                end
            end
    
        endcase

    end
endmodule
