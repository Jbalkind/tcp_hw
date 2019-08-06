`include "packet_defs.vh"
module rx_fsm_pipe 
import packet_struct_pkg::*;
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input          [`IP_ADDR_W-1:0]    fsm_hdr_src_ip
    ,input          [`IP_ADDR_W-1:0]    fsm_hdr_dst_ip
    ,input                              fsm_hdr_val
    ,input  tcp_pkt_hdr                 fsm_tcp_hdr
    ,input                              fsm_payload_val
    ,input  payload_buf_struct          fsm_payload_entry
    ,input                              fsm_new_flow
    ,input          [FLOWID_W-1:0]      fsm_flowid
    ,output logic                       fsm_hdr_rdy
    
    ,output logic                       fsm_tcp_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]      fsm_tcp_state_rd_req_flowid
    ,input  logic                       tcp_state_fsm_rd_req_rdy

    ,input  logic                       tcp_state_fsm_rd_resp_val
    ,input  logic   [TCP_STATE_W-1:0]   tcp_state_fsm_rd_resp_data
    ,output logic                       fsm_tcp_state_rd_resp_rdy
    
    ,output logic                       fsm_rx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]      fsm_rx_state_rd_req_flowid
    ,input  logic                       rx_state_fsm_rd_req_rdy

    ,input  logic                       rx_state_fsm_rd_resp_val
    ,input  recv_state_entry            rx_state_fsm_rd_resp_data
    ,output logic                       fsm_rx_state_rd_resp_rdy
    
    ,output logic                       fsm_tx_state_rd_req_val
    ,output logic   [FLOWID_W-1:0]      fsm_tx_state_rd_req_flowid
    ,input  logic                       tx_state_fsm_rd_req_rdy

    ,input  logic                       tx_state_fsm_rd_resp_val
    ,input  tx_state_struct             tx_state_fsm_rd_resp_data
    ,output logic                       fsm_tx_state_rd_resp_rdy
    
    ,output logic                       fsm_reinject_q_enq_req_val
    ,output fsm_reinject_queue_struct   fsm_reinject_q_enq_req_data
    ,input                              fsm_reinject_q_full

    ,output logic                       fsm_send_pkt_enqueue_val
    ,output logic   [`IP_ADDR_W-1:0]    fsm_send_pkt_enqueue_src_ip
    ,output logic   [`IP_ADDR_W-1:0]    fsm_send_pkt_enqueue_dst_ip
    ,output logic   [FLOWID_W-1:0]      fsm_send_pkt_enqueue_flowid
    ,output tcp_pkt_hdr                 fsm_send_pkt_enqueue_hdr
    ,input                              fsm_send_pkt_enqueue_rdy

    ,output logic                       next_flow_state_wr_req_val
    ,output logic   [TCP_STATE_W-1:0]   next_flow_state_wr_req_data
    ,output logic   [FLOWID_W-1:0]      next_flow_state_wr_req_flowid
    ,input                              next_flow_state_rdy

    ,output logic                       new_flow_val
    ,output four_tuple_struct           new_flow_lookup_entry
    ,output logic   [FLOWID_W-1:0]      new_flow_flowid
    ,output recv_state_entry            new_flow_rx_state
    ,output tx_state_struct             new_flow_tx_state
    ,output logic                       tcp_fsm_clear_flowid_val
    ,output four_tuple_struct           tcp_fsm_clear_flowid_tag
    ,input                              new_flow_rdy

    ,output logic                       app_new_flow_notif_val
    ,output four_tuple_struct           app_new_flow_entry
    ,output logic   [FLOWID_W-1:0]      app_new_flow_flowid
    ,input  logic                       app_new_flow_notif_rdy
);
    
    typedef enum logic [3:0] {
        READY = 4'd0,
        TCP_STATE_RD_REQ = 4'd1,
        TCP_STATE_RD_RESP = 4'd2,
        REINJECT_PKT = 4'd3,
        RX_TX_STATE_RD_REQ = 4'd4,
        RX_TX_STATE_RD_RESP = 4'd5,
        STATE_DEC = 4'd6,
        INIT_STATE = 4'd7,
        WR_FLOW_STATE = 4'd8,
        SEND_PKT = 4'd9,
        NOTIF_APP = 4'd10,
        UND = 'X

    } ctrl_states_e;

    ctrl_states_e ctrl_state_reg;
    ctrl_states_e ctrl_state_next;
    
    logic   [`IP_ADDR_W-1:0]            hdr_src_ip_reg;
    logic   [`IP_ADDR_W-1:0]            hdr_dst_ip_reg;
    tcp_pkt_hdr                         tcp_hdr_reg;
    logic                               payload_val_reg;
    payload_buf_struct                  payload_entry_reg;
    logic                               new_flow_reg;
    logic   [FLOWID_W-1:0]              flowid_reg;
    
    logic   [`IP_ADDR_W-1:0]            hdr_src_ip_next;
    logic   [`IP_ADDR_W-1:0]            hdr_dst_ip_next;
    tcp_pkt_hdr                         tcp_hdr_next;
    logic                               payload_val_next;
    payload_buf_struct                  payload_entry_next;
    logic                               new_flow_next;
    logic   [FLOWID_W-1:0]              flowid_next;

    tcp_flow_state_struct               tcp_state_resp_cast;
    tcp_flow_state_struct               tcp_state_reg;
    tcp_flow_state_struct               tcp_state_next;

    recv_state_entry                    rx_state_next;
    recv_state_entry                    rx_state_reg;
    
    tx_state_struct                     tx_state_next;
    tx_state_struct                     tx_state_reg;

    logic                               next_state_req;
    tcp_flow_state_struct               next_flow_state;
    tcp_flow_state_struct               next_flow_state_next;               
    tcp_flow_state_struct               next_flow_state_reg;
    logic                               send_pkt_val;
    logic                               send_pkt_val_next;
    logic                               send_pkt_val_reg;
    tcp_pkt_hdr                         send_tcp_hdr;
    tcp_pkt_hdr                         send_tcp_hdr_next;
    tcp_pkt_hdr                         send_tcp_hdr_reg;
    
    recv_state_entry                    rx_state_init;
    tx_state_struct                     tx_state_init;
    four_tuple_struct                   flow_lookup_init;

    fsm_reinject_queue_struct           reinject_struct_cast;
    
    logic                               app_new_flow_notif;
    logic                               app_new_flow_notif_next;
    logic                               app_new_flow_notif_reg;

    assign app_new_flow_flowid = flowid_reg;
    assign app_new_flow_entry = flow_lookup_init;

    assign fsm_reinject_q_enq_req_data = reinject_struct_cast;

    assign tcp_state_resp_cast = tcp_state_fsm_rd_resp_data;

    assign reinject_struct_cast.flowid = flowid_reg;
    assign reinject_struct_cast.tcp_hdr = tcp_hdr_reg;
    assign reinject_struct_cast.payload_val = payload_val_reg;
    assign reinject_struct_cast.payload_entry = payload_entry_reg;

    assign fsm_tx_state_rd_req_flowid = flowid_reg;
    assign fsm_rx_state_rd_req_flowid = flowid_reg;

    assign fsm_send_pkt_enqueue_src_ip = hdr_dst_ip_reg;
    assign fsm_send_pkt_enqueue_dst_ip = hdr_src_ip_reg;
    assign fsm_send_pkt_enqueue_flowid = flowid_reg;

    assign new_flow_rx_state = rx_state_init;
    assign new_flow_tx_state = tx_state_init;
    assign new_flow_flowid = flowid_reg;
    assign new_flow_lookup_entry = flow_lookup_init;

    assign flow_lookup_init.host_ip = hdr_dst_ip_reg;
    assign flow_lookup_init.dest_ip = hdr_src_ip_reg;
    assign flow_lookup_init.host_port = tcp_hdr_reg.dst_port;
    assign flow_lookup_init.dest_port = tcp_hdr_reg.src_port;


    assign tcp_fsm_clear_flowid_tag = flow_lookup_init;

    assign tx_state_init.tx_curr_seq_num = send_tcp_hdr_reg.seq_num + 1'b1;
    assign tx_state_init.timer.timestamp = '0;
    assign tx_state_init.timer.timer_armed = 1'b0;
    assign tx_state_init.tx_curr_ack_state.tx_curr_ack_num = send_tcp_hdr_reg.seq_num + 1'b1;
    assign tx_state_init.tx_curr_ack_state.tx_curr_ack_cnt = '0;

    assign rx_state_init.rx_curr_ack_num = send_tcp_hdr_reg.ack_num;
    assign rx_state_init.rx_curr_wnd_size = {1'b1, {(RX_PAYLOAD_PTR_W){1'b0}}};

    assign next_flow_state_wr_req_data = next_flow_state_reg;
    assign next_flow_state_wr_req_flowid = flowid_reg;


    always_ff @(posedge clk) begin
        if (rst) begin
            ctrl_state_reg <= READY;
            hdr_src_ip_reg <= '0;
            hdr_dst_ip_reg <= '0;
            tcp_hdr_reg <= '0;
            payload_val_reg <= '0;
            payload_entry_reg <= '0;
            new_flow_reg <= '0;
            flowid_reg <= '0;

            tcp_state_reg <= TCP_NONE;
            rx_state_reg <= '0;
            tx_state_reg <= '0;

            next_flow_state_reg <= TCP_NONE;
            send_pkt_val_reg <= '0;
            send_tcp_hdr_reg <= '0;
            app_new_flow_notif_reg <= '0;
        end
        else begin
            ctrl_state_reg <= ctrl_state_next;
            hdr_src_ip_reg <= hdr_src_ip_next;
            hdr_dst_ip_reg <= hdr_dst_ip_next;
            tcp_hdr_reg <= tcp_hdr_next;
            payload_val_reg <= payload_val_next;
            payload_entry_reg <= payload_entry_next;
            new_flow_reg <= new_flow_next;
            flowid_reg <= flowid_next;

            tcp_state_reg <= tcp_state_next;
            rx_state_reg <= rx_state_next;
            tx_state_reg <= tx_state_next;

            next_flow_state_reg <= next_flow_state_next;
            send_pkt_val_reg <= send_pkt_val_next;
            send_tcp_hdr_reg <= send_tcp_hdr_next;
            app_new_flow_notif_reg <= app_new_flow_notif_next;
        end
    end

    assign fsm_send_pkt_enqueue_hdr = send_tcp_hdr_reg;


    always_comb begin
        fsm_hdr_rdy = 1'b0;
        ctrl_state_next = ctrl_state_reg;
                    
        hdr_src_ip_next = hdr_src_ip_reg;
        hdr_dst_ip_next = hdr_dst_ip_reg;
        tcp_hdr_next = tcp_hdr_reg;
        payload_val_next = payload_val_reg;
        payload_entry_next = payload_entry_reg;
        new_flow_next = new_flow_reg;
        flowid_next = flowid_reg;

        fsm_tcp_state_rd_req_val = 1'b0;
        fsm_tcp_state_rd_req_flowid = flowid_reg;
        fsm_tcp_state_rd_resp_rdy = 1'b1;

        tcp_fsm_clear_flowid_val = 1'b0;

        tcp_state_next = tcp_state_reg;
                        
        fsm_tx_state_rd_req_val = 1'b0;
        fsm_rx_state_rd_req_val = 1'b0;

        fsm_reinject_q_enq_req_val = 1'b0;
        
        fsm_tx_state_rd_resp_rdy = 1'b1;
        fsm_rx_state_rd_resp_rdy = 1'b1;

        next_state_req = 1'b0;
        next_flow_state_next = next_flow_state_reg;

        new_flow_val = 1'b0;

        fsm_send_pkt_enqueue_val = 1'b0;

        next_flow_state_wr_req_val = 1'b0;

        send_pkt_val_next = send_pkt_val_reg;
        send_tcp_hdr_next = send_tcp_hdr_reg;

        app_new_flow_notif_next = app_new_flow_notif_reg;
        app_new_flow_notif_val = 1'b0;
                    
        rx_state_next = rx_state_reg;
        tx_state_next = tx_state_reg;
        case (ctrl_state_reg)
            READY: begin
                fsm_hdr_rdy = 1'b1;

                if (fsm_hdr_val) begin
                    ctrl_state_next = TCP_STATE_RD_REQ;

                    hdr_src_ip_next = fsm_hdr_src_ip;
                    hdr_dst_ip_next = fsm_hdr_dst_ip;
                    tcp_hdr_next = fsm_tcp_hdr;
                    payload_val_next = fsm_payload_val;
                    payload_entry_next = fsm_payload_entry;
                    new_flow_next = fsm_new_flow;
                    flowid_next = fsm_flowid;
                end
                else begin
                    ctrl_state_next = READY;
                end
            end
            TCP_STATE_RD_REQ: begin
                // we should only try to read state if this isn't a new flow
                if (~new_flow_reg) begin
                    fsm_tcp_state_rd_req_val = 1'b1;
                    fsm_tcp_state_rd_req_flowid = flowid_reg;
                    if (tcp_state_fsm_rd_req_rdy) begin
                        ctrl_state_next = TCP_STATE_RD_RESP;
                    end
                    else begin
                        ctrl_state_next = TCP_STATE_RD_RESP;
                    end
                end
                else begin
                    tcp_state_next.state = TCP_NONE;
                    ctrl_state_next = STATE_DEC;
                end
            end
            TCP_STATE_RD_RESP: begin
                fsm_tcp_state_rd_resp_rdy = 1'b1;
                if (tcp_state_fsm_rd_resp_val) begin
                    tcp_state_next = tcp_state_resp_cast;
                    // if the flow is established and the flags are normal, this is potentially a 
                    // packet that has been sitting in the queue that needs to be reinjected
                    if ((tcp_state_resp_cast.state == TCP_EST)) begin
                        // if it's here, because the flags are bad, request the state
                        if (tcp_hdr_reg.flags & ~(`TCP_ACK | `TCP_PSH)) begin
                            ctrl_state_next = RX_TX_STATE_RD_REQ;
                        end
                        else begin
                            fsm_reinject_q_enq_req_val = ~fsm_reinject_q_full;
                            if (~fsm_reinject_q_full) begin 
                                fsm_reinject_q_enq_req_val = payload_val_reg;
                                ctrl_state_next = READY;
                            end
                            else begin
                                ctrl_state_next = REINJECT_PKT;
                            end
                        end
                    end
                    // otherwise, we should try to read the rx and tx state if this isn't a new flow
                    else begin
                        fsm_tx_state_rd_req_val = 1'b1;
                        fsm_rx_state_rd_req_val = 1'b1;
                        if (tx_state_fsm_rd_req_rdy & rx_state_fsm_rd_req_rdy) begin
                            ctrl_state_next = RX_TX_STATE_RD_RESP;
                        end
                        else begin
                            ctrl_state_next = RX_TX_STATE_RD_REQ;
                        end
                    end
                end
                else begin
                    ctrl_state_next = TCP_STATE_RD_RESP;
                end
            end
            REINJECT_PKT: begin
                fsm_reinject_q_enq_req_val = ~fsm_reinject_q_full;
                if (~fsm_reinject_q_full) begin
                    ctrl_state_next = READY;
                end
                else begin
                    ctrl_state_next = REINJECT_PKT;
                end
            end
            RX_TX_STATE_RD_REQ: begin
                fsm_tx_state_rd_req_val = 1'b1;
                fsm_rx_state_rd_req_val = 1'b1;
                if (tx_state_fsm_rd_req_rdy & rx_state_fsm_rd_req_rdy) begin
                    ctrl_state_next = RX_TX_STATE_RD_RESP;
                end
                else begin
                    ctrl_state_next = RX_TX_STATE_RD_REQ;
                end
            end
            RX_TX_STATE_RD_RESP: begin
                fsm_tx_state_rd_resp_rdy = tx_state_fsm_rd_resp_val & rx_state_fsm_rd_resp_val;
                fsm_rx_state_rd_resp_rdy = tx_state_fsm_rd_resp_val & rx_state_fsm_rd_resp_val;

                if (tx_state_fsm_rd_resp_val & rx_state_fsm_rd_resp_val) begin
                    rx_state_next = rx_state_fsm_rd_resp_data;
                    tx_state_next = tx_state_fsm_rd_resp_data;
                    ctrl_state_next = STATE_DEC;
                end
                else begin
                    ctrl_state_next = RX_TX_STATE_RD_RESP;
                end
            end
            STATE_DEC: begin
                next_state_req = 1'b1;

                next_flow_state_next = next_flow_state;
                app_new_flow_notif_next = app_new_flow_notif;
                send_pkt_val_next = send_pkt_val;
                send_tcp_hdr_next = send_tcp_hdr;

                if (new_flow_reg) begin
                    if (next_flow_state != TCP_NONE) begin
                        ctrl_state_next = INIT_STATE;
                    end
                    else begin
                        tcp_fsm_clear_flowid_val = 1'b1; 
                        ctrl_state_next = WR_FLOW_STATE;
                    end
                end
                else begin
                    ctrl_state_next = WR_FLOW_STATE;
                
                end
            end
            INIT_STATE: begin
                new_flow_val = 1'b1;

                if (new_flow_rdy) begin
                    ctrl_state_next = WR_FLOW_STATE;
                end
                else begin
                    ctrl_state_next = INIT_STATE;
                end
            end
            WR_FLOW_STATE: begin
                next_flow_state_wr_req_val = 1'b1;

                if (next_flow_state_rdy) begin
                    if (send_pkt_val_reg) begin
                        ctrl_state_next = SEND_PKT;
                    end
                    else if (app_new_flow_notif_reg) begin
                        ctrl_state_next = NOTIF_APP;
                    end
                    else begin
                        ctrl_state_next = READY;
                    end
                end
                else begin
                    ctrl_state_next = WR_FLOW_STATE;
                end
            end
            SEND_PKT: begin
                fsm_send_pkt_enqueue_val = 1'b1;
                if (fsm_send_pkt_enqueue_rdy) begin
                    if (app_new_flow_notif_reg) begin
                        ctrl_state_next = NOTIF_APP;
                    end
                    else begin
                        ctrl_state_next = READY;
                    end
                end
                else begin
                    ctrl_state_next = SEND_PKT;
                end
            end
            NOTIF_APP: begin
                app_new_flow_notif_val = 1'b1;

                if (app_new_flow_notif_rdy) begin
                    ctrl_state_next = READY;
                end
                else begin
                    ctrl_state_next = NOTIF_APP;
                end
            end
            default: begin
                ctrl_state_next = UND;
                tcp_state_next = TCP_UND;
                next_flow_state_next = TCP_UND;

                fsm_hdr_rdy = 'X;

                hdr_src_ip_next = 'X;
                hdr_dst_ip_next = 'X;
                tcp_hdr_next = 'X;
                payload_val_next = 'X;
                payload_entry_next = 'X;
                new_flow_next = 'X;
                flowid_next = 'X;

                fsm_tcp_state_rd_req_val = 'X;
                fsm_tcp_state_rd_req_flowid = 'X;
                fsm_tcp_state_rd_resp_rdy = 'X;


                fsm_tx_state_rd_req_val = 'X;
                fsm_rx_state_rd_req_val = 'X;

                fsm_reinject_q_enq_req_val = 'X;

                fsm_tx_state_rd_resp_rdy = 'X;
                fsm_rx_state_rd_resp_rdy = 'X;

                next_state_req = 'X;

                new_flow_val = 'X;

                fsm_send_pkt_enqueue_val = 'X;

                next_flow_state_wr_req_val = 'X;
                
                send_pkt_val_next = 'X;
                send_tcp_hdr_next = 'X;
                app_new_flow_notif_next = 'X;
            end
        endcase
    end

    tcp_state_machine state_machine (
         .clk   (clk)
        ,.rst   (rst)

        ,.curr_flow_state   (tcp_state_reg      )
        ,.curr_tcp_hdr      (tcp_hdr_reg        )
        ,.curr_rx_state     (rx_state_reg       )
        ,.curr_tx_state     (tx_state_reg       )
        ,.next_state_req    (next_state_req     )

        ,.next_flow_state   (next_flow_state    )
        ,.send_pkt_val      (send_pkt_val       )
        ,.send_tcp_hdr      (send_tcp_hdr       )
        ,.app_new_flow_notif(app_new_flow_notif )
    );
endmodule
