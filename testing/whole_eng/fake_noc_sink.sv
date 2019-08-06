`include "noc_defs.vh"
`include "noc_struct_defs.vh"

module fake_noc_sink (
     input clk
    ,input rst

    ,input                                  rx_pipe_noc0_val
    ,input          [`NOC_DATA_WIDTH-1:0]   rx_pipe_noc0_data
    ,output logic                           noc0_rx_pipe_rdy

    ,output logic                           noc0_rx_pipe_val 
    ,output logic   [`NOC_DATA_WIDTH-1:0]   noc0_rx_pipe_data
    ,input                                  rx_pipe_noc0_rdy
);

    typedef enum logic[1:0] {
        READY = 2'd0,
        RECV_PAYLOAD = 2'd2,
        SEND_RESP = 2'd3,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;
    
    logic   init_metadata;
    logic   incr_flits_rxed;

    noc_hdr_flit    req_flit_reg;
    noc_hdr_flit    req_flit_next;
    noc_hdr_flit    resp_hdr_flit;

    logic   [`MSG_LENGTH_WIDTH-1:0] flits_rxed_reg;
    logic   [`MSG_LENGTH_WIDTH-1:0] flits_rxed_next;

    assign noc0_rx_pipe_data = resp_hdr_flit;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            req_flit_reg <= '0;
            flits_rxed_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            req_flit_reg <= req_flit_next;
            flits_rxed_reg <= flits_rxed_next;
        end
    end

    always_comb begin
        init_metadata = 1'b0;
        incr_flits_rxed = 1'b0;

        noc0_rx_pipe_rdy = 1'b0;
        noc0_rx_pipe_val = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                noc0_rx_pipe_rdy = 1'b1;
                if (rx_pipe_noc0_val) begin
                    init_metadata = 1'b1;
                    state_next = RECV_PAYLOAD;
                end
                else begin
                    state_next = READY;
                end
            end
            RECV_PAYLOAD: begin
                noc0_rx_pipe_rdy = 1'b1;
                if (rx_pipe_noc0_val) begin
                    incr_flits_rxed = 1'b1;
                    if (flits_rxed_next == req_flit_reg.msg_len) begin
                        state_next = SEND_RESP;
                    end
                    else begin
                        state_next = RECV_PAYLOAD;
                    end
                end
                else begin
                    state_next = RECV_PAYLOAD;
                end
            end
            SEND_RESP: begin
                noc0_rx_pipe_val = 1'b1;
                if (rx_pipe_noc0_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = SEND_RESP;
                end
            end
        endcase
    end

    assign req_flit_next = init_metadata
                         ? rx_pipe_noc0_data
                         : req_flit_reg;

    always_comb begin
        if (init_metadata) begin
            flits_rxed_next = '0;
        end
        else if (incr_flits_rxed) begin
            flits_rxed_next = flits_rxed_reg + 1'b1;
        end
        else begin
            flits_rxed_next = flits_rxed_reg;
        end
    end
    
    // response flit crafting
    always_comb begin
        resp_hdr_flit = '0;
        resp_hdr_flit.dst_chip_id = req_flit_reg.src_chip_id;
        resp_hdr_flit.dst_x_coord = req_flit_reg.src_x_coord;
        resp_hdr_flit.dst_y_coord = req_flit_reg.src_y_coord;
        resp_hdr_flit.fbits = req_flit_reg.src_fbits;
        resp_hdr_flit.data_size = req_flit_reg.data_size;

        resp_hdr_flit.src_chip_id = '0;
        resp_hdr_flit.src_x_coord = 1;
        resp_hdr_flit.src_y_coord = 1;

        resp_hdr_flit.msg_len = '0;
        resp_hdr_flit.msg_type = `MSG_TYPE_STORE_MEM_ACK;
    end
endmodule
