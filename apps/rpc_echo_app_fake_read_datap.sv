`include "noc_defs.vh"
`include "noc_struct_defs.vh"
`include "bsg_defines.v"
`include "state_defs.vh"
module rpc_echo_app_fake_read_datap (
     input  clk
    ,input  rst
    
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

    ,output logic   [`FLOW_ID_W-1:0]                    datapath_wr_buf_req_flowid
    ,output logic   [`PAYLOAD_PTR_W:0]                  datapath_wr_buf_req_wr_ptr
    ,output logic   [`MSG_DATA_SIZE_WIDTH-1:0]          datapath_wr_buf_req_size

    ,output logic   [`NOC_DATA_WIDTH-1:0]               datapath_wr_buf_req_data
    ,output logic                                       datapath_wr_buf_req_data_last
    ,output logic   [`NOC_PADBYTES_WIDTH-1:0]           datapath_wr_buf_req_data_padbytes

    ,output logic   [`FLOW_ID_W-1:0]                    datapath_rd_buf_req_flowid
    ,output logic   [`RX_PAYLOAD_PTR_W:0]               datapath_rd_buf_req_offset
    ,output logic   [`MSG_DATA_SIZE_WIDTH-1:0]          datapath_rd_buf_req_size

    ,input  logic   [`NOC_DATA_WIDTH-1:0]               rd_buf_datapath_resp_data
    ,input  logic                                       rd_buf_datapath_resp_data_last
    ,input  logic   [`NOC_PADBYTES_WIDTH-1:0]           rd_buf_datapath_resp_data_padbytes

    ,input  logic                                       store_curr_flowid
    ,input  logic                                       store_rx_ptrs
    ,input  logic                                       store_tx_ptrs
    ,input  logic                                       store_req_hdr
    ,input  logic                                       ctrl_datap_decr_bytes_left
    
    ,output logic                                       datap_ctrl_hdr_arrived
    ,output logic                                       datap_ctrl_rd_sat
    ,output logic                                       datap_ctrl_wr_sat
    ,output logic                                       datap_ctrl_last_wr
);

    typedef struct packed {
        logic   [15:0]  rd_len;
        logic   [15:0]  wr_len;
        logic   [223:0] padding;
    } req_hdr_struct;
    
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
    
    logic   [`RX_PAYLOAD_PTR_W:0]   rx_payload_q_space_used;

    logic   [`PAYLOAD_PTR_W:0]      tx_payload_q_space_used;

    logic   [`PAYLOAD_PTR_W:0]      tx_payload_q_space_left;

    req_hdr_struct                  req_hdr_reg;
    req_hdr_struct                  req_hdr_next;

    logic   [15:0]  wr_bytes_left_reg;
    logic   [15:0]  wr_bytes_left_next;
    
    logic   [`NOC_PADBYTES_WIDTH:0]   padbytes_calc;
    
    
    assign app_tail_ptr_tx_rd_req1_flowid = curr_flowid_reg;
    assign app_head_ptr_tx_rd_req0_flowid = curr_flowid_reg;
    assign app_rx_head_ptr_rd_req_addr = curr_flowid_reg;
    assign app_rx_commit_ptr_rd_req_addr = curr_flowid_reg;

    assign datapath_requeue_flowid = curr_flowid_reg;
    
    assign app_tail_ptr_tx_wr_req_flowid = curr_flowid_reg;
    assign app_tail_ptr_tx_wr_req_data = tx_tail_ptr_reg + 32;

    assign app_rx_head_ptr_wr_req_addr = curr_flowid_reg;
    assign app_rx_head_ptr_wr_req_data = rx_head_ptr_reg + rx_payload_q_space_used;
    
    assign datapath_wr_buf_req_flowid = curr_flowid_reg;
    assign datapath_wr_buf_req_wr_ptr = tx_tail_ptr_reg;
    assign datapath_wr_buf_req_size = {{(`MSG_DATA_SIZE_WIDTH - 16){1'b0}}, 
                                        16'd32};
    
    assign datapath_rd_buf_req_flowid = curr_flowid_reg;
    assign datapath_rd_buf_req_offset = rx_head_ptr_reg;
    assign datapath_rd_buf_req_size = 0; 
    
    assign datapath_wr_buf_req_data = 256'h61626364_65666768_696a6b6c_6d6e6f70_71727374_75767778_797a6162_63646566;
    assign datapath_wr_buf_req_data_last = datap_ctrl_last_wr;

    assign padbytes_calc = '0;
    assign datapath_wr_buf_req_data_padbytes = padbytes_calc[`NOC_PADBYTES_WIDTH-1:0];

    assign datap_ctrl_last_wr = wr_bytes_left_reg <= `NOC_DATA_BYTES;

    assign rx_payload_q_space_used = rx_commit_ptr_reg - rx_head_ptr_reg;

    assign tx_payload_q_space_used = tx_tail_ptr_reg - tx_head_ptr_reg;
    assign tx_payload_q_space_left = {1'b1, {(`PAYLOAD_PTR_W){1'b0}}} - tx_payload_q_space_used;

    // need to subtract 32 bytes for the request header
    assign datap_ctrl_hdr_arrived = (rx_payload_q_space_used >= 32);
    assign datap_ctrl_rd_sat = (rx_payload_q_space_used != 0);
    assign datap_ctrl_wr_sat = (tx_payload_q_space_left) >= 32;
                                     
    
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
    
    assign curr_flowid_next = store_curr_flowid ? flow_fifo_datapath_flowid : curr_flowid_reg;

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

    assign req_hdr_next = store_req_hdr 
                        ? rd_buf_datapath_resp_data
                        : req_hdr_reg;

    always_comb begin
        if (store_req_hdr) begin
            wr_bytes_left_next = 32;
        end
        else if (ctrl_datap_decr_bytes_left) begin
            wr_bytes_left_next = wr_bytes_left_reg - `NOC_DATA_BYTES;
        end
        else begin
            wr_bytes_left_next = wr_bytes_left_reg;
        end
    end

    
    always_ff @(posedge clk) begin
        if (rst) begin
            curr_flowid_reg <= '0;
            tx_head_ptr_reg <= '0;
            tx_tail_ptr_reg <= '0;
            rx_head_ptr_reg <= '0;
            rx_commit_ptr_reg <= '0;
            req_hdr_reg <= '0;
            wr_bytes_left_reg <= '0;
        end
        else begin
            curr_flowid_reg <= curr_flowid_next;
            tx_head_ptr_reg <= tx_head_ptr_next;
            tx_tail_ptr_reg <= tx_tail_ptr_next;
            rx_head_ptr_reg <= rx_head_ptr_next;
            rx_commit_ptr_reg <= rx_commit_ptr_next;
            req_hdr_reg <= req_hdr_next;
            wr_bytes_left_reg <= wr_bytes_left_next;
        end
    end
    

endmodule
