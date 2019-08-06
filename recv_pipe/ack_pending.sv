module ack_pending 
    import tcp_pkg::*;
(
     input                      clk
    ,input                      rst

    ,input  [FLOWID_W-1:0]      recv_set_ack_pending_addr
    ,input                      recv_set_ack_pending
    
    ,input  [FLOWID_W-1:0]      send_clear_ack_pending_addr
    ,input                      send_clear_ack_pending

    ,input                      read_ack_pending_val
    ,input  [FLOWID_W-1:0]      read_ack_pending_addr
    ,output                     read_ack_pending
);

reg                         clear_ack_pending_val;
reg     [FLOWID_W-1:0]    clear_ack_pending_addr;
wire                        clear_ack_pending;

reg                         set_ack_pending_val;
reg     [FLOWID_W-1:0]    set_ack_pending_addr;
wire                        set_ack_pending;

assign clear_ack_pending = 1'b0;
assign set_ack_pending = 1'b1;

reg     [MAX_FLOW_CNT-1:0]    ack_pending_bits;

assign read_ack_pending = read_ack_pending_val ? ack_pending_bits[read_ack_pending_addr] : 1'b0;

// if we're supposed to be setting and clearing the same address, resolve by just setting
always @(*) begin
    if (recv_set_ack_pending & send_clear_ack_pending 
     & (recv_set_ack_pending_addr == send_clear_ack_pending_addr)) begin
        clear_ack_pending_val = 1'b0; 
        clear_ack_pending_addr = 'b0;

        set_ack_pending_val = 1'b1;
        set_ack_pending_addr = recv_set_ack_pending_addr;
    end
    else begin
        clear_ack_pending_val = send_clear_ack_pending;
        clear_ack_pending_addr = send_clear_ack_pending_addr;

        set_ack_pending_val = recv_set_ack_pending;
        set_ack_pending_addr = recv_set_ack_pending_addr;
    end

end


always @(posedge clk) begin
    if (rst) begin
        ack_pending_bits <= 'b0;
    end
    // we have already resolved conflicts between addresses above using the val signals, so
    // we can just check those to do the write
    else begin
        if (set_ack_pending_val) begin
            ack_pending_bits[set_ack_pending_addr] <= set_ack_pending;
        end
        if (clear_ack_pending_val) begin
            ack_pending_bits[clear_ack_pending_addr] <= clear_ack_pending;
        end
    end
end

endmodule
