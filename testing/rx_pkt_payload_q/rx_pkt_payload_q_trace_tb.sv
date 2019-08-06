`include "bsg_defines.v"
`include "test_defs.vh"
module rx_pkt_payload_q_trace_tb();
    localparam  CLOCK_PERIOD      = 10000;
    localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
    localparam  RST_TIME = CLOCK_PERIOD * 3;

    localparam num_traces = 39;
    localparam trace_addr_w = `BSG_SAFE_CLOG2(num_traces);
    
    logic clk;
    logic rst;
    
    logic   en_trace;
    
    logic                           trace_input_val;
    logic   [`TRACE_W-1:0]          trace_input;
    logic                           trace_input_rdy;

    logic                           trace_resp_val;
    logic   [`TRACE_W-1:0   ]       trace_resp;
    logic                           trace_resp_rdy;


    logic   [`TRACE_W + 4 - 1:0]    rom_trace_data;
    logic   [trace_addr_w-1:0]      rom_trace_addr;

    logic   [`IF_SELECT_W-1:0]      if_select;
    logic   [`IF_SELECT_W-1:0]      resp_if_select;
    
    logic                               new_head_val;
    logic   [`FLOW_ID_W-1:0]            new_head_addr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    new_head_data;
    logic                               new_head_rdy;
    logic                               new_tail_val;
    logic   [`FLOW_ID_W-1:0]            new_tail_addr;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    new_tail_data;
    logic                               new_tail_rdy;

    logic                               q_full_req_val;
    logic   [`FLOW_ID_W-1:0]            q_full_req_flowid;
    logic                               q_full_req_rdy;

    logic                               q_full_resp_val;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    q_full_resp_tail_index;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    q_full_resp_head_index;
    logic                               q_full_resp_rdy;

    logic                               enqueue_pkt_req_val;
    logic   [`FLOW_ID_W-1:0]            enqueue_pkt_req_flowid;
    logic   [`PAYLOAD_ENTRY_W-1:0]      enqueue_pkt_req_data;
    logic   [`RX_PAYLOAD_Q_SIZE_W:0]    enqueue_pkt_req_index;
    logic                               enqueue_pkt_req_rdy;
    
    logic                               read_payload_req_val;
    logic   [`FLOW_ID_W-1:0]            read_payload_req_flowid;
    logic                               read_payload_req_rdy;

    logic                               read_payload_resp_val;
    logic                               read_payload_resp_is_empty;
    logic   [`PAYLOAD_ENTRY_W-1:0]      read_payload_resp_entry;
    logic                               read_payload_resp_rdy;

    logic   [`CMD_TRACE_W-1:0]          input_cmd_trace;
    logic   [`CMD_TRACE_W-1:0]          output_cmd_trace;

    new_req_struct                      new_req;
    full_req_struct                     full_req;
    full_resp_struct                    full_resp;
    enq_req_struct                      enq_req;
    deq_req_struct                      deq_req;
    deq_resp_struct                     deq_resp;

    
    // Clock generation
    initial begin
        clk = 0;
        forever begin
            #(CLOCK_HALF_PERIOD) clk = ~clk;
        end
    end
    
    initial begin
        @(negedge rst);
        @(posedge clk);
        
        // Try to write a whole line of 512 bits (64 bytes)
        @(posedge clk);
        en_trace = 1;
    end
    
    // Reset generation
    initial begin
        rst = 1'b1;
        #RST_TIME rst = 1'b0; 
    end

    assign input_cmd_trace = trace_input[`CMD_TRACE_W-1:0];
    assign if_select = trace_input[`TRACE_W-1 -: `IF_SELECT_W];

    always_comb begin
        trace_input_rdy = 1'b0;
        if (trace_input_val) begin
            if (if_select == `NEW_REQ) begin
                trace_input_rdy = new_head_rdy & new_tail_rdy;
            end
            else if (if_select == `FULL_REQ) begin
                trace_input_rdy = q_full_req_rdy;
            end
            else if (if_select == `ENQ_REQ) begin
                trace_input_rdy = enqueue_pkt_req_rdy;
            end
            else if (if_select == `DEQ_REQ) begin
                trace_input_rdy = read_payload_req_rdy;
            end
            else begin
                trace_input_rdy = 'X;
            end
        end
        else begin
            trace_input_rdy = 1'b0;
        end
    end

    assign resp_if_select = rom_trace_data[`TRACE_W - 1 -: `IF_SELECT_W];
    always_comb begin
        trace_resp_val = 1'b0;
        trace_resp = '0;
        if (resp_if_select == `FULL_REQ) begin
            trace_resp_val = q_full_resp_val;
            trace_resp = {resp_if_select, full_resp, {(`CMD_TRACE_W-`FULL_RESP_STRUCT_W){1'b0}}};
        end
        else if (resp_if_select == `DEQ_REQ) begin
            trace_resp_val = read_payload_resp_val;
            trace_resp = {resp_if_select,
                          deq_resp,
                         {(`CMD_TRACE_W-`DEQ_RESP_STRUCT_W){1'b0}}};
        end
        else begin
            trace_resp_val = 1'b0;
            trace_resp = '0;
        end
    end
    
    bsg_trace_replay #(
         .payload_width_p   (`TRACE_W           )
        ,.rom_addr_width_p  (trace_addr_w       )
        ,.debug_p   (2)
    ) trace_replay (
         .clk_i     (clk)
        ,.reset_i   (rst)
        ,.en_i      (en_trace)

        // input channel
        ,.v_i       (trace_resp_val )
        ,.data_i    (trace_resp     )
        ,.ready_o   (trace_resp_rdy )

        // output channel
        ,.v_o       (trace_input_val)
        ,.data_o    (trace_input    )
        ,.yumi_i    (trace_input_rdy)

        // connection to rom
        // note: asynchronous reads

        ,.rom_addr_o(rom_trace_addr )
        ,.rom_data_i(rom_trace_data )

        // true outputs
        ,.done_o    ()
        ,.error_o   ()
    );
    
    test_rom #(
         .width_p(`TRACE_W + 4)
        ,.addr_width_p(`BSG_SAFE_CLOG2(num_traces))
    ) test_rom (
         .addr_i(rom_trace_addr)
        ,.data_o(rom_trace_data)
    );

    assign new_head_val = trace_input_val & (if_select == `NEW_REQ);
    assign new_tail_val = trace_input_val & (if_select == `NEW_REQ);
    assign q_full_req_val = trace_input_val & (if_select == `FULL_REQ);
    assign enqueue_pkt_req_val = trace_input_val & (if_select == `ENQ_REQ);
    assign read_payload_req_val = trace_input_val & (if_select == `DEQ_REQ);

    assign new_req = input_cmd_trace[`CMD_TRACE_W-1 -: `NEW_REQ_STRUCT_W];
    assign full_req = input_cmd_trace[`CMD_TRACE_W-1 -: `FULL_REQ_STRUCT_W];
    assign enq_req = input_cmd_trace[`CMD_TRACE_W-1 -: `ENQ_REQ_STRUCT_W];
    assign deq_req = input_cmd_trace[`CMD_TRACE_W-1 -: `DEQ_REQ_STRUCT_W];


    rx_pkt_payload_q DUT (
         .clk   (clk)
        ,.rst   (rst)

        // For setting new pointer state
        ,.new_head_val              (new_head_val           )
        ,.new_head_addr             (new_req.flowid         )
        ,.new_head_data             (new_req.head_ptr       )
        ,.new_head_rdy              (new_head_rdy           )
        ,.new_tail_val              (new_tail_val           )
        ,.new_tail_addr             (new_req.flowid         )
        ,.new_tail_data             (new_req.tail_ptr       )
        ,.new_tail_rdy              (new_tail_rdy           )

        ,.q_full_req_val            (q_full_req_val         )
        ,.q_full_req_flowid         (full_req.flowid        )
        ,.q_full_req_rdy            (q_full_req_rdy         )

        ,.q_full_resp_val           (q_full_resp_val        )
        ,.q_full_resp_tail_index    (full_resp.tail_ptr     )
        ,.q_full_resp_head_index    (full_resp.head_ptr     )
        ,.q_full_resp_rdy           (trace_resp_rdy         )

        ,.enqueue_pkt_req_val       (enqueue_pkt_req_val    )
        ,.enqueue_pkt_req_flowid    (enq_req.flowid         )
        ,.enqueue_pkt_req_data      (enq_req.payload_desc   )
        ,.enqueue_pkt_req_index     (enq_req.tail_ptr       )
        ,.enqueue_pkt_req_rdy       (enqueue_pkt_req_rdy    )

        // For reading out a packet from the queue
        ,.read_payload_req_val      (read_payload_req_val   )
        ,.read_payload_req_flowid   (deq_req.flowid         )
        ,.read_payload_req_rdy      (read_payload_req_rdy   )

        ,.read_payload_resp_val     (read_payload_resp_val  )
        ,.read_payload_resp_is_empty(deq_resp.empty         )
        ,.read_payload_resp_entry   (deq_resp.payload_desc  )
        ,.read_payload_resp_rdy     (trace_resp_rdy         )
    );
endmodule
