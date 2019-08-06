`include "state_defs.vh"
`include "packet_defs.vh"

module recv_pipe_wrap (
     input                                      clk
    ,input                                      rst

    ,input  [`IP_ADDR_WIDTH-1:0]                recv_src_ip
    ,input  [`IP_ADDR_WIDTH-1:0]                recv_dst_ip
    ,input                                      recv_header_val
    ,output                                     recv_header_rdy
    ,input  [`TCP_HEADER_WIDTH-1:0]             recv_header
    ,input                                      recv_payload_val
    ,input  [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] recv_payload_addr
    ,input  [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  recv_payload_len
    
    ,output                                     new_idtoaddr_lookup_val
    ,output [`FLOW_ID_W-1:0]                    new_idtoaddr_lookup_flow_id
    ,output [`FLOW_LOOKUP_ENTRY_WIDTH-1:0]      new_idtoaddr_lookup_entry
    ,output [`SEQ_NUM_WIDTH-1:0]                new_init_seq_num

    ,output                                     curr_recv_state_req_val
    ,output [`FLOW_ID_W-1:0]                    curr_recv_state_req_addr
    ,input                                      curr_recv_state_req_rdy

    ,input                                      curr_recv_state_resp_val
    ,input  [`RECV_STATE_ENTRY_WIDTH-1:0]       curr_recv_state_resp
    ,output                                     curr_recv_state_resp_rdy

    ,output logic                               recv_pipe_init_seq_num_rd_req_val
    ,output logic   [`FLOW_ID_W-1:0]            recv_pipe_init_seq_num_rd_req_addr
    ,input                                      init_seq_num_recv_pipe_rd_req_rdy
   
    ,input                                      init_seq_num_recv_pipe_rd_resp_val
    ,input          [`SEQ_NUM_WIDTH-1:0]        init_seq_num_recv_pipe_rd_resp_data
    ,output logic                               recv_pipe_init_seq_num_rd_resp_rdy
    
    ,output                                     next_recv_state_val
    ,output logic   [`FLOW_ID_W-1:0]            next_recv_state_addr
    ,output [`RECV_STATE_ENTRY_WIDTH-1:0]       next_recv_state

    ,output                                     engine_recv_header_val
    ,output [`TCP_HEADER_WIDTH-1:0]             engine_recv_tcp_hdr
    ,output [`FLOW_ID_W-1:0]                    engine_recv_flowid

    ,output                                     engine_recv_packet_enqueue_val
    ,output [`PAYLOAD_BUF_ENTRY_WIDTH-1:0]      engine_recv_packet_enqueue_entry

    ,output                                     recv_set_ack_pending
    ,output [`FLOW_ID_W-1:0]                    recv_set_ack_pending_addr
    
    ,output logic                               syn_ack_val
    ,output logic   [`IP_ADDR_WIDTH-1:0]        syn_ack_src_ip
    ,output logic   [`IP_ADDR_WIDTH-1:0]        syn_ack_dst_ip
    ,output logic   [`TCP_HEADER_WIDTH-1:0]     syn_ack_hdr
    ,input                                      syn_ack_rdy

    ,output logic                               app_new_flow_notif_val
    ,output logic   [`FLOW_ID_W-1:0]            app_new_flow_flow_id

);
    logic                                       app_new_flow_notif_val_reg;
    logic   [`FLOW_ID_W-1:0]                    app_new_flow_flow_id_reg;

    logic                                       next_flow_state_wr_val;
    tcp_flow_state_struct                       next_flow_state;
    logic   [`FLOW_ID_W-1:0]                    next_flow_state_flow_id;
    logic                                       next_flow_state_rdy;
    
    logic                                       tcp_fsm_curr_lookup_val;
    logic                                       tcp_fsm_curr_flow_id_val;
    logic   [`FLOW_ID_W-1:0]                    tcp_fsm_curr_flow_id;
    logic                                       tcp_fsm_curr_temp_flow_id_val;
    logic   [`TEMP_FLOWID_W-1:0]                tcp_fsm_curr_temp_flow_id;
    
    logic                                       new_flow_nums_val;
    logic   [`FLOW_ID_W-1:0]                    new_flow_flow_id;
    logic   [`ACK_NUM_WIDTH-1:0]                new_ack_num;
    flow_lookup_entry                           new_flow_lookup_entry;

    logic                                       tcp_fsm_clear_temp_flow_id_val;
    logic   [`TEMP_FLOWID_W-1:0]                tcp_fsm_clear_temp_flow_id;

    logic                                       stores_fsm_pipe_new_flow_rdy;

    logic                                       frontend_fsm_addrtoid_lookup_rdy;
    logic                                       est_pipe_new_write_rdy;
    
    logic   [`IP_ADDR_WIDTH-1:0]                state_backend_src_ip;
    logic   [`IP_ADDR_WIDTH-1:0]                state_backend_dst_ip;
    logic                                       state_backend_flow_id_val;
    logic   [`FLOW_ID_W-1:0]                    state_backend_flow_id;
    logic                                       state_backend_flow_header_val;
    tcp_packet_header                           state_backend_flow_header;
    logic                                       backend_state_flow_rdy;
    tcp_flow_state_struct                       state_backend_tcp_state;
    recv_state_entry                            state_backend_recv_state;
    
    logic                                       state_backend_temp_id_val;
    logic   [`TEMP_FLOWID_W-1:0]                state_backend_temp_id;
    
    logic                                       state_backend_payload_val;
    logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] state_backend_payload_addr;
    logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  state_backend_payload_len;
    
    logic                                       est_header_val;
    tcp_packet_header                           est_tcp_header;
    logic   [`FLOW_ID_W-1:0]                    est_flow_id;
    logic                                       est_payload_val;
    logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] est_payload_addr;
    logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  est_payload_len;
    logic                                       est_pipe_rdy;
    
    logic   [`IP_ADDR_WIDTH-1:0]                fsm_header_src_ip;
    logic   [`IP_ADDR_WIDTH-1:0]                fsm_header_dst_ip;
    logic                                       fsm_header_val;
    logic                                       fsm_pipe_rdy;
    tcp_packet_header                           fsm_tcp_header;
    logic                                       fsm_payload_val;
    logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] fsm_payload_addr;
    logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  fsm_payload_len;
    
    tcp_flow_state_e                            fsm_tcp_flow_state;
    logic                                       fsm_flow_id_val;
    logic   [`FLOW_ID_W-1:0]                    fsm_flow_id;
    logic                                       fsm_temp_flow_id_val;
    logic   [`TEMP_FLOWID_W-1:0]                fsm_temp_flow_id;
    recv_state_entry                            fsm_recv_state_entry;
   

    logic                                       stall_i;
    logic   [`IP_ADDR_WIDTH-1:0]                state_backend_src_ip_reg_i;
    logic   [`IP_ADDR_WIDTH-1:0]                state_backend_dst_ip_reg_i;
    logic                                       state_backend_flow_id_val_reg_i;
    logic   [`FLOW_ID_W-1:0]                    state_backend_flow_id_reg_i;
    logic                                       state_backend_flow_header_val_reg_i;
    tcp_packet_header                           state_backend_flow_header_reg_i;
    tcp_flow_state_e                            state_backend_tcp_state_reg_i;
    recv_state_entry                            state_backend_recv_state_reg_i;
    
    logic                                       state_backend_temp_id_val_reg_i;
    logic   [`TEMP_FLOWID_W-1:0]                state_backend_temp_id_reg_i;
   
    logic                                       state_backend_payload_val_reg_i;
    logic   [`PAYLOAD_BUF_ENTRY_ADDR_WIDTH-1:0] state_backend_payload_addr_reg_i;
    logic   [`PAYLOAD_BUF_ENTRY_LEN_WIDTH-1:0]  state_backend_payload_len_reg_i;
   
    logic                                       tcp_state_collision_i;
    tcp_flow_state_e                            tcp_state_stall_reg_i;
    tcp_flow_state_e                            tcp_state_stall_next_i;
    logic                                       tcp_state_stall_val_reg_i;
    logic                                       tcp_state_stall_val_next_i;

    logic                                       stall_i_reg;
    logic                                       byp_recv_state_i;
    recv_state_entry                            recv_state_stall_reg_i;
    recv_state_entry                            recv_state_stall_next_i;
    logic                                       recv_state_stall_val_reg_i;
    logic                                       recv_state_stall_val_next_i;

    tcp_flow_state_e                            curr_tcp_state_i;
    recv_state_entry                            curr_recv_state_i;

    flow_lookup_entry                           curr_recv_lookup_entry_i;
    
    typedef enum logic { 
        EST_PIPE = 1'd0,
        FSM_PIPE = 1'd1
    } route_e;

    route_e route;

    assign recv_set_ack_pending = 1'b0;
    assign recv_set_ack_pending_addr = '0;

    assign stores_fsm_pipe_new_flow_rdy = frontend_fsm_addrtoid_lookup_rdy
                                          & est_pipe_new_write_rdy;
    assign new_idtoaddr_lookup_val = new_flow_nums_val;
    assign new_idtoaddr_lookup_flow_id = new_flow_flow_id;
    assign new_idtoaddr_lookup_entry = new_flow_lookup_entry;

    // all writes to the tuple to flow ID CAM and the TCP state machine states must go
    // through this module

    recv_flow_state_pipe rx_frontend_state_pipe (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.recv_src_ip                           (recv_src_ip                            )
        ,.recv_dst_ip                           (recv_dst_ip                            )
        ,.recv_header_val                       (recv_header_val                        )
        ,.recv_header                           (recv_header                            )
        ,.recv_header_rdy                       (recv_header_rdy                        )
        
        ,.recv_payload_val                      (recv_payload_val                       )
        ,.recv_payload_addr                     (recv_payload_addr                      )
        ,.recv_payload_len                      (recv_payload_len                       )

        ,.tcp_fsm_new_flow_lookup_val           (new_flow_nums_val                      )
        ,.tcp_fsm_new_flow_lookup_id            (new_flow_flow_id                       )
        ,.tcp_fsm_new_flow_lookup               (new_flow_lookup_entry                  )
        ,.tcp_fsm_new_flow_lookup_rdy           (frontend_fsm_addrtoid_lookup_rdy       )
        ,.tcp_fsm_clear_temp_flow_id_val        (tcp_fsm_clear_temp_flow_id_val         )
        ,.tcp_fsm_clear_temp_flow_id            (tcp_fsm_clear_temp_flow_id             )

        ,.tcp_fsm_update_tcp_state_val          (next_flow_state_wr_val                 )
        ,.tcp_fsm_update_tcp_state_flow_id      (next_flow_state_flow_id                )
        ,.tcp_fsm_update_tcp_state              (next_flow_state                        )
        ,.tcp_fsm_update_tcp_state_rdy          (next_flow_state_rdy                    )
    
        ,.tcp_fsm_curr_lookup_val               (tcp_fsm_curr_lookup_val                )
        ,.tcp_fsm_curr_flow_id_val              (tcp_fsm_curr_flow_id_val               )
        ,.tcp_fsm_curr_flow_id                  (tcp_fsm_curr_flow_id                   )
        ,.tcp_fsm_curr_temp_id_val              (tcp_fsm_curr_temp_flow_id_val          )
        ,.tcp_fsm_curr_temp_id                  (tcp_fsm_curr_temp_flow_id              )
    
        ,.curr_recv_state_req_val               (curr_recv_state_req_val                )
        ,.curr_recv_state_req_addr              (curr_recv_state_req_addr               )
        ,.curr_recv_state_req_rdy               (curr_recv_state_req_rdy                )

        ,.curr_recv_state_resp_val              (curr_recv_state_resp_val               )
        ,.curr_recv_state_resp                  (curr_recv_state_resp                   )
        ,.curr_recv_state_resp_rdy              (curr_recv_state_resp_rdy               )
    
        ,.recv_pipe_init_seq_num_rd_req_val     (recv_pipe_init_seq_num_rd_req_val      )
        ,.recv_pipe_init_seq_num_rd_req_addr    (recv_pipe_init_seq_num_rd_req_addr     )
        ,.init_seq_num_recv_pipe_rd_req_rdy     (init_seq_num_recv_pipe_rd_req_rdy      )

        ,.recv_state_wr_val                     (next_recv_state_val                    )
        ,.recv_state_wr_addr                    (next_recv_state_addr                   )
        ,.recv_state_wr_entry                   (next_recv_state                        )

        ,.state_backend_src_ip                  (state_backend_src_ip                   )
        ,.state_backend_dst_ip                  (state_backend_dst_ip                   )
        ,.state_backend_flow_header_val         (state_backend_flow_header_val          )
        ,.state_backend_flow_header             (state_backend_flow_header              )
        ,.state_backend_flow_id_val             (state_backend_flow_id_val              )
        ,.state_backend_flow_id                 (state_backend_flow_id                  )
        ,.backend_state_flow_rdy                (~stall_i                               )
        ,.state_backend_tcp_state               (state_backend_tcp_state                )
        ,.state_backend_recv_state              (state_backend_recv_state               )
        ,.state_backend_temp_id_val             (state_backend_temp_id_val              )
        ,.state_backend_temp_id                 (state_backend_temp_id                  )
                                                                                        
        ,.state_backend_payload_val             (state_backend_payload_val              )
        ,.state_backend_payload_addr            (state_backend_payload_addr             )
        ,.state_backend_payload_len             (state_backend_payload_len              )
    );

/***************************************************************
 * Frontend -> (I)ssue stage
 **************************************************************/
    always_ff @(posedge clk) begin
        if (rst) begin
            state_backend_src_ip_reg_i <= '0;
            state_backend_dst_ip_reg_i <= '0;
            state_backend_flow_id_val_reg_i <= '0;
            state_backend_flow_id_reg_i <= '0;
            state_backend_flow_header_val_reg_i <= '0;
            state_backend_flow_header_reg_i <= '0;
            state_backend_tcp_state_reg_i <= TCP_NONE;
            state_backend_recv_state_reg_i <= '0;
            state_backend_temp_id_val_reg_i <= '0;
            state_backend_temp_id_reg_i <= '0;
            
            state_backend_payload_val_reg_i <= '0;
            state_backend_payload_addr_reg_i <= '0;
            state_backend_payload_len_reg_i <= '0;
        end
        else begin
            if (~stall_i) begin
                state_backend_src_ip_reg_i <= state_backend_src_ip;
                state_backend_dst_ip_reg_i <= state_backend_dst_ip;
                state_backend_flow_id_val_reg_i <= state_backend_flow_id_val;
                state_backend_flow_id_reg_i <= state_backend_flow_id;
                state_backend_flow_header_val_reg_i <= state_backend_flow_header_val;
                state_backend_flow_header_reg_i <= state_backend_flow_header;
                state_backend_tcp_state_reg_i <= state_backend_tcp_state.state;
                state_backend_recv_state_reg_i <= state_backend_recv_state;
                
                state_backend_temp_id_val_reg_i <= state_backend_temp_id_val;
                state_backend_temp_id_reg_i <= state_backend_temp_id;
                
                state_backend_payload_val_reg_i <= state_backend_payload_val;
                state_backend_payload_addr_reg_i <= state_backend_payload_addr;
                state_backend_payload_len_reg_i <= state_backend_payload_len;
            end
        end
    end


/***************************************************************
 * (I)ssue stage
 **************************************************************/
    // do bypassing of the tcp state if needed
    always_comb begin
        if (tcp_fsm_curr_lookup_val & state_backend_flow_header_val_reg_i) begin
            if (state_backend_temp_id_val_reg_i) begin
                tcp_state_collision_i = state_backend_temp_id_reg_i == tcp_fsm_curr_temp_flow_id;
            end
            else begin
                tcp_state_collision_i = state_backend_flow_id_reg_i == tcp_fsm_curr_flow_id;
            end
        end
        else begin
            tcp_state_collision_i = 1'b0;
        end
    end

    // stall if there is a collision or if either of the places you want to send the packet
    // is busy
    assign stall_i = state_backend_flow_header_val_reg_i & 
                     ( (state_backend_flow_id_val_reg_i & ~init_seq_num_recv_pipe_rd_resp_val)
                     | (route == FSM_PIPE & ~fsm_pipe_rdy) 
                     | (route == EST_PIPE & ~est_pipe_rdy));

    assign recv_pipe_init_seq_num_rd_resp_rdy = state_backend_flow_header_val_reg_i &
                                                ((route == FSM_PIPE & fsm_pipe_rdy)
                                               | (route == EST_PIPE & est_pipe_rdy));


    always_comb begin
        if (tcp_state_collision_i & next_flow_state_wr_val) begin
            tcp_state_stall_next_i = next_flow_state.state;
            tcp_state_stall_val_next_i = 1'b1;
        end
        else begin
            tcp_state_stall_next_i = tcp_state_stall_reg_i;
            if (stall_i) begin
                tcp_state_stall_val_next_i = tcp_state_stall_val_reg_i;
            end
            else begin
                tcp_state_stall_val_next_i = 1'b0;
            end
        end
    end

    always_comb begin
        if (curr_tcp_state_i == TCP_EST) begin
            // if any flags are set that aren't ACK or push
            if ((state_backend_flow_header_reg_i.flags & ~(`TCP_ACK | `TCP_PSH))) begin
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

    assign byp_recv_state_i = state_backend_flow_id_val_reg_i 
                            & (next_recv_state_val & state_backend_flow_header_val_reg_i)
                            & (next_recv_state_addr == state_backend_flow_id_reg_i);

    always_comb begin
        if (byp_recv_state_i) begin
            recv_state_stall_next_i = next_recv_state;
            recv_state_stall_val_next_i = 1'b1;
        end
        else begin
            if (stall_i) begin
                recv_state_stall_next_i = recv_state_stall_reg_i;
                recv_state_stall_val_next_i = recv_state_stall_val_reg_i;
            end
            else begin
                recv_state_stall_val_next_i = 1'b0;
                recv_state_stall_next_i = recv_state_stall_reg_i;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            stall_i_reg <= '0;
            tcp_state_stall_reg_i <= TCP_NONE;
            tcp_state_stall_val_reg_i <= TCP_NONE;

            recv_state_stall_val_reg_i <= '0;
            recv_state_stall_reg_i <= '0;
        end
        else begin
            stall_i_reg <= stall_i;

            tcp_state_stall_reg_i <= tcp_state_stall_next_i;
            tcp_state_stall_val_reg_i <= tcp_state_stall_val_next_i;

            recv_state_stall_val_reg_i <= recv_state_stall_val_next_i;
            recv_state_stall_reg_i <= recv_state_stall_next_i;
        end
    end
    
    // there are multiple places the tcp state data may come from
    always_comb begin
        // we may have saved it from a bypass while stalling
        if (stall_i_reg & tcp_state_stall_val_reg_i) begin
            curr_tcp_state_i = tcp_state_stall_reg_i;
        end
        // it may be available this cycle but need bypassing
        else if (tcp_state_collision_i & next_flow_state_wr_val) begin
            curr_tcp_state_i = next_flow_state.state;
        end
        // otherwise, just take what we read if we actually read it
        else begin
            curr_tcp_state_i = state_backend_tcp_state_reg_i;
        end
    end
    
    // there are multiple places the receive state may come from
    always_comb begin
        if (stall_i_reg & recv_state_stall_val_reg_i) begin
            curr_recv_state_i = recv_state_stall_reg_i;
        end
        else if (byp_recv_state_i) begin
            curr_recv_state_i = next_recv_state;
        end
        else begin
            curr_recv_state_i = state_backend_recv_state_reg_i;
        end
    end


    assign est_header_val = (route == EST_PIPE) & state_backend_flow_header_val_reg_i & ~stall_i;
    assign est_tcp_header = state_backend_flow_header_reg_i;
    assign est_flow_id = state_backend_flow_id_reg_i;
    assign est_payload_val = state_backend_payload_val_reg_i & ~stall_i;
    assign est_payload_len = state_backend_payload_len_reg_i;
    assign est_payload_addr = state_backend_payload_addr_reg_i;

    // all writes to the RX state store must come out of this module
    est_pipe rx_est_flow_backend (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.est_header_val                    (est_header_val                     )
        ,.est_tcp_header                    (est_tcp_header                     )
        ,.est_flow_id                       (est_flow_id                        )
        ,.est_payload_val                   (est_payload_val                    )
        ,.est_payload_addr                  (est_payload_addr                   )
        ,.est_payload_len                   (est_payload_len                    )
        ,.est_pipe_rdy                      (est_pipe_rdy                       )
        ,.curr_recv_state                   (curr_recv_state_i                  )
        ,.init_seq_num                      (init_seq_num_recv_pipe_rd_resp_data)
    
        ,.new_flow_val                      (new_flow_nums_val                  )
        ,.new_flow_flow_id                  (new_flow_flow_id                   )
        ,.new_flow_init_ack_num             (new_ack_num                        )
        ,.new_flow_rdy                      (est_pipe_new_write_rdy             )
        
        ,.next_recv_state_val               (next_recv_state_val                )
        ,.next_recv_state_addr              (next_recv_state_addr               )
        ,.next_recv_state                   (next_recv_state                    )
    
        ,.engine_recv_header_val            (engine_recv_header_val             )
        ,.engine_recv_tcp_hdr               (engine_recv_tcp_hdr                )
        ,.engine_recv_flowid                (engine_recv_flowid                 )
    
        ,.engine_recv_packet_enqueue_val    (engine_recv_packet_enqueue_val     )
        ,.engine_recv_packet_enqueue_entry  (engine_recv_packet_enqueue_entry   )
    );
   

    assign fsm_header_src_ip = state_backend_src_ip_reg_i;
    assign fsm_header_dst_ip = state_backend_dst_ip_reg_i;
    assign fsm_header_val = (route == FSM_PIPE) & state_backend_flow_header_val_reg_i & ~stall_i;
    assign fsm_tcp_header = state_backend_flow_header_reg_i;
    assign fsm_payload_val = state_backend_payload_val_reg_i;
    assign fsm_payload_addr = state_backend_payload_addr_reg_i;
    assign fsm_payload_len = state_backend_payload_len_reg_i;


    assign fsm_tcp_flow_state = curr_tcp_state_i;
    assign fsm_flow_id_val = state_backend_flow_id_val_reg_i;
    assign fsm_flow_id = state_backend_flow_id_reg_i;
    assign fsm_temp_flow_id_val = state_backend_temp_id_val_reg_i;
    assign fsm_temp_flow_id = state_backend_temp_id_reg_i;
    assign fsm_recv_state_entry = curr_recv_state_i;

    fsm_pipe rx_tcp_state_backend (
         .clk   (clk)
        ,.rst   (rst)

        ,.recv_header_src_ip                    (fsm_header_src_ip                      )
        ,.recv_header_dst_ip                    (fsm_header_dst_ip                      )
        ,.recv_header_val                       (fsm_header_val                         )
        ,.recv_header_rdy                       (fsm_pipe_rdy                           )
        ,.recv_header                           (fsm_tcp_header                         )
        ,.recv_payload_val                      (fsm_payload_val                        )
        ,.recv_payload_addr                     (fsm_payload_addr                       )
        ,.recv_payload_len                      (fsm_payload_len                        )

        ,.recv_flow_state                       (fsm_tcp_flow_state                     )
        ,.recv_flow_id_val                      (fsm_flow_id_val                        )
        ,.recv_flow_id                          (fsm_flow_id                            )
        ,.curr_recv_state_entry                 (fsm_recv_state_entry                   )
        ,.flow_init_seq_num                     (init_seq_num_recv_pipe_rd_resp_data    )
        ,.temp_flow_id_val                      (fsm_temp_flow_id_val                   )
        ,.temp_flow_id                          (fsm_temp_flow_id                       )
    
        ,.fsm_curr_lookup_val                   (tcp_fsm_curr_lookup_val                )
        ,.fsm_curr_flow_id_val                  (tcp_fsm_curr_flow_id_val               )
        ,.fsm_curr_flow_id                      (tcp_fsm_curr_flow_id                   )
        ,.fsm_curr_temp_flow_id_val             (tcp_fsm_curr_temp_flow_id_val          )
        ,.fsm_curr_temp_flow_id                 (tcp_fsm_curr_temp_flow_id              )

        ,.syn_ack_val                           (syn_ack_val                            )
        ,.syn_ack_src_ip                        (syn_ack_src_ip                         )
        ,.syn_ack_dst_ip                        (syn_ack_dst_ip                         )
        ,.syn_ack_hdr                           (syn_ack_hdr                            )
        ,.syn_ack_rdy                           (syn_ack_rdy                            )

        ,.next_flow_state_wr_val                (next_flow_state_wr_val                 )
        ,.next_flow_state                       (next_flow_state                        )
        ,.next_state_flow_id                    (next_flow_state_flow_id                )
        ,.next_flow_state_rdy                   (next_flow_state_rdy                    )

        ,.new_flow_nums_val                     (new_flow_nums_val                      )
        ,.new_flow_flow_id                      (new_flow_flow_id                       )
        ,.new_ack_num                           (new_ack_num                            )
        ,.new_seq_num                           (new_init_seq_num                       )
        ,.new_flow_lookup_entry                 (new_flow_lookup_entry                  )
        ,.new_flow_state_rdy                    (stores_fsm_pipe_new_flow_rdy           )

        ,.tcp_fsm_clear_temp_flow_id_val        (tcp_fsm_clear_temp_flow_id_val         )
        ,.tcp_fsm_clear_temp_flow_id            (tcp_fsm_clear_temp_flow_id             )
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            app_new_flow_notif_val_reg <= '0;
            app_new_flow_flow_id_reg <= '0;
        end
        else begin
            app_new_flow_notif_val_reg <= new_flow_nums_val;
            app_new_flow_flow_id_reg <= new_flow_flow_id;
        end
    end

    assign app_new_flow_notif_val = app_new_flow_notif_val_reg;
    assign app_new_flow_flow_id = app_new_flow_flow_id_reg;

endmodule
