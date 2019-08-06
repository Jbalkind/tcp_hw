`include "bsg_defines.v"
module multiplex_ram #(
     parameter width_p=-1
    ,parameter els_p=-1
    ,parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
) (
     input  mem_clk
    ,input  sys_clk
    ,input  mem_rst
    ,input  sys_rst
    
    ,input                      w_v_i
    ,input  [addr_width_lp-1:0] w_addr_i
    ,input  [width_p-1:0]       w_data_i

    // currently unused
    ,input                       r_v_i
    ,input  [addr_width_lp-1:0]  r_addr_i

    ,output logic [width_p-1:0] r_data_o
);

    localparam READ = 1'b0;
    localparam WRITE = 1'b1;

    logic serve_req_type_reg;
    logic serve_read;
    logic serve_read_reg;
    logic serve_write;

    logic                       mem_en;
    logic                       mem_w_en;
    logic   [addr_width_lp-1:0] mem_addr;
    logic   [width_p-1:0]       mem_read_data;

    logic   [width_p-1:0]       r_data_out_reg;

    always_ff @(posedge mem_clk) begin
        if (mem_rst) begin
            serve_req_type_reg <= READ;
        end
        else begin
            serve_req_type_reg <= ~serve_req_type_reg;
        end
    end

    assign serve_read = (serve_req_type_reg == READ);
    assign serve_write = (serve_req_type_reg == WRITE) & w_v_i;

    assign mem_addr = serve_req_type_reg == WRITE ? w_addr_i : r_addr_i;
    assign mem_en = serve_read | serve_write;
    assign mem_w_en = serve_write;

    bsg_mem_1rw_sync #(
         .width_p   (width_p)
        ,.els_p     (els_p)
    ) data_mem (
         .clk_i     (mem_clk    )
        ,.reset_i   (mem_rst    )
        ,.data_i    (w_data_i           )
        ,.addr_i    (mem_addr           )
        ,.v_i       (mem_en             )
        ,.w_i       (mem_w_en           )
        ,.data_o    (mem_read_data      )
    );
  
    always_ff @(posedge mem_clk) begin
        if (mem_rst) begin
            serve_read_reg <= 'b0; 
        end
        else begin
            serve_read_reg <= serve_read;
        end
    end
    always_ff @(posedge mem_clk) begin
        if (mem_rst) begin
            r_data_out_reg <= 'b0;
        end
        else begin
            if (serve_read_reg) begin
                r_data_out_reg <= mem_read_data;
            end
        end
    end

    assign r_data_o = r_data_out_reg;
endmodule
