`include "packet_defs.vh"
`include "noc_defs.vh"
module tcp_tmp_rx_buf_datapath 
import packet_struct_pkg::*;
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input          [`IP_ADDR_W-1:0]                src_tmp_buf_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]                src_tmp_buf_rx_dst_ip
    ,input          [`TOT_LEN_W-1:0]                src_tmp_buf_rx_tcp_payload_len
    ,input tcp_pkt_hdr                              src_tmp_buf_rx_tcp_hdr
    
    ,input          [`MAC_INTERFACE_W-1:0]          src_tmp_buf_rx_data
    ,input                                          src_tmp_buf_rx_data_last
    ,input          [`MAC_PADBYTES_W-1:0]           src_tmp_buf_rx_data_padbytes

    ,input                                          load_hdr_state
    ,input                                          store_entry_addr
    ,input                                          incr_store_addr

    ,input          [RX_TMP_BUF_ADDR_W-1:0]         alloc_slab_tmp_buf_resp_addr

    ,output         [RX_TMP_BUF_MEM_ADDR_W-1:0]     tmp_buf_buf_store_addr
    ,output         [`MAC_INTERFACE_W-1:0]          tmp_buf_buf_store_data
   
    
    ,output logic   [`IP_ADDR_W-1:0]                tmp_buf_dst_rx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]                tmp_buf_dst_rx_dst_ip
    ,output tcp_pkt_hdr                             tmp_buf_dst_rx_tcp_hdr

    ,output payload_buf_struct                      tmp_buf_dst_rx_payload_entry
);

    tcp_pkt_hdr tcp_hdr_reg;
    tcp_pkt_hdr tcp_hdr_next;

    logic   [`IP_ADDR_W-1:0]    src_ip_reg;
    logic   [`IP_ADDR_W-1:0]    src_ip_next;
    logic   [`IP_ADDR_W-1:0]    dst_ip_reg;
    logic   [`IP_ADDR_W-1:0]    dst_ip_next;

    logic   [`TOT_LEN_W-1:0]    tcp_payload_len_reg;
    logic   [`TOT_LEN_W-1:0]    tcp_payload_len_next;

    logic   [RX_TMP_BUF_ADDR_W-1:0]     alloc_addr_reg;
    logic   [RX_TMP_BUF_ADDR_W-1:0]     alloc_addr_next;
    
    logic   [RX_TMP_BUF_ADDR_W-1:0]     write_addr_reg;
    logic   [RX_TMP_BUF_ADDR_W-1:0]     write_addr_next;

    logic   [`MAC_INTERFACE_W-1:0]      data_mask;
    logic   [`MAC_INTERFACE_BITS_W-1:0] mask_shift;

    payload_buf_struct                  output_entry;

    assign tmp_buf_dst_rx_payload_entry = output_entry;

    assign output_entry.payload_addr = alloc_addr_reg;
    assign output_entry.payload_len = tcp_payload_len_reg;

    assign tmp_buf_dst_rx_src_ip = src_ip_reg;
    assign tmp_buf_dst_rx_dst_ip = dst_ip_reg;
    assign tmp_buf_dst_rx_tcp_hdr = tcp_hdr_reg;

    assign tmp_buf_buf_store_addr = write_addr_reg[RX_TMP_BUF_ADDR_W-1:`MAC_INTERFACE_BYTES_W];

    assign mask_shift = src_tmp_buf_rx_data_last
                      ? src_tmp_buf_rx_data_padbytes << 3
                      : '0;
    assign data_mask = {(`MAC_INTERFACE_W){1'b1}} << mask_shift;

    assign tmp_buf_buf_store_data = src_tmp_buf_rx_data & data_mask;


    always_ff @(posedge clk) begin
        if (rst) begin
            tcp_hdr_reg <= '0;
            src_ip_reg <= '0;
            dst_ip_reg <= '0;
            tcp_payload_len_reg <= '0;
            alloc_addr_reg <= '0;
            write_addr_reg <= '0;
        end
        else begin
            tcp_hdr_reg <= tcp_hdr_next;
            src_ip_reg <= src_ip_next;
            dst_ip_reg <= dst_ip_next;
            tcp_payload_len_reg <= tcp_payload_len_next;
            alloc_addr_reg <= alloc_addr_next;
            write_addr_reg <= write_addr_next;
        end
    end

    always_comb begin
        if (load_hdr_state) begin
            tcp_hdr_next = src_tmp_buf_rx_tcp_hdr;
            src_ip_next = src_tmp_buf_rx_src_ip;
            dst_ip_next = src_tmp_buf_rx_dst_ip;
            tcp_payload_len_next = src_tmp_buf_rx_tcp_payload_len;
        end
        else begin
            tcp_hdr_next = tcp_hdr_reg;
            src_ip_next = src_ip_reg;
            dst_ip_next = dst_ip_reg;
            tcp_payload_len_next = tcp_payload_len_reg;
        end
    end

    assign alloc_addr_next = store_entry_addr ? alloc_slab_tmp_buf_resp_addr : alloc_addr_reg;

    always_comb begin
        if (store_entry_addr) begin
            write_addr_next = alloc_slab_tmp_buf_resp_addr;
        end
        else if (incr_store_addr) begin
            write_addr_next = write_addr_reg + `NOC_DATA_BYTES;
        end
        else begin
            write_addr_next = write_addr_reg;
        end
    end



endmodule
