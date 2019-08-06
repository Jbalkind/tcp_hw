module sim_cpu (
     input clk
    ,input rst

    ,output                                 new_flow_val
    ,output [`FLOW_ID_W-1:0]                new_flow_flowid
    ,output [`FLOW_LOOKUP_ENTRY_WIDTH-1:0]  new_flow_lookup_entry
    ,output [`ACK_NUM_WIDTH-1:0]            new_flow_init_ack_num
);


    logic                                       flow_lookup_entry_val_dpi;
    logic                                       flow_lookup_entry_val_dpi_reg;
    logic   [`FLOW_ID_W-1:0]                    flow_lookup_entry_flowid_dpi;
    logic   [`FLOW_ID_W-1:0]                    flow_lookup_entry_flowid_dpi_reg;
    logic   [`FLOW_LOOKUP_ENTRY_WIDTH-1:0]      flow_lookup_entry_dpi;
    flow_lookup_entry                           flow_lookup_entry_dpi_reg;
    logic   [`ACK_NUM_WIDTH-1:0]                new_flow_init_ack_num_dpi;
    logic   [`ACK_NUM_WIDTH-1:0]                new_flow_init_ack_num_dpi_reg;

    
    flow_lookup_entry                           new_lookup_entry;

    assign new_flow_val = flow_lookup_entry_val_dpi_reg;
    assign new_flow_flowid = flow_lookup_entry_flowid_dpi_reg;
    assign new_flow_lookup_entry = flow_lookup_entry_dpi_reg;
    assign new_flow_init_ack_num = new_flow_init_ack_num_dpi_reg;

    always @(posedge clk) begin
        if (rst) begin
            flow_lookup_entry_val_dpi_reg <= 'b0;
            flow_lookup_entry_flowid_dpi_reg <= 'b0;
            flow_lookup_entry_dpi_reg <= 'b0;
            new_flow_init_ack_num_dpi_reg <= '0;
        end
        else begin
            flow_lookup_entry_val_dpi_reg <= flow_lookup_entry_val_dpi;
            flow_lookup_entry_flowid_dpi_reg <= flow_lookup_entry_flowid_dpi;
            flow_lookup_entry_dpi_reg <= flow_lookup_entry_dpi;
            new_flow_init_ack_num_dpi_reg <= new_flow_init_ack_num_dpi;
        end
    end

export "DPI-C" function write_flowid_lookup;
function void write_flowid_lookup(input bit[`FLOW_LOOKUP_ENTRY_WIDTH-1:0] new_lookup_entry,
                                  input int new_flowid, input int init_ack_num);
    flow_lookup_entry_dpi = new_lookup_entry;
    flow_lookup_entry_flowid_dpi = new_flowid;
    new_flow_init_ack_num_dpi = init_ack_num;
endfunction

/*****************************************************************************
 * Tick the valid signals
 ****************************************************************************/

import "DPI-C" context function bit tick_flow_valid(input int flowid);
always @(posedge clk) begin
   flow_lookup_entry_val_dpi = tick_flow_valid(flow_lookup_entry_flowid_dpi); 
end

import "DPI-C" context function void local_init();
initial begin
    local_init();
end


endmodule
