`include "soc_defs.vh"
`include "noc_defs.vh"
`include "packet_defs.vh"
`include "state_defs.vh"

module avalon_dram_controller #(
     parameter mem_addr_w_p = -1
    ,parameter mem_data_w_p = -1
    ,parameter mem_wr_mask_w_p = mem_data_w_p >> 3
    ,parameter SRC_X = 0
    ,parameter SRC_Y = 0
)(
     input clk
    ,input rst

    ,input                                      noc0_ctovr_controller_val
    ,input          [`NOC_DATA_WIDTH-1:0]       noc0_ctovr_controller_data
    ,output logic                               controller_noc0_ctovr_rdy

    ,output logic                               controller_noc0_vrtoc_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       controller_noc0_vrtoc_data
    ,input                                      noc0_vrtoc_controller_rdy

    ,output logic                               controller_mem_read_en
    ,output logic                               controller_mem_write_en
    ,output logic   [mem_addr_w_p-1:0]          controller_mem_addr
    ,output logic   [mem_data_w_p-1:0]          controller_mem_wr_data
    ,output logic   [mem_wr_mask_w_p-1:0]       controller_mem_byte_en
    ,output logic   [7-1:0]                     controller_mem_burst_cnt
    ,input                                      mem_controller_rdy

    ,input                                      mem_controller_rd_data_val
    ,input          [mem_data_w_p-1:0]          mem_controller_rd_data
);

    typedef enum logic [2:0] {
        READY = 3'd0,
        RD_OP_ISSUE = 3'd1,
        RD_OP_WAIT = 3'd2,
        RD_HDR_FLIT = 3'd3,
        RD_PAYLOAD_RESP = 3'd4,
        WRITING = 3'd5,
        WR_RESP = 3'd6,
        UND = 'X
    } state_e;

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

    logic   [block_addr_w-1:0]                  block_addr;
    logic   [`MSG_ADDR_WIDTH-block_addr_w-1:0]  line_addr;

    logic   [`MSG_LENGTH_WIDTH-1:0]             resp_msg_len;

    // figure out where in the line the data you want starts is
    logic   [`BSG_SAFE_CLOG2(mem_data_w_p)-1:0] mem_data_shift;

    logic   [`MSG_LENGTH_WIDTH-1:0]             last_msg_size;

    logic   [`MAC_INTERFACE_BYTES_W-1:0]        last_msg_padbytes;
    logic   [`MAC_INTERFACE_BYTES-1:0]          last_data_byte_mask;
    logic   [mem_wr_mask_w_p-1:0]               last_data_byte_en;

    logic   [mem_wr_mask_w_p-1:0]               body_data_byte_en;

    state_e state_reg;
    state_e state_next;

    noc_hdr_flit hdr_flit_cast;
    noc_hdr_flit hdr_flit_next;
    noc_hdr_flit hdr_flit_reg;

    noc_hdr_flit resp_hdr_flit;

    assign hdr_flit_cast = noc0_ctovr_controller_data;

    assign block_addr = curr_op_addr_reg[block_addr_w-1:0];
    assign line_addr = curr_op_addr_reg[`MSG_ADDR_WIDTH-1:block_addr_w];

    assign mem_data_shift = block_addr << 3;

    assign controller_mem_burst_cnt = 7'd1;

    assign shifted_read_data = mem_read_data_reg << mem_data_shift;


    // take the mod of the data size and the MAC width
    assign last_msg_padbytes = hdr_flit_reg.data_size[`MAC_INTERFACE_BYTES_W-1:0] == 0
                        ?  '0
                        : `MAC_INTERFACE_BYTES - hdr_flit_reg.data_size[`MAC_INTERFACE_BYTES_W-1:0];
        
    assign last_data_byte_mask = {`MAC_INTERFACE_BYTES{1'b1}}<<(last_msg_padbytes);

    assign last_data_byte_en = {last_data_byte_mask,
                                {(mem_data_w_bytes - `MAC_INTERFACE_BYTES){1'b0}}} >> block_addr;
    assign body_data_byte_en = {{`MAC_INTERFACE_BYTES{1'b1}},
                                {(mem_data_w_bytes - `MAC_INTERFACE_BYTES){1'b0}}} >> block_addr;

    assign controller_mem_wr_data = {noc0_ctovr_controller_data, 
                                    {(mem_data_w_p - `MAC_INTERFACE_W){1'b0}}} >> mem_data_shift;

    always @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            hdr_flit_reg <= '0;
            curr_flit_count_reg <= '0;
            curr_op_addr_reg <= '0;
            read_flits_sent_reg <= '0;
            mem_read_data_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            hdr_flit_reg <= hdr_flit_next;
            curr_flit_count_reg <= curr_flit_count_next;
            curr_op_addr_reg <= curr_op_addr_next;
            read_flits_sent_reg <= read_flits_sent_next;
            mem_read_data_reg <= mem_read_data_next;
        end
    end

    always_comb begin
        hdr_flit_next = hdr_flit_reg;
        state_next = state_reg;
        curr_flit_count_next = curr_flit_count_reg;
        controller_noc0_ctovr_rdy = 1'b0;
        controller_noc0_vrtoc_val = 1'b0;
        controller_noc0_vrtoc_data = '0;

        curr_op_addr_next = curr_op_addr_reg;
        read_flits_sent_next = read_flits_sent_reg;

        case (state_reg)
            READY: begin
                controller_noc0_ctovr_rdy = 1'b1;

                if (noc0_ctovr_controller_val) begin
                    hdr_flit_next = noc0_ctovr_controller_data;
                    curr_op_addr_next = hdr_flit_cast.addr;
                    curr_flit_count_next = '0;

                    if (hdr_flit_cast.msg_type == `MSG_TYPE_STORE_MEM) begin
                        curr_flit_count_next = `MSG_LENGTH_WIDTH'd1;
                        state_next = WRITING;
                    end
                    else if (hdr_flit_cast.msg_type == `MSG_TYPE_LOAD_MEM) begin
                        state_next = RD_OP_ISSUE;
                    end
                    else begin
                        state_next = UND;
                    end
                end
                else begin
                    state_next = READY;
                end
            end
            RD_OP_ISSUE: begin
                controller_noc0_ctovr_rdy = 1'b0;

                if (mem_controller_rdy) begin
                    state_next = RD_OP_WAIT;
                end
                else begin
                    state_next = RD_OP_ISSUE;
                end
            end
            RD_OP_WAIT: begin
                if (mem_controller_rd_data_val) begin
                    if (curr_op_addr_reg == hdr_flit_reg.addr) begin
                        state_next = RD_HDR_FLIT;
                    end
                    else begin
                        state_next = RD_PAYLOAD_RESP;
                    end
                end
                else begin
                    state_next = RD_OP_WAIT;
                end
            end
            RD_HDR_FLIT: begin
                controller_noc0_ctovr_rdy = 1'b0;
                controller_noc0_vrtoc_val = 1'b1;
                controller_noc0_vrtoc_data = resp_hdr_flit;
                read_flits_sent_next = '0;

                if (noc0_vrtoc_controller_rdy) begin
                    state_next = RD_PAYLOAD_RESP;
                end
                else begin
                    state_next = RD_HDR_FLIT;
                end
            end
            RD_PAYLOAD_RESP: begin
                controller_noc0_ctovr_rdy = 1'b0;
                controller_noc0_vrtoc_val = 1'b1;
                controller_noc0_vrtoc_data = shifted_read_data[mem_data_w_p-1 -: `NOC_DATA_WIDTH];

                if (noc0_vrtoc_controller_rdy) begin
                    read_flits_sent_next = read_flits_sent_reg + 1'b1;
                    if (read_flits_sent_reg == (resp_hdr_flit.msg_len - 1)) begin
                        state_next = READY;
                    end
                    else begin
                        // if we're gonna roll over a line, go back to read memory
                        curr_op_addr_next = curr_op_addr_reg + `NOC_DATA_BYTES;

                        if (curr_op_addr_next[`MSG_ADDR_WIDTH-1:block_addr_w] != line_addr) begin
                            state_next = RD_OP_ISSUE;
                        end
                        else begin
                            state_next = RD_PAYLOAD_RESP;
                        end
                    end
                end
                else begin
                    state_next = RD_PAYLOAD_RESP;
                end
            end
            WRITING: begin
                controller_noc0_ctovr_rdy = mem_controller_rdy;
                
                if (noc0_ctovr_controller_val & mem_controller_rdy) begin
                    curr_flit_count_next = curr_flit_count_reg + 1'b1;
                    
                    if (curr_flit_count_reg == (hdr_flit_reg.msg_len)) begin
                        state_next = WR_RESP;
                    end
                    else begin
                        curr_op_addr_next = curr_op_addr_reg + `NOC_DATA_BYTES;
                        state_next = WRITING;
                    end
                end
                else begin
                    state_next = WRITING;
                end
            end
            WR_RESP: begin
                controller_noc0_ctovr_rdy = 1'b0;
                controller_noc0_vrtoc_val = 1'b1;
                controller_noc0_vrtoc_data = resp_hdr_flit;

                if (noc0_vrtoc_controller_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = WR_RESP;
                end
            end
            default: begin
            end
        endcase
    end

    // interface with memory module
    always_comb begin
        controller_mem_read_en = 1'b0;
        controller_mem_write_en = 1'b0;
        controller_mem_addr = '0;
        controller_mem_byte_en = '0;

        mem_read_data_next = mem_read_data_reg;

        case (state_reg)
            RD_OP_ISSUE: begin
                controller_mem_read_en = mem_controller_rdy;
                controller_mem_addr = line_addr[mem_addr_w_p-1:0];
            end
            RD_OP_WAIT: begin
                if (mem_controller_rd_data_val) begin
                    mem_read_data_next = mem_controller_rd_data;
                end
                else begin
                    mem_read_data_next = mem_read_data_reg;
                end
            end
            WRITING: begin
                controller_mem_write_en = mem_controller_rdy;
                controller_mem_addr = line_addr[mem_addr_w_p-1:0];
                if (curr_flit_count_reg == hdr_flit_reg.msg_len) begin
                    controller_mem_byte_en = last_data_byte_en;
                end
                else begin
                    controller_mem_byte_en = body_data_byte_en;
                end
            end
        endcase
    end

    assign resp_msg_len = hdr_flit_reg.data_size[`NOC_DATA_BYTES_W-1:0] == 0
                        ? hdr_flit_reg.data_size >> `NOC_DATA_BYTES_W
                        : (hdr_flit_reg.data_size >> `NOC_DATA_BYTES_W) + 1;

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
