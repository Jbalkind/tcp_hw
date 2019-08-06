`include "noc_defs.vh"

module fake_dram_controller #(
         parameter mem_els_p = -1
        ,parameter mem_addr_w_p = `BSG_SAFE_CLOG2(mem_els_p)
        ,parameter mem_data_w_p = -1
        ,parameter mem_wr_mask_w_p = mem_data_w_p >> 3
    )
    (
     input clk
    ,input rst

    ,input                                      noc0_ctovr_controller_val
    ,input          [`NOC_DATA_WIDTH-1:0]       noc0_ctovr_controller_data
    ,output logic                               controller_noc0_ctovr_rdy

    ,output logic                               controller_noc0_vrtoc_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       controller_noc0_vrtoc_data
    ,input                                      noc0_vrtoc_controller_rdy

    ,output logic                               controller_mem_val
    ,output logic                               controller_mem_wren
    ,output logic   [mem_wr_mask_w_p-1:0]       controller_mem_wr_mask
    ,output logic   [`BSG_SAFE_CLOG2(512)-1:0]  controller_mem_addr
    ,output logic   [mem_data_w_p-1:0]          controller_mem_data
    ,input                                      mem_controller_rdy

    ,input                                      mem_controller_val
    ,input          [mem_data_w_p-1:0]          mem_controller_data
);

    typedef enum logic [2:0] {READY = 0, 
                    HEADER_2 = 1, 
                    HEADER_3 = 2, 
                    READING = 3, 
                    READ_HEADER_RESP = 4,
                    READ_PAYLOAD_RESP = 5, 
                    WRITING = 6, 
                    WRITE_RESP = 7,
                    UNDEFINED = 'x} states;

    //localparam STATE_WIDTH = 3;
    //localparam READY = 3'b000;
    //localparam HEADER_2 = 3'b001;
    //localparam HEADER_3 = 3'b011;
    //localparam READ = 3'b100;
    //localparam READ_RESP = 3'b101;
    //localparam WRITE = 3'b110;
    //localparam WRITE_RESP = 3'b111;
    
    localparam mem_data_index_w = `BSG_SAFE_CLOG2(mem_data_w_p);
    localparam mem_data_w_bytes = mem_data_w_p >> 3;
    localparam block_addr_width = `BSG_SAFE_CLOG2(mem_data_w_bytes);

    states  prev_state_reg;
    states  state_reg;
    states  state_next;

    logic   [`MSG_LENGTH_WIDTH-1:0]         curr_flit_count_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0]         curr_flit_count_next;

    logic   [mem_data_w_p-1:0]              mem_read_data_reg;
    logic   [mem_data_w_p-1:0]              mem_read_data_next;
    logic   [mem_data_index_w-1:0]          mem_read_data_top_index;

    logic   [`MSG_LENGTH_WIDTH-1:0]         read_flits_sent_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0]         read_flits_sent_next;

    logic   [`MSG_ADDR_WIDTH-1:0]              curr_op_addr_reg;
    logic   [`MSG_ADDR_WIDTH-1:0]              curr_op_addr_next;

    
    logic   [mem_wr_mask_w_p-1:0]                       curr_write_mask;
    logic   [`BSG_SAFE_CLOG2(mem_wr_mask_w_p)-1:0]      write_mask_shift;
    
    logic   [block_addr_width-1:0]                      block_addr;
    logic   [`MSG_ADDR_WIDTH - block_addr_width - 1:0] line_addr;
    
    logic [`MSG_DATA_SIZE_WIDTH-1:0]        data_size_shifted;

    logic   [`BSG_SAFE_CLOG2(mem_data_w_p)-1:0]       write_data_shift;

    noc_header_flit_1 header1_flit;
    noc_header_flit_2 header2_flit;
    noc_header_flit_3 header3_flit;

    noc_header_flit_1 resp_header_flit;
    
    noc_header_flit_1 header1_flit_reg;
    noc_header_flit_2 header2_flit_reg;
    noc_header_flit_3 header3_flit_reg;
    
    noc_header_flit_1 header1_flit_next;
    noc_header_flit_2 header2_flit_next;
    noc_header_flit_3 header3_flit_next;

    always @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            prev_state_reg <= READY;
            curr_flit_count_reg <= 'b0;
            mem_read_data_reg <= 'b0;
            header1_flit_reg <= 'b0;
            header2_flit_reg <= 'b0;
            header3_flit_reg <= 'b0;
            
            read_flits_sent_reg <= 'b0;
            curr_op_addr_reg <= '0;
        end
        else begin
            prev_state_reg <= state_reg;
            state_reg <= state_next;
            curr_flit_count_reg <= curr_flit_count_next;
            mem_read_data_reg <= mem_read_data_next;

            header1_flit_reg <= header1_flit_next;
            header2_flit_reg <= header2_flit_next;
            header3_flit_reg <= header3_flit_next;

            read_flits_sent_reg <= read_flits_sent_next;
            curr_op_addr_reg <= curr_op_addr_next;
        end
    end
    
    // starting from the top bit, get the bit that corresponds to the address requested
    // then subtract off the number of flits we've sent so far
    assign mem_read_data_top_index = (mem_data_w_p[mem_data_index_w-1:0] - 1) 
                                     - ({3'b0, block_addr} << 3);

    always @(*) begin
        header1_flit_next = header1_flit_reg;
        header2_flit_next = header2_flit_reg;
        header3_flit_next = header3_flit_reg;
        curr_flit_count_next = curr_flit_count_reg;
        controller_noc0_ctovr_rdy = 1'b0;
        controller_noc0_vrtoc_val = 1'b0;
        state_next = state_reg;
        read_flits_sent_next = read_flits_sent_reg;
        curr_op_addr_next = curr_op_addr_reg;

        case (state_reg) 
            // wait for and store the first header flit
            READY: begin
                controller_noc0_ctovr_rdy = 1'b1;

                if (noc0_ctovr_controller_val) begin
                    state_next = HEADER_2;
                    header1_flit_next = noc0_ctovr_controller_data;
                    curr_flit_count_next = curr_flit_count_reg + 1'b1;
                end
                else begin
                    header1_flit_next = header1_flit_reg;
                    state_next = state_reg;
                    curr_flit_count_next = curr_flit_count_reg;
                end
            end
            // store the second header flit
            HEADER_2: begin
                controller_noc0_ctovr_rdy = 1'b1;

                if (noc0_ctovr_controller_val) begin
                    header2_flit_next = noc0_ctovr_controller_data;
                    curr_op_addr_next = header2_flit_next.addr;
                    state_next = HEADER_3;
                    curr_flit_count_next = curr_flit_count_reg + 1'b1;
                end
                else begin
                    header2_flit_next = header2_flit_reg;
                    curr_op_addr_next = curr_op_addr_reg;
                    state_next = HEADER_2;
                    curr_flit_count_next = curr_flit_count_reg;
                end
            end
            // store the third header flit
            HEADER_3: begin
                controller_noc0_ctovr_rdy = 1'b1;

                if (noc0_ctovr_controller_val) begin
                    header3_flit_next = noc0_ctovr_controller_data;

                    if (header1_flit_reg.msg_type == `MSG_TYPE_STORE_MEM) begin
                        curr_flit_count_next = curr_flit_count_reg + 1'b1;
                        state_next = WRITING;
                    end
                    else if (header1_flit_reg.msg_type == `MSG_TYPE_LOAD_MEM) begin
                        curr_flit_count_next = 'b0;
                        state_next = READING;
                    end
                    else begin
                        curr_flit_count_next = 'b0;
                        state_next = UNDEFINED;
                    end
                end
                else begin
                    header3_flit_next = header3_flit_reg;
                    curr_flit_count_next = curr_flit_count_reg;
                    state_next = HEADER_3;
                end
            end
            // issue the read request to the memory
            READING: begin
                controller_noc0_ctovr_rdy = 1'b0;
   
                // TODO: we actually need to wait here for a READ valid signal, but we don't
                // deal with that right now
                if (mem_controller_rdy) begin
                    // if we're on the initial read
                    if (curr_op_addr_reg == header2_flit_reg.addr) begin
                        state_next = READ_HEADER_RESP;
                    end
                    // otherwise, we got here, because we rolled over a memory line
                    else begin
                        state_next = READ_PAYLOAD_RESP;
                    end
                end
                else begin
                    state_next = READING;
                end
            end
            // send the read header response, once we've gotten the read request back
            READ_HEADER_RESP: begin
                controller_noc0_ctovr_rdy = 1'b0;
                controller_noc0_vrtoc_val = 1'b1;

                if (noc0_vrtoc_controller_rdy) begin
                    state_next = READ_PAYLOAD_RESP;
                end
                else begin
                    state_next = READ_HEADER_RESP;
                end
            end
            // send the rest of the payload
            READ_PAYLOAD_RESP: begin
                controller_noc0_vrtoc_val = 1'b1;

                // if the noc is ready for our payloads
                if (noc0_vrtoc_controller_rdy) begin

                    // we're currently sending the last flit, so we can reset the counter
                    // and move back to READY
                    if (read_flits_sent_reg == (resp_header_flit.msg_len - 1)) begin
                        read_flits_sent_next = 'b0;
                        curr_op_addr_next = curr_op_addr_reg;
                        state_next = READY;
                    end
                    // Otherwise, we're sending some non-last flit and we should stay here
                    // Increment the number of flits we've sent though
                    else begin
                        curr_op_addr_next = curr_op_addr_reg + 8;
                        read_flits_sent_next = read_flits_sent_reg + 1'b1;

                        // if we're about to roll over a line, go back to read the memory
                        if (curr_op_addr_next[block_addr_width-1:0] == 0) begin
                            state_next = READING;
                        end
                        // otherwise, we're fine to read the next 8 byte segment
                        else begin
                            state_next = READ_PAYLOAD_RESP;
                        end
                    end
                end
                else begin
                    read_flits_sent_next = read_flits_sent_reg;
                    curr_op_addr_next = curr_op_addr_reg;
                    state_next = READ_PAYLOAD_RESP;
                end
            end
            WRITING: begin
                controller_noc0_ctovr_rdy = mem_controller_rdy;

                if (noc0_ctovr_controller_val) begin
                    if (mem_controller_rdy) begin
                        // if we're on the last data flit
                        if (curr_flit_count_reg == header1_flit_reg.msg_len) begin
                            state_next = WRITE_RESP;
                            curr_op_addr_next = curr_op_addr_reg;
                            curr_flit_count_next = 'b0;
                        end
                        // otherwise, we're reading data flits as normal
                        else begin
                            state_next = WRITING;
                            curr_op_addr_next = curr_op_addr_next + 8;
                            curr_flit_count_next = curr_flit_count_reg + 1'b1;
                        end
                    end
                    else begin
                        state_next = WRITING;
                        curr_op_addr_next = curr_op_addr_reg;
                        curr_flit_count_next = curr_flit_count_reg;
                    end
                end
                else begin
                    state_next = WRITING;
                    curr_op_addr_next = curr_op_addr_reg;
                    curr_flit_count_next = curr_flit_count_reg;
                end
            end
            WRITE_RESP: begin
                controller_noc0_ctovr_rdy = 1'b0;

                controller_noc0_vrtoc_val = 1'b1;

                if (noc0_vrtoc_controller_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = WRITE_RESP;
                end
            end
            default: begin
                controller_noc0_ctovr_rdy = 'bX;
                state_next = UNDEFINED;
                header1_flit_next = 'bX;
                header2_flit_next = 'bX;
                controller_noc0_ctovr_rdy = 1'bX;
                controller_noc0_vrtoc_val = 1'bX;
            end
        endcase
    end



    assign block_addr = curr_op_addr_reg[block_addr_width-1:0];
    assign line_addr = curr_op_addr_reg[`MSG_ADDR_WIDTH-1:block_addr_width];
    assign curr_write_mask = 64'hff00_0000_0000_0000 >> (block_addr);

    // get the starting bit value with block_addr, add on based on how many flits we've seen
    assign write_data_shift = (block_addr << 3);

    // interface with memory module
    always @(*) begin
        controller_mem_val = 'b0;
        controller_mem_wren = 'b0;
        controller_mem_data = 'b0;
        controller_mem_addr = 'b0;
        controller_mem_wr_mask = 'b0;
        mem_read_data_next = mem_read_data_reg;
        case (state_reg)
            READING: begin
                // TODO: we need to make sure we only issue one read request for an actual DRAM
                controller_mem_val = 1'b1;
                // 64 byte align
                controller_mem_addr = line_addr[mem_addr_w_p-1:0];
            end
            READ_HEADER_RESP: begin
                mem_read_data_next = mem_controller_data;
            end
            READ_PAYLOAD_RESP: begin
                if (prev_state_reg == READING) begin
                    mem_read_data_next = mem_controller_data;
                end
                else begin
                    mem_read_data_next = mem_read_data_reg;
                end
            end
            WRITING: begin
                controller_mem_val = noc0_ctovr_controller_val;
                controller_mem_wren = noc0_ctovr_controller_val;
                controller_mem_data = {noc0_ctovr_controller_data, {(mem_data_w_p - `NOC_DATA_WIDTH){1'b0}}} >> write_data_shift;

                controller_mem_wr_mask = curr_write_mask;
                // 64 byte align
                controller_mem_addr = line_addr[mem_addr_w_p-1:0];
            end      
            default: begin
                controller_mem_val = 'b0;
                controller_mem_wren = 'b0;
                controller_mem_data = 'b0;
                controller_mem_addr = 'b0;
                mem_read_data_next = mem_read_data_reg;
            end
        endcase
    end

    always @(*) begin

        case (state_reg) 
            READ_HEADER_RESP: begin
                controller_noc0_vrtoc_data = resp_header_flit;
            end
            READ_PAYLOAD_RESP: begin
                if (prev_state_reg == READING) begin
                    controller_noc0_vrtoc_data = mem_read_data_next[mem_read_data_top_index -: `NOC_DATA_WIDTH];
                end
                else begin
                    controller_noc0_vrtoc_data = mem_read_data_reg[mem_read_data_top_index -: `NOC_DATA_WIDTH];
                end
            end
            WRITE_RESP: begin
                controller_noc0_vrtoc_data = resp_header_flit;
            end
            default: begin
                controller_noc0_vrtoc_data = 'b0;
            end
        endcase
    end

    assign data_size_shifted = header3_flit_reg.data_size >> 3;

    // response flit crafting
    always @(*) begin
        resp_header_flit.dst_chip_id = header3_flit_reg.src_chip_id;
        resp_header_flit.dst_x_coord = header3_flit_reg.src_x_coord;
        resp_header_flit.dst_y_coord = header3_flit_reg.src_y_coord;
        resp_header_flit.fbits = header3_flit_reg.src_fbits;
        //resp_header_flit.fbits = 'b0;

        if (header1_flit_reg.msg_type == `MSG_TYPE_STORE_MEM) begin
            resp_header_flit.msg_len = 'b0;
            resp_header_flit.msg_type = `MSG_TYPE_STORE_MEM_ACK;
        end
        else if (header1_flit_reg.msg_type == `MSG_TYPE_LOAD_MEM) begin
            resp_header_flit.msg_len = data_size_shifted[`MSG_LENGTH_WIDTH-1:0];
            resp_header_flit.msg_type = `MSG_TYPE_LOAD_MEM_ACK;
        end
        else begin
            resp_header_flit.msg_len = 'b0;
            resp_header_flit.msg_type = 'b0;
        end
    end

endmodule
