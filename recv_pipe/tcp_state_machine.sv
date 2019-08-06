`include "packet_defs.vh"
module tcp_state_machine 
import tcp_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst
    
    ,input  logic   [TCP_STATE_W-1:0]           curr_flow_state
    ,input  tcp_pkt_hdr                         curr_tcp_hdr
    ,input  recv_state_entry                    curr_rx_state
    ,input  tx_state_struct                     curr_tx_state
    ,input  logic                               next_state_req

    ,output logic   [TCP_STATE_W-1:0]           next_flow_state
    ,output logic                               send_pkt_val
    ,output tcp_pkt_hdr                         send_tcp_hdr
    ,output logic                               app_new_flow_notif
);

    tcp_pkt_hdr                 send_tcp_hdr_struct;
    tcp_pkt_hdr                 curr_tcp_hdr_struct_cast;

    recv_state_entry            curr_rx_state_entry_cast;
    tx_state_struct             curr_tx_state_struct_cast;
        
    logic                       req_hdr_assemble_val;
    logic   [`PORT_NUM_W-1:0]   req_hdr_assemble_host_port;
    logic   [`PORT_NUM_W-1:0]   req_hdr_assemble_dest_port;
    logic   [`ACK_NUM_W-1:0]    req_hdr_assemble_ack_num;
    logic   [`SEQ_NUM_W-1:0]    req_hdr_assemble_seq_num;
    logic   [`FLAGS_W-1:0]      req_hdr_assemble_flags;
        
    logic                       init_seq_num_yumi;
    logic   [`SEQ_NUM_W-1:0]    init_seq_num;
        
    logic                       manager_flowid_req;
    logic                       manager_flowid_avail;  
    logic   [FLOWID_W-1:0]      manager_flowid; 

    logic                       seq_num_req;

    assign curr_tcp_hdr_struct_cast = curr_tcp_hdr;
    assign curr_rx_state_entry_cast = curr_rx_state;
    assign curr_tx_state_struct_cast = curr_tx_state;

    assign init_seq_num_yumi = seq_num_req & next_state_req;

    assign send_tcp_hdr = send_tcp_hdr_struct;

    
    always_comb begin
        next_flow_state = curr_flow_state;
        
        send_pkt_val = 1'b0;
        seq_num_req = 1'b0;

        req_hdr_assemble_val = 1'b0;
        req_hdr_assemble_host_port = '0;
        req_hdr_assemble_dest_port = '0;
        req_hdr_assemble_ack_num = '0;
        req_hdr_assemble_seq_num = '0;
        req_hdr_assemble_flags = '0;

        app_new_flow_notif = 1'b0;
        case (curr_flow_state)
            TCP_NONE: begin
                if (curr_tcp_hdr_struct_cast.flags == `TCP_SYN) begin
                    next_flow_state = TCP_SYN_RECV;
                    
                    send_pkt_val = 1'b1;
                    seq_num_req = 1'b1;
                    req_hdr_assemble_val = 1'b1;
                    req_hdr_assemble_host_port = curr_tcp_hdr_struct_cast.dst_port;
                    req_hdr_assemble_dest_port = curr_tcp_hdr_struct_cast.src_port;
                    req_hdr_assemble_ack_num = curr_tcp_hdr_struct_cast.seq_num + 1;
                    // we do this such that after we finish the handshake, the payload buffer should
                    // start at 0
                    req_hdr_assemble_seq_num = 
                        {init_seq_num[TX_PAYLOAD_PTR_W +: (`SEQ_NUM_W - TX_PAYLOAD_PTR_W)], 
                                               {(TX_PAYLOAD_PTR_W){1'b1}}};
                    req_hdr_assemble_flags = `TCP_SYN | `TCP_ACK;
                end
                else begin
                    next_flow_state = TCP_NONE;
                end
            end
            TCP_SYN_RECV: begin
                // if we're getting the ACK we expect
                if (curr_tcp_hdr_struct_cast.flags == `TCP_ACK 
                    // just check that the seq and ack nums are correct
                    & (curr_rx_state_entry_cast.rx_curr_ack_num == curr_tcp_hdr_struct_cast.seq_num)
                    & (curr_tx_state_struct_cast.tx_curr_seq_num 
                        == curr_tcp_hdr_struct_cast.ack_num)) begin
                    next_flow_state = TCP_EST;
                    app_new_flow_notif = 1'b1;
                end
                // otherwise, we need to resend the SYN-ACK
                else begin
                    send_pkt_val = 1'b1;

                    req_hdr_assemble_val = 1'b1;
                    req_hdr_assemble_host_port = curr_tcp_hdr_struct_cast.dst_port;
                    req_hdr_assemble_dest_port = curr_tcp_hdr_struct_cast.src_port;
                    req_hdr_assemble_ack_num = curr_rx_state_entry_cast.rx_curr_ack_num;

                    // reuse the initial sequence number we already gave it
                    req_hdr_assemble_seq_num = curr_tx_state_struct_cast.tx_curr_seq_num;
                    req_hdr_assemble_flags = `TCP_SYN | `TCP_ACK;
                    
                    next_flow_state = TCP_SYN_RECV;
                end
            end
            TCP_EST: begin
                next_flow_state = TCP_EST;
                next_flow_state = 1'b0;
            end
            default: begin
                next_flow_state = TCP_UND;
                
                send_pkt_val = 'X;

                req_hdr_assemble_val = 'X;
                req_hdr_assemble_host_port = 'X;
                req_hdr_assemble_dest_port = 'X;
                req_hdr_assemble_ack_num = 'X;
                req_hdr_assemble_seq_num = 'X;
                req_hdr_assemble_flags = 'X;
            end
        endcase
    end



/***************************************************************
 * LFSR for random initial sequence number
 **************************************************************/
    bsg_lfsr #(
        .width_p(`SEQ_NUM_W)
    ) init_seq_num_gen (
         .clk       (clk)
        ,.reset_i   (rst)
        ,.yumi_i    (init_seq_num_yumi  )
        ,.o         (init_seq_num       )
    );

/***************************************************************
 * SYN/ACK Header assembler
 **************************************************************/

    logic [`WIN_SIZE_W-1:0]  base_window_size;
    assign base_window_size = {1'b1, {TX_PAYLOAD_PTR_W{1'b0}}};

    tcp_hdr_assembler hdr_assemble (
         .tcp_hdr_req_val        (req_hdr_assemble_val      )
        ,.host_port              (req_hdr_assemble_host_port)
        ,.dest_port              (req_hdr_assemble_dest_port)
        ,.seq_num                (req_hdr_assemble_seq_num  )
        ,.ack_num                (req_hdr_assemble_ack_num  )
        ,.flags                  (req_hdr_assemble_flags    )
        ,.window                 (base_window_size          )
        ,.tcp_hdr_req_rdy        ()

        ,.outbound_tcp_hdr_val   ()
        ,.outbound_tcp_hdr_rdy   (1'b1)
        ,.outbound_tcp_hdr       (send_tcp_hdr_struct       )
    );
endmodule
