`include "packet_defs.vh"
import packet_struct_pkg::*;

module eth_hdr_assembler (
     input clk
    ,input rst

    ,input                                  eth_hdr_req_val
    ,input  [`IP_ADDR_W-1:0]                source_ip_addr
    ,input  [`IP_ADDR_W-1:0]                dest_ip_addr
    ,output logic                           eth_hdr_req_rdy 

    ,output logic                           outbound_eth_hdr_val
    ,output logic                           outbound_eth_hdr_hit
    ,input                                  outbound_eth_hdr_rdy
    ,output eth_hdr                         outbound_eth_hdr
);

    logic                           dst_mac_addr_req_rdy;
    logic                           src_mac_addr_req_rdy;

    logic   [`MAC_ADDR_W-1:0]       dst_mac_addr;
    logic                           dst_mac_addr_val;
    logic                           dst_mac_addr_hit;

    logic   [`MAC_ADDR_W-1:0]       src_mac_addr;
    logic                           src_mac_addr_val;
    logic                           src_mac_addr_hit;

    eth_hdr                         outbound_hdr_struct;

    typedef enum logic {
        READY = 1'b0,
        OUTPUT = 1'b1,
        UND = 'X
    } state_e;



    state_e state_reg;
    state_e state_next;



    logic   [`IP_ADDR_W-1:0]    src_ip_addr_reg;
    logic   [`IP_ADDR_W-1:0]    src_ip_addr_next;
    logic   [`IP_ADDR_W-1:0]    dst_ip_addr_reg;
    logic   [`IP_ADDR_W-1:0]    dst_ip_addr_next;

    logic                       dst_mac_addr_req_val;
    logic   [`IP_ADDR_W-1:0]    dst_mac_addr_req_ip_addr;
    logic                       src_mac_addr_req_val;
    logic   [`IP_ADDR_W-1:0]    src_mac_addr_req_ip_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            src_ip_addr_reg <= '0;
            dst_ip_addr_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            src_ip_addr_reg <= src_ip_addr_next;
            dst_ip_addr_reg <= dst_ip_addr_next;
        end
    end

    always_comb begin
        eth_hdr_req_rdy = 1'b0;
        state_next = state_reg;
        src_mac_addr_req_val = 1'b0;
        src_mac_addr_req_ip_addr =  '0;
        dst_mac_addr_req_val = 1'b0;
        dst_mac_addr_req_ip_addr = '0;

        src_ip_addr_next = src_ip_addr_reg;
        dst_ip_addr_next = dst_ip_addr_reg;
        case (state_reg)
            READY: begin
                eth_hdr_req_rdy = 1'b1;

                if (eth_hdr_req_val) begin
                    src_ip_addr_next = source_ip_addr;
                    dst_ip_addr_next = dest_ip_addr;
                    state_next = OUTPUT;
                end
                else begin
                    state_next = READY;
                end
            end     
            OUTPUT: begin
                src_mac_addr_req_val = 1'b1;
                src_mac_addr_req_ip_addr = src_ip_addr_reg;
                dst_mac_addr_req_val = 1'b1;
                dst_mac_addr_req_ip_addr = dst_ip_addr_reg;

                if (outbound_eth_hdr_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = OUTPUT;
                end
            end
            default: begin
                eth_hdr_req_rdy = 1'bX;
                state_next = UND;
                src_mac_addr_req_val = 1'bX;
                src_mac_addr_req_ip_addr =  'X;
                dst_mac_addr_req_val = 1'bX;
                dst_mac_addr_req_ip_addr = 'X;
                src_ip_addr_next = 'X;
                dst_ip_addr_next = 'X;
            end
        endcase
    end

    assign outbound_eth_hdr_hit = dst_mac_addr_val & dst_mac_addr_hit 
                                & src_mac_addr_val & src_mac_addr_hit;
//    assign outbound_eth_hdr_hit = src_mac_addr_val & src_mac_addr_hit;

    assign outbound_eth_hdr_val = dst_mac_addr_val & src_mac_addr_val;
//    assign outbound_eth_hdr_val = src_mac_addr_val;

    assign outbound_eth_hdr = outbound_hdr_struct;

    assign outbound_hdr_struct.dst = dst_mac_addr;
//    assign outbound_hdr_struct.dst = `MAC_ADDR_W'h00_90_fb_60_e1_e7;
    assign outbound_hdr_struct.src = src_mac_addr;
    assign outbound_hdr_struct.eth_type = `ETH_TYPE_IPV4;

    ip_to_mac src_addr (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.ip_addr       (src_mac_addr_req_ip_addr   )
        ,.ip_addr_val   (src_mac_addr_req_val       )
        ,.ip_addr_rdy   (src_mac_addr_req_rdy       )

        ,.mac_addr      (src_mac_addr               )
        ,.mac_addr_val  (src_mac_addr_val           )
        ,.mac_addr_hit  (src_mac_addr_hit           )
        ,.mac_addr_rdy  (outbound_eth_hdr_rdy       )

    );

    ip_to_mac dst_addr (
         .clk   (clk)
        ,.rst   (rst)

        ,.ip_addr       (dst_mac_addr_req_ip_addr   )
        ,.ip_addr_val   (dst_mac_addr_req_val       )
        ,.ip_addr_rdy   (dst_mac_addr_req_rdy       )

        ,.mac_addr      (dst_mac_addr               )
        ,.mac_addr_val  (dst_mac_addr_val           )
        ,.mac_addr_hit  (dst_mac_addr_hit           )
        ,.mac_addr_rdy  (outbound_eth_hdr_rdy       )

    );

endmodule
