`include "state_defs.vh"
`include "packet_defs.vh"
module handshake_trace_echo_app (
     input clk
    ,input rst

    ,input                                          engine_recv_header_val
    ,input          [`TCP_HEADER_WIDTH-1:0]         engine_recv_tcp_hdr
    ,input          [`FLOW_ID_W-1:0]                engine_recv_flowid

    ,input                                          new_idtoaddr_lookup_val
    ,input          [`FLOW_ID_W-1:0]                new_idtoaddr_lookup_flow_id
    ,input          [`FLOW_LOOKUP_ENTRY_WIDTH-1:0]  new_idtoaddr_lookup_entry
    
    ,output logic                                   tx_tcp_hdr_val
    ,output logic   [`IP_ADDR_WIDTH-1:0]            tx_src_ip
    ,output logic   [`IP_ADDR_WIDTH-1:0]            tx_dst_ip
    ,output logic   [`TCP_HEADER_WIDTH-1:0]         tx_tcp_hdr
    ,input  logic                                   tx_tcp_hdr_rdy
);

    typedef enum logic {
        READY = 1'd0,
        OUTPUT = 1'd1,
        UND = 'X
    } state_e;

    logic                       rx_queue_hdr_val;
    tcp_packet_header           rx_queue_tcp_hdr;
    logic   [`FLOW_ID_W-1:0]    rx_queue_flowid;
    logic                       rx_queue_yumi;

    logic                       read_flowid_lookup_val;
    logic   [`FLOW_ID_W-1:0]    read_flowid_lookup_flowid;
    flow_lookup_entry           read_flowid_lookup_entry;

    tcp_packet_header           tcp_hdr_reg;
    tcp_packet_header           tcp_hdr_next;
    tcp_packet_header           output_tcp_hdr_cast;

    logic   [`FLOW_ID_W-1:0]    flowid_reg;
    logic   [`FLOW_ID_W-1:0]    flowid_next;


    state_e state_reg;
    state_e state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            tcp_hdr_reg <= '0;
            flowid_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            tcp_hdr_reg <= tcp_hdr_next;
            flowid_reg <= flowid_next;
        end
    end

    assign tx_src_ip = read_flowid_lookup_entry.host_ip;
    assign tx_dst_ip = read_flowid_lookup_entry.dest_ip;
    assign tx_tcp_hdr = output_tcp_hdr_cast;

    always_comb begin
        output_tcp_hdr_cast = tcp_hdr_reg;

        output_tcp_hdr_cast.src_port = tcp_hdr_reg.dst_port;
        output_tcp_hdr_cast.dst_port = tcp_hdr_reg.src_port;
        output_tcp_hdr_cast.ack_num = tcp_hdr_reg.ack_num + 1'b1;
    end

    always_comb begin
        state_next = state_reg;
        tcp_hdr_next = tcp_hdr_reg;
        flowid_next = flowid_reg;

        read_flowid_lookup_val = 1'b0;
        read_flowid_lookup_flowid = '0;

        tx_tcp_hdr_val = 1'b0;
        rx_queue_yumi = 1'b0;
        case (state_reg)
            READY: begin
                if (rx_queue_hdr_val) begin
                    rx_queue_yumi = 1'b1;
                    state_next = OUTPUT;
                    tcp_hdr_next = rx_queue_tcp_hdr;
                    flowid_next = rx_queue_flowid;

                    read_flowid_lookup_val = 1'b1;
                    read_flowid_lookup_flowid = rx_queue_flowid;
                end
                else begin
                    state_next = READY;
                end
            end
            OUTPUT: begin
                tx_tcp_hdr_val = 1'b1;
                if (tx_tcp_hdr_rdy) begin
                    state_next = READY;
                end
                else begin
                    read_flowid_lookup_val = 1'b1;
                    read_flowid_lookup_flowid = flowid_reg;
                    state_next = OUTPUT;
                end
            end
            default: begin
                state_next = UND;
                tcp_hdr_next = 'X;
                flowid_next = 'X;

                read_flowid_lookup_val = 1'bX;
                read_flowid_lookup_flowid = 'X;

                tx_tcp_hdr_val = 1'bX;
            end
        endcase
    end

    bsg_fifo_1r1w_small #(
         .width_p(`FLOW_ID_W + `TCP_HEADER_WIDTH)
        ,.els_p  (16)
    ) rx_fifo (
         .clk_i     (clk)
        ,.reset_i   (rst)

        ,.v_i       (engine_recv_header_val                     )
        ,.ready_o   ()
        ,.data_i    ({engine_recv_flowid, engine_recv_tcp_hdr}  )

        ,.v_o       (rx_queue_hdr_val                           )
        ,.data_o    ({rx_queue_flowid, rx_queue_tcp_hdr}        )
        ,.yumi_i    (rx_queue_yumi                              )
    ); 

    flowid_to_addr flowid_addr_lookup(
         .clk(clk)
        ,.rst(rst)

        ,.write_val         (new_idtoaddr_lookup_val        )
        ,.write_flowid      (new_idtoaddr_lookup_flow_id    )
        ,.write_flow_entry  (new_idtoaddr_lookup_entry      )

        ,.read_val          (read_flowid_lookup_val         )
        ,.read_flowid       (read_flowid_lookup_flowid      )
        ,.read_flow_entry   (read_flowid_lookup_entry       )
    );

endmodule
