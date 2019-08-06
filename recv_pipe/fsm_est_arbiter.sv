module fsm_est_arbiter 
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input  logic                   fsm_arbiter_tx_state_rd_req_val
    ,input  logic   [FLOWID_W-1:0]  fsm_arbiter_tx_state_rd_req_flowid
    ,output logic                   arbiter_fsm_tx_state_rd_req_grant
    
    ,input  logic                   fsm_arbiter_rx_state_rd_req_val
    ,input  logic   [FLOWID_W-1:0]  fsm_arbiter_rx_state_rd_req_flowid
    ,output logic                   arbiter_fsm_rx_state_rd_req_grant

    ,input  logic                   est_arbiter_tx_state_rd_req_val
    ,input  logic   [FLOWID_W-1:0]  est_arbiter_tx_state_rd_req_flowid
    ,output logic                   arbiter_est_tx_state_rd_req_grant

    ,input  logic                   est_arbiter_rx_state_rd_req_val
    ,input  logic   [FLOWID_W-1:0]  est_arbiter_rx_state_rd_req_flowid
    ,output logic                   arbiter_est_rx_state_rd_req_grant
    
    ,output logic                   curr_recv_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]  curr_recv_state_rd_req_flowid
    ,input  logic                   curr_recv_state_rd_req_rdy
    
    ,input                          curr_recv_state_rd_resp_val
    ,input  recv_state_entry        curr_recv_state_rd_resp_data
    ,output                         curr_recv_state_rd_resp_rdy

    ,output logic                   curr_tx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]  curr_tx_state_rd_req_flowid
    ,input  logic                   curr_tx_state_rd_req_rdy
    
    ,input                          curr_tx_state_rd_resp_val
    ,input  tx_state_struct         curr_tx_state_rd_resp_data
    ,output                         curr_tx_state_rd_resp_rdy
    
    ,output logic                   arbiter_fsm_tx_state_rd_resp_val
    ,output tx_state_struct         arbiter_fsm_tx_state_rd_resp_data
    ,input  logic                   fsm_arbiter_tx_state_rd_resp_rdy
    
    ,output logic                   arbiter_fsm_rx_state_rd_resp_val
    ,output recv_state_entry        arbiter_fsm_rx_state_rd_resp_data
    ,input  logic                   fsm_arbiter_rx_state_rd_resp_rdy
    
    ,output logic                   arbiter_est_tx_state_rd_resp_val
    ,output tx_state_struct         arbiter_est_tx_state_rd_resp_data
    ,input  logic                   est_arbiter_tx_state_rd_resp_rdy
    
    ,output logic                   arbiter_est_rx_state_rd_resp_val
    ,output recv_state_entry        arbiter_est_rx_state_rd_resp_data
    ,input  logic                   est_arbiter_rx_state_rd_resp_rdy
);

    typedef enum logic {
        READY = 1'd0,
        WAIT = 1'd1,
        UND = 'X
    } state_e;

    localparam FSM_GRANT = 2'b01;
    localparam EST_GRANT = 2'b10;

    state_e state_reg;
    state_e state_next;

    logic   [1:0]   input_arb_vals;
    logic   [1:0]   arb_output_grants; 
    logic           arb_advance;

    logic   [1:0]   arb_decision_reg;
    logic   [1:0]   arb_decision_next;

    assign input_arb_vals[0] = fsm_arbiter_tx_state_rd_req_val & fsm_arbiter_rx_state_rd_req_val;
    assign input_arb_vals[1] = est_arbiter_tx_state_rd_req_val & est_arbiter_rx_state_rd_req_val;

    logic           some_valid;
    assign some_valid = |arb_output_grants;

    bsg_arb_round_robin #(
        .width_p(2)
    ) arbiter (
         .clk_i     (clk)
        ,.reset_i   (rst)

        ,.reqs_i    (input_arb_vals     )
        ,.grants_o  (arb_output_grants  )
        ,.yumi_i    (arb_advance        )
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            arb_decision_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            arb_decision_reg <= arb_decision_next;
        end
    end

    assign curr_recv_state_rd_req_flowid = (arb_output_grants == FSM_GRANT)
                                         ? fsm_arbiter_rx_state_rd_req_flowid
                                         : est_arbiter_rx_state_rd_req_flowid;

    assign curr_tx_state_rd_req_flowid = (arb_output_grants == FSM_GRANT)
                                       ? fsm_arbiter_tx_state_rd_req_flowid
                                       : est_arbiter_tx_state_rd_req_flowid;

    assign arbiter_fsm_tx_state_rd_resp_data = curr_tx_state_rd_resp_data;
    assign arbiter_fsm_rx_state_rd_resp_data = curr_recv_state_rd_resp_data;
    
    assign arbiter_est_tx_state_rd_resp_data = curr_tx_state_rd_resp_data;
    assign arbiter_est_rx_state_rd_resp_data = curr_recv_state_rd_resp_data;
    
    assign curr_recv_state_rd_resp_rdy = arb_decision_reg == FSM_GRANT
                                       ? fsm_arbiter_rx_state_rd_resp_rdy
                                       : est_arbiter_rx_state_rd_resp_rdy;

    assign curr_tx_state_rd_resp_rdy = arb_decision_reg == FSM_GRANT
                                     ? fsm_arbiter_tx_state_rd_resp_rdy
                                     : est_arbiter_tx_state_rd_resp_rdy;

    always_comb begin
        state_next = state_reg;
        curr_recv_state_rd_req_val = 1'b0;
        curr_tx_state_rd_req_val = 1'b0;

        arb_advance = 1'b0;
        arb_decision_next = arb_decision_reg;

        arbiter_fsm_rx_state_rd_req_grant = 1'b0;
        arbiter_est_rx_state_rd_req_grant = 1'b0;
        arbiter_fsm_tx_state_rd_req_grant = 1'b0;
        arbiter_est_tx_state_rd_req_grant = 1'b0;

        arbiter_fsm_rx_state_rd_resp_val = 1'b0;
        arbiter_fsm_tx_state_rd_resp_val = 1'b0;

        arbiter_est_rx_state_rd_resp_val = 1'b0;
        arbiter_est_tx_state_rd_resp_val = 1'b0;
        case (state_reg)
            READY: begin
                if (some_valid & curr_recv_state_rd_req_rdy & curr_tx_state_rd_req_rdy) begin
                    curr_recv_state_rd_req_val = 1'b1;
                    curr_tx_state_rd_req_val = 1'b1;

                    arbiter_fsm_rx_state_rd_req_grant = arb_output_grants == FSM_GRANT;
                    arbiter_fsm_tx_state_rd_req_grant = arb_output_grants == FSM_GRANT;
                    
                    arbiter_est_rx_state_rd_req_grant = arb_output_grants == EST_GRANT;
                    arbiter_est_tx_state_rd_req_grant = arb_output_grants == EST_GRANT;

                    arb_decision_next = arb_output_grants;
                    arb_advance = 1'b1;
                    state_next = WAIT;
                end
                else begin
                    state_next = READY;
                end
            end
            WAIT: begin
                if (curr_recv_state_rd_resp_val & curr_tx_state_rd_resp_val) begin

                    arbiter_fsm_rx_state_rd_resp_val = arb_decision_reg == FSM_GRANT;
                    arbiter_fsm_tx_state_rd_resp_val = arb_decision_reg == FSM_GRANT;

                    arbiter_est_rx_state_rd_resp_val = arb_decision_reg == EST_GRANT;
                    arbiter_est_tx_state_rd_resp_val = arb_decision_reg == EST_GRANT;

                    if (curr_recv_state_rd_resp_rdy & curr_tx_state_rd_resp_rdy) begin
                        state_next = READY;
                    end
                    else begin
                        state_next = WAIT;
                    end
                end
                else begin
                    state_next = WAIT;
                end
            end
        endcase
    end

endmodule
