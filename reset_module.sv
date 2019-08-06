`include "tonic_params.vh"
`include "state_defs.vh"
`include "tonic_defaults.vh"
module reset_rams (
     input clk
    ,input rst

    ,output                                 reset_tonic_fifo_flowid_val
    ,output [`FLOW_ID_W-1:0]                reset_tonic_fifo_flowid

    ,output                                 reset_tonic_cntxt_val
    ,output [`FLOW_ID_W-1:0]                reset_tonic_cntxt_flowid
    ,output [`DD_CONTEXT_1_W-1:0]           reset_tonic_dd_cntxt_1
    ,output [`DD_CONTEXT_2_W-1:0]           reset_tonic_dd_cntxt_2
    ,output [`CR_CONTEXT_1_W-1:0]           reset_tonic_cr_cntxt_1
    
    ,output                                 reset_tonic_expected_ack_val
    ,output [`FLOW_ID_W-1:0]                reset_tonic_expected_ack_addr
    ,output [`PAYLOAD_WIN_SIZE_WIDTH-1:0]   reset_tonic_expected_ack_data
    
    ,output                                 reset_tonic_next_free_val
    ,output [`FLOW_ID_W-1:0]                reset_tonic_next_free_addr
    ,output [`PAYLOAD_WIN_SIZE_WIDTH-1:0]   reset_tonic_next_free_data

    ,output                                 reset_tonic_recv_enqueue_val
    ,output [`FLOW_ID_W-1:0]                reset_tonic_recv_enqueue_addr
    ,output [`PAYLOAD_WIN_SIZE_WIDTH-1:0]   reset_tonic_recv_enqueue_data
    
    ,output                                 reset_tonic_recv_dequeue_val
    ,output [`FLOW_ID_W-1:0]                reset_tonic_recv_dequeue_addr
    ,output [`PAYLOAD_WIN_SIZE_WIDTH-1:0]   reset_tonic_recv_dequeue_data

    ,output                                 reset_finished
);

// Model Parameters
`ifdef TONIC_INIT_CREDIT
localparam  INIT_CREDIT         = `TONIC_INIT_CREDIT;
`else
localparam  INIT_CREDIT         = 0;
`endif

`ifdef TONIC_INIT_RATE
localparam  INIT_RATE           = `TONIC_INIT_RATE;
`else
localparam  INIT_RATE           = 1;
`endif

// Reset state machine
localparam RESET_RAMS = 2'b00;
localparam RESET_FIFO = 2'b01;
localparam RUNNING    = 2'b10;

reg     [2:0]                   sim_state_reg;
reg     [2:0]                   sim_state_next;

reg     [`FLOW_ID_W-1:0]        fifo_flow_counter_reg;
wire    [`FLOW_ID_W-1:0]        fifo_flow_counter_next;


reg     [`FLOW_ID_W-1:0]        ram_flow_counter_reg;
wire    [`FLOW_ID_W-1:0]        ram_flow_counter_next;

assign reset_finished = sim_state_reg == RUNNING;

always @(posedge reset_finished) begin
    $display("Reset finished");
end


always @(posedge clk) begin
    if (rst) begin
        sim_state_reg <= RESET_RAMS;
    end
    else begin
        sim_state_reg <= sim_state_next;
    end
end

always @(*) begin

    case (sim_state_reg)
        RESET_RAMS: begin
            if (ram_flow_counter_reg == (`ACTIVE_FLOW_CNT - 1)) begin
                sim_state_next = RESET_FIFO;            
            end
            else begin
                sim_state_next = sim_state_reg;
            end
        end
        RESET_FIFO: begin
            if (fifo_flow_counter_reg == (`ACTIVE_FLOW_CNT - 2)) begin
                sim_state_next = RUNNING;
            end
            else begin
                sim_state_next = sim_state_reg;
            end
        end
        RUNNING: begin
            sim_state_next = sim_state_reg;
        end
        default: begin
            sim_state_next = 2'bX;
        end
    endcase 
end

// TODO add flow sizes

// Initializing the Fifo
assign fifo_flow_counter_next = 
        (sim_state_reg == RESET_FIFO) & (fifo_flow_counter_reg < `ACTIVE_FLOW_CNT) 
        ? fifo_flow_counter_reg + {{(`FLOW_ID_W - 1){1'b0}}, {1'b1}} : fifo_flow_counter_reg;

assign reset_tonic_fifo_flowid_val = (fifo_flow_counter_reg < `ACTIVE_FLOW_CNT) 
                            & (sim_state_reg == RESET_FIFO);
assign reset_tonic_fifo_flowid = fifo_flow_counter_reg;

always @(posedge clk) begin
    if (rst) begin
        fifo_flow_counter_reg <= {`FLOW_ID_W{1'b0}};
    end
    else begin
        fifo_flow_counter_reg <= fifo_flow_counter_next;
    end
end
//// Initializing the context stores

// Data Delivery Engine

wire    [`FLOW_SEQ_NUM_W-1:0]   rst_next_new;
wire    [`FLOW_SEQ_NUM_W-1:0]   rst_wnd_start;
wire    [`FLOW_WIN_IND_W-1:0]   rst_wnd_start_ind;
wire    [`TX_CNT_WIN_SIZE-1:0]  rst_tx_cnt_wnd;
wire    [`FLOW_WIN_SIZE-1:0]    rst_acked_wnd;
wire    [`FLOW_WIN_SIZE_W-1:0]  rst_wnd_size;

assign  rst_next_new        = `RST_NEXT_NEW;
assign  rst_wnd_start       = `RST_WND_START;
assign  rst_wnd_start_ind   = `RST_WND_START_IND;
assign  rst_tx_cnt_wnd      = `RST_TX_CNT_WND;
assign  rst_acked_wnd       = `RST_ACKED_WND;
assign  rst_wnd_size        = `TONIC_INIT_WND_SIZE;

wire    [`TIME_W-1:0]           rst_rtx_exptime;
wire    [`FLAG_W-1:0]           rst_active_rtx_timer;
wire    [`PKT_QUEUE_IND_W-1:0]  rst_pkt_queue_size;
wire    [`FLAG_W-1:0]           rst_back_pressure;
wire    [`FLAG_W-1:0]           rst_idle;
wire    [`FLOW_WIN_SIZE-1:0]    rst_rtx_wnd;
wire    [`TIMER_W-1:0]          rst_rtx_timer_amnt;
wire    [`USER_CONTEXT_W-1:0]   rst_user_cntxt;

assign  rst_rtx_exptime         = `RST_RTX_EXPTIME;
assign  rst_active_rtx_timer    = `RST_ACTIVE_RTX_TIMER;
assign  rst_pkt_queue_size      = `RST_PKT_QUEUE_SIZE;
assign  rst_back_pressure       = `RST_BACK_PRESSURE;
assign  rst_idle                = `RST_IDLE;
assign  rst_rtx_wnd             = `RST_RTX_WND;
assign  rst_rtx_timer_amnt      = `TONIC_INIT_RTX_TIMER_AMNT;
assign  rst_user_cntxt          = `INIT_USER_CONTEXT;

// Credit Engine
wire    [`MAX_QUEUE_BITS-1:0]       rst_pkt_queue;
wire    [`MAX_TX_ID_BITS-1:0]       rst_tx_id_queue;
wire    [`PKT_QUEUE_IND_W-1:0]      rst_pkt_queue_head;
wire    [`PKT_QUEUE_IND_W-1:0]      rst_pkt_queue_tail;
wire    [`FLAG_W-1:0]               rst_ready_to_tx;
wire    [`CRED_W-1:0]               rst_cred;
wire    [`TX_SIZE_W-1:0]            rst_tx_size;

assign  rst_pkt_queue       = `RST_PKT_QUEUE;
assign  rst_tx_id_queue     = `RST_TX_ID_QUEUE;
assign  rst_pkt_queue_head  = `RST_PKT_QUEUE_HEAD;
assign  rst_pkt_queue_tail  = `RST_PKT_QUEUE_TAIL;
assign  rst_ready_to_tx     = `RST_READY_TO_TX;
assign  rst_cred            = INIT_CREDIT;
assign  rst_tx_size         = `RST_TX_SIZE;

wire    [`TIME_W-1:0]               rst_last_cred_update;
wire    [`RATE_W-1:0]               rst_rate;
wire    [`TIME_W-1:0]               rst_reach_cap;

assign  rst_last_cred_update    = `RST_LAST_CRED_UPDATE;
assign  rst_rate                = INIT_RATE * 64 / 100; 
assign  rst_reach_cap           = (`CRED_CAP / INIT_RATE) * 512;


wire    [`DD_CONTEXT_1_W-1:0]  dd_init_cntxt_1;

assign  dd_init_cntxt_1 = {rst_next_new, rst_wnd_start,
                           rst_wnd_start_ind, rst_tx_cnt_wnd,
                           rst_acked_wnd, rst_wnd_size};


wire    [`DD_CONTEXT_2_W-1:0]  dd_init_cntxt_2;

assign dd_init_cntxt_2 =  {rst_rtx_exptime, rst_active_rtx_timer,
                           rst_pkt_queue_size, rst_back_pressure,
                           rst_idle, rst_rtx_wnd, 
                           rst_rtx_timer_amnt, rst_user_cntxt};

wire    [`CR_CONTEXT_1_W-1:0]  cr_init_cntxt;

assign  cr_init_cntxt =  {rst_pkt_queue, rst_tx_id_queue,
                          rst_pkt_queue_head, rst_pkt_queue_tail,
                          rst_pkt_queue_size, rst_ready_to_tx};

assign ram_flow_counter_next = 
    (sim_state_reg == RESET_RAMS) & (ram_flow_counter_reg < `ACTIVE_FLOW_CNT)
        ? ram_flow_counter_reg + {{(`FLOW_ID_W - 1){1'b0}}, {1'b1}}
        : ram_flow_counter_reg;

assign reset_tonic_cntxt_val = (ram_flow_counter_reg < `ACTIVE_FLOW_CNT)
                           & (sim_state_reg == RESET_RAMS);
assign reset_tonic_cntxt_flowid = ram_flow_counter_reg;
assign reset_tonic_dd_cntxt_1 = dd_init_cntxt_1;
assign reset_tonic_dd_cntxt_2 = dd_init_cntxt_2;
assign reset_tonic_cr_cntxt_1 = cr_init_cntxt;

always @(posedge clk) begin
    if (rst) begin
        ram_flow_counter_reg <= {`FLOW_ID_W{1'b0}};
    end
    else begin
        ram_flow_counter_reg <= ram_flow_counter_next;
    end
end

wire add_new_flowid_lookup;
assign add_new_flowid_lookup = ~rst 
                             & (sim_state_reg == RESET_RAMS) 
                             & (ram_flow_counter_reg < `ACTIVE_FLOW_CNT);

assign reset_tonic_expected_ack_val = reset_tonic_cntxt_val;
assign reset_tonic_expected_ack_addr = reset_tonic_cntxt_flowid;
assign reset_tonic_expected_ack_data = {`PAYLOAD_WIN_SIZE_WIDTH{1'b0}};

assign reset_tonic_next_free_val = reset_tonic_cntxt_val;
assign reset_tonic_next_free_addr = reset_tonic_cntxt_flowid;
assign reset_tonic_next_free_data = {`PAYLOAD_WIN_SIZE_WIDTH{1'b0}};

assign reset_tonic_recv_enqueue_val = reset_tonic_cntxt_val;
assign reset_tonic_recv_enqueue_addr = reset_tonic_cntxt_flowid;
assign reset_tonic_recv_enqueue_data = {`PAYLOAD_WIN_SIZE_WIDTH{1'b0}};

assign reset_tonic_recv_dequeue_val = reset_tonic_cntxt_val;
assign reset_tonic_recv_dequeue_addr = reset_tonic_cntxt_flowid;
assign reset_tonic_recv_dequeue_data = {`PAYLOAD_WIN_SIZE_WIDTH{1'b0}};

endmodule
