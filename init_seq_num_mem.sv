`include "state_defs.vh"
`include "packet_defs.vh"
`include "tonic_params.vh"

module init_seq_num_mem #(
     parameter width_p=`SEQ_NUM_WIDTH
    ,parameter els_p = `MAX_FLOW_CNT
    ,parameter addr_w = `BSG_SAFE_CLOG2(els_p)
)(
     input clk
    ,input rst

    ,input                          init_seq_num_wr_req_val
    ,input          [addr_w-1:0]    init_seq_num_wr_req_addr
    ,input          [width_p-1:0]   init_seq_num_wr_num
    ,output logic                   init_seq_num_wr_req_rdy

    ,input                          init_seq_num_rd0_req_val
    ,input          [addr_w-1:0]    init_seq_num_rd0_req_addr
    ,output logic                   init_seq_num_rd0_req_rdy

    ,output logic                   init_seq_num_rd0_resp_val
    ,output logic   [width_p-1:0]   init_seq_num_rd0_resp
    ,input                          init_seq_num_rd0_resp_rdy
    
    ,input                          init_seq_num_rd1_req_val
    ,input          [addr_w-1:0]    init_seq_num_rd1_req_addr
    ,output logic                   init_seq_num_rd1_req_rdy

    ,output logic                   init_seq_num_rd1_resp_val
    ,output logic   [width_p-1:0]   init_seq_num_rd1_resp
    ,input                          init_seq_num_rd1_resp_rdy
);
    assign init_seq_num_wr_req_rdy = 1'b1;
    assign init_seq_num_rd0_req_rdy = ~init_seq_num_rd0_resp_val | init_seq_num_rd0_resp_rdy;
    assign init_seq_num_rd1_req_rdy = ~init_seq_num_rd1_resp_val | init_seq_num_rd1_resp_rdy;

    logic                   mem_wr_req_val_byp;
    logic   [addr_w-1:0]    mem_wr_req_addr_byp;
    logic   [width_p-1:0]   mem_wr_req_data_byp;
    
    logic                   mem_wr_req_val_reg;
    logic   [addr_w-1:0]    mem_wr_req_addr_reg;
    logic   [width_p-1:0]   mem_wr_req_data_reg;
    
    logic                   mem_wr_req_val;
    logic   [addr_w-1:0]    mem_wr_req_addr;
    logic   [width_p-1:0]   mem_wr_req_data;
    
    logic                   mem_rd0_req_val_reg;
    logic   [addr_w-1:0]    mem_rd0_req_addr_reg;

    logic                   mem_rd0_req_val_byp;
    logic   [addr_w-1:0]    mem_rd0_req_addr_byp;

    logic                   mem_rd0_req_val;
    logic   [addr_w-1:0]    mem_rd0_req_addr;

    logic   [width_p-1:0]   mem_rd0_resp_data;
    
    logic                   mem_rd1_req_val_reg;
    logic   [addr_w-1:0]    mem_rd1_req_addr_reg;

    logic                   mem_rd1_req_val_byp;
    logic   [addr_w-1:0]    mem_rd1_req_addr_byp;

    logic                   mem_rd1_req_val;
    logic   [addr_w-1:0]    mem_rd1_req_addr;

    logic   [width_p-1:0]   mem_rd1_resp_data;

    assign mem_wr_req_val = init_seq_num_wr_req_val;
    assign mem_wr_req_addr = init_seq_num_wr_req_addr;
    assign mem_wr_req_data = init_seq_num_wr_num;

    // if we're currently backpressuring, we need to reissue from the registers
    assign mem_rd0_req_val = (init_seq_num_rd0_resp_val & ~init_seq_num_rd0_resp_rdy)
                            ? mem_rd0_req_val_reg
                            : init_seq_num_rd0_req_val;

    assign mem_rd0_req_addr = (init_seq_num_rd0_resp_val & ~init_seq_num_rd0_resp_rdy)
                             ? mem_rd0_req_addr_reg
                             : init_seq_num_rd0_req_addr;

    assign mem_rd1_req_val = (init_seq_num_rd1_resp_val & ~init_seq_num_rd1_resp_rdy)
                            ? mem_rd1_req_val_reg
                            : init_seq_num_rd1_req_val;
    
    assign mem_rd1_req_addr = (init_seq_num_rd1_resp_val & ~init_seq_num_rd1_resp_rdy)
                             ? mem_rd1_req_addr_reg
                             : init_seq_num_rd1_req_addr;
        

    always_ff @(posedge clk) begin
        if (rst) begin
            mem_wr_req_val_reg <= '0;
            mem_wr_req_addr_reg <= '0;
            mem_wr_req_data_reg <= '0;
        end
        else begin
            if (init_seq_num_wr_req_rdy) begin
                mem_wr_req_val_reg <= mem_wr_req_val;
                mem_wr_req_addr_reg <= mem_wr_req_addr;
                mem_wr_req_data_reg <= mem_wr_req_data;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mem_rd0_req_val_reg <= '0;
            mem_rd0_req_addr_reg <= '0;
        end
        else begin
            if (init_seq_num_rd0_req_rdy) begin
                mem_rd0_req_val_reg <= mem_rd0_req_val;
                mem_rd0_req_addr_reg <= mem_rd0_req_addr;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mem_rd1_req_val_reg <= '0;
            mem_rd1_req_addr_reg <= '0;
        end
        else begin
            if (init_seq_num_rd1_req_rdy) begin
                mem_rd1_req_val_reg <= mem_rd1_req_val;
                mem_rd1_req_addr_reg <= mem_rd1_req_addr;
            end
        end
    end
    
    // set valid signals for bypassing
    always_comb begin
        if (mem_rd0_req_val & mem_wr_req_val &
            (mem_rd0_req_addr == mem_wr_req_addr)) begin
            mem_rd0_req_val_byp = 1'b0;
        end
        else begin
            mem_rd0_req_val_byp = mem_rd0_req_val;
        end
    end
    
    always_comb begin
        if (mem_rd1_req_val & mem_wr_req_val &
            (mem_rd1_req_addr == mem_wr_req_addr)) begin
            mem_rd1_req_val_byp = 1'b0;
        end
        else begin
            mem_rd1_req_val_byp = mem_rd1_req_val;
        end
    end

    assign mem_rd0_req_addr_byp = mem_rd0_req_addr;
    assign mem_rd1_req_addr_byp = mem_rd1_req_addr;

    assign mem_wr_req_val_byp = mem_wr_req_val;
    assign mem_wr_req_addr_byp = mem_wr_req_addr;
    assign mem_wr_req_data_byp = mem_wr_req_data;

    bsg_mem_2r1w_sync #(
         .width_p   (width_p)
        ,.els_p     (els_p)
    ) init_seq_num_mem (
         .clk_i     (clk    )
        ,.reset_i   (rst    )
        
        ,.w_v_i     (mem_wr_req_val_byp )
        ,.w_addr_i  (mem_wr_req_addr_byp)
        ,.w_data_i  (mem_wr_req_data_byp)
    
        ,.r0_v_i    (mem_rd0_req_val_byp    )
        ,.r0_addr_i (mem_rd0_req_addr_byp   )
        ,.r0_data_o (mem_rd0_resp_data      )
        
        ,.r1_v_i    (mem_rd1_req_val_byp    )
        ,.r1_addr_i (mem_rd1_req_addr_byp   )
        ,.r1_data_o (mem_rd1_resp_data      )
        
    );

    assign init_seq_num_rd0_resp_val = mem_rd0_req_val_reg;
    assign init_seq_num_rd1_resp_val = mem_rd1_req_val_reg;

    // bypass write outputs if necessary
    always_comb begin
        if (mem_wr_req_val_reg & mem_rd0_req_val_reg & 
            (mem_wr_req_addr_reg == mem_rd0_req_addr_reg)) begin
            init_seq_num_rd0_resp = mem_wr_req_data_reg;
        end
        else begin
            init_seq_num_rd0_resp = mem_rd0_resp_data;
        end
    end
    
    always_comb begin
        if (mem_wr_req_val_reg & mem_rd1_req_val_reg & 
            (mem_wr_req_addr_reg == mem_rd1_req_addr_reg)) begin
            init_seq_num_rd1_resp = mem_wr_req_data_reg;
        end
        else begin
            init_seq_num_rd1_resp = mem_rd1_resp_data;
        end
    end
endmodule
