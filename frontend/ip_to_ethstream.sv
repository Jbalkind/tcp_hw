`include "packet_defs.vh"
`include "soc_defs.vh"
`include "noc_defs.vh"

module ip_to_ethstream 
import tracker_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    ,input                                  src_ip_to_ethstream_hdr_val
    ,input  ip_pkt_hdr                      src_ip_to_ethstream_ip_hdr
    ,input  tracker_stats_struct            src_ip_to_ethstream_timestamp
    ,output logic                           ip_to_ethstream_src_hdr_rdy

    ,input                                  src_ip_to_ethstream_data_val
    ,input          [`MAC_INTERFACE_W-1:0]  src_ip_to_ethstream_data
    ,input                                  src_ip_to_ethstream_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_ip_to_ethstream_data_padbytes
    ,output logic                           ip_to_ethstream_src_data_rdy

    ,output logic                           ip_to_ethstream_dst_hdr_val
    ,output logic   [ETH_HDR_W-1:0]         ip_to_ethstream_dst_eth_hdr
    ,output logic   [`TOT_LEN_W-1:0]        ip_to_ethstream_dst_data_len
    ,output tracker_stats_struct            ip_to_ethstream_dst_timestamp
    ,input                                  dst_ip_to_ethstream_hdr_rdy

    ,output logic                           ip_to_ethstream_dst_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]  ip_to_ethstream_dst_data
    ,output logic                           ip_to_ethstream_dst_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   ip_to_ethstream_dst_data_padbytes
    ,input                                  dst_ip_to_ethstream_data_rdy
);

    typedef enum logic [1:0] {
        READY = 2'd0,
        OUTPUT = 2'd1,
        OUTPUT_LAST = 2'd2,
        DATA_WAIT_TX_FIN = 2'd3,
        UND = 'X
    } data_state_e;

    typedef enum logic [1:0] {
        WAITING = 2'd0,
        ETH_HDR_WAIT = 2'd1,
        HDR_OUTPUT = 2'd2,
        HDR_WAIT_TX_FIN = 2'd3,
        UNDEF = 'X
    } hdr_state_e;
    
    localparam SAVE_BITS = IP_HDR_W;
    localparam SAVE_BYTES = SAVE_BITS/8;

    localparam USED_BITS = `MAC_INTERFACE_W - SAVE_BITS;
    localparam USED_BYTES = USED_BITS/8;
    
    localparam NOC_DATA_BYTES = `NOC_DATA_WIDTH/8;
    localparam NOC_DATA_BYTES_W = $clog2(NOC_DATA_BYTES);

    logic   [`MAC_PADBYTES_W-1:0]   input_padbytes_reg;
    logic   [`MAC_PADBYTES_W-1:0]   input_padbytes_next;

    logic   [SAVE_BITS-1:0]    save_reg;
    logic   [SAVE_BITS-1:0]    save_next; 

    logic   [`MAC_INTERFACE_W-1:0]    masked_data;
    logic   [`MAC_INTERFACE_W-1:0]    data_mask;
    
    logic                           eth_hdr_req_val;
    logic   [`IP_ADDR_W-1:0]        eth_hdr_req_src_ip;
    logic   [`IP_ADDR_W-1:0]        eth_hdr_req_dst_ip;
    logic                           eth_hdr_req_rdy;

    logic                           outbound_eth_hdr_val;
    logic                           outbound_eth_hdr_hit;
    logic                           outbound_eth_hdr_rdy;
    eth_hdr                         outbound_eth_hdr;

    eth_hdr                         outbound_eth_hdr_next;
    eth_hdr                         outbound_eth_hdr_reg;

    logic                           store_timestamp;
    tracker_stats_struct            pkt_timestamp_reg;
    tracker_stats_struct            pkt_timestamp_next;

    data_state_e data_state_reg;
    data_state_e data_state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;
   
    ip_pkt_hdr ip_hdr_struct_reg;
    ip_pkt_hdr ip_hdr_struct_next;
    ip_pkt_hdr ip_hdr_struct_cast;

    assign ip_hdr_struct_cast = src_ip_to_ethstream_ip_hdr;

    assign data_mask = src_ip_to_ethstream_data_last
                       ? {`MAC_INTERFACE_W{1'b1}} << (src_ip_to_ethstream_data_padbytes << 3)
                       : {`MAC_INTERFACE_W{1'b1}};

    assign masked_data = src_ip_to_ethstream_data & data_mask;

    assign ip_to_ethstream_dst_data_len = ip_hdr_struct_reg.tot_len;

    assign ip_to_ethstream_dst_timestamp = pkt_timestamp_reg;

    assign pkt_timestamp_next = store_timestamp
                                ? src_ip_to_ethstream_timestamp
                                : pkt_timestamp_reg;
 
    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            hdr_state_reg <= WAITING;
            outbound_eth_hdr_reg <= '0;
            save_reg <= '0;
            input_padbytes_reg <= '0;
            ip_hdr_struct_reg <= '0;
            pkt_timestamp_reg <= '0;
        end
        else begin
            data_state_reg <= data_state_next;
            hdr_state_reg <= hdr_state_next;
            outbound_eth_hdr_reg <= outbound_eth_hdr_next;
            input_padbytes_reg <= input_padbytes_next;
            save_reg <= save_next;
            ip_hdr_struct_reg <= ip_hdr_struct_next;
            pkt_timestamp_reg <= pkt_timestamp_next;
        end
    end

    always_comb begin
        ip_to_ethstream_src_hdr_rdy = 1'b0;
        ip_to_ethstream_src_data_rdy = 1'b0;

        ip_to_ethstream_dst_data_val = 1'b0;
        ip_to_ethstream_dst_data = '0;
        ip_to_ethstream_dst_data_last = 1'b0;
        ip_to_ethstream_dst_data_padbytes = '0;

        data_state_next = data_state_reg;
        save_next = save_reg;
        store_timestamp = 1'b0;
        ip_hdr_struct_next = ip_hdr_struct_reg;
        input_padbytes_next = input_padbytes_reg;
        case (data_state_reg)
            READY: begin
                ip_to_ethstream_src_hdr_rdy = eth_hdr_req_rdy;
                ip_to_ethstream_src_data_rdy = 1'b0;
                store_timestamp = 1'b1;

                if (src_ip_to_ethstream_hdr_val & eth_hdr_req_rdy) begin
                    ip_hdr_struct_next = ip_hdr_struct_cast;
                    save_next = ip_hdr_struct_cast;
                    // do we have payload to output? if not, go to last output
                    if (ip_hdr_struct_cast.tot_len == IP_HDR_BYTES) begin
                        input_padbytes_next = '0;
                        data_state_next = OUTPUT_LAST;
                    end
                    else begin
                        data_state_next = OUTPUT;
                    end
                end
                else begin
                    data_state_next = READY;
                end
            end
            OUTPUT: begin
                ip_to_ethstream_src_hdr_rdy = 1'b0;
                ip_to_ethstream_src_data_rdy = dst_ip_to_ethstream_data_rdy;
                ip_to_ethstream_dst_data_val = src_ip_to_ethstream_data_val;

                ip_to_ethstream_dst_data = {save_reg, masked_data[`MAC_INTERFACE_W-1 -: USED_BITS]};
                
                if (src_ip_to_ethstream_data_val & dst_ip_to_ethstream_data_rdy) begin
                    save_next = masked_data[SAVE_BITS-1:0];
                    
                    // if this is the last input line and we can fit all the bytes into the output
                    // dataline
                    if (src_ip_to_ethstream_data_last & 
                        (src_ip_to_ethstream_data_padbytes >= SAVE_BYTES)) begin
                        ip_to_ethstream_dst_data_last = 1'b1;
                        ip_to_ethstream_dst_data_padbytes = 
                            src_ip_to_ethstream_data_padbytes + USED_BYTES;
                        data_state_next = DATA_WAIT_TX_FIN;
                    end
                    // if this is just the last input line and we can't fit all the bytes into the
                    // output dataline
                    else if (src_ip_to_ethstream_data_last) begin
                        input_padbytes_next = src_ip_to_ethstream_data_padbytes;
                        data_state_next = OUTPUT_LAST;
                    end
                    // otherwise, this is boring
                    else begin
                        data_state_next = OUTPUT;
                    end
                end
                else begin
                    data_state_next = OUTPUT;
                end
            end
            OUTPUT_LAST: begin
                ip_to_ethstream_src_hdr_rdy = 1'b0;
                ip_to_ethstream_src_data_rdy = 1'b0;

                ip_to_ethstream_dst_data_val = 1'b1;
                ip_to_ethstream_dst_data = {save_reg, {USED_BITS{1'b0}}};
                ip_to_ethstream_dst_data_last = 1'b1;
                ip_to_ethstream_dst_data_padbytes = input_padbytes_reg + USED_BYTES;

                if (dst_ip_to_ethstream_data_rdy) begin
                    data_state_next = DATA_WAIT_TX_FIN;
                end
                else begin
                    data_state_next = OUTPUT_LAST;
                end
            end
            DATA_WAIT_TX_FIN: begin
                ip_to_ethstream_src_hdr_rdy = 1'b0;
                ip_to_ethstream_src_data_rdy = 1'b0;
                ip_to_ethstream_dst_data_val = 1'b0;
                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    data_state_next = READY;
                end
                else begin
                    data_state_next = DATA_WAIT_TX_FIN;
                end
            end
            default: begin
                store_timestamp = 'X;

                ip_to_ethstream_src_hdr_rdy = 1'bX;
                ip_to_ethstream_src_data_rdy = 1'bX;

                ip_to_ethstream_dst_data_val = 1'bX;
                ip_to_ethstream_dst_data = 'X;
                ip_to_ethstream_dst_data_last = 1'bX;
                ip_to_ethstream_dst_data_padbytes = 'X;

                data_state_next = UND;
                save_next = 'X;
                input_padbytes_next = 'X;
            end
        endcase
    end

    always_comb begin
        eth_hdr_req_val = 1'b0;
        eth_hdr_req_src_ip = '0;
        eth_hdr_req_dst_ip = '0;
        hdr_state_next = hdr_state_reg;
        outbound_eth_hdr_rdy = 1'b0;

        ip_to_ethstream_dst_hdr_val = 1'b0;
        ip_to_ethstream_dst_eth_hdr = outbound_eth_hdr;

        outbound_eth_hdr_next = outbound_eth_hdr_reg;
        case (hdr_state_reg)
            WAITING: begin
                if ((data_state_reg == READY) & src_ip_to_ethstream_hdr_val & eth_hdr_req_rdy) begin
                    eth_hdr_req_val = 1'b1;
                    eth_hdr_req_src_ip = ip_hdr_struct_cast.source_addr;
                    eth_hdr_req_dst_ip = ip_hdr_struct_cast.dest_addr;

                    hdr_state_next = ETH_HDR_WAIT;
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            ETH_HDR_WAIT: begin
                outbound_eth_hdr_rdy = 1'b1;
                ip_to_ethstream_dst_hdr_val = outbound_eth_hdr_val;
                ip_to_ethstream_dst_eth_hdr = outbound_eth_hdr;

                if (outbound_eth_hdr_val) begin
                    outbound_eth_hdr_next = outbound_eth_hdr;
                    if (dst_ip_to_ethstream_hdr_rdy) begin
                        hdr_state_next = HDR_WAIT_TX_FIN;
                    end
                    else begin
                        hdr_state_next = HDR_OUTPUT;
                    end
                end
                else begin
                    hdr_state_next = ETH_HDR_WAIT;
                end
            end
            HDR_OUTPUT: begin
                outbound_eth_hdr_rdy = 1'b0;
                ip_to_ethstream_dst_hdr_val = 1'b1;
                ip_to_ethstream_dst_eth_hdr = outbound_eth_hdr_reg;

                if (dst_ip_to_ethstream_hdr_rdy) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
                else begin
                    hdr_state_next = HDR_OUTPUT;
                end
            end
            HDR_WAIT_TX_FIN: begin
                ip_to_ethstream_dst_hdr_val = 1'b0;
                if (data_state_reg == DATA_WAIT_TX_FIN) begin
                    hdr_state_next = WAITING;
                end
                else begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
            end
            default: begin
                eth_hdr_req_val = 1'bX;
                eth_hdr_req_src_ip = 'X;
                eth_hdr_req_dst_ip = 'X;
                hdr_state_next = UNDEF;
                outbound_eth_hdr_rdy = 1'bX;

                ip_to_ethstream_dst_hdr_val = 1'bX;
                ip_to_ethstream_dst_eth_hdr = 'X;
            end
        endcase
    end

    eth_hdr_assembler eth_hdr_assembler (
         .clk   (clk)
        ,.rst   (rst)

        ,.eth_hdr_req_val       (eth_hdr_req_val        )
        ,.source_ip_addr        (eth_hdr_req_src_ip     )
        ,.dest_ip_addr          (eth_hdr_req_dst_ip     )
        ,.eth_hdr_req_rdy       (eth_hdr_req_rdy        )

        ,.outbound_eth_hdr_val  (outbound_eth_hdr_val   )
        ,.outbound_eth_hdr_hit  (outbound_eth_hdr_hit   )
        ,.outbound_eth_hdr_rdy  (outbound_eth_hdr_rdy   )
        ,.outbound_eth_hdr      (outbound_eth_hdr       )
    );

endmodule
