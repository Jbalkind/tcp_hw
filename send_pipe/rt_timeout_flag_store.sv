module rt_timeout_flag_store 
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input                                      new_flow_val
    ,input          [FLOWID_W-1:0]              new_flow_flowid

    ,input                                      main_pipe_rt_timeout_rd_req_val
    ,input          [FLOWID_W-1:0]              main_pipe_rt_timeout_rd_req_flowid
    ,output                                     rt_timeout_main_pipe_rd_req_rdy

    ,output logic                               rt_timeout_main_pipe_rd_resp_val
    ,output logic   [RT_TIMEOUT_FLAGS_W-1:0]    rt_timeout_main_pipe_rd_resp_data
    ,input                                      main_pipe_rt_timeout_rd_resp_rdy

    ,input                                      main_pipe_rt_timeout_clr_bit_val
    ,input          [FLOWID_W-1:0]              main_pipe_rt_timeout_clr_bit_flowid

    ,input                                      timeout_set_bit_val
    ,input          [FLOWID_W-1:0]              timeout_set_bit_flowid

    ,input                                      rt_set_bit_val
    ,input          [FLOWID_W-1:0]              rt_set_bit_flowid
);

    logic   [MAX_FLOW_CNT-1:0]  rt_flags_reg;
    logic   [MAX_FLOW_CNT-1:0]  timeout_flags_reg;
    
    logic   [MAX_FLOW_CNT-1:0]  rt_flags_next;
    logic   [MAX_FLOW_CNT-1:0]  timeout_flags_next;

    logic                       timeout_bit_byp;
    logic                       rt_bit_byp;
   
    logic   [MAX_FLOW_CNT-1:0]  rt_set_bitmask;
    logic   [MAX_FLOW_CNT-1:0]  timeout_set_bitmask;
    
    logic   [MAX_FLOW_CNT-1:0]  rt_clr_bitmask;
    logic   [MAX_FLOW_CNT-1:0]  timeout_clr_bitmask;
    logic   [MAX_FLOW_CNT-1:0]  new_flow_clr_bitmask;

    logic                       rd_val_reg;
    logic   [FLOWID_W-1:0]      rd_addr_reg;

    logic   [MAX_FLOW_CNT-1:0]  timeout_bit_shifted;
    logic   [MAX_FLOW_CNT-1:0]  rt_bit_shifted;

    rt_timeout_flag_struct      rd_resp_struct;

    assign rt_timeout_main_pipe_rd_req_rdy = (main_pipe_rt_timeout_rd_resp_rdy | ~rd_val_reg);

    always_ff @(posedge clk) begin
        if (rst) begin
            rt_flags_reg <= '0;
            timeout_flags_reg <= '0;
        end
        else begin
            rt_flags_reg <= rt_flags_next;
            timeout_flags_reg <= timeout_flags_next;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_val_reg <= '0;
            rd_addr_reg <= '0;
        end
        else begin
            if (main_pipe_rt_timeout_rd_resp_rdy | ~rd_val_reg) begin
                rd_val_reg <= main_pipe_rt_timeout_rd_req_val;
                rd_addr_reg <= main_pipe_rt_timeout_rd_req_flowid;
            end
        end
    end

    assign rt_timeout_main_pipe_rd_resp_val = rd_val_reg;
    assign rt_timeout_main_pipe_rd_resp_data = rd_resp_struct;

    assign timeout_bit_shifted = timeout_flags_reg >> rd_addr_reg;
    assign rt_bit_shifted = rt_flags_reg >> rd_addr_reg;

    assign rd_resp_struct.timeout_pending = timeout_bit_shifted[0];
    assign rd_resp_struct.rt_pending = rt_bit_shifted[0];


    // we don't need to check for bypassing, because the set bits will override appropriately
    
    // set the bit at the flowid to 1, everything else is 0
    assign rt_set_bitmask = {{(MAX_FLOW_CNT-1){1'b0}}, rt_set_bit_val} << rt_set_bit_flowid;
    assign timeout_set_bitmask = 
        {{(MAX_FLOW_CNT-1){1'b0}}, timeout_set_bit_val} << timeout_set_bit_flowid;

    // set the bit at the flowid to 0, everything else is 1
    assign rt_clr_bitmask = 
        ~({{(MAX_FLOW_CNT-1){1'b0}}, main_pipe_rt_timeout_clr_bit_val} 
            << main_pipe_rt_timeout_clr_bit_flowid);
    assign timeout_clr_bitmask = 
        ~({{(MAX_FLOW_CNT-1){1'b0}}, main_pipe_rt_timeout_clr_bit_val} 
            << main_pipe_rt_timeout_clr_bit_flowid);

    // set the bit at the flowid to 0, everything else is 1
    assign new_flow_clr_bitmask = 
        ~({{(MAX_FLOW_CNT-1){1'b0}}, new_flow_val} << new_flow_flowid);


    // we don't check for bypassing with the new flow, because if the flow ID is available, there
    // shouldn't be any operations for it in the pipe
    
    //assign timeout_bit_byp = (main_pipe_clr_bit_val & timeout_set_bit_val 
    //                         & (main_pipe_clr_bit_flowid == timeout_set_bit_flowid));

    //assign rt_bit_byp = (main_pipe_clr_bit_val & rt_set_bit_val)
    //                    & (main_pipe_clr_bit_flowid == rt_set_bit_flowid);

    //// set the rt bit if the write is valid and we aren't bypassing
    //assign rt_bit_mask = rt_set_bit_val
    //                   ? {{(MAX_FLOW_CNT-1){1'b0}}, ~rt_bit_byp} << rt_set_bit_flowid
    //                   : 
    //assign timeout_bit_mask = {{(MAX_FLOW_CNT-1){1'b0}}, }

   
    assign rt_flags_next = ((rt_flags_reg | rt_set_bitmask) 
                           & rt_clr_bitmask) 
                           & new_flow_clr_bitmask;
    assign timeout_flags_next = ((timeout_flags_reg | timeout_set_bitmask)
                                & timeout_clr_bitmask)
                                & new_flow_clr_bitmask;
    
endmodule
