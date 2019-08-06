`include "packet_defs.vh"
`include "soc_defs.vh"
import packet_struct_pkg::*;
module tcp_tx_chksum_input_ctrl #(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
    ,parameter USER_WIDTH = `PKT_TIMESTAMP_W
)(
     input clk
    ,input rst

    // I/O from the payload engine
    ,input                                  src_chksum_tx_hdr_val
    ,output logic                           chksum_src_tx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]        src_chksum_tx_src_ip
    ,input          [`IP_ADDR_W-1:0]        src_chksum_tx_dst_ip
    ,input          [`TOT_LEN_W-1:0]        src_chksum_tx_payload_len
    ,input          [`PKT_TIMESTAMP_W-1:0]  src_chksum_tx_timestamp
    ,input  tcp_pkt_hdr                     src_chksum_tx_tcp_hdr

    ,input                                  src_chksum_tx_data_val
    ,output logic                           chksum_src_tx_data_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_chksum_tx_data
    ,input                                  src_chksum_tx_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_chksum_tx_data_padbytes

    // I/O to the checksum engine
    
    /*
     * Control
     */
    ,output logic                           req_cmd_csum_enable
    ,output logic   [7:0]                   req_cmd_csum_start
    ,output logic   [7:0]                   req_cmd_csum_offset
    ,output logic   [15:0]                  req_cmd_csum_init
    ,output logic                           req_cmd_val
    ,input                                  req_cmd_rdy
    
    /*
     * Data Output
     */
    ,output logic   [DATA_WIDTH-1:0]        req_tdata
    ,output logic   [KEEP_WIDTH-1:0]        req_tkeep
    ,output logic   [USER_WIDTH-1:0]        req_tuser
    ,output logic                           req_tval
    ,input                                  req_trdy
    ,output logic                           req_tlast
);
    localparam HOLD_BYTES = CHKSUM_PSEUDO_HDR_BYTES + TCP_HDR_BYTES;
    localparam HOLD_W = HOLD_BYTES * 8;
    localparam USE_BYTES = `MAC_INTERFACE_BYTES - HOLD_BYTES;
    localparam USE_W = USE_BYTES * 8;
    localparam CHKSUM_OFFSET_BYTES = `MAC_INTERFACE_BYTES - CHKSUM_PSEUDO_HDR_BYTES - TCP_HDR_BYTES + 2;
    
    typedef enum logic [1:0] {
        READY = 2'd0,
        CHKSUM_DATA_INPUT = 2'd1,
        CHKSUM_DATA_LAST = 2'd2,
        UND = 'X
    } state_e;
    
    typedef enum logic[1:0] {
        ZERO = 2'd0,
        INPUT = 2'd1,
        REG = 2'd2
    } padbytes_out_mux_sel_e;

    typedef enum logic {
        IN = 1'b0,
        TCP_HDR_ONLY = 1'b1
    } padbytes_store_mux_sel_e;

    typedef enum logic {
        HDRS = 1'b0,
        INPUT_DATA = 1'b1
    } hold_mux_sel_e;

    state_e state_reg;
    state_e state_next;
    
    chksum_pseudo_hdr pseudo_hdr_cast;

    tcp_pkt_hdr tcp_hdr_input;
    
    logic   [HOLD_W-1:0]    hold_reg;
    logic   [HOLD_W-1:0]    hold_next;
    
    logic   [`MAC_PADBYTES_W-1:0]   padbytes_reg;
    logic   [`MAC_PADBYTES_W-1:0]   padbytes_next;

    logic   [`MAC_PADBYTES_W-1:0]   padbytes_output;
    logic   [$clog2(KEEP_WIDTH)-1:0]    keep_mask_shift;

    logic                           store_timestamp;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_reg;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_next;
    
    logic store_padbytes;
    padbytes_out_mux_sel_e padbytes_out_mux_sel;
    padbytes_store_mux_sel_e padbytes_store_mux_sel;
    logic store_hold;
    hold_mux_sel_e hold_mux_sel;

    logic shift_keep_mask;

    always_comb begin
        tcp_hdr_input = src_chksum_tx_tcp_hdr;
        tcp_hdr_input.chksum = '0;
    end

    assign pseudo_hdr_cast.source_addr = src_chksum_tx_src_ip;
    assign pseudo_hdr_cast.dest_addr = src_chksum_tx_dst_ip;
    assign pseudo_hdr_cast.length = src_chksum_tx_payload_len + TCP_HDR_BYTES;
    assign pseudo_hdr_cast.zeros = '0;
    assign pseudo_hdr_cast.protocol = `IPPROTO_TCP;

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

    assign pkt_timestamp_next = store_timestamp
                            ? src_chksum_tx_timestamp
                            : pkt_timestamp_reg;
    assign req_tuser = pkt_timestamp_reg;

    always_comb begin
        if (padbytes_out_mux_sel == INPUT) begin
            padbytes_output = src_chksum_tx_data_padbytes + USE_BYTES;
        end
        else if (padbytes_out_mux_sel == REG) begin
            padbytes_output = padbytes_reg + USE_BYTES;
        end
        else begin
            padbytes_output = '0;
        end
    end

    always_comb begin
        padbytes_next = padbytes_reg;
        if (store_padbytes) begin
            if (padbytes_store_mux_sel == TCP_HDR_ONLY) begin
                padbytes_next = '0;
            end
            else begin
                padbytes_next = src_chksum_tx_data_padbytes;
            end
        end
        else begin
            padbytes_next = padbytes_reg;
        end
    end

    assign keep_mask_shift = padbytes_output;
    generate
        if (USE_W == 0) begin
            assign req_tdata = hold_reg;
        end
        else begin
            assign req_tdata = {hold_reg, src_chksum_tx_data[`MAC_INTERFACE_W-1 -: USE_W]};
        end
    endgenerate


    assign req_tkeep = shift_keep_mask
                    ? {KEEP_WIDTH{1'b1}} << keep_mask_shift
                    : {KEEP_WIDTH{1'b1}};

    always_comb begin
        hold_next = hold_reg;
        if (store_hold) begin
            if (hold_mux_sel == HDRS) begin
                hold_next = {pseudo_hdr_cast, tcp_hdr_input};
            end
            else begin
                hold_next = src_chksum_tx_data[HOLD_W-1:0];
            end
        end
        else begin
            hold_next = hold_reg;
        end
    end

    assign req_cmd_csum_start = '0;
    assign req_cmd_csum_init = '0;
    // how many bytes from the end of the line is the checksum field?
    assign req_cmd_csum_offset = CHKSUM_OFFSET_BYTES;

    always_comb begin
        chksum_src_tx_hdr_rdy = 1'b0;
        chksum_src_tx_data_rdy = 1'b0;

        req_cmd_csum_enable = 1'b0;
        req_cmd_val = 1'b0;

        req_tval = 1'b0;
        req_tlast = 1'b0;

        store_hold = 1'b0;
        hold_mux_sel = HDRS;

        store_padbytes = 1'b0;
        padbytes_out_mux_sel = ZERO;
        padbytes_store_mux_sel = IN;

        shift_keep_mask = 1'b0;
        store_timestamp = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                chksum_src_tx_hdr_rdy = req_cmd_rdy;
                store_timestamp = 1'b1;

                if (src_chksum_tx_hdr_val & req_cmd_rdy) begin
                    req_cmd_csum_enable = 1'b1;
                    req_cmd_val = 1'b1;
                    store_hold = 1'b1;
                    hold_mux_sel = HDRS;

                    if (src_chksum_tx_payload_len == 0) begin
                        store_padbytes = 1'b1;
                        padbytes_store_mux_sel = TCP_HDR_ONLY;
                        state_next = CHKSUM_DATA_LAST;
                    end
                    else begin
                        state_next = CHKSUM_DATA_INPUT;
                    end
                end
            end
            CHKSUM_DATA_INPUT: begin
                chksum_src_tx_data_rdy = req_trdy;
                padbytes_out_mux_sel = INPUT;

                req_tval = src_chksum_tx_data_val;
                hold_mux_sel  = INPUT_DATA;

                if (src_chksum_tx_data_val & req_trdy) begin
                    // if we get the last dataline
                    if (src_chksum_tx_data_last) begin
                        // the incoming line has too much data to output in
                        // this cycle along with the saved data, so go to drain
                        if (src_chksum_tx_data_padbytes < HOLD_BYTES) begin
                            store_padbytes = 1'b1;
                            padbytes_store_mux_sel = IN;
                            store_hold = 1'b1;

                            state_next = CHKSUM_DATA_LAST;
                        end
                        // if we can transmit everything this cycle
                        else begin
                            req_tlast = 1'b1;
                            shift_keep_mask = 1'b1;

                            state_next = READY;
                        end
                    end
                    else begin
                        store_hold = 1'b1;
                        state_next = CHKSUM_DATA_INPUT;
                    end
                end
            end
            CHKSUM_DATA_LAST: begin
                padbytes_out_mux_sel = REG;
                req_tval = 1'b1;
                req_tlast = 1'b1;
                shift_keep_mask = 1'b1;

                if (req_trdy) begin
                    state_next = READY;
                end
            end
            default: begin
                chksum_src_tx_hdr_rdy = 'X;
                chksum_src_tx_data_rdy = 'X;
        
                req_cmd_csum_enable = 'X;
                req_cmd_val = 'X;
        
                req_tval = 'X;
                req_tlast = 'X;
        
                store_hold = 'X;
        
                store_padbytes = 'X;
        
                shift_keep_mask = 'X;
                store_timestamp = 'X;
                
                hold_mux_sel = HDRS;
                padbytes_out_mux_sel = ZERO;
                padbytes_store_mux_sel = IN;
        
                state_next = UND;
            end
        endcase
    end
endmodule
