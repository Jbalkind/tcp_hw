`include "soc_defs.vh"
`include "noc_defs.vh"

module rx_payload_store_buf_cp_datapath 
import tcp_pkg::*;
(
     input  clk
    ,input  rst
    ,input  rx_store_buf_q_struct                   read_store_buf_q_req_data
    
    ,output logic   [PAYLOAD_ENTRY_ADDR_W-1:0]      store_buf_tmp_buf_store_rx_rd_req_addr

    ,input  logic   [`MAC_INTERFACE_W-1:0]          tmp_buf_store_store_buf_rx_rd_resp_data

    ,output logic   [RX_TMP_BUF_ADDR_W-1:0]         store_buf_tmp_buf_free_slab_rx_req_addr

    ,output logic   [FLOWID_W-1:0]                  store_buf_commit_ptr_rd_req_flowid
    
    ,input  logic   [RX_PAYLOAD_PTR_W:0]            commit_ptr_store_buf_rd_resp_data

    ,output logic   [FLOWID_W-1:0]                  store_buf_commit_ptr_wr_req_flowid
    ,output logic   [RX_PAYLOAD_PTR_W:0]            store_buf_commit_ptr_wr_req_data
    
    ,input  logic                                   save_q_entry
    ,input  logic                                   save_commit_ptr
    ,input  logic                                   init_tmp_buf_rd_metadata
    ,input  logic                                   update_tmp_buf_rd_metadata
    ,output logic                                   last_transfer
    ,output logic                                   accept_payload
    ,output logic                                   pkt_len_0

    ,output logic   [FLOWID_W-1:0]                  datapath_wr_buf_req_flowid
    ,output logic   [RX_PAYLOAD_PTR_W-1:0]          datapath_wr_buf_req_wr_ptr
    ,output logic   [`MSG_DATA_SIZE_WIDTH-1:0]      datapath_wr_buf_req_size

    ,output logic   [`NOC_DATA_WIDTH-1:0]           datapath_wr_buf_req_data
);
    
    rx_store_buf_q_struct               q_entry_reg;
    rx_store_buf_q_struct               q_entry_next;

    logic   [RX_PAYLOAD_PTR_W:0]        commit_ptr_reg;
    logic   [RX_PAYLOAD_PTR_W:0]        commit_ptr_next;
    logic   [RX_TMP_BUF_ADDR_W-1:0]     read_addr_reg;
    logic   [RX_TMP_BUF_ADDR_W-1:0]     read_addr_next;
    logic   [PAYLOAD_ENTRY_LEN_W-1:0]   bytes_left_reg;
    logic   [PAYLOAD_ENTRY_LEN_W-1:0]   bytes_left_next;

    assign accept_payload = q_entry_next.accept_payload;
    assign pkt_len_0 = q_entry_next.payload_entry.payload_len == '0;
    
    assign store_buf_tmp_buf_store_rx_rd_req_addr = read_addr_next[RX_TMP_BUF_ADDR_W-1 -: RX_TMP_BUF_MEM_ADDR_W];
    assign last_transfer = bytes_left_reg <= `NOC_DATA_BYTES;

    assign datapath_wr_buf_req_flowid = q_entry_reg.flowid;
    assign datapath_wr_buf_req_wr_ptr = commit_ptr_reg[RX_PAYLOAD_PTR_W-1:0];
    assign datapath_wr_buf_req_size = {{(`MSG_DATA_SIZE_WIDTH-PAYLOAD_ENTRY_LEN_W){1'b0}},
                                          q_entry_reg.payload_entry.payload_len};

    assign store_buf_commit_ptr_rd_req_flowid = q_entry_next.flowid;
    assign store_buf_commit_ptr_wr_req_flowid = q_entry_reg.flowid;
    assign store_buf_commit_ptr_wr_req_data = commit_ptr_reg + q_entry_reg.payload_entry.payload_len;

    assign datapath_wr_buf_req_data = tmp_buf_store_store_buf_rx_rd_resp_data;

    assign store_buf_tmp_buf_free_slab_rx_req_addr = q_entry_reg.payload_entry.payload_addr;


    always_ff @(posedge clk) begin
        if (rst) begin
            q_entry_reg <= '0;
            commit_ptr_reg <= '0;
            read_addr_reg <= '0;
            bytes_left_reg <= '0;
        end
        else begin
            q_entry_reg <= q_entry_next;
            commit_ptr_reg <= commit_ptr_next;
            read_addr_reg <= read_addr_next;
            bytes_left_reg <= bytes_left_next;
        end
    end
    
    assign q_entry_next = save_q_entry ? read_store_buf_q_req_data : q_entry_reg;
    assign commit_ptr_next = save_commit_ptr ? commit_ptr_store_buf_rd_resp_data : commit_ptr_reg;

    always_comb begin
        if (init_tmp_buf_rd_metadata) begin
            read_addr_next = q_entry_next.payload_entry.payload_addr;
            bytes_left_next = q_entry_next.payload_entry.payload_len;
        end
        else if (update_tmp_buf_rd_metadata) begin
            read_addr_next = read_addr_reg + `MAC_INTERFACE_BYTES;
            bytes_left_next = bytes_left_reg - `MAC_INTERFACE_BYTES;
        end
        else begin
            read_addr_next = read_addr_reg;
            bytes_left_next = bytes_left_reg;
        end
    end
endmodule
