`include "packet_defs.vh"
`include "soc_defs.vh"
`include "noc_defs.vh"

module tcp_tmp_rx_buf_ctrl (
     input clk
    ,input rst

    ,input                                      src_tmp_buf_rx_hdr_val
    ,output logic                               tmp_buf_src_rx_hdr_rdy
    ,input          [`TOT_LEN_W-1:0]            src_tmp_buf_rx_tcp_payload_len

    ,input                                      src_tmp_buf_rx_data_val
    ,output logic                               tmp_buf_src_rx_data_rdy


    ,output logic                               tmp_buf_dst_rx_hdr_val
    ,input                                      dst_tmp_buf_rx_rdy

    // signals to the allocator
    ,output logic                               tmp_buf_alloc_slab_consume_val
    ,input                                      alloc_slab_tmp_buf_resp_error

    // signals to the buffer
    ,output logic                               tmp_buf_buf_store_val
    ,input                                      buf_store_tmp_buf_rdy

    // control signals
    ,output logic                               load_hdr_state
    ,output logic                               store_entry_addr
    ,output logic                               incr_store_addr

);
   
    typedef enum logic[1:0] {
        READY = 2'd0,
        DATA_COPY = 2'd1,
        OUTPUT = 2'd2,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    logic   [`TOT_LEN_W-1:0]    payload_bytes_rem_reg;
    logic   [`TOT_LEN_W-1:0]    payload_bytes_rem_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;

            payload_bytes_rem_reg <= '0;
        end
        else begin
            state_reg <= state_next;

            payload_bytes_rem_reg <= payload_bytes_rem_next;
        end
    end

    always_comb begin

        load_hdr_state = 1'b0;
        store_entry_addr = 1'b0;
        incr_store_addr = 1'b0;

        tmp_buf_alloc_slab_consume_val = 1'b0;

        tmp_buf_buf_store_val = 1'b0;
        tmp_buf_src_rx_hdr_rdy = 1'b0;
        tmp_buf_src_rx_data_rdy = 1'b0;
    
        tmp_buf_dst_rx_hdr_val = 1'b0;

        payload_bytes_rem_next = payload_bytes_rem_reg;
        state_next = state_reg;
        case (state_reg)
            READY: begin
                if (src_tmp_buf_rx_hdr_val) begin
                    load_hdr_state = 1'b1;
                    payload_bytes_rem_next = src_tmp_buf_rx_tcp_payload_len;

                    if (src_tmp_buf_rx_tcp_payload_len == 0) begin
                        tmp_buf_src_rx_hdr_rdy = 1'b1;
                        state_next = OUTPUT;
                    end
                    // if there is a payload
                    else begin
                        // if we can't store the payload, stall
                        if (alloc_slab_tmp_buf_resp_error) begin
                            tmp_buf_src_rx_hdr_rdy = 1'b0;

                            state_next = READY;
                        end
                        else begin
                            tmp_buf_src_rx_hdr_rdy = 1'b1;
                            store_entry_addr = 1'b1;
                            tmp_buf_alloc_slab_consume_val = 1'b1;

                            state_next = DATA_COPY;
                        end
                    end
                end
                else begin
                    state_next = READY;
                end
            end
            DATA_COPY: begin
                tmp_buf_buf_store_val = src_tmp_buf_rx_data_val;
                tmp_buf_src_rx_data_rdy = buf_store_tmp_buf_rdy;

                if (src_tmp_buf_rx_data_val & buf_store_tmp_buf_rdy) begin
                    incr_store_addr = 1'b1;
                    payload_bytes_rem_next = payload_bytes_rem_reg - `NOC_DATA_BYTES;

                    if (payload_bytes_rem_reg <= `NOC_DATA_BYTES) begin
                        state_next = OUTPUT;
                    end
                    else begin
                        state_next = DATA_COPY;
                    end
                end
                else begin
                    state_next = DATA_COPY;
                end
            end
            OUTPUT: begin
                tmp_buf_dst_rx_hdr_val = 1'b1;
            
                if (dst_tmp_buf_rx_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = OUTPUT;
                end
            end
            default: begin
                load_hdr_state = 'X;
                store_entry_addr = 'X;
                incr_store_addr = 'X;
        
                tmp_buf_alloc_slab_consume_val = 'X;
        
                tmp_buf_buf_store_val = 'X;
                tmp_buf_src_rx_data_rdy = 'X;
            
                tmp_buf_dst_rx_hdr_val = 'X;
        
                payload_bytes_rem_next = 'X;
                state_next = UND;
            end
        endcase
    end

endmodule
