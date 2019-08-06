`include "soc_defs.vh"
`include "state_defs.vh"
module fake_tmp_buf (
     input clk
    ,input rst
    
    ,input  logic                                   store_buf_tmp_buf_store_rx_rd_req_val
    ,input  logic   [`PAYLOAD_ENTRY_ADDR_W-1:0]     store_buf_tmp_buf_store_rx_rd_req_addr
    ,output logic                                   tmp_buf_store_store_buf_rx_rd_req_rdy

    ,output logic                                   tmp_buf_store_store_buf_rx_rd_resp_val
    ,output logic   [`MAC_INTERFACE_W-1:0]          tmp_buf_store_store_buf_rx_rd_resp_data
    ,input  logic                                   store_buf_tmp_buf_store_rx_rd_resp_rdy
);

    logic   val_store_reg;

    assign tmp_buf_store_store_buf_rx_rd_resp_val = val_store_reg;
    assign tmp_buf_store_store_buf_rx_rd_resp_data = '0;
    assign tmp_buf_store_store_buf_rx_rd_req_rdy = store_buf_tmp_buf_store_rx_rd_resp_rdy | ~val_store_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            val_store_reg <= 1'b0;
        end
        else begin
            val_store_reg <= store_buf_tmp_buf_store_rx_rd_req_val;
        end
    end
endmodule
