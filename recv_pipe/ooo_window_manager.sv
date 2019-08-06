module ooo_window_manager(
     input                              clk
    ,input                              rst

    ,input  [`SEQ_NUM_WIDTH-1:0]        packet_seq_num
    ,input  [`ACK_NUM_WIDTH-1:0]        curr_ack_num
    ,input  [`ACK_NUM_WIDTH-1:0]        next_ack_num
    ,input  [`SEQ_NUM_WIDTH-1:0]        curr_next_free
    ,input  [`SEQ_NUM_WIDTH-1:0]        next_next_free

    ,input  [`SEQ_NUM_WIDTH-1:0]        curr_ooo_seq_num_pointer
    ,input                              curr_ooo_seq_num_state

    ,output reg [`SEQ_NUM_WIDTH-1:0]    next_ooo_seq_num_pointer
    ,output reg                         next_ooo_seq_num_state
    ,output                             ooo_software_flag
);

localparam  TRACKING = 1'b1;
localparam  IN_ORDER = 1'b0;

reg         ooo_software_flag_reg;
reg         ooo_software_flag_next;

assign      ooo_software_flag = ooo_software_flag_reg;

always @(*) begin
    // check if we're currently tracking an out of order window
    if (curr_ooo_seq_num_state == TRACKING) begin
        next_ooo_seq_num_pointer = curr_ooo_seq_num_pointer;

        // if we're out of order, we can either be contiguous at the end of the window
        // or we can match the ack number. Otherwise we're hopeless (kinda...) and we want to 
        // set something that'll let software sort it out for us
        if (packet_seq_num == curr_next_free) begin
            ooo_software_flag_next = 1'b0;
            // increment the next pointer

        end
        else if (packet_seq_num == curr_ack_num) begin
            ooo_software_flag_next = 1'b0;
            // if the next ack num would close the ooo interval, reset the state
            if (next_ack_num == curr_ooo_seq_num_pointer) begin
                next_ooo_seq_num_state = IN_ORDER;
            end
            else begin
                next_ooo_seq_num_state = curr_ooo_seq_num_state;
            end
        end
        else begin
            ooo_software_flag_next = 1'b1;
            // Ok we're super out of order. Set our help flag, leave state the same
            next_ooo_seq_num_state   = curr_ooo_seq_num_state;
        end
    end
    else begin
        ooo_software_flag_next = 1'b0;
        // we've received an out of order packet
        if (packet_seq_num > curr_ack_num) begin
            next_ooo_seq_num_pointer = packet_seq_num;
            next_ooo_seq_num_state = TRACKING;
        end
        // Otherwise, we're all good and don't need to update state
        else begin
            next_ooo_seq_num_pointer = curr_ooo_seq_num_pointer;
            next_ooo_seq_num_state = curr_ooo_seq_num_state;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        ooo_software_flag_reg <= 1'b0;
    end
    else begin
        ooo_software_flag_reg <= ooo_software_flag_next;
    end
end

endmodule
