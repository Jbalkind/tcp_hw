`include "state_defs.vh"
`include "noc_defs.vh"
module test_echo_app_datap (
     input clk
    ,input rst
    
    ,output logic   [`FLOW_ID_W-1:0]                    app_tail_ptr_tx_wr_req_flowid
    ,output logic   [`PAYLOAD_PTR_W:0]                  app_tail_ptr_tx_wr_req_data

    ,output logic   [`FLOW_ID_W-1:0]                    app_tail_ptr_tx_rd_req1_flowid

    ,input  logic   [`PAYLOAD_PTR_W:0]                  tail_ptr_app_tx_rd_resp1_data

    ,output logic   [`FLOW_ID_W-1:0]                    app_head_ptr_tx_rd_req0_flowid

    ,input  logic   [`PAYLOAD_PTR_W:0]                  head_ptr_app_tx_rd_resp0_data
    
    ,output logic   [`FLOW_ID_W-1:0]                    app_rx_head_ptr_wr_req_addr
    ,output logic   [`RX_PAYLOAD_PTR_W:0]               app_rx_head_ptr_wr_req_data

    ,output logic   [`FLOW_ID_W-1:0]                    app_rx_head_ptr_rd_req_addr

    ,input  logic   [`RX_PAYLOAD_PTR_W:0]               rx_head_ptr_app_rd_resp_data

    ,output logic   [`FLOW_ID_W-1:0]                    app_rx_commit_ptr_rd_req_addr

    ,input  logic   [`RX_PAYLOAD_PTR_W:0]               rx_commit_ptr_app_rd_resp_data

    ,input  logic   [`FLOW_ID_W-1:0]                    flow_fifo_datapath_flowid
    ,output logic   [`FLOW_ID_W-1:0]                    datapath_requeue_flowid

    ,input  logic                                       store_curr_flowid
    ,input  logic                                       store_rx_ptrs
    ,input  logic                                       store_tx_ptrs
    ,input  logic                                       update_q_space

    ,output logic                                       rx_buf_empty
    ,output logic                                       rx_buf_full
    ,output logic                                       tx_buf_full
);


    logic   [`FLOW_ID_W-1:0]    curr_flowid_reg;
    logic   [`FLOW_ID_W-1:0]    curr_flowid_next;
    
    logic   [`PAYLOAD_PTR_W:0]  tx_head_ptr_reg;
    logic   [`PAYLOAD_PTR_W:0]  tx_tail_ptr_reg;
    logic   [`PAYLOAD_PTR_W:0]  tx_head_ptr_next;
    logic   [`PAYLOAD_PTR_W:0]  tx_tail_ptr_next;

    logic   [`RX_PAYLOAD_PTR_W:0]   rx_head_ptr_reg;
    logic   [`RX_PAYLOAD_PTR_W:0]   rx_commit_ptr_reg;
    logic   [`RX_PAYLOAD_PTR_W:0]   rx_head_ptr_next;
    logic   [`RX_PAYLOAD_PTR_W:0]   rx_commit_ptr_next;
    
    logic   [`RX_PAYLOAD_PTR_W:0]   rx_payload_q_space_used_reg;
    logic   [`RX_PAYLOAD_PTR_W:0]   rx_payload_q_space_used_next;

    logic   [`PAYLOAD_PTR_W:0]      tx_payload_q_space_used_reg;
    logic   [`PAYLOAD_PTR_W:0]      tx_payload_q_space_used_next;

    logic   [`PAYLOAD_PTR_W:0]      tx_payload_q_space_left_reg;
    logic   [`PAYLOAD_PTR_W:0]      tx_payload_q_space_left_next;

    logic   [`PAYLOAD_PTR_W:0]      datapath_copy_size;

    logic   [`RX_PAYLOAD_PTR_W:0]   rx_want_to_send;
    logic                           bytes_can_send;
    
    assign app_tail_ptr_tx_rd_req1_flowid = curr_flowid_reg;
    assign app_head_ptr_tx_rd_req0_flowid = curr_flowid_reg;
    assign app_rx_head_ptr_rd_req_addr = curr_flowid_reg;
    assign app_rx_commit_ptr_rd_req_addr = curr_flowid_reg;
    
    assign datapath_requeue_flowid = curr_flowid_reg;
    
    assign app_tail_ptr_tx_wr_req_flowid = curr_flowid_reg;
    assign app_tail_ptr_tx_wr_req_data = tx_tail_ptr_reg + datapath_copy_size;
    assign app_rx_head_ptr_wr_req_addr = curr_flowid_reg;
    assign app_rx_head_ptr_wr_req_data = rx_head_ptr_reg + datapath_copy_size;
    
    assign rx_buf_full = (rx_head_ptr_reg[`RX_PAYLOAD_PTR_W] != rx_commit_ptr_reg[`RX_PAYLOAD_PTR_W])
                       & (rx_head_ptr_reg[`RX_PAYLOAD_PTR_W-1:0] == rx_commit_ptr_reg[`RX_PAYLOAD_PTR_W-1:0]);
    assign rx_buf_empty = rx_head_ptr_reg == rx_commit_ptr_reg;

    assign tx_buf_full = (tx_head_ptr_reg[`PAYLOAD_PTR_W] != tx_tail_ptr_reg[`PAYLOAD_PTR_W])
                       & (tx_head_ptr_reg[`PAYLOAD_PTR_W-1:0] == tx_tail_ptr_reg[`PAYLOAD_PTR_W-1:0]); 
    // can we send more than 32 bytes? if so, round down to the nearest 32. If not, just send whatever
    // is still in the buffer. Obviously, we should probably try to realign if unaligned (send whatever 
    // remainder 32 plus what is expected), but whatever for now
    assign rx_want_to_send = rx_payload_q_space_used_reg >= `NOC_DATA_BYTES
                           ? {rx_payload_q_space_used_reg[`RX_PAYLOAD_PTR_W:`NOC_DATA_BYTES_W]
                            , {(`NOC_DATA_BYTES_W){1'b0}}}
                           : rx_payload_q_space_used_reg;
    
    // check if the tx buffer has room for what we want to send
    assign bytes_can_send = tx_payload_q_space_left_reg >= rx_want_to_send;

    always_comb begin
        // if the tx buffer has room, send it
        if (bytes_can_send) begin
            datapath_copy_size = rx_want_to_send;
        end
        // otherwise, just send what's gonna fill up the tx buffer
        else begin
            datapath_copy_size = tx_payload_q_space_left_reg;
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            curr_flowid_reg <= '0;
            tx_head_ptr_reg <= '0;
            tx_tail_ptr_reg <= '0;
            rx_head_ptr_reg <= '0;
            rx_commit_ptr_reg <= '0;
            rx_payload_q_space_used_reg <= '0;
            tx_payload_q_space_used_reg <= '0;
            tx_payload_q_space_left_reg <= '0;
        end
        else begin
            curr_flowid_reg <= curr_flowid_next;
            tx_head_ptr_reg <= tx_head_ptr_next;
            tx_tail_ptr_reg <= tx_tail_ptr_next;
            rx_head_ptr_reg <= rx_head_ptr_next;
            rx_commit_ptr_reg <= rx_commit_ptr_next;
            rx_payload_q_space_used_reg <= rx_payload_q_space_used_next;
            tx_payload_q_space_used_reg <= tx_payload_q_space_used_next;
            tx_payload_q_space_left_reg <= tx_payload_q_space_left_next;
        end
    end
    
    assign curr_flowid_next = store_curr_flowid ? flow_fifo_datapath_flowid : curr_flowid_reg;

    always_comb begin
        if (update_q_space) begin
            rx_payload_q_space_used_next = rx_commit_ptr_reg - rx_head_ptr_reg;

            // this ordering is very important since tx_payload_q_space_left_next is relying
            // on tx_payload_q_space_used_next
            tx_payload_q_space_used_next = tx_tail_ptr_reg - tx_head_ptr_reg;
            tx_payload_q_space_left_next = {1'b1, {(`PAYLOAD_PTR_W){1'b0}}} - tx_payload_q_space_used_next;
        end
        else begin
            rx_payload_q_space_used_next = rx_payload_q_space_used_reg;

            tx_payload_q_space_used_next = tx_payload_q_space_used_reg;
            tx_payload_q_space_left_next = tx_payload_q_space_left_reg;

        end
    end

    always_comb begin
        if (store_rx_ptrs) begin
            rx_head_ptr_next = rx_head_ptr_app_rd_resp_data;
            rx_commit_ptr_next = rx_commit_ptr_app_rd_resp_data;
        end
        else begin
            rx_head_ptr_next = rx_head_ptr_reg;
            rx_commit_ptr_next = rx_commit_ptr_reg;
        end
    end

    always_comb begin
        if (store_tx_ptrs) begin
            tx_head_ptr_next = head_ptr_app_tx_rd_resp0_data;
            tx_tail_ptr_next = tail_ptr_app_tx_rd_resp1_data;
        end
        else begin
            tx_head_ptr_next = tx_head_ptr_reg;
            tx_tail_ptr_next = tx_tail_ptr_reg;
        end
    end


endmodule
