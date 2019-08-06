`include "packet_defs.vh"
`include "state_defs.vh"
`include "soc_defs.vh"
`include "noc_defs.vh"
module ip_to_stream (
     input clk
    ,input rst
    
    ,input                                  src_ip_to_stream_hdr_val
    ,input          [`IP_HDR_W-1:0]         src_ip_to_stream_ip_hdr
    ,output logic                           ip_to_stream_src_hdr_rdy

    ,input                                  src_ip_to_stream_data_val
    ,input          [`MAC_INTERFACE_W-1:0]  src_ip_to_stream_data
    ,input                                  src_ip_to_stream_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_ip_to_stream_data_padbytes
    ,output logic                           ip_to_stream_src_data_rdy
    
    ,output logic                           ip_to_stream_dst_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]  ip_to_stream_dst_data
    ,output logic                           ip_to_stream_dst_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   ip_to_stream_dst_data_padbytes
    ,input                                  dst_ip_to_stream_data_rdy
);
    
    typedef enum logic [1:0] {
        READY = 2'd0,
        OUTPUT = 2'd1,
        OUTPUT_LAST = 2'd2,
        UND = 'X
    } data_state_e;
    
    localparam SAVE_BITS = `IP_HDR_W;
    localparam SAVE_BYTES = SAVE_BITS/8;

    localparam USED_BITS = `MAC_INTERFACE_W - SAVE_BITS;
    localparam USED_BYTES = USED_BITS/8;
    
    localparam NOC_DATA_BYTES = `NOC_DATA_WIDTH/8;
    localparam NOC_DATA_BYTES_W = $clog2(NOC_DATA_BYTES);
    
    typedef enum logic {
        IN_HDR = 1'd0,
        IN_DATA = 1'd1
    } save_mux_e;

    typedef enum logic {
        IN_PADBYTES = 1'd0,
        REG_PADBYTES = 1'd1
    } padbytes_mux_e;

    logic   [`MAC_PADBYTES_W-1:0]   input_padbytes_reg;
    logic   [`MAC_PADBYTES_W-1:0]   input_padbytes_next;

    logic   [SAVE_BITS-1:0]    save_reg;
    logic   [SAVE_BITS-1:0]    save_next; 

    logic                       update_save;
    save_mux_e                  save_mux_sel;
    logic   [`MAC_PADBYTES_W-1:0]   padbytes_calc;
    padbytes_mux_e              padbytes_mux_sel;

    data_state_e data_state_reg;
    data_state_e data_state_next;
    
    ip_pkt_hdr ip_hdr_struct_cast;

    assign ip_hdr_struct_cast = src_ip_to_stream_ip_hdr;

    assign ip_to_stream_dst_data = {save_reg, src_ip_to_stream_data[`MAC_INTERFACE_W-1 -: USED_BITS]};
    assign ip_to_stream_dst_data_padbytes = padbytes_calc + USED_BYTES;

    always_comb begin
        if (padbytes_mux_sel == IN_PADBYTES) begin
            padbytes_calc = src_ip_to_stream_data_padbytes;
        end
        else begin
            padbytes_calc = input_padbytes_reg;
        end
    end
    
    always_comb begin
        if (update_save) begin
            if (save_mux_sel == IN_HDR) begin
                save_next = ip_hdr_struct_cast;
            end
            else begin
                save_next = src_ip_to_stream_data[SAVE_BITS-1:0];
            end
        end
        else begin
            save_next = save_reg;
        end
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            save_reg <= '0;
            input_padbytes_reg <= '0;
        end
        else begin
            data_state_reg <= data_state_next;
            input_padbytes_reg <= input_padbytes_next;
            save_reg <= save_next;
        end
    end
    
    always_comb begin
        ip_to_stream_src_hdr_rdy = 1'b0;
        ip_to_stream_src_data_rdy = 1'b0;

        ip_to_stream_dst_data_val = 1'b0;
        ip_to_stream_dst_data_last = 1'b0;

        update_save = 1'b0;
        save_mux_sel = IN_DATA;
        padbytes_mux_sel = IN_PADBYTES;
        input_padbytes_next = input_padbytes_reg;

        data_state_next = data_state_reg;
        case (data_state_reg) 
            READY: begin
                ip_to_stream_src_hdr_rdy = 1'b1;
                ip_to_stream_src_data_rdy = 1'b0;
                save_mux_sel = IN_HDR;

                if (src_ip_to_stream_hdr_val) begin
                    update_save = 1'b1;
                    if (ip_hdr_struct_cast.tot_len == `IP_HDR_BYTES) begin
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
                ip_to_stream_src_hdr_rdy = 1'b0;
                ip_to_stream_src_data_rdy = dst_ip_to_stream_data_rdy;
                ip_to_stream_dst_data_val = src_ip_to_stream_data_val;

                save_mux_sel = IN_DATA;

                // if this is the last input line and we can fit all the bytes into the output
                // dataline
                if (src_ip_to_stream_data_val & dst_ip_to_stream_data_rdy) begin
                    update_save = 1'b1;

                    padbytes_mux_sel = IN_PADBYTES;
                    
                    // if this is the last input line and we can fit all the bytes into the output
                    // dataline
                    if (src_ip_to_stream_data_last 
                        & (src_ip_to_stream_data_padbytes >= SAVE_BYTES)) begin

                        ip_to_stream_dst_data_last = 1'b1;
                        data_state_next = READY;
                    end
                    // if this is just the last input line and we can't fit all the bytes into the
                    // output dataline
                    else if (src_ip_to_stream_data_last) begin
                        input_padbytes_next = src_ip_to_stream_data_padbytes;
                        data_state_next = OUTPUT_LAST;
                    end
                    else begin
                        data_state_next = OUTPUT;
                    end
                end
                else begin
                    data_state_next = OUTPUT;
                end
            end
            OUTPUT_LAST: begin
                ip_to_stream_src_hdr_rdy = 1'b0;
                ip_to_stream_src_data_rdy = 1'b0;

                ip_to_stream_dst_data_val = 1'b1;
                ip_to_stream_dst_data_last = 1'b1;
                padbytes_mux_sel = REG_PADBYTES;

                if (dst_ip_to_stream_data_rdy) begin
                    data_state_next = READY;
                end
                else begin
                    data_state_next = OUTPUT_LAST;
                end
            end
            default: begin
                ip_to_stream_src_hdr_rdy = 'X;
                ip_to_stream_src_data_rdy = 'X;

                ip_to_stream_dst_data_val = 'X;
                ip_to_stream_dst_data_last = 'X;

                update_save = 'X;
                input_padbytes_next = 'X;
                
                save_mux_sel = IN_DATA;
                padbytes_mux_sel = IN_PADBYTES;

                data_state_next = UND;
            end
        endcase
    end


endmodule
