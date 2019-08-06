`include "packet_defs.vh"
`include "state_defs.vh"

module recv_packet_payload_queues(
     input clk
    ,input rst
    // For setting new state
    ,input                              new_enqueue_val
    ,input  [`FLOW_ID_W-1:0]            new_enqueue_addr
    ,input  [`PAYLOAD_WIN_SIZE_W-1:0]   new_enqueue_data
    
    ,input                              new_dequeue_val
    ,input  [`FLOW_ID_W-1:0]            new_dequeue_addr
    ,input  [`PAYLOAD_WIN_SIZE_W-1:0]   new_dequeue_data

    // For adding a new packet to the queue
    ,input                              enqueue_packet_val
    ,input  [`FLOW_ID_W-1:0]            enqueue_packet_flowid
    ,input  [`PAYLOAD_ENTRY_ADDR_W-1:0] enqueue_packet_payload_addr
    ,input  [`PAYLOAD_ENTRY_LEN_W-1:0]  enqueue_packet_payload_len

    // For reading out a packet from the queue
    ,input                              read_payload_req_val
    ,input  [`FLOW_ID_W-1:0]            read_payload_req_flowid

    ,output                             read_payload_resp_val
    ,output                             read_payload_resp_empty
    ,output [`PAYLOAD_ENTRY_ADDR_W-1:0] read_payload_resp_addr
    ,output [`PAYLOAD_ENTRY_LEN_W-1:0]  read_payload_resp_len
);

/*************************************************************
 * Wires
 ************************************************************/
logic [`FLOW_ID_W-1:0]              empty_flowid_qp;
logic [`FLOW_ID_W-1:0]              full_flowid_qp;

logic                               enqueue_index_test_full_val_qp;

logic                               enqueue_index_test_empty_val_qp;
    
logic                               enqueue_packet_val_qp;
logic   [`FLOW_ID_W-1:0]            enqueue_packet_flowid_qp;
payload_buf_entry                   enqueue_payload_entry_qp;

logic                               dequeue_index_test_full_val_qp;

logic                               dequeue_index_test_empty_val_qp;

logic                               enqueue_write_val_pb;
logic   [`FLOW_ID_W-1:0]            enqueue_write_addr_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   enqueue_write_data_pb;

logic                               enqueue_write_val_pb_reg;
logic   [`FLOW_ID_W-1:0]            enqueue_write_addr_pb_reg;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   enqueue_write_data_pb_reg;

logic                               dequeue_write_val_pb;
logic   [`FLOW_ID_W-1:0]            dequeue_write_addr_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   dequeue_write_data_pb;

logic                               dequeue_write_val_pb_reg;
logic   [`FLOW_ID_W-1:0]            dequeue_write_addr_pb_reg;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   dequeue_write_data_pb_reg;

logic                               enqueue_packet_val_pb;
logic   [`FLOW_ID_W-1:0]            enqueue_packet_flowid_pb;
payload_buf_entry                   enqueue_payload_entry_pb;

logic                               read_payload_req_val_pb;
logic   [`FLOW_ID_W-1:0]            read_payload_req_flowid_pb;

logic                               payload_buf_write_val_pb;
logic   [`PAYLOAD_Q_ADDR_W-1:0]     payload_buf_write_addr_pb;
payload_buf_entry                   payload_buf_write_entry_pb;

logic                               payload_buf_read_req_val_pb;
logic   [`PAYLOAD_Q_ADDR_W-1:0]     payload_buf_read_req_addr_pb;

logic                               payload_buf_read_resp_val_pb;

logic   [`PAYLOAD_WIN_SIZE_W-1:0]   enqueue_index_read_full_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   enqueue_index_read_empty_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   dequeue_index_read_full_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   dequeue_index_read_empty_pb;

logic   [`PAYLOAD_WIN_SIZE_W-1:0]   enqueue_index_test_full_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   enqueue_index_test_empty_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   dequeue_index_test_full_pb;
logic   [`PAYLOAD_WIN_SIZE_W-1:0]   dequeue_index_test_empty_pb;

logic [`FLOW_ID_W-1:0]              empty_flowid_pb;
logic [`FLOW_ID_W-1:0]              full_flowid_pb;
logic                               is_full_pb;
logic                               is_empty_pb;

logic                               is_empty_w;
logic                               read_payload_resp_val_w;
payload_buf_entry                   payload_buf_read_resp_entry_w;

/*************************************************************
 * (Q)ueue (P)ointer read stage
 ************************************************************/
assign empty_flowid_qp = read_payload_req_flowid;
assign full_flowid_qp = enqueue_packet_flowid;

assign enqueue_packet_val_qp = enqueue_packet_val;
assign enqueue_packet_flowid_qp = enqueue_packet_flowid;
assign enqueue_payload_entry_qp.pkt_payload_addr = enqueue_packet_payload_addr;
assign enqueue_payload_entry_qp.pkt_payload_len = enqueue_packet_payload_len;

/***********************************
 * Tail pointers (enqueue)
 **********************************/
always @(*) begin
    if (enqueue_write_val_pb & (enqueue_write_addr_pb == full_flowid_qp)) begin
        enqueue_index_test_full_val_qp = 1'b0;
    end
    else begin
        enqueue_index_test_full_val_qp = enqueue_packet_val_qp;
    end
end

always @(*) begin
    if (enqueue_write_val_pb & (enqueue_write_addr_pb == empty_flowid_qp)) begin
        enqueue_index_test_empty_val_qp = 1'b0;
    end
    else begin
        enqueue_index_test_empty_val_qp = read_payload_req_val;
    end
end

bsg_mem_2r1w_sync
    #(.width_p      (`PAYLOAD_WIN_SIZE_W)
     ,.els_p        (`MAX_FLOW_CNT)
     )
    enqueue_pointers (
         .clk_i   (clk)
        ,.reset_i (rst)
        
        ,.w_v_i     (enqueue_write_val_pb            )
        ,.w_addr_i  (enqueue_write_addr_pb           )
        ,.w_data_i  (enqueue_write_data_pb           )

        ,.r0_v_i    (enqueue_index_test_full_val_qp  )
        ,.r0_addr_i (full_flowid_qp                  )
        ,.r0_data_o (enqueue_index_read_full_pb      )

        ,.r1_v_i    (enqueue_index_test_empty_val_qp )
        ,.r1_addr_i (empty_flowid_qp                 )
        ,.r1_data_o (enqueue_index_read_empty_pb     )
);

/***********************************
 * Head pointers (dequeue)
 **********************************/
always @(*) begin
    if (dequeue_write_val_pb & (dequeue_write_addr_pb == full_flowid_qp)) begin
        dequeue_index_test_full_val_qp = 1'b0;
    end
    else begin
        dequeue_index_test_full_val_qp = enqueue_packet_val_qp;
    end
end

always @(*) begin
    if (dequeue_write_val_pb & (dequeue_write_addr_pb == empty_flowid_qp)) begin
        dequeue_index_test_empty_val_qp = 1'b0;
    end
    else begin
        dequeue_index_test_empty_val_qp = read_payload_req_val;
    end
end
bsg_mem_2r1w_sync
    #(.width_p      (`PAYLOAD_WIN_SIZE_W)
     ,.els_p        (`MAX_FLOW_CNT)
     )
    dequeue_pointers (
         .clk_i   (clk)
        ,.reset_i (rst)
        
        ,.w_v_i     (dequeue_write_val_pb            )
        ,.w_addr_i  (dequeue_write_addr_pb           )
        ,.w_data_i  (dequeue_write_data_pb           )

        ,.r0_v_i    (dequeue_index_test_full_val_qp  )
        ,.r0_addr_i (full_flowid_qp                  )
        ,.r0_data_o (dequeue_index_read_full_pb      )

        ,.r1_v_i    (dequeue_index_test_empty_val_qp )
        ,.r1_addr_i (empty_flowid_qp                 )
        ,.r1_data_o (dequeue_index_read_empty_pb     )
);
/*************************************************************
 * (Q)ueue (P)ointer stage -> (P)ayload (B)uffer stage
 ************************************************************/

always_ff @(posedge clk) begin
    if (rst) begin  
        enqueue_packet_val_pb <= 'b0;
        enqueue_packet_flowid_pb <= 'b0;
        enqueue_payload_entry_pb <= 'b0;

        read_payload_req_val_pb <= 'b0;
        read_payload_req_flowid_pb <= 'b0;

        full_flowid_pb <= 'b0;
        empty_flowid_pb <= 'b0;
    end
    else begin
        enqueue_packet_val_pb <= enqueue_packet_val_qp;
        enqueue_packet_flowid_pb <= enqueue_packet_flowid_qp;
        enqueue_payload_entry_pb <= enqueue_payload_entry_qp;

        read_payload_req_val_pb <= read_payload_req_val;
        read_payload_req_flowid_pb <= read_payload_req_flowid;
        
        full_flowid_pb <= full_flowid_qp;
        empty_flowid_pb <= empty_flowid_qp;
    end
end

/*************************************************************
 * (W)rite stage
 ************************************************************/
// Take care of bypassing
// Tail pointers
always @(*) begin
    if (enqueue_write_val_pb_reg & (enqueue_write_addr_pb_reg == full_flowid_pb)) begin
        enqueue_index_test_full_pb = enqueue_write_data_pb_reg;
    end
    else begin
        enqueue_index_test_full_pb = enqueue_index_read_full_pb;
    end
end

always @(*) begin
    if (enqueue_write_val_pb_reg & (enqueue_write_addr_pb_reg == empty_flowid_pb)) begin
        enqueue_index_test_empty_pb = enqueue_write_data_pb_reg;
    end
    else begin
        enqueue_index_test_empty_pb = enqueue_index_read_empty_pb;
    end
end

// Head pointers
always @(*) begin
    if (dequeue_write_val_pb_reg & (dequeue_write_addr_pb_reg == full_flowid_pb)) begin
        dequeue_index_test_full_pb = dequeue_write_data_pb_reg;
    end
    else begin
        dequeue_index_test_full_pb = dequeue_index_read_full_pb;
    end
end

always @(*) begin
    if (dequeue_write_val_pb_reg & (dequeue_write_addr_pb_reg == empty_flowid_pb)) begin
        dequeue_index_test_empty_pb = dequeue_write_data_pb_reg;
    end
    else begin
        dequeue_index_test_empty_pb = dequeue_index_read_empty_pb;
    end
end
    
    
assign is_empty_pb = enqueue_index_test_empty_pb == dequeue_index_test_empty_pb;
assign is_full_pb = (enqueue_index_test_full_pb + 1'b1) == dequeue_index_test_full_pb;

assign enqueue_write_val_pb = new_enqueue_val | enqueue_packet_val_pb;
assign enqueue_write_addr_pb = new_enqueue_val ? new_enqueue_addr : enqueue_packet_flowid_pb;
// FIXME: need to fix this so we check is_full...
assign enqueue_write_data_pb = new_enqueue_val ? new_enqueue_data : enqueue_index_test_full_pb + 1'b1;

assign dequeue_write_val_pb = new_dequeue_val | read_payload_req_val_pb;
assign dequeue_write_addr_pb = new_dequeue_val ? new_dequeue_addr : read_payload_req_flowid_pb;
// only dequeue if we have something to dequeue
assign dequeue_write_data_pb = new_dequeue_val ? new_dequeue_data : 
                              payload_buf_read_req_val_pb ? dequeue_index_test_empty_pb + 1'b1
                                                         : dequeue_index_test_empty_pb;

assign payload_buf_write_val_pb = enqueue_packet_val_pb;
assign payload_buf_write_addr_pb = {enqueue_packet_flowid_pb[`FLOW_ID_W-1:0],
                                   enqueue_index_test_full_pb};
assign payload_buf_write_entry_pb = enqueue_payload_entry_pb;

assign payload_buf_read_req_val_pb = read_payload_req_val_pb ? ~is_empty_pb : 1'b0;
assign payload_buf_read_req_addr_pb = 
                                    {read_payload_req_flowid_pb[`FLOW_ID_W-1:0],
                                     dequeue_index_test_empty_pb};
assign payload_buf_read_resp_val_pb = payload_buf_read_req_val_pb;


bsg_mem_1r1w_sync
    #(.width_p  (`PAYLOAD_ENTRY_W)
     ,.els_p    (`MAX_FLOW_CNT * `PAYLOAD_WIN_SIZE)
    )
    payload_ring_buffers(
         .clk_i   (clk)
        ,.reset_i (rst)

        ,.w_v_i     (payload_buf_write_val_pb        )
        ,.w_addr_i  (payload_buf_write_addr_pb       )
        ,.w_data_i  (payload_buf_write_entry_pb      )

        ,.r_v_i     (payload_buf_read_req_val_pb     )
        ,.r_addr_i  (payload_buf_read_req_addr_pb    )

        // This read is synchronous, so we just assign it to the next stage
        ,.r_data_o  (payload_buf_read_resp_entry_w )
);

// We need to save these for bypassing...sucks
always_ff @(posedge clk) begin
    if (rst) begin
        enqueue_write_val_pb_reg <= 'b0;
        enqueue_write_addr_pb_reg <= 'b0;
        enqueue_write_data_pb_reg <= 'b0;
        dequeue_write_val_pb_reg <= 'b0;
        dequeue_write_addr_pb_reg <= 'b0;
        dequeue_write_data_pb_reg <= 'b0;
    end
    else begin
        enqueue_write_val_pb_reg <= enqueue_write_val_pb;
        enqueue_write_addr_pb_reg <= enqueue_write_addr_pb;
        enqueue_write_data_pb_reg <= enqueue_write_data_pb;
        dequeue_write_val_pb_reg <= dequeue_write_val_pb;
        dequeue_write_addr_pb_reg <= dequeue_write_addr_pb;
        dequeue_write_data_pb_reg <= dequeue_write_data_pb;
    end
end

/*************************************************************
 * (P)ayload (B)uffer stage -> (W)riteout stage
 ************************************************************/
always_ff @(posedge clk) begin
    if (rst) begin
        is_empty_w <= 1'b0;
        read_payload_resp_val_w <= 'b0;
    end
    else begin
        is_empty_w <= is_empty_pb;
        read_payload_resp_val_w <= read_payload_req_val_pb;
    end
end
/*************************************************************
 * (P)ayload (O)ut stage
 ************************************************************/
assign read_payload_resp_empty = is_empty_w;
assign read_payload_resp_val = read_payload_resp_val_w;
assign read_payload_resp_addr = payload_buf_read_resp_entry_w.pkt_payload_addr;
assign read_payload_resp_len = payload_buf_read_resp_entry_w.pkt_payload_len;

endmodule
