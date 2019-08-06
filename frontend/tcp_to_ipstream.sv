`include "packet_defs.vh"
`include "state_defs.vh"
`include "soc_defs.vh"
`include "noc_defs.vh"
module tcp_to_ipstream (
     input clk
    ,input rst
    
    ,input                                  src_tcp_to_ipstream_hdr_val
    ,input          [`IP_ADDR_W-1:0]        src_tcp_to_ipstream_src_ip_addr
    ,input          [`IP_ADDR_W-1:0]        src_tcp_to_ipstream_dst_ip_addr
    ,input          [`TOT_LEN_W-1:0]        src_tcp_to_ipstream_tcp_len
    ,input          [`TCP_HDR_W-1:0]        src_tcp_to_ipstream_tcp_hdr
    ,output logic                           tcp_to_ipstream_src_hdr_rdy
    
    ,input                                  src_tcp_to_ipstream_data_val
    ,output logic                           tcp_to_ipstream_src_data_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_tcp_to_ipstream_data
    ,input                                  src_tcp_to_ipstream_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_tcp_to_ipstream_data_padbytes

    ,output logic                           tcp_to_ipstream_dst_hdr_val
    ,output logic   [`IP_HDR_W-1:0]         tcp_to_ipstream_dst_ip_hdr
    ,input                                  dst_tcp_to_ipstream_hdr_rdy
    
    // Stream output
    ,output logic                           tcp_to_ipstream_dst_val
    ,input                                  dst_tcp_to_ipstream_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  tcp_to_ipstream_dst_data
    ,output logic                           tcp_to_ipstream_dst_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   tcp_to_ipstream_dst_padbytes
);
    typedef enum logic[1:0] {
        READY = 2'd0,
        OUTPUT = 2'd1,
        OUTPUT_LAST = 2'd2,
        DATA_WAIT_TX_FIN = 2'd3,
        UND = 'X
    } data_state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        IP_HDR_WAIT = 2'd1,
        HDR_OUTPUT = 2'd2,
        HDR_WAIT_TX_FIN = 2'd3,
        UNDEF = 'X
    } hdr_state_e;

    localparam SAVE_BITS = `TCP_HDR_W;
    localparam SAVE_BYTES = SAVE_BITS/8;

    localparam USED_BITS = `MAC_INTERFACE_W - SAVE_BITS;
    localparam USED_BYTES = USED_BITS/8;
    
    localparam NOC_DATA_BYTES = `NOC_DATA_WIDTH/8;
    localparam NOC_DATA_BYTES_W = $clog2(NOC_DATA_BYTES);

    data_state_e data_state_reg;
    data_state_e data_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;
    
    ip_pkt_hdr resp_ip_hdr_struct_reg;
    ip_pkt_hdr resp_ip_hdr_struct_next;

    tcp_pkt_hdr tcp_hdr_struct_reg;
    tcp_pkt_hdr tcp_hdr_struct_next;
    tcp_pkt_hdr tcp_hdr_cast;
    
    logic                           ip_hdr_req_val;
    logic   [`IP_ADDR_W-1:0]        source_ip_addr;
    logic   [`IP_ADDR_W-1:0]        dest_ip_addr;
    logic   [`TOT_LEN_W-1:0]        data_payload_len;
    logic                           ip_hdr_req_rdy; 

    logic                           outbound_ip_hdr_val;
    logic                           outbound_ip_hdr_rdy;
    ip_pkt_hdr                      outbound_ip_hdr;
    
    logic   [`MAC_PADBYTES_W-1:0]   input_padbytes_reg;
    logic   [`MAC_PADBYTES_W-1:0]   input_padbytes_next;
    // we need the top bit temporarily
    logic   [`MAC_PADBYTES_W:0]     output_padbytes_temp;
    logic   [`MAC_PADBYTES_W-1:0]   output_padbytes;

    logic   [SAVE_BITS-1:0]         save_reg;
    logic   [SAVE_BITS-1:0]         save_next;

    logic                           is_start_reg;
    logic                           is_start_next;

    logic   [`MAC_INTERFACE_W-1:0]  masked_data;
    logic   [`MAC_INTERFACE_W-1:0]  data_mask;

    logic   [`TOT_LEN_W-1:0]        payload_bytes;
    logic   [`TOT_LEN_W-1:0]        payload_bytes_to_send_reg;
    logic   [`TOT_LEN_W-1:0]        payload_bytes_to_send_next;
    logic   [`TOT_LEN_W-1:0]        payload_bytes_to_recv_reg;
    logic   [`TOT_LEN_W-1:0]        payload_bytes_to_recv_next;

    logic   [`MAC_PADBYTES_W-1:0]   payload_bytes_mod_macbytes;

    logic                           tcp_hdr_saved_reg;
    logic                           tcp_hdr_saved_next;

    assign data_mask = {`MAC_INTERFACE_W{1'b1}} << tcp_to_ipstream_dst_padbytes;
    assign tcp_hdr_cast = src_tcp_to_ipstream_tcp_hdr;

    assign payload_bytes = src_tcp_to_ipstream_tcp_len - (tcp_hdr_cast.raw_data_offset << 2);

    assign payload_bytes_mod_macbytes = payload_bytes[`MAC_PADBYTES_W-1:0];

    assign output_padbytes_temp = USED_BYTES + input_padbytes_reg;
    assign output_padbytes = output_padbytes_temp[`MAC_PADBYTES_W-1:0];

    assign tcp_to_ipstream_dst_data = masked_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            hdr_state_reg <= WAITING;
            resp_ip_hdr_struct_reg <= '0;
            tcp_hdr_struct_reg <= '0;
            input_padbytes_reg <= '0;
            save_reg <= '0;
            payload_bytes_to_send_reg <= '0;
            payload_bytes_to_recv_reg <= '0;
            tcp_hdr_saved_reg <= '0;
        end
        else begin
            data_state_reg <= data_state_next;
            hdr_state_reg <= hdr_state_next;
            resp_ip_hdr_struct_reg <= resp_ip_hdr_struct_next;
            tcp_hdr_struct_reg <= tcp_hdr_struct_next;
            input_padbytes_reg <= input_padbytes_next;
            save_reg <= save_next;
            payload_bytes_to_send_reg <= payload_bytes_to_send_next;
            payload_bytes_to_recv_reg <= payload_bytes_to_recv_next;
            tcp_hdr_saved_reg <= tcp_hdr_saved_next;
        end
    end

    always_comb begin
        tcp_to_ipstream_src_hdr_rdy = 1'b0;
        tcp_to_ipstream_src_data_rdy = 1'b0;
        data_state_next = data_state_reg;

        tcp_to_ipstream_dst_val = 1'b0;
        tcp_to_ipstream_dst_last = 1'b0;
        tcp_to_ipstream_dst_padbytes = '0;
        masked_data = '0;

        tcp_hdr_struct_next = tcp_hdr_struct_reg;

        input_padbytes_next = input_padbytes_reg;

        payload_bytes_to_send_next = payload_bytes_to_send_reg;
        payload_bytes_to_recv_next = payload_bytes_to_recv_reg;

        save_next = save_reg;
        tcp_hdr_saved_next = tcp_hdr_saved_reg;
        case (data_state_reg)
            READY: begin
                tcp_to_ipstream_src_hdr_rdy = ip_hdr_req_rdy;
                tcp_to_ipstream_src_data_rdy = 1'b0;
                if (src_tcp_to_ipstream_hdr_val) begin
                    tcp_hdr_struct_next = tcp_hdr_cast;

                    payload_bytes_to_send_next = payload_bytes;
                    payload_bytes_to_recv_next = payload_bytes;
                        
                    save_next = tcp_hdr_cast;
                    tcp_hdr_saved_next = 1'b1;

                    // is there payload to send? if not, go to last output state
                    if (src_tcp_to_ipstream_tcp_len == `TCP_HDR_BYTES) begin
                        data_state_next = OUTPUT_LAST;
                        input_padbytes_next = '0;
                    end
                    else begin
                        input_padbytes_next = (`MAC_INTERFACE_W/8) - payload_bytes_mod_macbytes;
                        data_state_next = OUTPUT;
                    end
                end
                else begin
                    data_state_next = READY;
                end
            end
            OUTPUT: begin
                tcp_to_ipstream_src_hdr_rdy = 1'b0;

                masked_data = {save_reg, 
                               src_tcp_to_ipstream_data[`MAC_INTERFACE_W-1 -: USED_BITS]} & data_mask;

                tcp_to_ipstream_dst_val = src_tcp_to_ipstream_data_val;
                tcp_to_ipstream_src_data_rdy = dst_tcp_to_ipstream_rdy;

                // if we're supposed to receive the last bytes this cycle
                if (payload_bytes_to_recv_reg <= `MAC_INTERFACE_W/8) begin
                    // if we can actually receive it
                    if (dst_tcp_to_ipstream_rdy & src_tcp_to_ipstream_data_val) begin
                        tcp_hdr_saved_next = 1'b0;
                        payload_bytes_to_recv_next = '0;
                        save_next = src_tcp_to_ipstream_data[SAVE_BITS-1:0];

                        // check if we're partially sending the TCP header
                        if (tcp_hdr_saved_reg) begin
                            // check if we're sending the remaining data this cycle
                            if (payload_bytes_to_send_reg <= USED_BYTES) begin
                                payload_bytes_to_send_next = '0;
                                tcp_to_ipstream_dst_last = 1'b1;
                                tcp_to_ipstream_dst_padbytes = output_padbytes;
                                data_state_next = DATA_WAIT_TX_FIN;
                            end
                            else begin
                                payload_bytes_to_send_next = payload_bytes_to_send_reg - USED_BYTES;
                                data_state_next = OUTPUT_LAST;
                            end
                        end
                        else begin
                            // check if we're sending the remaining data this cycle
                            if (payload_bytes_to_send_reg <= `MAC_INTERFACE_W/8) begin
                                payload_bytes_to_send_next = '0;
                                tcp_to_ipstream_dst_last = 1'b1;
                                tcp_to_ipstream_dst_padbytes = output_padbytes;
                                data_state_next = DATA_WAIT_TX_FIN;
                            end
                            else begin
                                payload_bytes_to_send_next = payload_bytes_to_send_reg 
                                                             - `MAC_INTERFACE_W/8;
                                data_state_next = OUTPUT_LAST;
                            end
                        end
                    end
                    else begin
                        data_state_next = OUTPUT;
                    end
                end
                // otherwise, we have more data to receive
                else begin
                    // if we can actually receive the data
                    if (dst_tcp_to_ipstream_rdy & src_tcp_to_ipstream_data_val) begin
                        tcp_hdr_saved_next = 1'b0;
                        save_next = src_tcp_to_ipstream_data[SAVE_BITS-1:0];
                        payload_bytes_to_send_next = tcp_hdr_saved_reg
                                                    ? payload_bytes_to_send_reg - USED_BYTES
                                                    : payload_bytes_to_send_reg - `MAC_INTERFACE_W/8;
                        payload_bytes_to_recv_next = payload_bytes_to_recv_reg - `MAC_INTERFACE_W/8;
                    end
                    else begin
                        data_state_next = OUTPUT;
                    end
                end
            end
            OUTPUT_LAST: begin
                tcp_to_ipstream_src_hdr_rdy = 1'b0;
                tcp_to_ipstream_src_data_rdy = 1'b0;

                tcp_to_ipstream_dst_val = 1'b1;
                tcp_to_ipstream_dst_last = 1'b1;
                tcp_to_ipstream_dst_padbytes = output_padbytes;

                masked_data = {save_reg, {USED_BITS{1'b0}}} & data_mask;

                if (dst_tcp_to_ipstream_rdy) begin
                    data_state_next = DATA_WAIT_TX_FIN;
                end
                else begin
                    data_state_next = OUTPUT_LAST;
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
            default: begin
                tcp_to_ipstream_src_hdr_rdy = 1'bX;
                tcp_to_ipstream_src_data_rdy = 'X;
                data_state_next = UND;

                tcp_to_ipstream_dst_last = 1'bX;
                tcp_to_ipstream_dst_padbytes = 'X;

                tcp_hdr_struct_next = 'X;

                input_padbytes_next = 'X;

                payload_bytes_to_send_next = 'X;
                payload_bytes_to_recv_next = 'X;

                save_next = 'X;
                tcp_hdr_saved_next = 'X;
            end
        endcase
    end

    always_comb begin
        hdr_state_next = hdr_state_reg;

        tcp_to_ipstream_dst_hdr_val = 1'b0;
        tcp_to_ipstream_dst_ip_hdr = '0;

        ip_hdr_req_val = 1'b0;
        source_ip_addr = '0;
        dest_ip_addr = '0;
        data_payload_len = '0;
        resp_ip_hdr_struct_next = '0;
        outbound_ip_hdr_rdy = 1'b0;

        case (hdr_state_reg)
            WAITING: begin
                if ((data_state_reg == READY) & src_tcp_to_ipstream_hdr_val & ip_hdr_req_rdy) begin
                    ip_hdr_req_val = 1'b1;
                    source_ip_addr = src_tcp_to_ipstream_src_ip_addr;
                    dest_ip_addr = src_tcp_to_ipstream_dst_ip_addr;
                    data_payload_len = src_tcp_to_ipstream_tcp_len;
                    hdr_state_next = IP_HDR_WAIT;
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            IP_HDR_WAIT: begin
                outbound_ip_hdr_rdy = 1'b1;
                tcp_to_ipstream_dst_hdr_val = outbound_ip_hdr_val;
                tcp_to_ipstream_dst_ip_hdr = outbound_ip_hdr;

                if (outbound_ip_hdr_val) begin
                    if (dst_tcp_to_ipstream_hdr_rdy) begin
                        hdr_state_next = HDR_WAIT_TX_FIN;
                    end
                    else begin
                        resp_ip_hdr_struct_next = outbound_ip_hdr_val;
                        hdr_state_next = HDR_OUTPUT;
                    end
                end
                else begin
                    hdr_state_next = IP_HDR_WAIT;
                end
            end
            HDR_OUTPUT: begin
                outbound_ip_hdr_rdy = 1'b0;
                tcp_to_ipstream_dst_hdr_val = 1'b1;
                tcp_to_ipstream_dst_ip_hdr = resp_ip_hdr_struct_reg;

                if (dst_tcp_to_ipstream_hdr_rdy) begin
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
                hdr_state_next = UNDEF;

                tcp_to_ipstream_dst_hdr_val = 1'bX;
                tcp_to_ipstream_dst_ip_hdr = 'X;

                ip_hdr_req_val = 1'bX;
                source_ip_addr = 'X;
                dest_ip_addr = 'X;
                resp_ip_hdr_struct_next = 'X;
                outbound_ip_hdr_rdy = 1'bX;
            end
        endcase
    end


    ip_header_assembler ip_assembler(
         .clk(clk)
        ,.rst(rst)

        ,.ip_hdr_req_val        (ip_hdr_req_val         )
        ,.source_ip_addr        (source_ip_addr         )
        ,.dest_ip_addr          (dest_ip_addr           )
        ,.data_payload_len      (data_payload_len       )
        ,.protocol              (`IPPROTO_TCP           )
        ,.ip_hdr_req_rdy        (ip_hdr_req_rdy         )
        
        ,.outbound_ip_hdr_val   (outbound_ip_hdr_val    )
        ,.outbound_ip_hdr_rdy   (outbound_ip_hdr_rdy    )
        ,.outbound_ip_hdr       (outbound_ip_hdr        )
    );
endmodule
