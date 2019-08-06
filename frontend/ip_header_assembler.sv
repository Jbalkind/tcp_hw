`include "packet_defs.vh"
`include "soc_defs.vh"
import packet_struct_pkg::*;
// Expects requesting module to check rdy before asserting val
module ip_header_assembler #(
    parameter DATA_WIDTH = 256
)(
     input clk
    ,input rst

    ,input                          ip_hdr_req_val
    ,input  [`IP_ADDR_W-1:0]        source_ip_addr
    ,input  [`IP_ADDR_W-1:0]        dest_ip_addr
    ,input  [`TOT_LEN_W-1:0]        data_payload_len
    ,input  [`PROTOCOL_W-1:0]       protocol
    ,input  [`PKT_TIMESTAMP_W-1:0]  timestamp
    ,output logic                   ip_hdr_req_rdy 

    ,output logic                   outbound_ip_hdr_val
    ,input                          outbound_ip_hdr_rdy
    ,output [`PKT_TIMESTAMP_W-1:0]  outbound_timestamp
    ,output ip_pkt_hdr              outbound_ip_hdr
);
    localparam KEEP_WIDTH = DATA_WIDTH/8;
    localparam CHKSUM_OFFSET = (DATA_WIDTH/8) - 12;

    
    logic                                   ip_chksum_cmd_enable;
    logic   [7:0]                           ip_chksum_cmd_start;
    logic   [7:0]                           ip_chksum_cmd_offset;
    logic   [15:0]                          ip_chksum_cmd_init;
    logic                                   ip_chksum_cmd_val;
    logic                                   ip_chksum_cmd_rdy;

    logic   [DATA_WIDTH-1:0]                ip_chksum_req_data;
    logic   [KEEP_WIDTH-1:0]                ip_chksum_req_keep;
    logic                                   ip_chksum_req_val;
    logic                                   ip_chksum_req_rdy;
    logic                                   ip_chksum_req_last;
    
    logic   [DATA_WIDTH-1:0]                ip_chksum_resp_data;
    logic   [KEEP_WIDTH-1:0]                ip_chksum_resp_keep;
    logic                                   ip_chksum_resp_val;
    logic                                   ip_chksum_resp_rdy;
    logic                                   ip_chksum_resp_last;

    typedef enum logic[1:0] {
        READY = 2'd0,
        CHKSUM_INPUT = 2'd1,
        CHKSUM_OUTPUT = 2'd2,
        UND = 'X
    } states_e;

    states_e state_reg;
    states_e state_next;

    ip_pkt_hdr    ip_hdr_chksum_reg;
    ip_pkt_hdr    ip_hdr_chksum_next;
    ip_pkt_hdr    ip_hdr_chksum_cast;
    ip_pkt_hdr    outbound_ip_hdr_struct;

    logic                           store_timestamp;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_reg;
    logic   [`PKT_TIMESTAMP_W-1:0]  pkt_timestamp_next;

    assign outbound_timestamp = pkt_timestamp_reg;
    assign outbound_ip_hdr = outbound_ip_hdr_struct;
            
    // hardwire these
    assign ip_hdr_chksum_cast.ip_hdr_len = `IHL_W'd5;
    assign ip_hdr_chksum_cast.ip_version = `IP_VERSION_W'd4;
    // not sure why this is 0 but it works
    assign ip_hdr_chksum_cast.tos = '0;
    assign ip_hdr_chksum_cast.tot_len = IP_HDR_BYTES
                                        + data_payload_len;
    // who knows what this is for...it doesn't seem to matter
    // katie: this has to be 0 for demikernel/catnip
    assign ip_hdr_chksum_cast.id = `ID_W'd0;
    // this has to do with IP packet fragmentation...we just don't support this
    assign ip_hdr_chksum_cast.frag_offset = `FRAG_OFF_W'h4000;
    // live as long as possble
    assign ip_hdr_chksum_cast.ttl = `TTL_W'd64;
    assign ip_hdr_chksum_cast.protocol_no = protocol;
    assign ip_hdr_chksum_cast.chksum = '0;
    assign ip_hdr_chksum_cast.source_addr = source_ip_addr;
    assign ip_hdr_chksum_cast.dest_addr = dest_ip_addr;

    assign pkt_timestamp_next = store_timestamp
                                ? timestamp
                                : pkt_timestamp_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            ip_hdr_chksum_reg <= '0;
            pkt_timestamp_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            ip_hdr_chksum_reg <= ip_hdr_chksum_next;
            pkt_timestamp_reg <= pkt_timestamp_next;
        end
    end

    always_comb begin
        ip_hdr_req_rdy = 1'b0;
        ip_hdr_chksum_next = ip_hdr_chksum_reg;

        ip_chksum_cmd_val = 1'b0;
        ip_chksum_cmd_enable = 1'b0;
        ip_chksum_cmd_start = '0;
        ip_chksum_cmd_offset = '0;
        ip_chksum_cmd_init = '0;
                
        ip_chksum_req_data = '0;
        ip_chksum_req_val = 1'b0;
        ip_chksum_req_keep = '0;
        ip_chksum_req_last = 1'b0;

        state_next = state_reg;
        store_timestamp = 1'b0;
               
        ip_chksum_resp_rdy = 1'b0;
        outbound_ip_hdr_val = 1'b0;
        outbound_ip_hdr_struct = '0;
        case (state_reg) 
            READY: begin
                store_timestamp = 1'b1;
                ip_hdr_req_rdy = ip_chksum_cmd_rdy;

                if (ip_hdr_req_val) begin
                    ip_chksum_cmd_val = 1'b1;
                    ip_chksum_cmd_enable = 1'b1;
                    ip_chksum_cmd_start = '0;
                    ip_chksum_cmd_offset = CHKSUM_OFFSET[7:0];
                    ip_chksum_cmd_init = '0;

                    ip_hdr_chksum_next = ip_hdr_chksum_cast;

                    state_next = CHKSUM_INPUT;
                end
                else begin
                    ip_hdr_chksum_next = ip_hdr_chksum_reg;
                    state_next = READY;
                end
            end
            CHKSUM_INPUT: begin
                ip_hdr_req_rdy = 1'b0;

                ip_chksum_req_data = {ip_hdr_chksum_reg, {(DATA_WIDTH-IP_HDR_W){1'b0}}};
                ip_chksum_req_val = 1'b1;
                ip_chksum_req_keep = {KEEP_WIDTH{1'b1}} << ((DATA_WIDTH/8) - IP_HDR_BYTES);
                ip_chksum_req_last = 1'b1;

                if (ip_chksum_req_rdy) begin
                    state_next = CHKSUM_OUTPUT;
                end
                else begin
                    state_next = CHKSUM_INPUT;
                end
            end
            CHKSUM_OUTPUT: begin
                ip_hdr_req_rdy = 1'b0;
                ip_chksum_resp_rdy = outbound_ip_hdr_rdy;
                outbound_ip_hdr_val = ip_chksum_resp_val;
                outbound_ip_hdr_struct = ip_chksum_resp_data[DATA_WIDTH-1 -: IP_HDR_W];

                if (outbound_ip_hdr_rdy & outbound_ip_hdr_val) begin 
                    state_next = READY;
                end
                else begin
                    state_next = CHKSUM_OUTPUT;
                end
            end
            default: begin
                ip_hdr_req_rdy = 1'bX;
                ip_hdr_chksum_next = 'X;
                store_timestamp = 'X;

                ip_chksum_cmd_val = 1'bX;
                ip_chksum_cmd_enable = 1'bX;
                ip_chksum_cmd_start = 'X;
                ip_chksum_cmd_offset = 'X;
                ip_chksum_cmd_init = 'X;
                        
                ip_chksum_req_data = 'X;
                ip_chksum_req_val = 1'bX;
                ip_chksum_req_keep = 'X;
                ip_chksum_req_last = 1'bX;

                state_next = UND;
                       
                ip_chksum_resp_rdy = 1'bX;
                outbound_ip_hdr_val = 1'bX;
                outbound_ip_hdr_struct = 'X;
            end
        endcase
    end
    
    chksum_calc #(
        // Width of AXI stream interfaces in bits
         .DATA_WIDTH            (DATA_WIDTH)
        // AXI stream tkeep signal width (words per cycle)
        ,.KEEP_WIDTH            (KEEP_WIDTH)
        // Propagate tid signal
        ,.ID_ENABLE             (0)
        // Propagate tdest signal
        ,.DEST_ENABLE           (0)
        // Propagate tuser signal
        ,.USER_ENABLE           (0)
        // Use checksum init value
        ,.USE_INIT_VALUE        (1)
        ,.DATA_FIFO_DEPTH       (256)
        ,.CHECKSUM_FIFO_DEPTH   (64)
    ) tx_ip_hdr_chksum (
         .clk   (clk)
        ,.rst   (rst)
        /*
         * Control
         */
        ,.s_axis_cmd_csum_enable    (ip_chksum_cmd_enable   )
        ,.s_axis_cmd_csum_start     (ip_chksum_cmd_start    )
        ,.s_axis_cmd_csum_offset    (ip_chksum_cmd_offset   )
        ,.s_axis_cmd_csum_init      (ip_chksum_cmd_init     )
        ,.s_axis_cmd_valid          (ip_chksum_cmd_val      )
        ,.s_axis_cmd_ready          (ip_chksum_cmd_rdy      )

        /*
         * AXI input
         */
        ,.s_axis_tdata              (ip_chksum_req_data     )
        ,.s_axis_tkeep              (ip_chksum_req_keep     )
        ,.s_axis_tvalid             (ip_chksum_req_val      )
        ,.s_axis_tready             (ip_chksum_req_rdy      )
        ,.s_axis_tlast              (ip_chksum_req_last     )
        ,.s_axis_tid                ('0)
        ,.s_axis_tdest              ('0)
        ,.s_axis_tuser              ('0)

        /*
         * AXI output
         */
        ,.m_axis_tdata              (ip_chksum_resp_data    )
        ,.m_axis_tkeep              (ip_chksum_resp_keep    )
        ,.m_axis_tvalid             (ip_chksum_resp_val     )
        ,.m_axis_tready             (ip_chksum_resp_rdy     )
        ,.m_axis_tlast              (ip_chksum_resp_last    )
        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()
        ,.m_axis_tuser              ()

        ,.csum_result               ()
    );
    
    
endmodule
