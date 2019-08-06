module logger_addr_mux #(
     parameter LOG_ADDR_W = 13
)(
     input clk
    ,input rst

    ,input                  rd_cmd_queue_empty
    ,output logic           rd_cmd_queue_rd_req
    ,input          [63:0]  rd_cmd_queue_rd_data
    
    ,output logic                       rd_resp_val
    ,output logic   [63:0]              rd_cmd_resp

    ,input          [LOG_ADDR_W-1:0]    curr_log_wr_addr
    ,input                              has_wrapped

    ,output logic                       log_rd_req_val
    ,output logic   [LOG_ADDR_W-1:0]    log_rd_req_addr

    ,input                              log_rd_resp_val
    ,input          [63:0]              log_rd_resp_data
);

    typedef struct packed {
        logic                       get_metadata;
        logic   [LOG_ADDR_W-1:0]    log_addr_req;
    } rd_cmd_struct;
    localparam RD_CMD_STRUCT_W = 1 + LOG_ADDR_W;

    typedef enum logic[1:0] {
        READY = 2'd0,
        RD_REQ = 2'd1,
        RD_RESP = 2'd2,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    logic           store_cmd;
    logic   [63:0]  rd_cmd_queue_data_reg;
    logic   [63:0]  rd_cmd_queue_data_next;

    rd_cmd_struct rd_cmd_struct_cast;

    assign rd_cmd_struct_cast = rd_cmd_queue_data_reg[RD_CMD_STRUCT_W-1:0];


    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            rd_cmd_queue_data_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            rd_cmd_queue_data_reg <= rd_cmd_queue_data_next;
        end
    end

    assign rd_cmd_queue_data_next = store_cmd 
                                    ? rd_cmd_queue_rd_data
                                    : rd_cmd_queue_data_reg;

    assign log_rd_req_addr = rd_cmd_struct_cast.log_addr_req;

    always_comb begin
        store_cmd = 1'b0;
        rd_resp_val = 1'b0;
        rd_cmd_queue_rd_req = 1'b0;
        log_rd_req_val = 1'b0;
        state_next = state_reg;
        case (state_reg)
            READY: begin
                if (~rd_cmd_queue_empty) begin
                    rd_cmd_queue_rd_req = 1'b1;
                    store_cmd = 1'b1;

                    state_next = RD_REQ;
               end 
               else begin
                   state_next = READY;
               end
            end 
            RD_REQ: begin
                log_rd_req_val = 1'b1;

                state_next = RD_RESP; 
            end
            RD_RESP: begin
                if (log_rd_resp_val | rd_cmd_struct_cast.get_metadata) begin
                    rd_resp_val = 1'b1;
                    state_next = READY;
                end 
                else begin
                    state_next = RD_RESP;
                end
            end
        endcase
    end

    logic   [63:0]  meta_data;
    assign meta_data = {{(64 -  LOG_ADDR_W - 1){1'b0}}, has_wrapped, curr_log_wr_addr};

    always_comb begin
        if (rd_cmd_struct_cast.get_metadata) begin
            if (rd_cmd_struct_cast.log_addr_req == 0) begin
                rd_cmd_resp = meta_data;
            end
            else begin
                rd_cmd_resp = {64{1'b1}}; 
            end
        end
        else begin
            rd_cmd_resp = log_rd_resp_data;
        end
    end
endmodule
