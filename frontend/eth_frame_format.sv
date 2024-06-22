`include "soc_defs.vh"
`include "packet_defs.vh"
module eth_frame_format 
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    ,input                                  src_eth_format_val
    ,input          [`MAC_INTERFACE_W-1:0]  src_eth_format_data
    ,input          [`MTU_SIZE_W-1:0]       src_eth_format_frame_size
    ,input                                  src_eth_format_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_eth_format_data_padbytes
    ,output logic                           eth_format_src_rdy

    ,output eth_hdr                         eth_format_dst_eth_hdr
    ,output logic   [`MTU_SIZE_W-1:0]       eth_format_dst_data_size
    ,output logic                           eth_format_dst_hdr_val
    ,output logic   [`PKT_TIMESTAMP_W-1:0]  eth_format_dst_timestamp
    ,input                                  dst_eth_format_hdr_rdy

    ,output logic                           eth_format_dst_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]  eth_format_dst_data
    ,input                                  dst_eth_format_data_rdy
    ,output logic                           eth_format_dst_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   eth_format_dst_data_padbytes
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        FIRST_DATA = 3'd1,
        DATA_OUTPUT = 3'd2,
        DATA_OUTPUT_LAST = 3'd3,
        DATA_WAIT_TX_FIN = 3'd4,
        UNDEF = 'X
    } data_state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        HDR_OUTPUT = 2'd1,
        HDR_WAIT_TX_FIN = 2'd2,
        UND = 'X
    } hdr_state_e;

    typedef enum logic[1:0] {
        INIT = 2'd0,
        DECR = 2'd1,
        HOLD = 2'd2,
        INIT_SMALL = 2'd3
    } bytes_left_sel_e;

    data_state_e data_state_reg;
    data_state_e data_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;

    eth_hdr eth_hdr_struct_reg;
    eth_hdr eth_hdr_struct_next;

    logic   [`MTU_SIZE_W-1:0]   data_size_reg;
    logic   [`MTU_SIZE_W-1:0]   data_size_next;

    eth_hdr eth_hdr_struct_cast;
    eth_hdr_vlan eth_hdr_vlan_cast;

    logic   [`PKT_TIMESTAMP_W-1:0]  timestamp_reg;

    localparam realign_shift_width = 8;
    
    logic   [`MAC_INTERFACE_W-1:0]            realign_upper_reg;
    logic   [`MAC_INTERFACE_W-1:0]            realign_upper_next;
    logic   [`MAC_INTERFACE_W-1:0]            realign_lower_reg;
    logic   [`MAC_INTERFACE_W-1:0]            realign_lower_next;

    logic   [(`MAC_INTERFACE_W* 2) - 1 :0]  realigned_data;
    logic   [realign_shift_width-1:0]       realign_shift_next;
    logic   [realign_shift_width-1:0]       realign_shift_reg;
    logic   [`MAC_PADBYTES_W-1:0]           padbytes_temp;
    
    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_reg;
    logic   [`MAC_PADBYTES_W-1:0]           data_padbytes_next;

    logic   [`MAC_PADBYTES_W:0] bytes_left_reg;
    logic   [`MAC_PADBYTES_W:0] bytes_left_next;
    bytes_left_sel_e            store_bytes_left;
    
    logic                       output_hdr;

    assign realigned_data = {realign_upper_reg, realign_lower_reg} << realign_shift_reg;

    assign padbytes_temp = (realign_shift_reg/8) + data_padbytes_reg;

    assign eth_hdr_struct_cast = src_eth_format_data[`MAC_INTERFACE_W-1 -: ETH_HDR_W];
    assign eth_hdr_vlan_cast = src_eth_format_data[`MAC_INTERFACE_W-1 -: ETH_HDR_VLAN_W];

    assign eth_format_dst_data_size = data_size_reg;
    
    assign eth_format_dst_data = realigned_data[(`MAC_INTERFACE_W*2)-1 -: `MAC_INTERFACE_W];

    assign eth_format_dst_timestamp = timestamp_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            hdr_state_reg <= WAITING;
            realign_upper_reg <= '0;
            realign_lower_reg <= '0;
            data_padbytes_reg <= '0;
            eth_hdr_struct_reg <= '0;
            bytes_left_reg <= '0;
            realign_shift_reg <= '0;
            data_size_reg <= '0;
            timestamp_reg <= '0;
        end
        else begin
            data_state_reg <= data_state_next;
            hdr_state_reg <= hdr_state_next;
            realign_upper_reg <= realign_upper_next;
            realign_lower_reg <= realign_lower_next;
            data_padbytes_reg <= data_padbytes_next;
            eth_hdr_struct_reg <= eth_hdr_struct_next;
            bytes_left_reg <= bytes_left_next;
            realign_shift_reg <= realign_shift_next;
            data_size_reg <= data_size_next;
            timestamp_reg <= timestamp_reg + 1'b1;
        end
    end

    always_comb begin
        if (store_bytes_left == INIT) begin
            bytes_left_next = `MAC_INTERFACE_BYTES - (realign_shift_next >> 3)
                            + `MAC_INTERFACE_BYTES - src_eth_format_data_padbytes;
        end
        else if (store_bytes_left == INIT_SMALL) begin
            bytes_left_next = `MAC_INTERFACE_BYTES - (realign_shift_next >> 3);
        end
        else if (store_bytes_left == DECR) begin
            bytes_left_next = bytes_left_reg - `MAC_INTERFACE_BYTES;
        end
        else begin
            bytes_left_next = bytes_left_reg;
        end
    end


    always_comb begin
        data_state_next = data_state_reg;
        eth_hdr_struct_next = eth_hdr_struct_reg;
        realign_upper_next = realign_upper_reg;
        realign_lower_next = realign_lower_reg;
        eth_format_src_rdy = 1'b0;
        eth_format_dst_data_val = 1'b0;
        eth_format_dst_data_padbytes = '0;
        eth_format_dst_data_last = 1'b0; 
        data_padbytes_next = data_padbytes_reg;
        realign_shift_next = realign_shift_reg;
        data_size_next = data_size_reg;
        output_hdr = 1'b0;
        store_bytes_left = HOLD;
        case (data_state_reg)
            READY: begin
                eth_format_src_rdy = 1'b1;
                if (src_eth_format_val) begin
                    realign_upper_next = src_eth_format_data;
                    output_hdr = 1'b1;

                    if (eth_hdr_struct_cast.eth_type == `ETH_TYPE_VLAN) begin
                        eth_hdr_struct_next.eth_type = eth_hdr_vlan_cast.eth_type; 
                        data_size_next = src_eth_format_frame_size - ETH_HDR_VLAN_BYTES;
                        realign_shift_next = ETH_HDR_VLAN_W;
                    end
                    else begin
                        eth_hdr_struct_next = eth_hdr_struct_cast; 
                        data_size_next = src_eth_format_frame_size - ETH_HDR_BYTES;
                        realign_shift_next = ETH_HDR_W;
                    end

                    if (src_eth_format_data_last) begin
                        store_bytes_left = INIT_SMALL;
                        data_padbytes_next = src_eth_format_data_padbytes;
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        data_state_next = FIRST_DATA;
                    end
                end 
                else begin
                    eth_hdr_struct_next = eth_hdr_struct_reg;
                    realign_upper_next = realign_upper_reg;
                    data_state_next = READY;
                end
                
            end
            FIRST_DATA: begin
                eth_format_src_rdy = 1'b1;
                if (src_eth_format_val) begin
                    realign_lower_next = src_eth_format_data;
                    if (src_eth_format_data_last) begin
                        store_bytes_left = INIT;
                        data_padbytes_next = src_eth_format_data_padbytes;
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        data_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    realign_lower_next = realign_lower_reg;
                    data_state_next = FIRST_DATA;
                end
            end
            DATA_OUTPUT: begin
                eth_format_src_rdy = dst_eth_format_data_rdy;
                eth_format_dst_data_val = src_eth_format_val;

                if (src_eth_format_val & dst_eth_format_data_rdy) begin
                    realign_upper_next = realign_lower_reg;
                    realign_lower_next = src_eth_format_data;

                    if (src_eth_format_data_last) begin
                        data_state_next = DATA_OUTPUT_LAST;
                        store_bytes_left = INIT;
                        data_padbytes_next = src_eth_format_data_padbytes;
                    end 
                    else begin
                        data_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    realign_upper_next = realign_upper_reg;
                    realign_lower_next = realign_lower_reg;
                    data_state_next = DATA_OUTPUT; 
                end
            end
            DATA_OUTPUT_LAST: begin
                eth_format_src_rdy = 1'b0;
                eth_format_dst_data_val = 1'b1;
                eth_format_dst_data_padbytes = bytes_left_reg <= (`MAC_INTERFACE_BYTES)
                                                 ? padbytes_temp[`MAC_PADBYTES_W-1:0]
                                                 : '0;
                eth_format_dst_data_last = bytes_left_reg <= (`MAC_INTERFACE_BYTES);

                data_padbytes_next = data_padbytes_reg;
                if (dst_eth_format_data_rdy) begin
                    if (bytes_left_reg > (`MAC_INTERFACE_BYTES)) begin
                        store_bytes_left = DECR;
                        realign_upper_next = realign_lower_reg;
                        realign_lower_next = '0;
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        data_state_next = DATA_WAIT_TX_FIN;
                    end
                end
                else begin
                    data_state_next = DATA_OUTPUT_LAST;
                end
            end
            DATA_WAIT_TX_FIN: begin
                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    data_state_next = READY;
                end
                else begin
                    data_state_next = DATA_WAIT_TX_FIN;
                end 
            end
        endcase        
    end

    always_comb begin
        hdr_state_next = hdr_state_reg;
        eth_format_dst_hdr_val = 1'b0;
        eth_format_dst_eth_hdr = '0;
        case (hdr_state_reg)
            WAITING: begin
               if (output_hdr) begin
                   hdr_state_next = HDR_OUTPUT;
               end 
               else begin
                   hdr_state_next = WAITING;
               end
            end
            HDR_OUTPUT: begin
                eth_format_dst_hdr_val = 1'b1;
                eth_format_dst_eth_hdr = eth_hdr_struct_reg;
                if (dst_eth_format_hdr_rdy) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
                else begin
                    hdr_state_next = HDR_OUTPUT;
                end
            end
            HDR_WAIT_TX_FIN: begin
                if (data_state_reg == DATA_WAIT_TX_FIN) begin
                   hdr_state_next = WAITING; 
                end
                else begin
                   hdr_state_next = HDR_WAIT_TX_FIN; 
                end
            end
        endcase
    end
endmodule
