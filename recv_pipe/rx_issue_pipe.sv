`include "packet_defs.vh"
module rx_issue_pipe 
import tcp_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    
    ,input          [`IP_ADDR_W-1:0]    recv_src_ip
    ,input          [`IP_ADDR_W-1:0]    recv_dst_ip
    ,input                              recv_tcp_hdr_val
    ,input  tcp_pkt_hdr                 recv_tcp_hdr
    ,output logic                       recv_hdr_rdy
    
    ,input                              recv_payload_val
    ,input  payload_buf_struct          recv_payload_entry

    ,input                              tcp_fsm_clear_flowid_val
    ,input          [FLOWID_W-1:0]      tcp_fsm_clear_flowid_flowid
    ,input four_tuple_struct            tcp_fsm_clear_flowid_tag

    ,input                              tcp_fsm_update_tcp_state_val
    ,input          [FLOWID_W-1:0]      tcp_fsm_update_tcp_state_flowid
    ,input          [TCP_STATE_W-1:0]   tcp_fsm_update_tcp_state_data
    ,output logic                       tcp_fsm_update_tcp_state_rdy
    
    ,input  logic                       fsm_tcp_state_rd_req_val
    ,input  logic   [FLOWID_W-1:0]      fsm_tcp_state_rd_req_flowid
    ,output logic                       tcp_state_fsm_rd_req_rdy

    ,output logic                       tcp_state_fsm_rd_resp_val
    ,output logic   [TCP_STATE_W-1:0]   tcp_state_fsm_rd_resp_data
    ,input  logic                       fsm_tcp_state_rd_resp_rdy

    ,output logic                       issue_pipe_flowid_manager_flowid_req
    ,input                              flowid_manager_issue_pipe_flowid_avail
    ,input          [FLOWID_W-1:0]      flowid_manager_issue_pipe_flowid

    ,output logic                       est_hdr_val
    ,output tcp_pkt_hdr                 est_tcp_hdr
    ,output logic   [FLOWID_W-1:0]      est_flowid
    ,output logic                       est_payload_val
    ,output payload_buf_struct          est_payload_entry
    ,input  logic                       est_pipe_rdy
    
    ,output logic   [`IP_ADDR_W-1:0]    fsm_hdr_src_ip
    ,output logic   [`IP_ADDR_W-1:0]    fsm_hdr_dst_ip
    ,output logic                       fsm_hdr_val
    ,output tcp_pkt_hdr                 fsm_tcp_hdr
    ,output logic                       fsm_payload_val
    ,output payload_buf_struct          fsm_payload_entry
    ,output logic                       fsm_new_flow
    ,output logic   [FLOWID_W-1:0]      fsm_flowid
    ,input  logic                       fsm_pipe_rdy
    
);

    typedef enum logic { 
        EST_PIPE = 1'd0,
        FSM_PIPE = 1'd1
    } route_e;

    route_e route;
    
    logic                       stall_f;
    logic                       stall_t;
    logic                       stall_i;

    logic                       bubble_t;
    logic                       bubble_i;
    
    logic   [`IP_ADDR_W-1:0]    recv_src_ip_reg_f;
    logic   [`IP_ADDR_W-1:0]    recv_dst_ip_reg_f;

    logic                       recv_hdr_val_reg_f;
    tcp_pkt_hdr                 recv_tcp_hdr_reg_f;
    
    logic                       recv_payload_val_reg_f;
    payload_buf_struct          recv_payload_entry_reg_f;
    payload_buf_struct          recv_payload_entry_next_f;

    logic   [MAX_FLOW_CNT-1:0]  addr_to_flowid_cam_wr_val_f;
    logic                       addr_to_flowid_cam_wr_clear_f;
    four_tuple_struct           addr_to_flowid_cam_wr_tag_f;
    logic   [FLOWID_W-1:0]      addr_to_flowid_cam_wr_data_f;
    four_tuple_struct           new_flow_lookup_struct_f;

    logic                       addr_to_flowid_cam_rd_req_val_f;
    four_tuple_struct           addr_to_flowid_cam_rd_req_tag_f;

    logic                       addr_to_flowid_cam_rd_resp_val_f;
    logic   [FLOWID_W-1:0]      addr_to_flowid_cam_rd_resp_data_f;

    logic                       flowid_byp_val_f;

    logic                       flowid_val_next_t;
    logic   [FLOWID_W-1:0]      flowid_next_t;
    
    logic   [`IP_ADDR_W-1:0]    recv_src_ip_reg_t;
    logic   [`IP_ADDR_W-1:0]    recv_dst_ip_reg_t;

    logic                       recv_hdr_val_reg_t;
    tcp_pkt_hdr                 recv_tcp_hdr_reg_t;
    
    logic                       recv_payload_val_reg_t;
    payload_buf_struct          recv_payload_entry_reg_t;
    
    logic                       flowid_val_reg_t;
    logic   [FLOWID_W-1:0]      flowid_reg_t;
   
    
    logic                       alloc_new_flowid_val_t;
    four_tuple_struct           alloc_new_flowid_tag_t;
    logic   [FLOWID_W-1:0]      alloc_new_flowid_data_t;
    logic                       want_new_flowid_t;

    logic                       tcp_state_wr_req_val_t;
    logic   [FLOWID_W-1:0]      tcp_state_wr_req_addr_t;
    tcp_flow_state_struct       tcp_state_wr_req_data_t;
    logic                       tcp_state_wr_req_rdy_t;
    
    logic                       tcp_state_rd_req_val_t;
    logic   [FLOWID_W-1:0]      tcp_state_rd_req_addr_t;
    logic                       tcp_state_rd_req_rdy_t;
    
    logic                       drop_hdr_t;

    logic                       flowid_val_next_i;
    logic   [FLOWID_W-1:0]      flowid_next_i;
    
    logic                       alloc_new_flowid_reg_i;

    logic   [`IP_ADDR_W-1:0]    recv_src_ip_reg_i;
    logic   [`IP_ADDR_W-1:0]    recv_dst_ip_reg_i;
    logic                       recv_hdr_val_reg_i;
    tcp_pkt_hdr                 recv_tcp_hdr_reg_i;

    logic                       recv_new_flow_reg_i;
    logic   [FLOWID_W-1:0]      recv_flowid_reg_i;

    logic                       recv_payload_val_reg_i;
    payload_buf_struct          recv_payload_entry_reg_i;

    logic                       tcp_state_rd_resp_val_i;
    tcp_flow_state_struct       tcp_state_rd_resp_data_i;
    logic                       tcp_state_rd_resp_rdy_i;

    logic                       tcp_state_byp_val_i;

    tcp_flow_state_struct       curr_tcp_state_i;
    tcp_flow_state_struct       tcp_state_stall_reg_i;
    tcp_flow_state_struct       tcp_state_stall_next_i;
    logic                       tcp_state_stall_val_reg_i;
    logic                       tcp_state_stall_val_next_i;

    assign recv_payload_entry_next_f = recv_payload_entry;

/**********************************************************
 * Inputs -> (F)low ID lookup
 *********************************************************/
    assign recv_hdr_rdy = ~stall_f;

    always_ff @(posedge clk) begin
        if (rst) begin
            recv_src_ip_reg_f <= '0;
            recv_dst_ip_reg_f <= '0;
            recv_hdr_val_reg_f <= '0;
            recv_tcp_hdr_reg_f <= '0;
            recv_payload_val_reg_f <= '0;
            recv_payload_entry_reg_f <='0;
        end
        else begin
            if (~stall_f) begin
                recv_src_ip_reg_f <= recv_src_ip;
                recv_dst_ip_reg_f <= recv_dst_ip;
                recv_hdr_val_reg_f <= recv_tcp_hdr_val;
                recv_tcp_hdr_reg_f <= recv_tcp_hdr;
                recv_payload_val_reg_f <= recv_payload_val & recv_tcp_hdr_val;
                recv_payload_entry_reg_f <= recv_payload_entry_next_f;
            end
        end
    end

/**********************************************************
 * (F)low ID lookup
 *********************************************************/

    logic   [MAX_FLOW_CNT-1:0] tcp_clear_flowid_one_hot;
    logic   [MAX_FLOW_CNT-1:0] alloc_new_flowid_one_hot;

    assign tcp_clear_flowid_one_hot = {{(MAX_FLOW_CNT-1){1'b0}}, tcp_fsm_clear_flowid_val} 
                                      << tcp_fsm_clear_flowid_flowid;
    assign alloc_new_flowid_one_hot = {{(MAX_FLOW_CNT-1){1'b0}}, alloc_new_flowid_val_t}
                                     << alloc_new_flowid_data_t;
    
    assign stall_f = recv_hdr_val_reg_f & (stall_t);

    assign addr_to_flowid_cam_wr_val_f = tcp_fsm_clear_flowid_val 
                                       ? tcp_clear_flowid_one_hot
                                       : alloc_new_flowid_one_hot;
    assign addr_to_flowid_cam_wr_clear_f = tcp_fsm_clear_flowid_val;
    assign addr_to_flowid_cam_wr_tag_f = tcp_fsm_clear_flowid_val 
                                       ? tcp_fsm_clear_flowid_tag
                                       : alloc_new_flowid_tag_t;
    assign addr_to_flowid_cam_wr_data_f = alloc_new_flowid_data_t;

    assign addr_to_flowid_cam_rd_req_val_f = recv_hdr_val_reg_f;
    assign addr_to_flowid_cam_rd_req_tag_f.host_ip = recv_dst_ip_reg_f;
    assign addr_to_flowid_cam_rd_req_tag_f.dest_ip = recv_src_ip_reg_f;
    assign addr_to_flowid_cam_rd_req_tag_f.host_port = recv_tcp_hdr_reg_f.dst_port;
    assign addr_to_flowid_cam_rd_req_tag_f.dest_port = recv_tcp_hdr_reg_f.src_port;

    bsg_cam_1r1w_unmanaged #(
         .els_p         (MAX_FLOW_CNT           )  
        ,.tag_width_p   (FLOW_LOOKUP_ENTRY_W    )
        ,.data_width_p  (FLOWID_W               )
    ) addr_to_flowid (
         .clk_i     (clk)
        ,.reset_i   (rst)

        // Synchronous write/invalidate of a tag
        // one or zero-hot
        ,.w_v_i             (addr_to_flowid_cam_wr_val_f    )
        ,.w_set_not_clear_i (~addr_to_flowid_cam_wr_clear_f )
        // Tag/data to set on write
        ,.w_tag_i           (addr_to_flowid_cam_wr_tag_f    )
        ,.w_data_i          (addr_to_flowid_cam_wr_data_f   )
        // Metadata useful for an external replacement policy
        // Whether there's an empty entry in the tag array
        ,.w_empty_o         ()
        
        // Asynchronous read of a tag, if exists
        ,.r_v_i             (addr_to_flowid_cam_rd_req_val_f    )
        ,.r_tag_i           (addr_to_flowid_cam_rd_req_tag_f    )

        ,.r_data_o          (addr_to_flowid_cam_rd_resp_data_f  )
        ,.r_v_o             (addr_to_flowid_cam_rd_resp_val_f   )
    );


    // we need to bypass the assigned flow ID from the next stage if:
    // - both stages are valid
    // - we are writing a new flowID
    // - the tags are equal
    assign flowid_byp_val_f = recv_hdr_val_reg_f & recv_hdr_val_reg_t &
                              (alloc_new_flowid_val_t) &
                              (alloc_new_flowid_tag_t == addr_to_flowid_cam_rd_req_tag_f);

    assign flowid_val_next_t = flowid_byp_val_f 
                             ? 1'b1
                             : addr_to_flowid_cam_rd_resp_val_f;
    assign flowid_next_t = flowid_byp_val_f
                         ? alloc_new_flowid_data_t
                         : addr_to_flowid_cam_rd_resp_data_f;
                             
/**********************************************************
 * (F)low ID lookup -> (T)CP state lookup
 *********************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            recv_src_ip_reg_t <= '0;
            recv_dst_ip_reg_t <= '0;

            flowid_val_reg_t <= '0;
            flowid_reg_t <= '0;

            recv_hdr_val_reg_t <='0;
            recv_tcp_hdr_reg_t <= '0;

            recv_payload_val_reg_t <= '0;
            recv_payload_entry_reg_t <='0;

        end
        else begin
            if (~stall_t) begin
                recv_src_ip_reg_t <= recv_src_ip_reg_f;
                recv_dst_ip_reg_t <= recv_dst_ip_reg_f;
                
                recv_hdr_val_reg_t <= recv_hdr_val_reg_f;
                recv_tcp_hdr_reg_t <= recv_tcp_hdr_reg_f;

                recv_payload_val_reg_t <= recv_payload_val_reg_f;
                recv_payload_entry_reg_t <= recv_payload_entry_reg_f;

                flowid_val_reg_t <= flowid_val_next_t;
                flowid_reg_t <= flowid_next_t;
            end
        end
    end

/**********************************************************
 * (T)CP state lookup
 *********************************************************/
    // we need to stall if the stage is valid and either
    // the TCP state memory is not ready for a read
    // or we need to allocate a new flow ID and the FSM is trying to clear the flow ID
    // or a later stage is stalling
    assign stall_t = recv_hdr_val_reg_t & 
                    ( stall_i
                    | ~tcp_state_rd_req_rdy_t
                    | want_new_flowid_t & tcp_fsm_update_tcp_state_val
                    | want_new_flowid_t & tcp_fsm_clear_flowid_val );

    assign want_new_flowid_t = recv_hdr_val_reg_t 
                             & ~flowid_val_reg_t 
                             & flowid_manager_issue_pipe_flowid_avail;

    assign bubble_t = stall_t | drop_hdr_t;

    // we need to allocate a new flow ID if the stage is valid but we didn't get a valid flow ID
    // and there's one available and we're not stalling Otherwise, drop the packet
    assign alloc_new_flowid_val_t = ~stall_t & want_new_flowid_t;

    assign drop_hdr_t = recv_hdr_val_reg_t 
                        & ~flowid_val_reg_t 
                        & ~flowid_manager_issue_pipe_flowid_avail;
    assign issue_pipe_flowid_manager_flowid_req = alloc_new_flowid_val_t;

    assign alloc_new_flowid_data_t = flowid_manager_issue_pipe_flowid;
    
    assign alloc_new_flowid_tag_t.host_ip = recv_dst_ip_reg_t;
    assign alloc_new_flowid_tag_t.dest_ip = recv_src_ip_reg_t;
    assign alloc_new_flowid_tag_t.host_port = recv_tcp_hdr_reg_t.dst_port;
    assign alloc_new_flowid_tag_t.dest_port = recv_tcp_hdr_reg_t.src_port;

    // read if the stage is valid, we have a flow ID, and we're not going to stall
    assign tcp_state_rd_req_val_t = recv_hdr_val_reg_t 
                                  & flowid_val_reg_t
                                  & ~stall_t;
    assign tcp_state_rd_req_addr_t = flowid_reg_t;

    assign tcp_fsm_update_tcp_state_rdy = 1'b1;
    assign tcp_state_wr_req_val_t = tcp_fsm_update_tcp_state_val | alloc_new_flowid_val_t;
    assign tcp_state_wr_req_addr_t = tcp_fsm_update_tcp_state_val
                                   ? tcp_fsm_update_tcp_state_flowid
                                   : alloc_new_flowid_data_t;
    assign tcp_state_wr_req_data_t = tcp_fsm_update_tcp_state_val
                                   ? tcp_fsm_update_tcp_state_data
                                   : TCP_NONE;

    tcp_state_store #(
         .width_p   (TCP_STATE_W    )
        ,.els_p     (MAX_FLOW_CNT   )
    ) tcp_state_mem (
         .clk   (clk)
        ,.rst   (rst)

        ,.fsm_tcp_state_wr_req_val      (tcp_state_wr_req_val_t     )
        ,.fsm_tcp_state_wr_req_addr     (tcp_state_wr_req_addr_t    )
        ,.fsm_tcp_state_wr_req_state    (tcp_state_wr_req_data_t    )
        ,.tcp_state_fsm_wr_req_rdy      (tcp_state_wr_req_rdy_t     )

        ,.issue_tcp_state_rd_req_val    (tcp_state_rd_req_val_t     )
        ,.issue_tcp_state_rd_req_addr   (tcp_state_rd_req_addr_t    )
        ,.tcp_state_issue_rd_req_rdy    (tcp_state_rd_req_rdy_t     )

        ,.tcp_state_issue_rd_resp_val   (tcp_state_rd_resp_val_i    )
        ,.tcp_state_issue_rd_resp_state (tcp_state_rd_resp_data_i   )
        ,.issue_tcp_state_rd_resp_rdy   (tcp_state_rd_resp_rdy_i    )

        ,.fsm_tcp_state_rd_req_val      (fsm_tcp_state_rd_req_val   )
        ,.fsm_tcp_state_rd_req_addr     (fsm_tcp_state_rd_req_flowid)
        ,.tcp_state_fsm_rd_req_rdy      (tcp_state_fsm_rd_req_rdy   )

        ,.tcp_state_fsm_rd_resp_val     (tcp_state_fsm_rd_resp_val  )
        ,.tcp_state_fsm_rd_resp_state   (tcp_state_fsm_rd_resp_data )
        ,.fsm_tcp_state_rd_resp_rdy     (fsm_tcp_state_rd_resp_rdy  )
    );

/**********************************************************
 * (T)CP state -> (I)ssue
 *********************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            recv_src_ip_reg_i <= '0;
            recv_dst_ip_reg_i <= '0;

            recv_hdr_val_reg_i <= '0;
            recv_tcp_hdr_reg_i <= '0;
            recv_payload_val_reg_i <= '0; 
            recv_payload_entry_reg_i <= '0;

            recv_new_flow_reg_i <= '0;
            recv_flowid_reg_i <= '0;

            alloc_new_flowid_reg_i <= '0;
        end
        else begin
            if (~stall_i) begin
                recv_src_ip_reg_i <= recv_src_ip_reg_t;
                recv_dst_ip_reg_i <= recv_dst_ip_reg_t;

                recv_hdr_val_reg_i <= ~bubble_t & recv_hdr_val_reg_t;
                recv_tcp_hdr_reg_i <= recv_tcp_hdr_reg_t;
                recv_payload_val_reg_i <= recv_payload_val_reg_t;
                recv_payload_entry_reg_i <= recv_payload_entry_reg_t;

                recv_new_flow_reg_i <= ~flowid_val_reg_t;
                recv_flowid_reg_i <= alloc_new_flowid_val_t
                                   ? alloc_new_flowid_data_t
                                   : flowid_reg_t;

                alloc_new_flowid_reg_i <= alloc_new_flowid_val_t;
            end
        end
    end

/**********************************************************
 * (I)ssue stage
 *********************************************************/
    // stall if the stage is valid and either the response isn't ready & we read it or if the 
    // destinations aren't ready
    tcp_flow_state_struct tcp_state_resp_cast_i;
	 assign tcp_state_resp_cast_i = tcp_state_rd_resp_data_i;

    assign stall_i = recv_hdr_val_reg_i &
                    ( (route == FSM_PIPE & ~fsm_pipe_rdy)
                    | (route == EST_PIPE & ~est_pipe_rdy)
                    | (~alloc_new_flowid_reg_i & ~tcp_state_rd_resp_val_i));

    assign tcp_state_rd_resp_rdy_i = ~stall_i;
    assign curr_tcp_state_i.state = alloc_new_flowid_reg_i
                                  ? TCP_NONE
                                  : tcp_state_resp_cast_i.state;
    
    always_comb begin
        if (curr_tcp_state_i.state == TCP_EST) begin
            // if any flags are set that aren't ACK or push
            if ((recv_tcp_hdr_reg_i.flags & ~(`TCP_ACK | `TCP_PSH))) begin
                route = FSM_PIPE;
            end
            else begin
                route = EST_PIPE;
            end
        end
        else begin
            route = FSM_PIPE;
        end
    end
    
    assign est_hdr_val = (route == EST_PIPE) & recv_hdr_val_reg_i & ~stall_i;
    assign est_tcp_hdr = recv_tcp_hdr_reg_i;
    assign est_flowid = recv_flowid_reg_i;
    assign est_payload_val = recv_payload_val_reg_i & ~stall_i;
    assign est_payload_entry = recv_payload_entry_reg_i;
    
    assign fsm_hdr_val = (route == FSM_PIPE) & recv_hdr_val_reg_i & ~stall_i;
    assign fsm_hdr_src_ip = recv_src_ip_reg_i;
    assign fsm_hdr_dst_ip = recv_dst_ip_reg_i;
    assign fsm_tcp_hdr = recv_tcp_hdr_reg_i;
    assign fsm_payload_val = recv_payload_val_reg_i;
    assign fsm_payload_entry = recv_payload_entry_reg_i;

    assign fsm_new_flow = recv_new_flow_reg_i;
    assign fsm_flowid = recv_flowid_reg_i;
endmodule
