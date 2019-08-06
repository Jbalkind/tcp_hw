`include "packet_defs.vh"
`include "state_defs.vh"
`include "noc_defs.vh"
`include "soc_defs.vh"

import noc_struct_pkg::*;
import state_struct_pkg::*;
import packet_struct_pkg::*;

module frontend_rx_payload_engine #( 
     parameter SRC_X = 0
    ,parameter SRC_Y = 0
    ,parameter RX_DRAM_X = 0
    ,parameter RX_DRAM_Y = 0
    ,parameter FBITS = 0
) (
     input clk
    ,input rst
    
    // I/O for the NoC
    ,output logic                               rx_payload_noc0_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       rx_payload_noc0_data
    ,input                                      noc0_rx_payload_rdy
    
    ,input                                      noc0_rx_payload_val
    ,input          [`NOC_DATA_WIDTH-1:0]       noc0_rx_payload_data
    ,output logic                               rx_payload_noc0_rdy

    // Write req inputs
    ,input                                      src_payload_rx_hdr_val
    ,output logic                               payload_src_rx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]            src_payload_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]            src_payload_rx_dst_ip
    ,input          [`TOT_LEN_W-1:0]            src_payload_rx_tcp_payload_len
    ,input  tcp_pkt_hdr                         src_payload_rx_tcp_hdr
    
    ,input                                      src_payload_rx_data_val
    ,input          [`MAC_INTERFACE_W-1:0]      src_payload_rx_data
    ,input                                      src_payload_rx_data_last
    ,input          [`MAC_PADBYTES_W-1:0]       src_payload_rx_data_padbytes
    ,output logic                               payload_src_rx_data_rdy
    
    // Write resp
    ,output logic                               payload_dst_rx_hdr_val
    ,input                                      dst_payload_rx_rdy
    ,output logic   [`IP_ADDR_W-1:0]            payload_dst_rx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]            payload_dst_rx_dst_ip
    ,output tcp_pkt_hdr                         payload_dst_rx_tcp_hdr

    ,output logic                               payload_dst_rx_payload_val
    ,output payload_buf_entry                   payload_dst_rx_payload_addr
    ,output logic   [`PAYLOAD_ENTRY_LEN_W-1:0]  payload_dst_rx_payload_len

);

    typedef enum logic [2:0] {
        READY = 3'd0,
        HDR_FLIT = 3'd1,
        PAYLOAD = 3'd2,
        WRITE_RESP = 3'd3,
        OUTPUT = 3'd4,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;
    
    logic   [`IP_ADDR_W-1:0]            src_payload_rx_src_ip_next;
    logic   [`IP_ADDR_W-1:0]            src_payload_rx_src_ip_reg;
    
    logic   [`IP_ADDR_W-1:0]            src_payload_rx_dst_ip_next;
    logic   [`IP_ADDR_W-1:0]            src_payload_rx_dst_ip_reg;

    tcp_pkt_hdr                         src_payload_rx_tcp_hdr_next;
    tcp_pkt_hdr                         src_payload_rx_tcp_hdr_reg;
    
    logic   [`TOT_LEN_W-1:0]            src_payload_payload_len_bytes_next;
    logic   [`TOT_LEN_W-1:0]            src_payload_payload_len_bytes_reg;

    logic   [`MSG_LENGTH_WIDTH-1:0]     data_flits_to_send_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0]     data_flits_to_send_next;
    
    logic   [`MSG_LENGTH_WIDTH-1:0]     flits_sent_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0]     flits_sent_next;
    
    logic   [`PAYLOAD_ENTRY_ADDR_W-1:0] curr_write_addr_reg;
    logic   [`PAYLOAD_ENTRY_ADDR_W-1:0] curr_write_addr_next;
    
    logic   [`PAYLOAD_ENTRY_ADDR_W-1:0] output_write_addr_reg;
    logic   [`PAYLOAD_ENTRY_ADDR_W-1:0] output_write_addr_next;

    logic   [`MAC_INTERFACE_W-1:0]      src_payload_rx_data_masked;
    logic   [`MAC_INTERFACE_W-1:0]      src_payload_rx_data_mask;
    
    logic   [`MAC_INTERFACE_BITS_W-1:0] data_mask_shift;

    noc_hdr_flit hdr_flit;

    noc_hdr_flit resp_flit_cast;
    
    assign resp_flit_cast = noc0_rx_payload_data;

    assign payload_dst_rx_src_ip = src_payload_rx_src_ip_reg;
    assign payload_dst_rx_dst_ip = src_payload_rx_dst_ip_reg;
    assign payload_dst_rx_tcp_hdr = src_payload_rx_tcp_hdr_reg;
    assign payload_dst_rx_payload_len = src_payload_payload_len_bytes_reg;
    assign payload_dst_rx_payload_addr = output_write_addr_reg;

    assign data_mask_shift = src_payload_rx_data_padbytes << 3;
    assign src_payload_rx_data_mask = src_payload_rx_data_last
                               ? {(`MAC_INTERFACE_W){1'b1}} << (data_mask_shift)
                               : {(`MAC_INTERFACE_W){1'b1}};

    assign src_payload_rx_data_masked = src_payload_rx_data & src_payload_rx_data_mask;


    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;

            src_payload_rx_src_ip_reg <= '0; 
            src_payload_rx_dst_ip_reg <= '0;
            src_payload_rx_tcp_hdr_reg <= '0;
            src_payload_payload_len_bytes_reg <= '0;

            data_flits_to_send_reg <= '0;
            flits_sent_reg <= '0;

            curr_write_addr_reg <= '0;
            output_write_addr_reg <= '0;
        end
        else begin
            state_reg <= state_next;

            src_payload_rx_src_ip_reg <= src_payload_rx_src_ip_next;
            src_payload_rx_dst_ip_reg <= src_payload_rx_dst_ip_next;
            src_payload_rx_tcp_hdr_reg <= src_payload_rx_tcp_hdr_next;
            src_payload_payload_len_bytes_reg <= src_payload_payload_len_bytes_next;

            data_flits_to_send_reg <= data_flits_to_send_next;
            flits_sent_reg <= flits_sent_next;

            curr_write_addr_reg <= curr_write_addr_next >= {1'b1, `MEM_ADDR_W'd0}
                                 ? '0
                                 : curr_write_addr_next;
            output_write_addr_reg <= output_write_addr_next;
        end
    end

    always_comb begin
        state_next = state_reg;
        payload_dst_rx_hdr_val = 1'b0;
        payload_src_rx_hdr_rdy = 1'b0;
                    
        src_payload_rx_src_ip_next = src_payload_rx_src_ip_reg;
        src_payload_rx_dst_ip_next = src_payload_rx_dst_ip_reg;
        src_payload_rx_tcp_hdr_next = src_payload_rx_tcp_hdr_reg;
        src_payload_payload_len_bytes_next = src_payload_payload_len_bytes_reg;

        data_flits_to_send_next = data_flits_to_send_reg;
        flits_sent_next = flits_sent_reg;

        curr_write_addr_next = curr_write_addr_reg;
        output_write_addr_next = output_write_addr_reg;
                
        rx_payload_noc0_val = 1'b0;
        rx_payload_noc0_data = '0;
        rx_payload_noc0_rdy = 1'b0;

        payload_src_rx_data_rdy = 1'b0;
        payload_dst_rx_payload_val = 1'b0;

        case (state_reg)
            READY: begin
                payload_src_rx_hdr_rdy = 1'b1;
                if (src_payload_rx_hdr_val) begin
                    src_payload_rx_src_ip_next = src_payload_rx_src_ip;
                    src_payload_rx_dst_ip_next = src_payload_rx_dst_ip;
                    src_payload_rx_tcp_hdr_next = src_payload_rx_tcp_hdr;
                    src_payload_payload_len_bytes_next = src_payload_rx_tcp_payload_len;
    
                    data_flits_to_send_next = 
                        src_payload_rx_tcp_payload_len[`NOC_DATA_BYTES_W-1:0] == 0
                              ? src_payload_rx_tcp_payload_len >> `NOC_DATA_BYTES_W
                              : (src_payload_rx_tcp_payload_len >> `NOC_DATA_BYTES_W) + 1;
                    flits_sent_next = '0;

                    output_write_addr_next = curr_write_addr_reg;

                    if (src_payload_rx_tcp_payload_len != 0) begin
                        state_next = HDR_FLIT;
                    end
                    else begin
                        state_next = OUTPUT;
                    end
                end
                else begin
                    state_next = READY;
                end
            end
            HDR_FLIT: begin
                rx_payload_noc0_val = 1'b1;
                rx_payload_noc0_data = hdr_flit;

                if (noc0_rx_payload_rdy) begin
                    state_next = PAYLOAD;
                end
                else begin
                    state_next = HDR_FLIT;
                end
            end
            PAYLOAD: begin
                payload_src_rx_data_rdy = noc0_rx_payload_rdy;

                rx_payload_noc0_val = src_payload_rx_data_val;
                rx_payload_noc0_data = src_payload_rx_data_masked;
               
                if (noc0_rx_payload_rdy & src_payload_rx_data_val) begin
                    flits_sent_next = flits_sent_reg + 1'b1;
                    if (flits_sent_reg == (data_flits_to_send_reg - 1)) begin
                        state_next = WRITE_RESP; 
                    end
                    else begin
                        state_next = PAYLOAD;
                    end
                end
                else begin
                    state_next = PAYLOAD;
                end
            end
            WRITE_RESP: begin
                rx_payload_noc0_rdy = 1'b1;

                if (noc0_rx_payload_val) begin
                    if (resp_flit_cast.msg_type == `MSG_TYPE_STORE_MEM_ACK) begin
                        state_next = OUTPUT;
                        curr_write_addr_next = curr_write_addr_reg + 
                                           (data_flits_to_send_reg << `NOC_DATA_BYTES_W);
                    end
                    else begin
                        state_next = UND;
                    end
                end
                else begin
                    state_next = WRITE_RESP;
                end
            end
            OUTPUT: begin
                payload_dst_rx_hdr_val = 1'b1;
                payload_dst_rx_payload_val = src_payload_payload_len_bytes_reg != 0;
                
                if (dst_payload_rx_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = OUTPUT;
                end
            end
        endcase
    end
    
    // fill some header flits
    always_comb begin
        hdr_flit = '0;

        hdr_flit.dst_chip_id = 'b0;
        hdr_flit.dst_x_coord = RX_DRAM_X[`MSG_DST_X_WIDTH-1:0];
        hdr_flit.dst_y_coord = RX_DRAM_Y[`MSG_DST_Y_WIDTH-1:0];
        hdr_flit.fbits = 'b0;
        hdr_flit.msg_len = data_flits_to_send_reg;
        hdr_flit.msg_type = `MSG_TYPE_STORE_MEM;

        hdr_flit.addr = curr_write_addr_reg;

        hdr_flit.src_chip_id = 'b0;
        hdr_flit.src_x_coord = SRC_X[`MSG_SRC_X_WIDTH-1:0];
        hdr_flit.src_y_coord = SRC_Y[`MSG_SRC_Y_WIDTH-1:0];
        hdr_flit.src_fbits = {1'b1, FBITS[`MSG_SRC_FBITS_WIDTH-2:0]};
        hdr_flit.data_size = src_payload_payload_len_bytes_reg;
    end


endmodule
