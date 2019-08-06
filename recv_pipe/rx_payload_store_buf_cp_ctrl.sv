`include "noc_defs.vh"

module rx_payload_store_buf_cp_ctrl (
     input clk
    ,input rst
    
    ,output logic                                   read_store_buf_q_req_val
    ,input logic                                    read_store_buf_q_empty
    
    ,output logic                                   store_buf_tmp_buf_store_rx_rd_req_val
    ,input  logic                                   tmp_buf_store_store_buf_rx_rd_req_rdy

    ,input  logic                                   tmp_buf_store_store_buf_rx_rd_resp_val
    ,output logic                                   store_buf_tmp_buf_store_rx_rd_resp_rdy

    ,output logic                                   store_buf_tmp_buf_free_slab_rx_req_val
    ,input  logic                                   tmp_buf_free_slab_store_buf_rx_req_rdy
    
    ,output logic                                   store_buf_commit_ptr_rd_req_val
    ,input  logic                                   commit_ptr_store_buf_rd_req_rdy
                                                                            
    ,input  logic                                   commit_ptr_store_buf_rd_resp_val
    ,output logic                                   store_buf_commit_ptr_rd_resp_rdy

    ,output logic                                   store_buf_commit_ptr_wr_req_val
    ,input  logic                                   commit_ptr_store_buf_wr_req_rdy

    ,output logic                                   ctrl_wr_buf_req_val   
    ,input  logic                                   wr_buf_ctrl_req_rdy

    ,output logic                                   ctrl_wr_buf_req_data_val
    ,input  logic                                   wr_buf_ctrl_req_data_rdy

    ,input  logic                                   wr_buf_ctrl_wr_req_done
    ,output logic                                   ctrl_wr_buf_wr_req_done_rdy
    
    ,output logic                                   save_q_entry
    ,output logic                                   save_commit_ptr
    ,output logic                                   init_tmp_buf_rd_metadata
    ,output logic                                   update_tmp_buf_rd_metadata

    ,input  logic                                   last_transfer
    ,input  logic                                   accept_payload
    ,input  logic                                   pkt_len_0
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        COMMIT_PTR_RESP = 3'd1,
        WR_REQ = 3'd2,
        DATA_COPY_START = 3'd3,
        DATA_COPY = 3'd4,
        DATA_COPY_WAIT = 3'd5,
        UPDATE_POINTER = 3'd6,
        FREE_NON_ACCEPTED = 3'd7,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    always_comb begin
        ctrl_wr_buf_req_val = 1'b0;
        ctrl_wr_buf_req_data_val = 1'b0;
        ctrl_wr_buf_wr_req_done_rdy = 1'b0;

        read_store_buf_q_req_val = 1'b0;

        save_q_entry = 1'b0;
        save_commit_ptr = 1'b0;
        init_tmp_buf_rd_metadata = 1'b0;
        update_tmp_buf_rd_metadata = 1'b0;

        store_buf_tmp_buf_store_rx_rd_req_val = 1'b0;
        store_buf_tmp_buf_store_rx_rd_resp_rdy = 1'b1;

        store_buf_commit_ptr_rd_req_val = 1'b0;
        store_buf_commit_ptr_rd_resp_rdy = 1'b0;
       
        store_buf_tmp_buf_free_slab_rx_req_val = 1'b0;
        store_buf_commit_ptr_wr_req_val = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                if (~read_store_buf_q_empty) begin
                    read_store_buf_q_req_val = 1'b1;
                    save_q_entry = 1'b1;
                    if (pkt_len_0) begin
                        state_next = READY;
                    end
                    else if (~accept_payload) begin
                        state_next = FREE_NON_ACCEPTED;
                    end
                    else if (commit_ptr_store_buf_rd_req_rdy) begin
                        store_buf_commit_ptr_rd_req_val = 1'b1;

                        init_tmp_buf_rd_metadata = 1'b1;

                        state_next = COMMIT_PTR_RESP;
                    end
                end
            end
            COMMIT_PTR_RESP: begin
                store_buf_commit_ptr_rd_resp_rdy = 1'b1;

                if (commit_ptr_store_buf_rd_resp_val) begin
                    save_commit_ptr = 1'b1;
                    state_next = DATA_COPY_START;
                end
                else begin
                    state_next = COMMIT_PTR_RESP;
                end
            end
            DATA_COPY_START: begin
                if (wr_buf_ctrl_req_rdy & tmp_buf_store_store_buf_rx_rd_req_rdy) begin
                    ctrl_wr_buf_req_val = 1'b1;

                    store_buf_tmp_buf_store_rx_rd_req_val = 1'b1;
                    state_next = DATA_COPY;
                end
                else begin
                    state_next = DATA_COPY_START;
                end
            end
            DATA_COPY: begin
                ctrl_wr_buf_req_data_val = tmp_buf_store_store_buf_rx_rd_resp_val;
                store_buf_tmp_buf_store_rx_rd_resp_rdy = wr_buf_ctrl_req_data_rdy;
                store_buf_tmp_buf_store_rx_rd_req_val = 1'b1;

                if (tmp_buf_store_store_buf_rx_rd_resp_val & wr_buf_ctrl_req_data_rdy) begin
                    if (last_transfer) begin
                        state_next = DATA_COPY_WAIT;
                    end
                    else begin
                        update_tmp_buf_rd_metadata = 1'b1;
                        state_next = DATA_COPY;
                    end
                end
                else begin
                    state_next = DATA_COPY;
                end
            end
            DATA_COPY_WAIT: begin
                ctrl_wr_buf_wr_req_done_rdy = 1'b1;
                
                if (wr_buf_ctrl_wr_req_done) begin
                    state_next = UPDATE_POINTER;
                end
                else begin
                    state_next = DATA_COPY_WAIT;
                end
            end
            UPDATE_POINTER: begin
                if (commit_ptr_store_buf_wr_req_rdy & tmp_buf_free_slab_store_buf_rx_req_rdy) begin
                    store_buf_tmp_buf_free_slab_rx_req_val = 1'b1;
                    store_buf_commit_ptr_wr_req_val = 1'b1;
                
                    state_next = READY;
                end
                else begin
                    state_next = UPDATE_POINTER;
                end
            end
            FREE_NON_ACCEPTED: begin
                store_buf_tmp_buf_free_slab_rx_req_val = 1'b1;
                if (tmp_buf_free_slab_store_buf_rx_req_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = FREE_NON_ACCEPTED;
                end
            end
            default: begin
                ctrl_wr_buf_req_val = 'X;
                ctrl_wr_buf_req_data_val = 'X;
                ctrl_wr_buf_wr_req_done_rdy = 'X;

                read_store_buf_q_req_val = 'X;

                save_q_entry = 'X;
                save_commit_ptr = 'X;
                init_tmp_buf_rd_metadata = 'X;
                update_tmp_buf_rd_metadata = 'X;

                store_buf_tmp_buf_store_rx_rd_req_val = 'X;
                store_buf_tmp_buf_store_rx_rd_resp_rdy = 'X;

                store_buf_commit_ptr_rd_req_val = 'X;
                store_buf_commit_ptr_rd_resp_rdy = 'X;
       
                store_buf_tmp_buf_free_slab_rx_req_val = 'X;
                store_buf_commit_ptr_wr_req_val = 'X;

                state_next = UND;
            end
        endcase
    end


endmodule
