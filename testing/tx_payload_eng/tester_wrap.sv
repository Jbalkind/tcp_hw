`include "soc_defs.vh"
`include "noc_defs.vh"
`include "test.vh"
module tester_wrap #(
     parameter SRC_X = 0
    ,parameter SRC_Y = 0
    ,parameter DST_DRAM_X = 0
    ,parameter DST_DRAM_Y = 0
) (
     input clk
    ,input rst

    ,output logic                               tester_noc0_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]       tester_noc0_data
    ,input                                      noc0_tester_rdy
   
    ,input                                      noc0_tester_val
    ,input          [`NOC_DATA_WIDTH-1:0]       noc0_tester_data
    ,output logic                               tester_noc0_rdy
    
    // trace tester's control interface
    ,input                                      trace_tester_tile_wr_mem_req_val
    ,input          [`TRACE_ADDR_W-1:0]         trace_tester_tile_wr_mem_req_addr
    ,input          [`TRACE_SIZE_W-1:0]         trace_tester_tile_wr_mem_req_size
    ,output logic                               tester_tile_trace_wr_mem_req_rdy
    
    ,input  logic                               trace_tester_tile_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]      trace_tester_tile_data
    ,input  logic                               trace_tester_tile_data_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]       trace_tester_tile_data_padbytes
    ,output                                     tester_tile_trace_data_rdy

    ,input                                      trace_tester_tile_rd_mem_req_val
    ,input          [`TRACE_ADDR_W-1:0]         trace_tester_tile_rd_mem_req_addr
    ,input          [`TRACE_SIZE_W-1:0]         trace_tester_tile_rd_mem_req_size
    ,output logic                               tester_tile_trace_rd_mem_req_rdy
   
     // control to the rd mem engine
    ,output logic                               tester_tile_rd_mem_req_val
    ,output logic   [`FLOW_ID_W-1:0]            tester_tile_rd_mem_req_flowid
    ,output logic   [`PAYLOAD_PTR_W-1:0]        tester_tile_rd_mem_req_offset
    ,output logic   [`MSG_DATA_SIZE_WIDTH-1:0]  tester_tile_rd_mem_req_size
    ,input  logic                               rd_mem_tester_tile_req_rdy
    
    ,input  logic                               rd_mem_tester_tile_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]      rd_mem_tester_tile_data
    ,input  logic                               rd_mem_tester_tile_data_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]       rd_mem_tester_tile_data_padbytes
    ,output                                     tester_tile_rd_mem_data_rdy
    
    ,output logic                               tester_tile_trace_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      tester_tile_trace_data
    ,output logic                               tester_tile_trace_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]       tester_tile_trace_data_padbytes
    ,input                                      trace_tester_tile_data_rdy
);
    typedef enum logic[2:0] {
        READY = 3'd0,
        SEND_WR_REQ = 3'd1,
        WAIT_WR_RESP = 3'd2,
        SEND_RD_REQ = 3'd3,
        RECV_RD_RESP = 3'd4,
        UND = 'X
    } state_e;
    
    logic                               tester_wr_mem_req_val;
    logic   [`MEM_REQ_STRUCT_W-1:0]     tester_wr_mem_req_entry;
    logic                               wr_mem_tester_req_rdy;
    
    logic                               wr_req_done;
    logic                               wr_req_done_rdy;
    
    state_e state_reg;
    state_e state_next;

    mem_req_struct wr_req_struct;

    logic   [`TRACE_ADDR_W-1:0]         trace_addr_reg;
    logic   [`TRACE_ADDR_W-1:0]         trace_addr_next;
    logic   [`TRACE_SIZE_W-1:0]         trace_size_reg;
    logic   [`TRACE_SIZE_W-1:0]         trace_size_next;
    logic   [`MAC_INTERFACE_W-1:0]      rd_mem_tester_tile_data_masked;
    logic   [`MAC_INTERFACE_W-1:0]      rd_mem_tester_tile_data_mask;
    logic   [`MAC_INTERFACE_BITS_W-1:0] rd_mem_tester_tile_mask_shift;


    assign rd_mem_tester_tile_mask_shift = rd_mem_tester_tile_data_padbytes << 3;
    assign rd_mem_tester_tile_data_mask = {(`MAC_INTERFACE_W){1'b1}} << rd_mem_tester_tile_mask_shift;
    assign rd_mem_tester_tile_data_masked = rd_mem_tester_tile_data_last
                                          ? rd_mem_tester_tile_data & rd_mem_tester_tile_data_mask
                                          :rd_mem_tester_tile_data;

    assign tester_tile_trace_data_val = rd_mem_tester_tile_data_val;
    assign tester_tile_trace_data = rd_mem_tester_tile_data_masked;
    assign tester_tile_trace_data_last = rd_mem_tester_tile_data_last;
    assign tester_tile_trace_data_padbytes = rd_mem_tester_tile_data_padbytes;
    assign tester_tile_rd_mem_data_rdy = trace_tester_tile_data_rdy;

    assign tester_tile_rd_mem_req_flowid = '0;
    assign tester_tile_rd_mem_req_offset = trace_addr_reg[`PAYLOAD_PTR_W-1:0];
    assign tester_tile_rd_mem_req_size = 
        {{(`MSG_DATA_SIZE_WIDTH-`TRACE_SIZE_W){1'b0}}, trace_size_reg};

    assign wr_req_struct.mem_req_size = 
        {{(`MSG_DATA_SIZE_WIDTH-`TRACE_SIZE_W){1'b0}}, trace_size_reg};
    assign wr_req_struct.mem_req_addr = trace_addr_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            trace_addr_reg <= '0;
            trace_size_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            trace_addr_reg <= trace_addr_next;
            trace_size_reg <= trace_size_next;
        end
    end

    always_comb begin
        state_next = state_reg;

        tester_tile_trace_wr_mem_req_rdy = 1'b0;
        tester_tile_trace_rd_mem_req_rdy = 1'b0;
        tester_wr_mem_req_val = 1'b0;
        tester_tile_rd_mem_req_val = 1'b0;

        wr_req_done_rdy = 1'b0;

        trace_addr_next = trace_addr_reg;
        trace_size_next = trace_size_reg;
        case (state_reg)
            READY: begin
                tester_tile_trace_wr_mem_req_rdy = 1'b1;
                tester_tile_trace_rd_mem_req_rdy = 1'b1;

                if (trace_tester_tile_wr_mem_req_val) begin
                    trace_addr_next = trace_tester_tile_wr_mem_req_addr;
                    trace_size_next = trace_tester_tile_wr_mem_req_size;
                    state_next = SEND_WR_REQ;
                end
                else if (trace_tester_tile_rd_mem_req_val) begin
                    trace_addr_next = trace_tester_tile_rd_mem_req_addr;
                    trace_size_next = trace_tester_tile_rd_mem_req_size;
                    state_next = SEND_RD_REQ;
                end
                else begin
                    state_next = READY;
                end
            end
            SEND_WR_REQ: begin
                tester_wr_mem_req_val = 1'b1;
                
                if (wr_mem_tester_req_rdy) begin
                    state_next = WAIT_WR_RESP;
                end
                else begin
                    state_next = SEND_WR_REQ;
                end
            end
            WAIT_WR_RESP: begin
                wr_req_done_rdy = 1'b1;
                if (wr_req_done) begin
                    state_next = READY;
                end
                else begin
                    state_next = WAIT_WR_RESP;
                end
            end
            SEND_RD_REQ: begin
                tester_tile_rd_mem_req_val = 1'b1;
                if (rd_mem_tester_tile_req_rdy) begin
                    state_next = RECV_RD_RESP;
                end
                else begin
                    state_next = SEND_RD_REQ;
                end
            end
            RECV_RD_RESP: begin
                if (rd_mem_tester_tile_data_val & rd_mem_tester_tile_data_last) begin
                    state_next = READY;
                end
                else begin
                    state_next = RECV_RD_RESP;
                end
            end
            default: begin
                state_next = UND;

                tester_tile_trace_wr_mem_req_rdy = 'X;
                tester_tile_trace_rd_mem_req_rdy = 'X;
                tester_wr_mem_req_val = 'X;
                tester_tile_rd_mem_req_val = 'X;

                wr_req_done_rdy = 'X;

                trace_addr_next = 'X;
                trace_size_next = 'X;
            end
        endcase
    end

    wr_mem_noc_module #(
         .SRC_X         (SRC_X      )
        ,.SRC_Y         (SRC_Y      )
        ,.DST_DRAM_X    (DST_DRAM_X )
        ,.DST_DRAM_Y    (DST_DRAM_Y )
    ) wr_mem_eng (
         .clk                           (clk)
        ,.rst                           (rst)

        ,.wr_mem_noc_req_noc0_val       (tester_noc0_val                    )
        ,.wr_mem_noc_req_noc0_data      (tester_noc0_data                   )
        ,.noc_wr_mem_req_noc0_rdy       (noc0_tester_rdy                    )
                                                                             
        ,.noc_wr_mem_resp_noc0_val      (noc0_tester_val                    )
        ,.noc_wr_mem_resp_noc0_data     (noc0_tester_data                   )
        ,.wr_mem_noc_resp_noc0_rdy      (tester_noc0_rdy                    )

        ,.src_wr_mem_req_val            (tester_wr_mem_req_val              )
        ,.src_wr_mem_req_entry          (wr_req_struct                      )
        ,.wr_mem_src_req_rdy            (wr_mem_tester_req_rdy              )

        ,.src_wr_mem_req_data_val       (trace_tester_tile_data_val         )
        ,.src_wr_mem_req_data           (trace_tester_tile_data             )
        ,.src_wr_mem_req_data_last      (trace_tester_tile_data_last        )
        ,.src_wr_mem_req_data_padbytes  (trace_tester_tile_data_padbytes    )
        ,.wr_mem_src_req_data_rdy       (tester_tile_trace_data_rdy         )

        ,.wr_req_done                   (wr_req_done                        )
        ,.wr_req_done_rdy               (wr_req_done_rdy                    )
    );

endmodule
