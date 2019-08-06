`include "packet_defs.vh"
`include "soc_defs.vh"
module udp_rx_chksum_input_ctrl 
    import packet_struct_pkg::*;
    import tracker_pkg::*;
#(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
    ,parameter USER_WIDTH = `PKT_TIMESTAMP_W
)(
     input clk
    ,input rst
    
    ,input                                  src_udp_formatter_rx_hdr_val
    ,input          [`IP_ADDR_W-1:0]        src_udp_formatter_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]        src_udp_formatter_rx_dst_ip
    ,input          [`TOT_LEN_W-1:0]        src_udp_formatter_rx_udp_len
    ,input  tracker_stats_struct            src_udp_formatter_rx_timestamp
    ,output logic                           udp_formatter_src_rx_hdr_rdy

    ,input                                  src_udp_formatter_rx_data_val
    ,output logic                           udp_formatter_src_rx_data_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_udp_formatter_rx_data
    ,input                                  src_udp_formatter_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_udp_formatter_rx_padbytes
    
    // Control
    ,output logic                           req_cmd_val
    ,output logic   [7:0]                   req_cmd_csum_start
    ,output logic   [7:0]                   req_cmd_csum_offset
    ,output logic   [15:0]                  req_cmd_csum_init
    ,output logic                           req_cmd_csum_enable
    ,input                                  req_cmd_rdy
    
    // Data Output
    ,output logic   [DATA_WIDTH-1:0]        req_tdata
    ,output logic   [KEEP_WIDTH-1:0]        req_tkeep
    ,output logic                           req_tval
    ,output logic   [USER_WIDTH-1:0]        req_tuser
    ,input                                  req_trdy
    ,output logic                           req_tlast
);
    
    localparam USE_BYTES = `MAC_INTERFACE_BYTES - CHKSUM_PSEUDO_HDR_BYTES;
    localparam USE_W = USE_BYTES * 8;
    localparam HOLD_BYTES = CHKSUM_PSEUDO_HDR_BYTES;
    localparam HOLD_W = CHKSUM_PSEUDO_HDR_W;
    localparam CHKSUM_OFFSET_BYTES = `MAC_INTERFACE_BYTES - CHKSUM_PSEUDO_HDR_BYTES - UDP_HDR_BYTES;

    typedef enum logic[1:0] {
        READY = 2'd0,
        CHKSUM_DATA_INPUT = 2'd1,
        CHKSUM_DATA_LAST = 2'd2,
        UND = 'X
    } chksum_state_e;

    typedef enum logic[1:0] {
        ZERO = 2'd0,
        INPUT = 2'd1,
        REG = 2'd2
    } padbytes_mux_sel_e;

    typedef enum logic {
        PSEUDO_HDR = 1'b0,
        INPUT_DATA = 1'b1
    } hold_mux_sel_e;
    
    chksum_state_e state_reg;
    chksum_state_e state_next;

    chksum_pseudo_hdr pseudo_hdr_cast;
    
    
    logic   [HOLD_W-1:0]    hold_reg;
    logic   [HOLD_W-1:0]    hold_next;

    logic   [`MAC_PADBYTES_W-1:0]   padbytes_reg;
    logic   [`MAC_PADBYTES_W-1:0]   padbytes_next;

    logic   [`MAC_PADBYTES_W-1:0]   padbytes_output;
    logic   [$clog2(KEEP_WIDTH)-1:0]    keep_mask_shift;

    logic                           store_timestamp;
    tracker_stats_struct            pkt_timestamp_reg;
    tracker_stats_struct            pkt_timestamp_next;

    logic store_padbytes;
    padbytes_mux_sel_e padbytes_mux_sel;
    logic store_hold;
    hold_mux_sel_e hold_mux_sel;

    logic shift_keep_mask;

    
    assign pseudo_hdr_cast.source_addr = src_udp_formatter_rx_src_ip;
    assign pseudo_hdr_cast.dest_addr = src_udp_formatter_rx_dst_ip;
    assign pseudo_hdr_cast.length = src_udp_formatter_rx_udp_len;
    assign pseudo_hdr_cast.zeros = '0;
    assign pseudo_hdr_cast.protocol = `IPPROTO_UDP;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            hold_reg <= '0;
            padbytes_reg <= '0;
            pkt_timestamp_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            hold_reg <= hold_next;
            padbytes_reg <= padbytes_next;
            pkt_timestamp_reg <= pkt_timestamp_next;
        end
    end

    always_comb begin
        if (padbytes_mux_sel == INPUT) begin
            padbytes_output = src_udp_formatter_rx_padbytes + USE_BYTES;
        end
        else if (padbytes_mux_sel == REG) begin
            padbytes_output = padbytes_reg + USE_BYTES;
        end
        else begin
            padbytes_output = '0;
        end
    end

    assign padbytes_next = store_padbytes 
                           ? src_udp_formatter_rx_padbytes
                           : padbytes_reg;

    assign keep_mask_shift = padbytes_output;

    assign req_tdata = {hold_reg, src_udp_formatter_rx_data[`MAC_INTERFACE_W-1 -: USE_W]};

    assign req_tkeep = shift_keep_mask
                        ? {KEEP_WIDTH{1'b1}} << keep_mask_shift
                        : {KEEP_WIDTH{1'b1}};

    assign pkt_timestamp_next = store_timestamp
                                ? src_udp_formatter_rx_timestamp
                                : pkt_timestamp_reg;

    assign req_tuser = pkt_timestamp_reg;

    always_comb begin
        if (store_hold) begin
            if (hold_mux_sel == PSEUDO_HDR) begin
                hold_next = pseudo_hdr_cast;
            end
            else begin
                hold_next = src_udp_formatter_rx_data[HOLD_W-1:0];
            end
        end
        else begin
            hold_next = hold_reg;
        end
    end
    
    assign req_cmd_csum_start = '0;
    assign req_cmd_csum_init = '0;
    // how many bytes from the end of the line is the checksum field?
    assign req_cmd_csum_offset = CHKSUM_OFFSET_BYTES[6:0];

    always_comb begin
        udp_formatter_src_rx_hdr_rdy = 1'b0;
        udp_formatter_src_rx_data_rdy = 1'b0;
        req_cmd_val = 1'b0;

        req_tval = 1'b0;
        req_cmd_csum_enable = 1'b0;
        req_tlast = 1'b0;

        store_hold = 1'b0;
        hold_mux_sel = PSEUDO_HDR;

        store_padbytes = 1'b0;
        padbytes_mux_sel = ZERO;

        shift_keep_mask = 1'b0;

        store_timestamp = 1'b0;

        state_next = state_reg;
        
        case (state_reg)
            READY: begin
                udp_formatter_src_rx_hdr_rdy = req_cmd_rdy;
                udp_formatter_src_rx_data_rdy = 1'b0;
                store_timestamp = 1'b1;

                if (src_udp_formatter_rx_hdr_val & req_cmd_rdy) begin
                    hold_mux_sel = PSEUDO_HDR;
                    store_hold = 1'b1;
                    req_cmd_val = 1'b1;
                    req_cmd_csum_enable = 1'b1;
                    state_next = CHKSUM_DATA_INPUT;
                end
                else begin
                    state_next = READY;
                end
            end
            CHKSUM_DATA_INPUT: begin
                udp_formatter_src_rx_hdr_rdy = 1'b0;
                udp_formatter_src_rx_data_rdy = req_trdy;

                req_tval = src_udp_formatter_rx_data_val;
                if (src_udp_formatter_rx_data_val & req_trdy) begin
                    if (src_udp_formatter_rx_last) begin
                        if (src_udp_formatter_rx_padbytes < HOLD_BYTES) begin
                            store_padbytes = 1'b1;
                            hold_mux_sel = INPUT_DATA;
                            store_hold = 1'b1;

                            state_next = CHKSUM_DATA_LAST;
                        end
                        else begin
                            padbytes_mux_sel = INPUT;
                            req_tlast = 1'b1;
                            shift_keep_mask = 1'b1;
                            
                            state_next = READY;
                        end
                    end
                    else begin
                        hold_mux_sel = INPUT_DATA;
                        store_hold = 1'b1;
                        state_next = CHKSUM_DATA_INPUT;
                    end
                end
                else begin
                    state_next = CHKSUM_DATA_INPUT;
                end
            end
            CHKSUM_DATA_LAST: begin
                udp_formatter_src_rx_hdr_rdy = 1'b0;
                udp_formatter_src_rx_data_rdy = 1'b0;

                padbytes_mux_sel = REG;

                req_tval = 1'b1;
                req_tlast = 1'b1;
                shift_keep_mask = 1'b1;

                if (req_trdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = CHKSUM_DATA_LAST;
                end
            end
            default: begin
                udp_formatter_src_rx_hdr_rdy = 'X;
                udp_formatter_src_rx_data_rdy = 'X;
                req_cmd_val = 'X;

                req_tval = 'X;
                req_tlast = 'X;

                store_hold = 'X;

                store_padbytes = 'X;

                shift_keep_mask = 'X;
                
                store_timestamp = 'X;

                padbytes_mux_sel = ZERO;
                hold_mux_sel = PSEUDO_HDR;

                state_next = UND;
            end
        endcase
    end

endmodule
