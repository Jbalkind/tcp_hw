`include "packet_defs.vh"
`include "soc_defs.vh"
import packet_struct_pkg::*;
module eth_hdrtostream (
     input clk
    ,input rst

    ,input                                  src_eth_hdrtostream_eth_hdr_val
    ,input  eth_hdr                         src_eth_hdrtostream_eth_hdr
    ,input  logic   [`MTU_SIZE_W-1:0]       src_eth_hdrtostream_payload_len
    ,input  logic   [`PKT_TIMESTAMP_W-1:0]  src_eth_hdrtostream_timestamp
    ,output logic                           eth_hdrtostream_src_eth_hdr_rdy

    ,input                                  src_eth_hdrtostream_data_val
    ,input          [`MAC_INTERFACE_W-1:0]  src_eth_hdrtostream_data
    ,input                                  src_eth_hdrtostream_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_eth_hdrtostream_data_padbytes
    ,output logic                           eth_hdrtostream_src_data_rdy

    ,output logic                           eth_hdrtostream_dst_data_val
    ,output logic                           eth_hdrtostream_dst_startframe
    ,output logic   [`MAC_INTERFACE_W-1:0]  eth_hdrtostream_dst_data
    ,output logic   [`MTU_SIZE_W-1:0]       eth_hdrtostream_dst_frame_size
    ,output logic                           eth_hdrtostream_dst_endframe
    ,output logic   [`MAC_PADBYTES_W-1:0]   eth_hdrtostream_dst_data_padbytes
    ,input                                  dst_eth_hdrtostream_data_rdy

    ,output logic                           eth_lat_wr_val
    ,output logic   [`PKT_TIMESTAMP_W-1:0]  eth_lat_wr_timestamp
);

    typedef enum logic[1:0] {
        READY = 2'd0,
        WRITE_IN = 2'd1,
        WAIT_OUT = 2'd2,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    logic   is_start_reg;
    logic   is_start_next;

    logic   store_inputs;
    
    logic   [ETH_HDR_W-1:0]     hdr_reg;
    logic   [ETH_HDR_W-1:0]     hdr_next;
    
    logic   [`PKT_TIMESTAMP_W-1:0]  timestamp_reg;
    logic   [`PKT_TIMESTAMP_W-1:0]  timestamp_next;
    
    logic   [`TOT_LEN_W-1:0]    payload_len_reg;
    logic   [`TOT_LEN_W-1:0]    payload_len_next;

    logic                       inserter_fifo_wr_val;
    logic                       inserter_fifo_wr_rdy;
    logic                       inserter_fifo_rd_val;
    logic                       inserter_fifo_rd_rdy;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
            hdr_reg <= hdr_next;
            timestamp_reg <= timestamp_next;
            payload_len_reg <= payload_len_next;
            is_start_reg <= is_start_next;
        end
    end

    always_comb begin
        if (store_inputs) begin
            hdr_next = src_eth_hdrtostream_eth_hdr;
            payload_len_next = src_eth_hdrtostream_payload_len;
            timestamp_next = src_eth_hdrtostream_timestamp;
        end
        else begin
            hdr_next = hdr_reg;
            payload_len_next = payload_len_reg;
            timestamp_next = timestamp_reg;
        end
    end
    
    assign eth_lat_wr_timestamp = timestamp_reg;
    assign eth_hdrtostream_dst_startframe = is_start_reg;
    assign eth_hdrtostream_dst_frame_size = payload_len_reg + ETH_HDR_BYTES;

    inserter_compile #(
         .INSERT_W       (ETH_HDR_W )
        ,.DATA_W         (`MAC_INTERFACE_W  )
    ) hdr_insert (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.insert_data             (hdr_next )
        
        ,.src_insert_data_val     (inserter_fifo_wr_val             )
        ,.src_insert_data         (src_eth_hdrtostream_data         )
        ,.src_insert_data_padbytes(src_eth_hdrtostream_data_padbytes)
        ,.src_insert_data_last    (src_eth_hdrtostream_data_last    )
        ,.insert_src_data_rdy     (inserter_fifo_wr_rdy             )
    
        ,.insert_dst_data_val     (inserter_fifo_rd_val             )
        ,.insert_dst_data         (eth_hdrtostream_dst_data         )
        ,.insert_dst_data_padbytes(eth_hdrtostream_dst_data_padbytes)
        ,.insert_dst_data_last    (eth_hdrtostream_dst_endframe     )
        ,.dst_insert_data_rdy     (inserter_fifo_rd_rdy             )
    );

    always_comb begin
        eth_hdrtostream_src_eth_hdr_rdy = 1'b0;
        eth_hdrtostream_src_data_rdy = 1'b0;

        eth_hdrtostream_dst_data_val = 1'b0;

        inserter_fifo_wr_val = 1'b0;

        store_inputs = 1'b0;

        is_start_next = is_start_reg;
        state_next = state_reg;
        case (state_reg) 
            READY: begin
                is_start_next = 1'b1;
                eth_hdrtostream_src_eth_hdr_rdy = 1'b1;
                store_inputs = 1'b1;
                if (src_eth_hdrtostream_eth_hdr_val) begin
                    state_next = WRITE_IN;
                end
            end
            WRITE_IN: begin
                inserter_fifo_wr_val = src_eth_hdrtostream_data_val;
                eth_hdrtostream_src_data_rdy = inserter_fifo_wr_rdy;

                eth_hdrtostream_dst_data_val = inserter_fifo_rd_val;
                inserter_fifo_rd_rdy = dst_eth_hdrtostream_data_rdy;

                is_start_next = dst_eth_hdrtostream_data_rdy & inserter_fifo_rd_val
                            ? 1'b0
                            : is_start_reg;

                if (src_eth_hdrtostream_data_val & inserter_fifo_wr_rdy) begin
                    if (src_eth_hdrtostream_data_last) begin
                        if (dst_eth_hdrtostream_data_rdy & inserter_fifo_rd_val) begin
                            if (eth_hdrtostream_dst_endframe) begin
                                state_next = READY;
                            end
                            else begin
                                state_next = WAIT_OUT;
                            end
                        end
                        else begin
                            state_next = WAIT_OUT;
                        end
                    end
                end
            end
            WAIT_OUT: begin
                eth_hdrtostream_dst_data_val = inserter_fifo_rd_val;
                inserter_fifo_rd_rdy = dst_eth_hdrtostream_data_rdy;

                if (dst_eth_hdrtostream_data_rdy & inserter_fifo_rd_val) begin
                    if (eth_hdrtostream_dst_endframe) begin
                        state_next = READY;
                    end
                end
            end
        endcase
    end

endmodule
