module mini_logger #(
     parameter INPUT_W = 128
    ,parameter LOG_DATA_W = 128
    ,parameter MEM_DEPTH_LOG2 = 8
    ,parameter OUTPUT_W = 64
    ,parameter PADDING_W = 64
    ,parameter MEM_CAPACITY = ((LOG_DATA_W + PADDING_W)/8) * (2**MEM_DEPTH_LOG2)
    ,parameter MEM_ADDR_W = $clog2(MEM_CAPACITY)
)(
     input clk
    ,input rst

    ,input logging_active

    ,input                              wr_val
    ,input          [INPUT_W-1:0]       wr_data

    ,input                              rd_req_val
    ,input          [MEM_ADDR_W-1:0]    rd_req_addr

    ,output logic                       rd_resp_val
    ,output logic   [OUTPUT_W-1:0]      rd_resp_data
    
    ,output logic   [MEM_ADDR_W-1:0]    curr_wr_addr
    ,output logic                       has_looped
);
    localparam  MEM_WIDTH = LOG_DATA_W + PADDING_W;

   // generate

   //     if ((MEM_WIDTH % OUTPUT_W) != 0) begin    
   //         $error("Memory width must be a multiple of the output line width. \
   //         Mem width is %d and output width is %d.", MEM_WIDTH, OUTPUT_W);
   //     end

   //     if ((MEM_WIDTH & (MEM_WIDTH - 1)) != 0) begin
   //         $error("Values must be set so that memory width is a power of 2. Mem width is %d", MEM_WIDTH);
   //     end
   // endgenerate

    localparam LINE_ADDR_W = MEM_DEPTH_LOG2;
    localparam BLOCK_ADDR_W = $clog2(MEM_WIDTH/8);
    localparam OUTPUT_SECTIONS = MEM_WIDTH/OUTPUT_W;
    localparam OUTPUT_SECTIONS_W = $clog2(OUTPUT_SECTIONS);

    logic   [LINE_ADDR_W-1:0]   wr_addr_reg;
    logic   [LINE_ADDR_W-1:0]   wr_addr_next;
    logic                       incr_wr_addr;

    logic                                       update_saved;
    logic   [OUTPUT_SECTIONS-1:0][OUTPUT_W-1:0] rd_data_save_reg;
    logic   [MEM_ADDR_W-1:0]                    rd_addr_save_reg;
    logic   [OUTPUT_SECTIONS-1:0][OUTPUT_W-1:0] rd_data_save_next;
    logic   [MEM_ADDR_W-1:0]                    rd_addr_save_next;

    logic   [MEM_ADDR_W-1:0]                    rd_addr_reg; 
    logic   [MEM_ADDR_W-1:0]                    rd_addr_reg_reg; 
    logic   [LINE_ADDR_W-1:0]                   mem_line_addr;
    logic                                       mem_rd_resp_val;
    logic   [MEM_WIDTH-1:0]                     mem_rd_data;
    logic                                       rd_resp_val_reg;

    logic   [OUTPUT_SECTIONS_W-1:0]             line_section_addr;
    logic                                       has_looped_reg;
    logic                                       has_looped_next;

    assign has_looped = has_looped_reg;

    assign curr_wr_addr = {wr_addr_reg, {BLOCK_ADDR_W{1'b0}}};

    assign mem_line_addr = rd_req_addr[MEM_ADDR_W - 1  -: LINE_ADDR_W];

    assign line_section_addr = rd_addr_reg_reg[BLOCK_ADDR_W - 1 -: OUTPUT_SECTIONS_W];
    assign rd_resp_val = rd_resp_val_reg;
    assign rd_resp_data = rd_data_save_reg[line_section_addr];

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_addr_reg <= '0;
            rd_data_save_reg <= '0;
            rd_addr_save_reg <= '0;
            rd_addr_reg <= '0;
            rd_addr_reg_reg <= '0;
            has_looped_reg <= '0;
            rd_resp_val_reg <= '0;
        end
        else begin
            wr_addr_reg <= wr_addr_next;
            rd_data_save_reg <= rd_data_save_next;
            rd_addr_save_reg <= rd_addr_save_next;
            has_looped_reg <= has_looped_next;
            rd_resp_val_reg <= mem_rd_resp_val;
            if (rd_req_val) begin
                rd_addr_reg <= rd_req_addr;
            end
            rd_addr_reg_reg <= rd_addr_reg;
        end
    end

    assign incr_wr_addr = wr_val;

    assign has_looped_next = has_looped_reg 
                        | (incr_wr_addr && (wr_addr_reg == {LINE_ADDR_W{1'b1}}));

    assign wr_addr_next = incr_wr_addr ? wr_addr_reg + 1'b1 : wr_addr_reg;
    assign update_saved = rd_addr_reg[MEM_ADDR_W-1 -: LINE_ADDR_W] != rd_addr_save_reg[MEM_ADDR_W-1 -: LINE_ADDR_W];

    assign rd_addr_save_next = update_saved 
                             ? rd_addr_reg
                             : rd_addr_save_reg;

    assign rd_data_save_next = update_saved
                             ? mem_rd_data
                             : rd_data_save_reg;

generate
    if (PADDING_W == 0) begin : no_padding
        ram_1r1w_sync_backpressure #(
             .width_p   (MEM_WIDTH                  )
            ,.els_p     (2 ** MEM_DEPTH_LOG2        )
        ) log_mem (
             .clk   (clk    )
            ,.rst   (rst    )

            ,.wr_req_val    (wr_val & logging_active    )
            ,.wr_req_addr   (wr_addr_reg                )
            ,.wr_req_data   (wr_data   )
            ,.wr_req_rdy    ()

            ,.rd_req_val    (rd_req_val                 )
            ,.rd_req_addr   (mem_line_addr              )
            ,.rd_req_rdy    ()

            ,.rd_resp_val   (mem_rd_resp_val            )
            ,.rd_resp_data  (mem_rd_data                )
            ,.rd_resp_rdy   (1'b1)
        );
    end
    else begin
        logic [PADDING_W-1:0]   padding;
        assign padding = {PADDING_W{1'b0}};
        ram_1r1w_sync_backpressure #(
             .width_p   (MEM_WIDTH                  )
            ,.els_p     (2 ** MEM_DEPTH_LOG2        )
        ) log_mem (
             .clk   (clk    )
            ,.rst   (rst    )

            ,.wr_req_val    (wr_val & logging_active    )
            ,.wr_req_addr   (wr_addr_reg                )
            ,.wr_req_data   ({wr_data, padding}   )
            ,.wr_req_rdy    ()

            ,.rd_req_val    (rd_req_val                 )
            ,.rd_req_addr   (mem_line_addr              )
            ,.rd_req_rdy    ()

            ,.rd_resp_val   (mem_rd_resp_val            )
            ,.rd_resp_data  (mem_rd_data                )
            ,.rd_resp_rdy   (1'b1)
        );
    end
endgenerate
endmodule

