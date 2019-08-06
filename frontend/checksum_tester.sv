`include "packet_defs.vh"
module checksum_tester #(
     // Width of AXI stream interfaces in bits
     parameter DATA_WIDTH = 64
     // AXI stream tkeep signal width (words per cycle)
    ,parameter KEEP_WIDTH = (DATA_WIDTH/8)

)(
     input clk
    ,input rst
    
    ,output logic                       req_axis_cmd_csum_enable
    ,output logic   [7:0]               req_axis_cmd_csum_start
    ,output logic   [7:0]               req_axis_cmd_csum_offset
    ,output logic   [15:0]              req_axis_cmd_csum_init
    ,output logic                       req_axis_cmd_valid
    ,input                              req_axis_cmd_ready
    
    ,output logic   [DATA_WIDTH-1:0]    req_axis_tdata
    ,output logic   [KEEP_WIDTH-1:0]    req_axis_tkeep
    ,output logic                       req_axis_tvalid
    ,input                              req_axis_tready
    ,output logic                       req_axis_tlast

    ,input          [DATA_WIDTH-1:0]    resp_axis_tdata
    ,input          [KEEP_WIDTH-1:0]    resp_axis_tkeep
    ,input                              resp_axis_tvalid
    ,output                             resp_axis_tready
    ,input                              resp_axis_tlast

);

    typedef enum {
        READY,
        PSEUDO_HEADER_1,
        PSEUDO_HEADER_2_TCP_HEADER_1,
        TCP_HEADER_2,
        TCP_HEADER_3,
        PAYLOAD,
        FINISH
    } states;

    states state_reg;
    states state_next;

    tcp_packet_header header;
    chksum_pseudo_header pseudo_header;

    logic [127:0] payload;
    logic   [`IP_ADDR_WIDTH-1:0]    source_addr;
    logic   [`IP_ADDR_WIDTH-1:0]    dest_addr;
    logic   [`TOT_LEN_WIDTH-1:0]    tot_len;
    logic   [`TOT_LEN_WIDTH-1:0]    tot_len_flipped;

    logic   [1:0]                   payload_rounds;
    logic   [1:0]                   payloads_summed_reg;
    logic   [1:0]                   payloads_summed_next;

    //assign source_addr = 32'h01_00_00_c0;
    //assign dest_addr = 32'h02_00_00_c0;
    assign source_addr = 32'hc0_00_00_01;
    assign dest_addr = 32'hc0_00_00_02;

    assign tot_len = `TOT_LEN_WIDTH'd20 + `TOT_LEN_WIDTH'd16;
    assign tot_len_flipped = {tot_len[7:0], tot_len[15:8]};

    assign pseudo_header.source_addr = source_addr;
    assign pseudo_header.dest_addr = dest_addr;
//    assign pseudo_header.tcp_length = tot_len_flipped;
    assign pseudo_header.tcp_length = tot_len;
    assign pseudo_header.protocol = `PROTOCOL_WIDTH'd`IPPROTO_TCP;
    assign pseudo_header.zeros = '0;

    assign resp_axis_tready = 1'b1;

    //assign header.src_port = 16'hd2_04;
    assign header.src_port = 16'h04_d2;
    //assign header.dst_port = 16'hd3_04;
    assign header.dst_port = 16'h04_d3;


    //assign header.seq_num = 32'h01_00_00_00;
    //assign header.ack_num = 32'h20_12_88_70;
    assign header.seq_num = 32'h00_00_00_01;
    assign header.ack_num = 32'h70_88_12_20;
    assign header.raw_data_offset = `DATA_OFFSET_WIDTH'd5;
    assign header.reserved = '0;
    assign header.flags = `TCP_ACK | `TCP_PSH;
    //assign header.win_size = 16'hd0_16;
    assign header.win_size = 16'h16_d0;
    assign header.chksum = '0;
    assign header.urg_pointer = '0;
    assign header.flowid = '0;

    assign payload = 128'h61_62_63_64_65_66_67_68_69_6a_6b_6c_6d_6e_6f_70;
    assign payload_rounds = 2'd2;
    
    assign req_axis_cmd_csum_init = '0;
    assign req_axis_cmd_csum_start = '0;

    always @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            payloads_summed_reg = '0;
        end
        else begin
            state_reg <= state_next;
            payloads_summed_reg <= payloads_summed_next;
        end
    end

    always @(*) begin
        state_next = state_reg;
        req_axis_cmd_csum_enable = 1'b0;
        req_axis_cmd_valid = 1'b0;
        req_axis_cmd_csum_offset = '0;
        
        req_axis_tvalid = 1'b0;
        req_axis_tdata = '0;
        req_axis_tkeep = '0;
        req_axis_tlast = 1'b0;

        payloads_summed_next = payloads_summed_reg;

        case (state_reg)
            READY: begin
                req_axis_cmd_valid = 1'b1;
                req_axis_cmd_csum_enable = 1'b1;
                req_axis_cmd_csum_offset = 7'd26;
                if (req_axis_cmd_ready) begin
                    state_next = PSEUDO_HEADER_1;
                end
                else begin
                    state_next = READY;
                end
            end
            PSEUDO_HEADER_1: begin
                req_axis_tvalid = 1'b1;
                req_axis_tdata = pseudo_header[`CHKSUM_PSEUDO_HEADER_WIDTH-1 -: 64];
                req_axis_tkeep = '1;

                if (req_axis_tready) begin
                    state_next = PSEUDO_HEADER_2_TCP_HEADER_1;
                end
                else begin
                    state_next = PSEUDO_HEADER_1;
                end
            end
            PSEUDO_HEADER_2_TCP_HEADER_1: begin
                req_axis_tvalid = 1'b1;
                req_axis_tdata = {pseudo_header[`CHKSUM_PSEUDO_HEADER_WIDTH - 1 - 64 -: 32],
                                  header[`TCP_HEADER_WIDTH-1 -: 32]};
                req_axis_tkeep = '1;

                if (req_axis_tready) begin
                    state_next = TCP_HEADER_2;
                end
                else begin
                    state_next = PSEUDO_HEADER_2_TCP_HEADER_1;
                end
            end
            TCP_HEADER_2: begin
                req_axis_tvalid = 1'b1;
                req_axis_tdata = {header[`TCP_HEADER_WIDTH - 1 - 32 -: 64]};
                req_axis_tkeep = '1;

                if (req_axis_tready) begin
                    state_next = TCP_HEADER_3;
                end
                else begin
                    state_next = TCP_HEADER_2;
                end
            end
            TCP_HEADER_3: begin
                req_axis_tvalid = 1'b1;
                req_axis_tdata = {header[`TCP_HEADER_WIDTH - 1 - 32 - 64 -: 64]};
                req_axis_tkeep = '1;

                if (req_axis_tready) begin
                    state_next = PAYLOAD;
                end
                else begin
                    state_next = TCP_HEADER_3;
                end
            end
            PAYLOAD: begin
                req_axis_tvalid = 1'b1;
                req_axis_tdata = payload[127 - (64 * payloads_summed_reg) -: 64];
                req_axis_tkeep = '1;
                req_axis_tlast = payloads_summed_reg == (payload_rounds - 1);

                if (req_axis_tready) begin
                    payloads_summed_next = payloads_summed_reg + 1'b1;
                    if (payloads_summed_reg == (payload_rounds - 1)) begin
                        state_next = FINISH;
                    end
                    else begin
                        state_next = PAYLOAD;
                    end
                end
                else begin
                    payloads_summed_next = payloads_summed_reg;
                    state_next = FINISH;
                end
            end
            FINISH: begin
                req_axis_cmd_valid = 1'b0;
                req_axis_tvalid = 1'b0;
                state_next = FINISH;
            end
            default: begin
                state_next = 'X;
                req_axis_cmd_csum_enable = 'X;
                req_axis_cmd_valid = 'X;
                req_axis_cmd_csum_offset = 'X;
                
                req_axis_tvalid = 'X;
                req_axis_tdata = 'X;
                req_axis_tkeep = 'X;
                req_axis_tlast = 'X;

                payloads_summed_next = 'X;
            end
        endcase
    end
endmodule
