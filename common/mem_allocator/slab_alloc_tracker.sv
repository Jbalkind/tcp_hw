`include "bsg_defines.v"

/* The free request interface is pretty normal val-ready
 * The allocation interface is a little different. The module will always have an addr
 * on the output. If there's no slabs avaialble, the error bit will be set. To consume
 * the slab, assert consume_val
 */
module slab_alloc_tracker #(
     parameter NUM_SLABS = -1
    ,parameter SLAB_NUM_W = `BSG_SAFE_CLOG2(NUM_SLABS)
    ,parameter SLAB_BYTES = -1
    ,parameter SLAB_BYTES_W = `BSG_SAFE_CLOG2(SLAB_BYTES)
    ,parameter ADDR_W = SLAB_NUM_W + SLAB_BYTES_W
)(
     input clk
    ,input rst

    ,input                          src_free_slab_req_val
    ,input          [ADDR_W-1:0]    src_free_slab_req_addr
    ,output logic                   free_slab_src_req_rdy

    ,input                          src_alloc_slab_consume_val

    ,output logic                   alloc_slab_src_resp_error
    ,output logic   [ADDR_W-1:0]    alloc_slab_src_resp_addr
);
    localparam LAST_SLAB_ADDR = (NUM_SLABS - 1) * SLAB_BYTES;

    logic                   freed_slab_fifo_rd_req;
    logic   [ADDR_W-1:0]    freed_slab_fifo_rd_data;
    logic                   freed_slab_fifo_empty;

    logic                   freed_slab_fifo_wr_req;
    logic   [ADDR_W-1:0]    freed_slab_fifo_wr_data;
    logic                   freed_slab_fifo_full;

    logic                   use_fifo_reg;
    logic                   use_fifo_next;
    logic   [ADDR_W-1:0]    init_slab_addr_reg;
    logic   [ADDR_W-1:0]    init_slab_addr_next;


    always_ff @(posedge clk) begin
        if (rst) begin
            init_slab_addr_reg <= '0;
            use_fifo_reg <= '0;
        end
        else begin
            init_slab_addr_reg <= init_slab_addr_next;
            use_fifo_reg <= use_fifo_next;
        end
    end
    
    // initially, allocate slabs from a counter. after, allocate slabs from the FIFO
    // control allocation from the fifo
    always_comb begin
        if (use_fifo_reg) begin
            freed_slab_fifo_rd_req = src_alloc_slab_consume_val & ~freed_slab_fifo_empty;
        end
        else begin
            freed_slab_fifo_rd_req = 1'b0;
        end
    end

    // control allocation from the initial counter
    always_comb begin
        use_fifo_next = use_fifo_reg;
        init_slab_addr_next = init_slab_addr_reg;
        if (~use_fifo_reg) begin
            if (src_alloc_slab_consume_val) begin
                use_fifo_next = init_slab_addr_reg == LAST_SLAB_ADDR;
                init_slab_addr_next = init_slab_addr_reg + SLAB_BYTES;
            end
        end
    end

    // control the allocation resp
    always_comb begin
        if (use_fifo_reg) begin
            alloc_slab_src_resp_error = freed_slab_fifo_empty;
            alloc_slab_src_resp_addr = freed_slab_fifo_rd_data;
        end
        else begin
            alloc_slab_src_resp_error = 1'b0;
            alloc_slab_src_resp_addr = init_slab_addr_reg;
        end
    end

    // Freed slabs are just written into a FIFO
    assign freed_slab_fifo_wr_req = src_free_slab_req_val & ~freed_slab_fifo_full;
    assign freed_slab_fifo_wr_data = src_free_slab_req_addr;
    assign free_slab_src_req_rdy = ~freed_slab_fifo_full;

    fifo_1r1w #(
         .width_p       (ADDR_W                     )
        ,.log2_els_p    (`BSG_SAFE_CLOG2(NUM_SLABS) )
    ) freed_slab_fifo (
         .clk       (clk)
        ,.rst       (rst)

        ,.rd_req    (freed_slab_fifo_rd_req     )
        ,.rd_data   (freed_slab_fifo_rd_data    )
        ,.empty     (freed_slab_fifo_empty      )
                                                  
        ,.wr_req    (freed_slab_fifo_wr_req     )
        ,.wr_data   (freed_slab_fifo_wr_data    )
        ,.full      (freed_slab_fifo_full       )
    );
endmodule
