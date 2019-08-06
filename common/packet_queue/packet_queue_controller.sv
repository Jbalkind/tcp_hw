`include "noc_defs.vh"
`include "packet_defs.vh"

module packet_queue_controller #(
     parameter width_p = -1
    // this is the width of the data element within the enqueue struct
    ,parameter data_width_p = -1
    // get the width of the number of bytes
    ,parameter data_pad_width_p = $clog2(data_width_p/8)
    ,parameter log2_els_p = -1
) (
     input clk
    ,input rst
    
    ,input                                  wr_req
    ,input          [width_p-1:0]           wr_data
    ,output                                 full
    ,input                                  start_frame
    ,input                                  end_frame
    ,input          [data_pad_width_p-1:0]  end_padbytes

    ,input                                  rd_req
    ,output logic                           empty
    ,output logic   [width_p-1:0]           rd_data
    
    ,input                                  pkt_size_queue_rd_req
    ,output logic                           pkt_size_queue_empty
    ,output logic   [`MTU_SIZE_W-1:0]       pkt_size_queue_rd_data
);

    typedef enum logic[1:0] {
        READY = 2'd0,
        WRITING_FRAME = 2'd1,
        PASS_FRAME = 2'd2,
        UND = 'X
    } state_t;


    state_t state_reg;
    state_t state_next;

    logic                   buffer_rd_req;
    logic                   buffer_empty;
    logic   [width_p-1:0]   buffer_rd_data;

    logic                   buffer_wr_req;
    logic                   buffer_full;
    logic   [width_p-1:0]   buffer_wr_data;

    logic                   buffer_dump_packet;
    logic                   buffer_cmt_packet;

    logic   [log2_els_p:0]  curr_pkt_els;
    
    logic                       pkt_size_queue_wr_req;
    logic   [`MTU_SIZE_W-1:0]   pkt_size_queue_wr_data;
    logic                       pkt_size_queue_full;

    assign buffer_rd_req = rd_req;
    assign empty = buffer_empty;
    assign full = buffer_full;
    assign rd_data = buffer_rd_data;

    assign buffer_wr_data = wr_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    always_comb begin
        state_next = state_reg;
        buffer_wr_req = 1'b0;
        buffer_cmt_packet = 1'b0;
        buffer_dump_packet = 1'b0;
        pkt_size_queue_wr_req = 1'b0;

        case (state_reg)
            READY: begin
                if (wr_req & ~buffer_full & start_frame) begin
                    buffer_wr_req = 1'b1;
                    if (end_frame) begin
                        buffer_cmt_packet = 1'b1;
                        pkt_size_queue_wr_req = 1'b1;
                    end
                    else begin
                        state_next = WRITING_FRAME;
                    end
                end
                else begin
                    state_next = READY;
                end
            end
            WRITING_FRAME: begin
                // if we need to write data
                if (wr_req) begin
                    // if the buffer is full, we need to sink the rest of the frame and dump it
                    if (buffer_full) begin
                        buffer_dump_packet = 1'b1;
                        if (end_frame) begin
                            state_next = READY; 
                        end
                        else begin
                            state_next = PASS_FRAME;
                        end
                    end
                    // if the buffer isn't full
                    else begin
                        // if this is the end of frame, commit the packet and go back to
                        // READY
                        if (end_frame) begin
                            buffer_wr_req = 1'b1;
                            buffer_cmt_packet = 1'b1;
                            pkt_size_queue_wr_req = 1'b1;

                            state_next = READY;
                        end
                        // if we see the start of a frame, but haven't seen the end, dump
                        // the one we were tracking and start this next one
                        else if (start_frame) begin
                            buffer_wr_req = 1'b1;
                            buffer_dump_packet = 1'b1;
                            state_next = WRITING_FRAME;
                        end
                        else begin
                            buffer_wr_req = 1'b1;
                            state_next = WRITING_FRAME;
                        end
                    end
                end
                else begin
                    state_next = WRITING_FRAME;
                end
            end
            PASS_FRAME: begin
                if (wr_req) begin
                    if (end_frame) begin
                        state_next = READY;
                    end
                    else begin
                        state_next = PASS_FRAME;
                    end
                end
                else begin
                    state_next = PASS_FRAME;
                end
            end
            default: begin
                state_next = UND;
                buffer_wr_req = 1'bX;
                buffer_cmt_packet = 1'bX;
                buffer_dump_packet = 1'bX;
            end
        endcase
    end

    packet_queue #(
         .width_p   (width_p)
        ,.log2_els_p(log2_els_p)
    ) drop_queue (
         .clk           (clk)
        ,.rst           (rst)

        ,.rd_req        (buffer_rd_req      )
        ,.empty         (buffer_empty       )
        ,.rd_data       (buffer_rd_data     )

        ,.wr_req        (buffer_wr_req      )
        ,.wr_data       (buffer_wr_data     )
        ,.full          (buffer_full        )

        ,.dump_packet   (buffer_dump_packet )
        ,.cmt_packet    (buffer_cmt_packet  )

        ,.curr_pkt_els  (curr_pkt_els       )
    );

    assign pkt_size_queue_wr_data = (curr_pkt_els << `NOC_DATA_BYTES_W) - end_padbytes;

    fifo_1r1w #(
         .width_p       (`MTU_SIZE_W   )
        // since each packet must take up 2 elements (Ethernet packet has a minimum size of
        // 64 bytes), this can be half the size of the main packet queue
        // update for 512-bit datapath: there needs to be a size available for each
        // possible entry
        ,.log2_els_p    (log2_els_p     )
    ) pkt_size_queue (
         .clk   (clk)
        ,.rst   (rst)

        ,.rd_req    (pkt_size_queue_rd_req  )
        ,.rd_data   (pkt_size_queue_rd_data )
        ,.empty     (pkt_size_queue_empty   )

        ,.wr_req    (pkt_size_queue_wr_req  )
        ,.wr_data   (pkt_size_queue_wr_data )
        ,.full      (pkt_size_queue_full    )
    );

endmodule
