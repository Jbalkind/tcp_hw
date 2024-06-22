`include "packet_defs.vh"

module ip_to_mac (
     input clk
    ,input rst

    ,input  [`IP_ADDR_W-1:0]    ip_addr
    ,input                      ip_addr_val
    ,output                     ip_addr_rdy

    ,output [`MAC_ADDR_W-1:0]   mac_addr
    ,output                     mac_addr_val
    ,output                     mac_addr_hit
    ,input                      mac_addr_rdy   
);

    logic   [`MAC_ADDR_W-1:0]   mac_result;
    logic                       mac_hit;
    logic                       mac_val;

    assign ip_addr_rdy = mac_addr_rdy;
    assign mac_addr_val = ip_addr_val;
    assign mac_addr_hit = mac_hit;
    assign mac_addr = mac_result;

    always_comb begin
        case (ip_addr)
            // 198.0.0.1
            `IP_ADDR_W'hc6_00_00_01: begin
                mac_hit = 1'b1;
                mac_result = `MAC_ADDR_W'hb8_59_9f_b7_bd_6c;
            end
            // 198.0.0.3
            `IP_ADDR_W'hc6_00_00_03: begin
                mac_hit = 1'b1;
                mac_result = `MAC_ADDR_W'h00_0a_35_0e_14_d2;
            end
            // 198.0.0.5
            `IP_ADDR_W'hc6_00_00_05: begin
                mac_hit = 1'b1;
                mac_result = `MAC_ADDR_W'hb8_59_9f_b7_ba_44;
            end
            // 198.0.0.7
            `IP_ADDR_W'hc6_00_00_07: begin
                mac_hit = 1'b1;
                mac_result = `MAC_ADDR_W'h00_0a_35_0d_4d_c6;
            end
            // 198.0.0.9
            `IP_ADDR_W'hc6_00_00_09: begin
                mac_hit = 1'b1;
                mac_result = `MAC_ADDR_W'h00_0a_35_0d_4d_28;
            end
            // 198.0.0.11
            `IP_ADDR_W'hc6_00_00_0b: begin
                mac_hit = 1'b1;
                mac_result = `MAC_ADDR_W'hb8_59_9f_b7_ba_bc;
            end
            `IP_ADDR_W'hc6_00_00_0d: begin
                mac_hit = 1'b1; 
                mac_result = `MAC_ADDR_W'h98_03_9b_cc_10_cc;
            end
            default: begin
                mac_hit = 1'b0;
                mac_result = '0;
            end
        endcase
    end

endmodule
