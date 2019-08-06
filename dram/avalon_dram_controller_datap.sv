`include "noc_defs.vh"
`include "state_defs.vh"
`include "bsg_defines.v"

import noc_struct_pkg::*;

module avalon_dram_controller_datap #(
     parameter mem_addr_w_p = -1
    ,parameter mem_data_w_p = -1
    ,parameter mem_wr_mask_w_p = mem_data_w_p >> 3
    ,parameter SRC_X = 0
    ,parameter SRC_Y = 0
    ,parameter WR_DRAIN_SRC = 2'd2
    ,parameter WR_FIRST_SRC = 2'd1
    ,parameter WR_COPY_SRC = 2'd0
    ,parameter METADATA_SEL_FULL = 1'd0
    ,parameter METADATA_SEL_PART = 1'd1
)(
     input clk
    ,input rst
    
    ,input          [`NOC_DATA_WIDTH-1:0]       noc0_ctovr_controller_data

    ,output logic   [`NOC_DATA_WIDTH-1:0]       controller_noc0_vrtoc_data

    ,output logic   [mem_addr_w_p-1:0]          controller_mem_addr
    ,output logic   [mem_data_w_p-1:0]          controller_mem_wr_data
    ,output logic   [mem_wr_mask_w_p-1:0]       controller_mem_byte_en
    ,output logic   [7-1:0]                     controller_mem_burst_cnt

    ,input          [mem_data_w_p-1:0]          mem_controller_rd_data
    
    ,input  logic                               ctrl_datap_store_hdr_flit
    ,input  logic                               ctrl_datap_init_metadata
    ,input  logic                               ctrl_datap_update_metadata
    ,input  logic                               ctrl_datap_update_metadata_sel
    ,input  logic                               ctrl_datap_send_hdr_flit
    ,input  logic                               ctrl_datap_incr_recv_flits
    ,input  logic                               ctrl_datap_incr_sent_flits
    ,input  logic                               ctrl_datap_store_rd_data
    ,input  logic                               ctrl_datap_store_save1
    ,input  logic   [1:0]                       ctrl_datap_sel_store_src
    ,input  logic                               ctrl_datap_store_msg_len

    ,output logic   [`MSG_TYPE_WIDTH-1:0]       datap_ctrl_msg_type
    ,output logic                               datap_ctrl_first_rd
    ,output logic                               datap_ctrl_last_req_flit
    ,output logic                               datap_ctrl_last_resp_flit
    ,output logic                               datap_ctrl_read_new_line
    ,output logic                               datap_ctrl_last_mem_write
);
    
    // for addressing bits within a line
    localparam mem_data_index_w = `BSG_SAFE_CLOG2(mem_data_w_p);
    // for addressing bytes within a line
    localparam mem_data_w_bytes = mem_data_w_p >> 3;
    localparam block_addr_w = `BSG_SAFE_CLOG2(mem_data_w_bytes);
    
    logic   [`MSG_LENGTH_WIDTH-1:0]         curr_flit_count_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0]         curr_flit_count_next;
    
    logic   [mem_data_w_p-1:0]              mem_read_data_reg;
    logic   [mem_data_w_p-1:0]              mem_read_data_next;
    logic   [mem_data_w_p-1:0]              shifted_read_data;
    
    logic   [`MSG_ADDR_WIDTH-1:0]           curr_op_addr_reg;
    logic   [`MSG_ADDR_WIDTH-1:0]           curr_op_addr_next;
    
    logic   [`MSG_LENGTH_WIDTH-1:0]         read_flits_sent_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0]         read_flits_sent_next;
    logic   [`MSG_LENGTH_WIDTH-1:0]         resp_msg_len_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0]         resp_msg_len_next;

    logic   [block_addr_w-1:0]                  block_addr;
    logic   [`MSG_ADDR_WIDTH-block_addr_w-1:0]  line_addr;

    logic   [`MSG_LENGTH_WIDTH-1:0]             resp_msg_len;

    // figure out where in the line the data you want starts is
    logic   [mem_data_index_w-1:0]              mem_data_shift;

    logic   [`NOC_DATA_BYTES_W:0]               bytes_first_wr;
    logic   [`NOC_DATA_BYTES_W:0]               bytes_unwritten;
    logic   [`NOC_DATA_BYTES_W:0]               bytes_first_wr_shift;
    logic   [`NOC_DATA_BYTES_W:0]               bytes_body_wr_shift;
    logic   [mem_data_index_w-1:0]              bytes_body_data_shift;

    logic   [`NOC_DATA_BYTES_W-1:0]             last_msg_rem;
    logic   [`NOC_DATA_BYTES_W:0]               last_msg_padbytes;

    logic   [`MSG_DATA_SIZE_WIDTH-1:0]          write_bytes_left_reg;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]          write_bytes_left_next;

    logic   [`NOC_DATA_WIDTH-1:0]               save1_reg;
    logic   [`NOC_DATA_WIDTH-1:0]               save1_next;
    logic   [`NOC_DATA_BYTES-1:0]               save1_mask_reg;
    logic   [`NOC_DATA_BYTES-1:0]               save1_mask_next;
    
    logic   [`NOC_DATA_BYTES-1:0]               noc0_data_mask;
    logic   [mem_data_w_p-1:0]  shifted_wr_data;

    // write mask with "used" bytes shifted out, usable mask is at top 32 bits
    logic   [mem_wr_mask_w_p-1:0]   wr_mask;
    // write mask shifted to the appropriate part of the line
    logic   [mem_wr_mask_w_p-1:0]   shifted_wr_mask;


    noc_hdr_flit hdr_flit_next;
    noc_hdr_flit hdr_flit_reg;

    noc_hdr_flit resp_hdr_flit;
    
    always @(posedge clk) begin
        if (rst) begin
            hdr_flit_reg <= '0;
            curr_flit_count_reg <= '0;
            curr_op_addr_reg <= '0;
            read_flits_sent_reg <= '0;
            mem_read_data_reg <= '0;
            write_bytes_left_reg <= '0;
            save1_reg <= '0;
            save1_mask_reg <= '0;
            resp_msg_len_reg <= '0;
        end
        else begin
            hdr_flit_reg <= hdr_flit_next;
            curr_flit_count_reg <= curr_flit_count_next;
            curr_op_addr_reg <= curr_op_addr_next;
            read_flits_sent_reg <= read_flits_sent_next;
            mem_read_data_reg <= mem_read_data_next;
            write_bytes_left_reg <= write_bytes_left_next;
            save1_reg <= save1_next;
            save1_mask_reg <= save1_mask_next;
            resp_msg_len_reg <= resp_msg_len_next;
        end
    end

    assign controller_mem_addr = line_addr;
    assign controller_mem_wr_data = shifted_wr_data;
    assign controller_mem_byte_en = shifted_wr_mask;
    assign controller_mem_burst_cnt = 7'd1;

    assign mem_data_shift = block_addr << 3;
    assign shifted_read_data = mem_read_data_reg << mem_data_shift;

    assign controller_noc0_vrtoc_data = ctrl_datap_send_hdr_flit
                                      ? resp_hdr_flit
                                      : shifted_read_data[mem_data_w_p-1 -: `NOC_DATA_WIDTH];

    assign hdr_flit_next = ctrl_datap_store_hdr_flit
                         ? noc0_ctovr_controller_data
                         : hdr_flit_reg;

    assign mem_read_data_next = ctrl_datap_store_rd_data
                              ? mem_controller_rd_data
                              : mem_read_data_reg;

    // how many bytes do we need in the first write to start writing to a multiple of 32
    assign bytes_first_wr = {1'b1, {(`NOC_DATA_BYTES_W){1'b0}}} - hdr_flit_reg.addr[`NOC_DATA_BYTES_W-1:0];
    // how many bytes won't be written in the first write
    assign bytes_unwritten = hdr_flit_reg.addr[`NOC_DATA_BYTES_W-1:0];
    // how many bits do we need to shift to get the first write mask
    assign bytes_first_wr_shift = bytes_unwritten;
    // how many bits do we need to shift during the rest of the write for the write mask
    assign bytes_body_wr_shift = bytes_first_wr;
    assign bytes_body_data_shift = bytes_body_wr_shift << 3;

    assign resp_msg_len_next = ctrl_datap_store_msg_len
                            ? resp_hdr_flit.msg_len
                            : resp_msg_len_reg;

    assign last_msg_rem = hdr_flit_reg.data_size[`NOC_DATA_BYTES_W-1:0];
    assign last_msg_padbytes = last_msg_rem == '0
                        ?  '0
                        : {1'b1, {(`NOC_DATA_BYTES_W){1'b0}}} - last_msg_rem;


    assign datap_ctrl_msg_type = hdr_flit_next.msg_type;
    assign datap_ctrl_first_rd = hdr_flit_reg.addr == curr_op_addr_reg;
    assign datap_ctrl_last_resp_flit = read_flits_sent_reg == (resp_msg_len_reg - 
                                                               `MSG_LENGTH_WIDTH'd1);
    assign datap_ctrl_last_req_flit = curr_flit_count_reg  == (hdr_flit_reg.msg_len - 
                                                                `MSG_LENGTH_WIDTH'd1);
    assign datap_ctrl_last_mem_write = write_bytes_left_next == '0;

    always_comb begin
        if (ctrl_datap_init_metadata) begin
            curr_flit_count_next = '0;
            read_flits_sent_next = '0;
        end
        else begin
            curr_flit_count_next = ctrl_datap_incr_recv_flits
                                 ? curr_flit_count_reg + 1'b1
                                 : curr_flit_count_reg;
            read_flits_sent_next = ctrl_datap_incr_sent_flits
                                ? read_flits_sent_reg + 1'b1
                                : read_flits_sent_reg;
        end
    end

    assign save1_next = ctrl_datap_store_save1
                      ? noc0_ctovr_controller_data
                      : save1_reg;
    assign save1_mask_next = ctrl_datap_store_save1
                           ? noc0_data_mask
                           : save1_mask_reg;

    assign datap_ctrl_read_new_line = curr_op_addr_next[`MSG_ADDR_WIDTH-1:block_addr_w] != line_addr;
    
    assign block_addr = curr_op_addr_reg[block_addr_w-1:0];
    assign line_addr = curr_op_addr_reg[`MSG_ADDR_WIDTH-1:block_addr_w];

    always_comb begin
        if (ctrl_datap_init_metadata) begin
            curr_op_addr_next = hdr_flit_next.addr;
            write_bytes_left_next = hdr_flit_next.data_size;
        end
        else if (ctrl_datap_update_metadata) begin
            if (ctrl_datap_update_metadata_sel == METADATA_SEL_PART) begin
                curr_op_addr_next = curr_op_addr_reg + bytes_first_wr;
                write_bytes_left_next = write_bytes_left_reg > bytes_first_wr
                                      ? write_bytes_left_reg - bytes_first_wr
                                      : '0;
            end
            else begin
                curr_op_addr_next = curr_op_addr_reg + `NOC_DATA_BYTES;
                write_bytes_left_next = write_bytes_left_reg > `NOC_DATA_BYTES
                                      ? write_bytes_left_reg - `NOC_DATA_BYTES
                                      : '0;
            end
        end
        else begin
            curr_op_addr_next = curr_op_addr_reg;
            write_bytes_left_next = write_bytes_left_reg;
        end
    end
    
    assign resp_msg_len = hdr_flit_reg.data_size[`NOC_DATA_BYTES_W-1:0] == 0
                        ? hdr_flit_reg.data_size >> `NOC_DATA_BYTES_W
                        : (hdr_flit_reg.data_size >> `NOC_DATA_BYTES_W) + 1;


    assign noc0_data_mask = datap_ctrl_last_req_flit
                          ? ({(`NOC_DATA_BYTES){1'b1}}) << last_msg_padbytes
                          : {(`NOC_DATA_BYTES){1'b1}};


    assign shifted_wr_mask = {wr_mask[mem_wr_mask_w_p-1 -: `NOC_DATA_BYTES], 
                              {(`NOC_DATA_BYTES){1'b0}}} >> block_addr;

    always_comb begin
        if (ctrl_datap_sel_store_src == WR_DRAIN_SRC) begin
            wr_mask = {save1_mask_reg, {(`NOC_DATA_BYTES){1'b0}}} << bytes_body_wr_shift;
        end
        else if (ctrl_datap_sel_store_src == WR_COPY_SRC) begin
            wr_mask = {save1_mask_reg, noc0_data_mask} << bytes_body_wr_shift;
        end
        else begin
            wr_mask = ({{(`NOC_DATA_BYTES){1'b1}}, {(`NOC_DATA_BYTES){1'b0}}} << bytes_first_wr_shift)
                      & {noc0_data_mask, {(`NOC_DATA_BYTES){1'b0}}};
        end
    end


    always_comb begin
        if (ctrl_datap_sel_store_src == WR_FIRST_SRC) begin
            shifted_wr_data = ({noc0_ctovr_controller_data, 
                               {(mem_data_w_p - `NOC_DATA_WIDTH){1'b0}}}) >> mem_data_shift;
        end
        else begin
            shifted_wr_data = ({save1_reg, 
                                noc0_ctovr_controller_data} << bytes_body_data_shift) 
                                >> mem_data_shift;
        end
    end

    
    // response flit crafting
    always_comb begin
        resp_hdr_flit = '0;
        resp_hdr_flit.dst_chip_id = hdr_flit_reg.src_chip_id;
        resp_hdr_flit.dst_x_coord = hdr_flit_reg.src_x_coord;
        resp_hdr_flit.dst_y_coord = hdr_flit_reg.src_y_coord;
        resp_hdr_flit.fbits = hdr_flit_reg.src_fbits;
        resp_hdr_flit.data_size = hdr_flit_reg.data_size;

        resp_hdr_flit.src_chip_id = '0;
        resp_hdr_flit.src_x_coord = SRC_X[`MSG_SRC_X_WIDTH-1:0];
        resp_hdr_flit.src_y_coord = SRC_Y[`MSG_SRC_Y_WIDTH-1:0];

        if (hdr_flit_reg.msg_type == `MSG_TYPE_STORE_MEM) begin
            resp_hdr_flit.msg_len = '0;
            resp_hdr_flit.msg_type = `MSG_TYPE_STORE_MEM_ACK;
        end
        else if (hdr_flit_reg.msg_type == `MSG_TYPE_LOAD_MEM) begin
            resp_hdr_flit.msg_len = resp_msg_len;
            resp_hdr_flit.msg_type = `MSG_TYPE_LOAD_MEM_ACK;
        end
        else begin
            resp_hdr_flit.msg_len = '0;
            resp_hdr_flit.msg_type = '0;
        end
    end
endmodule
