`include "packet_defs.vh"
`include "soc_defs.vh"
import packet_struct_pkg::*;

// CAUTION: we make the assumption that the checksum unit is always good to go 
// since the state machine is waiting for it to finish
module ip_stream_format #(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
)(
     input clk
    ,input rst
    
    // Data stream in from MAC
    ,input                                  src_ip_format_rx_val
    ,input          [`PKT_TIMESTAMP_W-1:0]  src_ip_format_rx_timestamp
    ,output logic                           ip_format_src_rx_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_ip_format_rx_data
    ,input                                  src_ip_format_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_ip_format_rx_padbytes

    // Header and data out
    ,output logic                           ip_format_dst_rx_hdr_val
    ,input                                  dst_ip_format_rx_hdr_rdy
    ,output ip_pkt_hdr                      ip_format_dst_rx_ip_hdr
    ,output logic   [`PKT_TIMESTAMP_W-1:0]  ip_format_dst_rx_timestamp

    ,output logic                           ip_format_dst_rx_data_val
    ,input                                  dst_ip_format_rx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  ip_format_dst_rx_data
    ,output logic                           ip_format_dst_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   ip_format_dst_rx_padbytes
);

    localparam CHKSUM_OFFSET = `MAC_INTERFACE_BYTES - 12;
    typedef enum logic[2:0] {
        READY = 3'd0,
        IP_HDR_DRAIN = 3'd1,
        CHKSUM_LAST = 3'd2,
        CHKSUM_WAIT_FIRST_DATA = 3'd3,
        DATA_OUTPUT = 3'd4,
        DATA_OUTPUT_LAST = 3'd5,
        DRAIN = 3'd6,
        DATA_WAIT_TX_FIN = 3'd7,
        UNDEF = 'X
    } data_state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        HDR_OUTPUT = 2'd1,
        HDR_WAIT_TX_FIN = 2'd2,
        UND = 'X
    } hdr_state_e;


    data_state_e data_state_reg;
    data_state_e data_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;

    ip_pkt_hdr ip_hdr_struct_reg;
    ip_pkt_hdr ip_hdr_struct_next;
    ip_pkt_hdr ip_hdr_cast;

    logic                           store_pkt_timestamp;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_reg;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_next;

    logic   [`TOT_LEN_W-1:0]        ip_hdr_bytes_left_reg;
    logic   [`TOT_LEN_W-1:0]        ip_hdr_bytes_left_next;

    logic   [`TOT_LEN_W-1:0]        payload_bytes_left_reg;
    logic   [`TOT_LEN_W-1:0]        payload_bytes_left_next;
    
    logic                           ip_chksum_cmd_val;
    logic                           ip_chksum_cmd_enable;
    logic   [7:0]                   ip_chksum_cmd_start;
    logic   [7:0]                   ip_chksum_cmd_offset;
    logic   [15:0]                  ip_chksum_cmd_init;
    logic                           ip_chksum_cmd_rdy;

    logic   [DATA_WIDTH-1:0]        ip_chksum_req_data;
    logic   [KEEP_WIDTH-1:0]        ip_chksum_req_keep;
    logic                           ip_chksum_req_val;
    logic                           ip_chksum_req_rdy;
    logic                           ip_chksum_req_last;

    logic                           ip_chksum_resp_rdy;
    logic                           ip_chksum_resp_val;
    logic   [`IP_CHKSUM_W-1:0]      ip_chksum_resp_result;

    logic   [`MAC_PADBYTES_W:0]   data_remainder;
    logic   [`MAC_PADBYTES_W:0]   data_padbytes;


    logic                           chksum_match;

    // because the 256 bits of data won't be aligned exactly, we have to grab data from the end
    // of one data line and the beginning of another
    logic   [`MAC_INTERFACE_W -1:0]  realign_upper_reg;
    logic   [`MAC_INTERFACE_W -1:0]  realign_upper_next;
    logic   [`MAC_INTERFACE_W -1:0]  realign_lower_reg;
    logic   [`MAC_INTERFACE_W -1:0]  realign_lower_next;

    logic   [(`MAC_INTERFACE_W * 2)-1:0]  realigned_data;
    logic   [`TOT_LEN_W-1:0]              realign_shift;
    logic   [`TOT_LEN_W-1:0]              padbytes_temp;
    
    logic                                 was_last_reg;
    logic                                 was_last_next;

    assign data_remainder = {1'b1, ip_hdr_struct_reg.tot_len[`MAC_PADBYTES_W-1:0]};
    assign data_padbytes = `MAC_INTERFACE_BYTES - data_remainder;

    assign realign_shift = (ip_hdr_bytes_left_reg << 3);
    assign realigned_data = {realign_upper_reg, realign_lower_reg} << realign_shift;
    
    assign padbytes_temp = ip_hdr_bytes_left_reg + data_padbytes[`MAC_PADBYTES_W-1:0];

    assign ip_hdr_cast = src_ip_format_rx_data[`MAC_INTERFACE_W-1 -: IP_HDR_W];

    assign ip_format_dst_rx_timestamp = pkt_timestamp_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            hdr_state_reg <= WAITING;
            ip_hdr_struct_reg <= '0;
            realign_upper_reg <= '0;
            realign_lower_reg <= '0;
            ip_hdr_bytes_left_reg <= '0;
            payload_bytes_left_reg <= '0;
            was_last_reg <= '0;
        end
        else begin
            data_state_reg <= data_state_next;
            hdr_state_reg <= hdr_state_next;
            ip_hdr_struct_reg <= ip_hdr_struct_next;
            realign_upper_reg <= realign_upper_next;
            realign_lower_reg <= realign_lower_next;
            ip_hdr_bytes_left_reg <= ip_hdr_bytes_left_next;
            payload_bytes_left_reg <= payload_bytes_left_next;
            was_last_reg <= was_last_next;
            pkt_timestamp_reg <= pkt_timestamp_next;
        end
    end

    // if a checksum is correct, then the checksum calculated with it in the field (instead of
    // zeroes) is all 1s, so the 1's complement (what the module outputs) is all 0s
    assign chksum_match = ip_chksum_resp_result == `IP_CHKSUM_W'd0;
    assign ip_chksum_req_data = realign_upper_reg;
                    
    assign ip_chksum_cmd_start = '0;
    assign ip_chksum_cmd_offset = CHKSUM_OFFSET[7:0];
    assign ip_chksum_cmd_init = '0;

    assign pkt_timestamp_next = store_pkt_timestamp
                                ? src_ip_format_rx_timestamp
                                : pkt_timestamp_reg;

    always_comb begin
        data_state_next = data_state_reg;
        ip_hdr_struct_next = ip_hdr_struct_reg;
        realign_upper_next = realign_upper_reg;
        realign_lower_next = realign_lower_reg;
        ip_format_src_rx_rdy = 1'b0;
        ip_hdr_bytes_left_next = ip_hdr_bytes_left_reg;
        ip_format_dst_rx_data_val = 1'b0;
        ip_format_dst_rx_data = '0;
        ip_format_dst_rx_last = 1'b0;
        ip_format_dst_rx_padbytes = '0;

        payload_bytes_left_next = payload_bytes_left_reg;
        
        ip_chksum_cmd_val = 1'b0;
        ip_chksum_cmd_enable = 1'b0;
        ip_chksum_req_val = 1'b0;
        ip_chksum_req_last = 1'b0;
        ip_chksum_req_keep = '0;
        ip_chksum_resp_rdy = 1'b0;

        store_pkt_timestamp = 1'b0;

        was_last_next = was_last_reg;
        case (data_state_reg)
            READY: begin
                ip_format_src_rx_rdy = ip_chksum_cmd_rdy;
                store_pkt_timestamp = 1'b1;
                
                if (src_ip_format_rx_val & ip_chksum_cmd_rdy) begin
                    ip_hdr_struct_next = ip_hdr_cast;
                    payload_bytes_left_next = ip_hdr_cast.tot_len - (ip_hdr_cast.ip_hdr_len << 2);
                    ip_hdr_bytes_left_next = ip_hdr_cast.ip_hdr_len << 2;

                    ip_chksum_cmd_val = 1'b1;
                    ip_chksum_cmd_enable = 1'b1;
                    realign_upper_next = src_ip_format_rx_data;
                    was_last_next = src_ip_format_rx_last;

                    // if the ip header doesn't end in the first line
                    if (ip_hdr_cast.ip_hdr_len > ((`MAC_INTERFACE_W/8)/4)) begin
                        data_state_next = IP_HDR_DRAIN;
                    end
                    else begin
                        data_state_next = CHKSUM_LAST;
                    end
                end
                else begin
                    data_state_next = READY;
                end
            end
            IP_HDR_DRAIN: begin
                ip_format_src_rx_rdy = ip_chksum_req_rdy;

                // since the IP hdr can be at most 60 bytes, the end must be in the second 
                // line of data
                if (src_ip_format_rx_val & ip_chksum_req_rdy) begin
                    was_last_next = src_ip_format_rx_last;
                    // checksum the first part of the IP header
                    ip_chksum_req_val = 1'b1;
                    ip_chksum_req_last = 1'b0;
                    ip_chksum_req_keep = '1;

                    ip_hdr_bytes_left_next = ip_hdr_bytes_left_reg - (`MAC_INTERFACE_W/8); 
                    realign_upper_next = src_ip_format_rx_data;
                    data_state_next = CHKSUM_LAST;
                end
                else begin
                    data_state_next = IP_HDR_DRAIN;
                end
            end
            CHKSUM_LAST: begin
                ip_format_src_rx_rdy = 1'b0;
                ip_chksum_req_val = 1'b1;
                ip_chksum_req_last = 1'b1;
                ip_chksum_req_keep = {KEEP_WIDTH{1'b1}} << (KEEP_WIDTH - ip_hdr_bytes_left_reg);

                if (ip_chksum_req_rdy) begin
                    data_state_next = CHKSUM_WAIT_FIRST_DATA;
                end
                else begin
                    data_state_next = CHKSUM_LAST;
                end
            end
            // wait for checksum before going to output
            CHKSUM_WAIT_FIRST_DATA: begin
                ip_chksum_resp_rdy = 1'b1;

                // if we already took in the last input line, just wait for the checksum
                if (was_last_reg) begin
                    if (ip_chksum_resp_val) begin
                        if (chksum_match) begin
                            data_state_next = DATA_OUTPUT_LAST;
                        end
                        else begin
                            data_state_next = DATA_WAIT_TX_FIN;
                        end
                    end
                    else begin
                        data_state_next = CHKSUM_WAIT_FIRST_DATA;
                    end
                end
                // otherwise, also wait for the first data line
                else begin
                    ip_format_src_rx_rdy = 1'b1;
                    if (src_ip_format_rx_val & ip_chksum_resp_val) begin
                        was_last_next = src_ip_format_rx_last;
                        realign_lower_next = src_ip_format_rx_data;
                        // check the checksum
                        // if the checksum is correct, continue on to the data output stages
                        if (chksum_match) begin
                            if (src_ip_format_rx_last) begin
                                data_state_next = DATA_OUTPUT_LAST;
                            end
                            else begin
                                data_state_next = DATA_OUTPUT;
                            end
                        end
                        // otherwise, go to a drain stage unless we're on the last line
                        // in that case, just go to the wait stage to check in
                        else begin
                            if (src_ip_format_rx_last) begin
                                data_state_next = DATA_WAIT_TX_FIN;
                            end
                            else begin
                                data_state_next = DRAIN;
                            end
                        end
                    end
                    else begin
                        ip_format_src_rx_rdy = 1'b0;
                        data_state_next = CHKSUM_WAIT_FIRST_DATA;
                    end
                end
            end
            DATA_OUTPUT: begin
                ip_format_src_rx_rdy = dst_ip_format_rx_data_rdy;
                // output from the realign reg shifted for correct alignment
                ip_format_dst_rx_data = 
                    realigned_data[(`MAC_INTERFACE_W*2)-1 -: `MAC_INTERFACE_W];
                ip_format_dst_rx_data_val = src_ip_format_rx_val;


                if (dst_ip_format_rx_data_rdy & src_ip_format_rx_val) begin
                    was_last_next = src_ip_format_rx_last;
                    payload_bytes_left_next = payload_bytes_left_reg - (`MAC_INTERFACE_W >> 3);
                    // move the lower bytes into the upper and the new data into the lower bytes
                    realign_upper_next = realign_lower_reg;
                    realign_lower_next = src_ip_format_rx_data;
                    if (src_ip_format_rx_last) begin
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        
                        data_state_next = DATA_OUTPUT;
                    end
                end
                else begin
                    data_state_next = DATA_OUTPUT;
                end
            end
            DATA_OUTPUT_LAST: begin
                ip_format_src_rx_rdy = 1'b0;


                ip_format_dst_rx_last = payload_bytes_left_reg <= (`MAC_INTERFACE_W >> 3);
                ip_format_dst_rx_padbytes = padbytes_temp[`MAC_PADBYTES_W-1:0];
                ip_format_dst_rx_data_val = 1'b1;
                ip_format_dst_rx_data = 
                    realigned_data[(`MAC_INTERFACE_W*2)-1 -: `MAC_INTERFACE_W];

                if (dst_ip_format_rx_data_rdy) begin
                    // if the number of bytes left is greater than the bus width, we have to go
                    // around again
                    if (payload_bytes_left_reg > (`MAC_INTERFACE_W >> 3)) begin
                        realign_upper_next = realign_lower_reg;
                        realign_lower_next = '0;

                        payload_bytes_left_next = payload_bytes_left_reg - (`MAC_INTERFACE_W >> 3);
                        data_state_next = DATA_OUTPUT_LAST;
                    end
                    else begin
                        payload_bytes_left_next = '0;
                        data_state_next = DATA_WAIT_TX_FIN;
                    end
                end
                else begin
                    data_state_next = DATA_OUTPUT_LAST;
                end
            end
            DRAIN: begin
                ip_format_src_rx_rdy = 1'b0;

                if (src_ip_format_rx_val) begin
                    if (src_ip_format_rx_last) begin
                        data_state_next = DATA_WAIT_TX_FIN;
                    end
                    else begin
                        data_state_next = DRAIN;
                    end
                end
                else begin
                    data_state_next = DRAIN;
                end
            end
            DATA_WAIT_TX_FIN: begin
                ip_format_src_rx_rdy = 1'b0;
                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    data_state_next = READY; 
                end
                else begin
                    data_state_next = DATA_WAIT_TX_FIN;
                end
            end
            default: begin
                data_state_next = UNDEF;
                ip_hdr_struct_next = 'X;
                realign_upper_next = 'X;
                realign_lower_next = 'X;
                ip_format_src_rx_rdy = 'X;
                ip_hdr_bytes_left_next = 'X;
                ip_format_dst_rx_data_val = 'X;
                ip_format_dst_rx_data = 'X;
                ip_format_dst_rx_last = 'X;
                ip_format_dst_rx_padbytes = 'X;

                store_pkt_timestamp = 'X;
            end
        endcase
    end

    always_comb begin
        hdr_state_next = hdr_state_reg;
        ip_format_dst_rx_hdr_val = 1'b0;
        ip_format_dst_rx_ip_hdr = '0;

        case (hdr_state_reg)
            WAITING: begin
                if (data_state_reg == CHKSUM_WAIT_FIRST_DATA) begin
                    if (ip_chksum_resp_val)
                        if (chksum_match) begin
                            hdr_state_next = HDR_OUTPUT;
                        end
                        else begin
                            hdr_state_next = HDR_WAIT_TX_FIN;
                        end
                    else begin
                        hdr_state_next = WAITING;
                    end
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            HDR_OUTPUT: begin
                ip_format_dst_rx_hdr_val = 1'b1;
                ip_format_dst_rx_ip_hdr = ip_hdr_struct_reg;
                if (dst_ip_format_rx_hdr_rdy) begin
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
            default: begin
                hdr_state_next = UND;
                ip_format_dst_rx_hdr_val = 'X;
                ip_format_dst_rx_ip_hdr = 'X;
            end
        endcase
    end
    
    ip_rx_chksum_calc_wrap #(
         .DATA_WIDTH    (DATA_WIDTH)
        ,.KEEP_WIDTH    (KEEP_WIDTH)
    ) rx_ip_chksum (
         .clk                   (clk)
        ,.rst                   (rst)

        ,.ip_chksum_cmd_val     (ip_chksum_cmd_val    )
        ,.ip_chksum_cmd_enable  (ip_chksum_cmd_enable )
        ,.ip_chksum_cmd_start   (ip_chksum_cmd_start  )
        ,.ip_chksum_cmd_offset  (ip_chksum_cmd_offset )
        ,.ip_chksum_cmd_init    (ip_chksum_cmd_init   )
        ,.ip_chksum_cmd_rdy     (ip_chksum_cmd_rdy    )
                                                      
        ,.ip_chksum_req_data    (ip_chksum_req_data   )
        ,.ip_chksum_req_keep    (ip_chksum_req_keep   )
        ,.ip_chksum_req_val     (ip_chksum_req_val    )
        ,.ip_chksum_req_rdy     (ip_chksum_req_rdy    )
        ,.ip_chksum_req_last    (ip_chksum_req_last   )
                                                      
        ,.ip_chksum_resp_rdy    (ip_chksum_resp_rdy   )
        ,.ip_chksum_resp_val    (ip_chksum_resp_val   )
        ,.ip_chksum_resp_result (ip_chksum_resp_result)
    
    );

endmodule
