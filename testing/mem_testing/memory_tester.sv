`include "packet_defs.vh"
`include "state_defs.vh"
`include "noc_defs.vh"
`include "soc_defs.vh"

module memory_tester(
     input clk
    ,input rst
    
    // I/O for the MAC
    ,input                                      mac_val
    ,input  [`MAC_INTERFACE_W-1:0]              mac_data
    ,input  [`MSG_DATA_SIZE_WIDTH-1:0]          mac_data_size
    ,input  [`MSG_ADDR_WIDTH-1:0]               mac_data_addr
    ,output logic                               mac_rdy
    
    ,output logic                               write_complete_notif_val
    ,output logic   [`MSG_ADDR_WIDTH-1:0]       write_complete_notif_addr

    ,input                                      app_read_req_val
    ,input  [`MSG_ADDR_WIDTH-1:0]               app_read_req_addr
    ,input  [`MSG_DATA_SIZE_WIDTH-1:0]          app_read_req_size

    ,output logic                               app_read_resp_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       app_read_resp_data
    
    // I/O for the NoC
    ,output logic                               parser_noc0_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       parser_noc0_data
    ,input                                      noc0_parser_rdy
    
    ,input                                      noc0_parser_val
    ,input  [`NOC_DATA_WIDTH-1:0]               noc0_parser_data
    ,output                                     parser_noc0_rdy

);

    typedef enum logic[2:0]{
        READY = 3'd0, 
        HEADER_FLIT = 3'd1,
        PAYLOAD = 3'd2,
        WRITE_RESP = 3'd3,
        READ_RESP_HEADER = 3'd4,
        READ_RESP_PAYLOAD = 3'd5,
        UND = 'X
    } states;

    logic   [`NOC_DATA_WIDTH-1:0]   noc_data_reg;
    logic   [`NOC_DATA_WIDTH-1:0]   noc_data_next;

    logic   [`MSG_ADDR_WIDTH-1:0]   mac_data_addr_reg;
    logic   [`MSG_ADDR_WIDTH-1:0]   mac_data_addr_next;

    logic   [`MAC_INTERFACE_W-1:0]  mac_data_reg;
    logic   [`MAC_INTERFACE_W-1:0]  mac_data_next;
    logic                           mac_val_reg;

    logic   [`MSG_DATA_SIZE_WIDTH-1:0]  mac_data_size_reg;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]  mac_data_size_next;

    logic   [`MSG_ADDR_WIDTH-1:0]       app_read_req_addr_reg;
    logic   [`MSG_ADDR_WIDTH-1:0]       app_read_req_addr_next;

    logic   [`MSG_DATA_SIZE_WIDTH-1:0]  app_read_req_size_reg;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]  app_read_req_size_next;
    
    states state_reg;
    states state_next;

    logic   [`MSG_LENGTH_WIDTH-1:0] flits_sent_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0] flits_sent_next;

    logic   [`MSG_LENGTH_WIDTH-1:0] total_msg_flits_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0] total_msg_flits_next;

    logic   [`MSG_TYPE_WIDTH-1:0]   message_type_reg;
    logic   [`MSG_TYPE_WIDTH-1:0]   message_type_next;

    
    logic   [`MSG_ADDR_WIDTH-1:0]   curr_write_addr_reg;
    logic   [`MSG_ADDR_WIDTH-1:0]   curr_write_addr_next;

    logic   [`MSG_LENGTH_WIDTH-1:0] read_payload_flits_recv_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0] read_payload_flits_recv_next;

    logic   [`NOC_DATA_BYTES_W-1:0]         last_flit_padbytes;
    logic   [$clog2(`NOC_DATA_WIDTH)-1:0]   last_flit_mask_shift;
    logic   [`NOC_DATA_WIDTH-1:0]           last_flit_data_mask;
    
    noc_hdr_flit hdr_flit;
    
    noc_hdr_flit resp_flit_reg;
    noc_hdr_flit resp_flit_next;
    noc_hdr_flit resp_flit_cast;

    assign resp_flit_cast = noc0_parser_data;

    assign parser_noc0_rdy = 1'b1;

    assign write_complete_notif_addr = curr_write_addr_reg;

    assign last_flit_padbytes = resp_flit_reg.data_size[`NOC_DATA_BYTES_W-1:0] == 0
                              ? '0
                              : `NOC_DATA_BYTES - resp_flit_reg.data_size[`NOC_DATA_BYTES_W-1:0];
    assign last_flit_mask_shift = last_flit_padbytes << 3;

    assign last_flit_data_mask = {`NOC_DATA_WIDTH{1'b1}} << (last_flit_mask_shift);


    always @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            flits_sent_reg <= '0;
            total_msg_flits_reg <= '0;
            message_type_reg <= '0;
            resp_flit_reg <= '0;
            read_payload_flits_recv_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            flits_sent_reg <= flits_sent_next;
            total_msg_flits_reg <= total_msg_flits_next;
            message_type_reg <= message_type_next;
            resp_flit_reg <= resp_flit_next;
            read_payload_flits_recv_reg <= read_payload_flits_recv_next;
        end
    end



    always @(*) begin
        mac_rdy = 1'b1;
        total_msg_flits_next = total_msg_flits_reg;
        flits_sent_next = flits_sent_reg;
        parser_noc0_data = '0;
        parser_noc0_val = 1'b0;

        mac_data_next = mac_data_reg;
        mac_data_size_next = mac_data_size_reg;
        mac_data_addr_next = mac_data_addr_reg;
        curr_write_addr_next = curr_write_addr_reg;
        app_read_req_addr_next = app_read_req_addr_reg;
        app_read_req_size_next = app_read_req_size_reg;

        app_read_resp_val = 1'b0;
        app_read_resp_data = '0;

        message_type_next = message_type_reg;
        write_complete_notif_val = 1'b0;
        resp_flit_next = resp_flit_reg;
        read_payload_flits_recv_next = read_payload_flits_recv_reg;

        case (state_reg)
            READY: begin
                mac_rdy = 1'b1;
                parser_noc0_val = 1'b0;
                parser_noc0_data = '0;

                if (mac_val) begin
                    state_next = HEADER_FLIT;
                    mac_data_next = mac_data;
                    mac_data_size_next = mac_data_size;
                    mac_data_addr_next = mac_data_addr;
                    app_read_req_addr_next = app_read_req_addr_reg;
                    app_read_req_size_next = app_read_req_size_reg;

                    total_msg_flits_next = (mac_data_size[`MAC_PADBYTES_W-1:0] == 0)
                                          ? mac_data_size >> `MAC_PADBYTES_W
                                          : (mac_data_size >> `MAC_PADBYTES_W) + 1;

                    message_type_next = `MSG_TYPE_STORE_MEM;
                end
                else if (app_read_req_val) begin
                    state_next = HEADER_FLIT;
                    mac_data_next = mac_data_reg;
                    mac_data_size_next = mac_data_size_reg;
                    mac_data_addr_next = mac_data_addr_reg;
                    app_read_req_addr_next = app_read_req_addr;
                    app_read_req_size_next = app_read_req_size;

                    total_msg_flits_next = '0;

                    message_type_next = `MSG_TYPE_LOAD_MEM;

                end
                else begin
                    state_next = READY;
                    mac_data_next = mac_data_reg;
                    mac_data_size_next = mac_data_size_reg;
                    mac_data_addr_next = mac_data_addr_reg;
                    app_read_req_addr_next = app_read_req_addr_reg;
                    app_read_req_size_next = app_read_req_size_reg;

                    total_msg_flits_next = total_msg_flits_reg;

                    message_type_next = message_type_reg;
                end
            end
            HEADER_FLIT: begin
                mac_rdy = 1'b0;

                parser_noc0_data = hdr_flit;
                parser_noc0_val = 1'b1;

                if (noc0_parser_rdy) begin
                    if (message_type_reg == `MSG_TYPE_STORE_MEM) begin
                        state_next = PAYLOAD;
                    end
                    else if (message_type_reg == `MSG_TYPE_LOAD_MEM) begin
                        flits_sent_next = '0;
                        state_next = READ_RESP_HEADER;
                    end
                    else begin
                        flits_sent_next = flits_sent_reg;
                        state_next = HEADER_FLIT;
                    end
                end
                else begin
                    flits_sent_next = flits_sent_reg;
                    state_next = HEADER_FLIT;
                end
            end
            PAYLOAD: begin
                mac_rdy = 1'b0;

                parser_noc0_data = mac_data_reg;
                parser_noc0_val = 1'b1;

                if (noc0_parser_rdy) begin
                    mac_data_next = mac_data_reg + 1'b1;
                    if ((flits_sent_reg + 1) == total_msg_flits_reg) begin
                        state_next = WRITE_RESP;
                        flits_sent_next = '0;
                    end
                    else begin
                        state_next = PAYLOAD;
                        flits_sent_next = flits_sent_reg + 1'b1;
                    end
                end
                else begin
                    mac_data_next = mac_data_reg;
                    flits_sent_next = flits_sent_reg;
                    state_next = PAYLOAD;
                end
            end
            WRITE_RESP: begin
                mac_rdy = 1'b0;
                parser_noc0_val = 1'b0;
                if (noc0_parser_val) begin
                    resp_flit_next = noc0_parser_data;
                    if (resp_flit_cast.msg_type == `MSG_TYPE_STORE_MEM_ACK) begin
                        state_next = READY;
                        write_complete_notif_val = 1'b1;
                        curr_write_addr_next = (curr_write_addr_reg + hdr_flit.data_size);
                    end
                    else begin
                        state_next = WRITE_RESP;
                        curr_write_addr_next = curr_write_addr_reg;
                    end
                end
                else begin
                    state_next = WRITE_RESP;
                    curr_write_addr_next = curr_write_addr_reg;
                end
            end
            READ_RESP_HEADER: begin
                mac_rdy = 1'b0;
                parser_noc0_val = 1'b0;
                
                if (noc0_parser_val) begin
                    resp_flit_next = noc0_parser_data;
                    state_next = READ_RESP_PAYLOAD;
                end
                else begin
                    state_next = READ_RESP_HEADER;
                end
            end
            READ_RESP_PAYLOAD: begin
                mac_rdy = 1'b0;
                parser_noc0_val = 1'b0;

                app_read_resp_val = noc0_parser_val;
                app_read_resp_data = noc0_parser_data;

                
                if (noc0_parser_val) begin
                    if (read_payload_flits_recv_reg == (resp_flit_reg.msg_len - 1)) begin
                        app_read_resp_data = noc0_parser_data & last_flit_data_mask;
                        read_payload_flits_recv_next = '0;
                        state_next = READY;
                    end
                    else begin
                        read_payload_flits_recv_next = read_payload_flits_recv_reg + 1'b1;
                        state_next = READ_RESP_PAYLOAD;
                    end
                end
                else begin
                    read_payload_flits_recv_next = read_payload_flits_recv_reg;
                    state_next = READ_RESP_PAYLOAD;
                end
            end
            default: begin
                mac_rdy = 'X;
                state_next = UND;
                mac_data_next = 'X;
                parser_noc0_data = 'X;
                parser_noc0_val = 'X;
            end
        endcase
    end

    // fill some header flits
    always @(*) begin
        hdr_flit = '0;
        hdr_flit.dst_chip_id = 'b0;
        hdr_flit.dst_x_coord = 'b1;
        hdr_flit.dst_y_coord = 'b0;
        hdr_flit.fbits = 'b0;
        hdr_flit.msg_len = total_msg_flits_reg;
        hdr_flit.msg_type = message_type_reg;

        hdr_flit.addr = 'b0;

        hdr_flit.src_chip_id = 'b0;
        hdr_flit.src_x_coord = 'b0;
        hdr_flit.src_y_coord = 'b0;
        hdr_flit.src_fbits = 'b0;
        hdr_flit.data_size = 'b0;

        if (message_type_reg == `MSG_TYPE_STORE_MEM) begin
            hdr_flit.addr = mac_data_addr_reg;
            hdr_flit.data_size = mac_data_size_reg;
        end
        else if (message_type_reg == `MSG_TYPE_LOAD_MEM) begin
            hdr_flit.addr = app_read_req_addr_reg;
            hdr_flit.data_size = app_read_req_size_reg;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            noc_data_reg <= '0;
            mac_data_reg <= '0;
            mac_val_reg <= '0;
            mac_data_size_reg <= '0;
            mac_data_addr_reg <= '0;
            app_read_req_addr_reg <= '0;
            app_read_req_size_reg <= '0;

            curr_write_addr_reg <= '0;
        end
        else begin
            noc_data_reg <= noc_data_next;
            mac_data_reg <= mac_data_next;
            mac_val_reg <= mac_val;
            mac_data_size_reg <= mac_data_size_next;
            mac_data_addr_reg <= mac_data_addr_next;
            app_read_req_addr_reg <= app_read_req_addr_next;
            app_read_req_size_reg <= app_read_req_size_next;
            
            curr_write_addr_reg <= curr_write_addr_next;
        end
    end

    always @(*) begin
        if (noc0_parser_val) begin
            noc_data_next = noc0_parser_data; 
        end
        else begin
            noc_data_next = noc_data_reg;
        end
    end

    
endmodule
