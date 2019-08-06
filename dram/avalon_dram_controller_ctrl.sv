`include "soc_defs.vh"
`include "noc_defs.vh"
`include "packet_defs.vh"
`include "state_defs.vh"

import noc_struct_pkg::*;
module avalon_dram_controller_ctrl #(
     parameter WR_DRAIN_SRC = 2'd2
    ,parameter WR_FIRST_SRC = 2'd1
    ,parameter WR_COPY_SRC = 2'd0
    ,parameter METADATA_SEL_FULL = 1'd0
    ,parameter METADATA_SEL_PART = 1'd1
)(
     input clk
    ,input rst

    ,input                                      noc0_ctovr_controller_val
    ,output logic                               controller_noc0_ctovr_rdy

    ,output logic                               controller_noc0_vrtoc_val
    ,input                                      noc0_vrtoc_controller_rdy

    ,output logic                               controller_mem_read_en
    ,output logic                               controller_mem_write_en
    ,input                                      mem_controller_rdy

    ,input                                      mem_controller_rd_data_val

    ,output logic                               ctrl_datap_store_hdr_flit
    ,output logic                               ctrl_datap_init_metadata
    ,output logic                               ctrl_datap_update_metadata
    ,output logic                               ctrl_datap_update_metadata_sel
    ,output logic                               ctrl_datap_send_hdr_flit
    ,output logic                               ctrl_datap_incr_recv_flits
    ,output logic                               ctrl_datap_incr_sent_flits
    ,output logic                               ctrl_datap_store_rd_data
    ,output logic                               ctrl_datap_store_save1
    ,output logic   [1:0]                       ctrl_datap_sel_store_src
    ,output logic                               ctrl_datap_store_msg_len

    ,input  logic   [`MSG_TYPE_WIDTH-1:0]       datap_ctrl_msg_type
    ,input  logic                               datap_ctrl_first_rd
    ,input  logic                               datap_ctrl_last_req_flit
    ,input  logic                               datap_ctrl_last_resp_flit
    ,input  logic                               datap_ctrl_read_new_line
    ,input  logic                               datap_ctrl_last_mem_write
);
    
    typedef enum logic [3:0] {
        READY = 4'd0,
        RD_OP_ISSUE = 4'd1,
        RD_OP_WAIT = 4'd2,
        RD_HDR_FLIT = 4'd3,
        RD_PAYLOAD_RESP = 4'd4,
        WR_FIRST_DATA = 4'd5,
        WR_DATA_COPY = 4'd6,
        WR_DATA_DRAIN = 4'd7,
        WR_RESP = 4'd8,
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
        controller_noc0_ctovr_rdy = 1'b0;
        controller_noc0_vrtoc_val = 1'b0;

        ctrl_datap_store_hdr_flit = 1'b0;
        ctrl_datap_init_metadata = 1'b0;
        ctrl_datap_send_hdr_flit = 1'b0;
        ctrl_datap_incr_sent_flits = 1'b0;
        ctrl_datap_incr_recv_flits = 1'b0;
        ctrl_datap_update_metadata = 1'b0;
        ctrl_datap_update_metadata_sel = 1'b0;
        ctrl_datap_store_rd_data = 1'b0;
        ctrl_datap_store_save1 = 1'b0;
        ctrl_datap_sel_store_src = '0;
        ctrl_datap_store_msg_len = '0;

        controller_mem_read_en = 1'b0;
        controller_mem_write_en = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                controller_noc0_ctovr_rdy = 1'b1;

                if (noc0_ctovr_controller_val) begin
                    ctrl_datap_store_hdr_flit = 1'b1;
                    ctrl_datap_init_metadata = 1'b1;
                    if (datap_ctrl_msg_type == `MSG_TYPE_LOAD_MEM) begin
                        state_next = RD_OP_ISSUE;
                    end
                    else if (datap_ctrl_msg_type == `MSG_TYPE_STORE_MEM) begin
                        state_next = WR_FIRST_DATA;
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
                controller_mem_read_en = 1'b1;
                ctrl_datap_store_msg_len = 1'b1;
                if (mem_controller_rdy) begin
                    state_next = RD_OP_WAIT;
                end
                else begin
                    state_next = RD_OP_ISSUE;
                end
            end
            RD_OP_WAIT: begin
                if (mem_controller_rd_data_val) begin
                    ctrl_datap_store_rd_data = 1'b1;
                    if (datap_ctrl_first_rd) begin
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
                controller_noc0_vrtoc_val = 1'b1;
                ctrl_datap_send_hdr_flit = 1'b1;
                if (noc0_vrtoc_controller_rdy) begin
                    state_next = RD_PAYLOAD_RESP;
                end
                else begin
                    state_next = RD_HDR_FLIT;
                end
            end
            RD_PAYLOAD_RESP: begin
                controller_noc0_vrtoc_val = 1'b1;
                if (noc0_vrtoc_controller_rdy) begin
                    ctrl_datap_incr_sent_flits = 1'b1;
                    if (datap_ctrl_last_resp_flit) begin
                        state_next = READY;
                    end
                    else begin
                        ctrl_datap_update_metadata = 1'b1;
                        ctrl_datap_update_metadata_sel = METADATA_SEL_FULL;
                        if (datap_ctrl_read_new_line) begin
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
            WR_FIRST_DATA: begin
                controller_noc0_ctovr_rdy = mem_controller_rdy;
                controller_mem_write_en = noc0_ctovr_controller_val;
                ctrl_datap_store_msg_len = 1'b1;

                ctrl_datap_sel_store_src = WR_FIRST_SRC;
                if (noc0_ctovr_controller_val & mem_controller_rdy) begin
                    ctrl_datap_incr_recv_flits = 1'b1;
                    ctrl_datap_store_save1 = 1'b1;
                    ctrl_datap_update_metadata = 1'b1;
                    ctrl_datap_update_metadata_sel = METADATA_SEL_PART;

                    if (datap_ctrl_last_req_flit) begin
                        if (datap_ctrl_last_mem_write) begin
                            state_next = WR_RESP;
                        end
                        else begin
                            state_next = WR_DATA_DRAIN;
                        end
                    end
                    else begin
                        state_next = WR_DATA_COPY;
                    end
                end
                else begin
                    state_next = WR_FIRST_DATA;
                end
            end
            WR_DATA_COPY: begin
                controller_noc0_ctovr_rdy = mem_controller_rdy;
                controller_mem_write_en = noc0_ctovr_controller_val;
                ctrl_datap_sel_store_src = WR_COPY_SRC;

                if (noc0_ctovr_controller_val & mem_controller_rdy) begin
                    ctrl_datap_incr_recv_flits = 1'b1;
                    ctrl_datap_store_save1 = 1'b1;
                    ctrl_datap_update_metadata = 1'b1;
                    ctrl_datap_update_metadata_sel = METADATA_SEL_FULL;
                    if (datap_ctrl_last_req_flit) begin
                        if (datap_ctrl_last_mem_write) begin
                            state_next = WR_RESP;
                        end
                        else begin
                            state_next = WR_DATA_DRAIN;
                        end
                    end
                    else begin
                        state_next = WR_DATA_COPY;
                    end
                end
                else begin
                    state_next = WR_DATA_COPY;
                end
            end
            WR_DATA_DRAIN: begin
                controller_noc0_ctovr_rdy = 1'b0;
                controller_mem_write_en = 1'b1;
                ctrl_datap_sel_store_src = WR_DRAIN_SRC;

                if (mem_controller_rdy) begin
                    state_next = WR_RESP;
                end
                else begin
                    state_next = WR_DATA_DRAIN;
                end
            end
            WR_RESP: begin
                controller_noc0_vrtoc_val = 1'b1;
                ctrl_datap_send_hdr_flit = 1'b1;

                if (noc0_vrtoc_controller_rdy) begin
                    state_next = READY;
                end
                else begin
                    state_next = WR_RESP;
                end
            end
            default: begin
                controller_noc0_ctovr_rdy = 'X;
                controller_noc0_vrtoc_val = 'X;

                ctrl_datap_store_hdr_flit = 'X;
                ctrl_datap_init_metadata = 'X;
                ctrl_datap_send_hdr_flit = 'X;
                ctrl_datap_incr_sent_flits = 'X;
                ctrl_datap_incr_recv_flits = 'X;
                ctrl_datap_update_metadata = 'X;
                ctrl_datap_update_metadata_sel = 'X;
                ctrl_datap_store_rd_data = 'X;
                ctrl_datap_store_save1 = 'X;
                ctrl_datap_sel_store_src = 'X;
                ctrl_datap_store_msg_len = 'X;

                controller_mem_read_en = 'X;
                controller_mem_write_en = 'X;

                state_next = UND;
            end
        endcase
    end

endmodule
