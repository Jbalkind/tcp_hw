`include "packet_defs.vh"
import packet_struct_pkg::*;
module ip_rx_chksum_calc_wrap #(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8  
) (
     input clk
    ,input rst

    ,input                                  ip_chksum_cmd_val
    ,input  logic                           ip_chksum_cmd_enable
    ,input  logic   [7:0]                   ip_chksum_cmd_start
    ,input  logic   [7:0]                   ip_chksum_cmd_offset
    ,input  logic   [15:0]                  ip_chksum_cmd_init
    ,output logic                           ip_chksum_cmd_rdy

    ,input  [DATA_WIDTH-1:0]                ip_chksum_req_data
    ,input  [KEEP_WIDTH-1:0]                ip_chksum_req_keep
    ,input                                  ip_chksum_req_val
    ,output logic                           ip_chksum_req_rdy
    ,input                                  ip_chksum_req_last

    ,input                                  ip_chksum_resp_rdy
    ,output logic                           ip_chksum_resp_val
    ,output logic   [`IP_CHKSUM_W-1:0]      ip_chksum_resp_result
);

    typedef enum logic {
        WAIT = 1'b0,
        DRAIN = 1'b1,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;
        
    logic   [DATA_WIDTH-1:0]        ip_chksum_wrap_data;
    logic   [KEEP_WIDTH-1:0]        ip_chksum_wrap_keep;
    logic                           ip_chksum_wrap_val;
    logic                           ip_chksum_wrap_rdy;
    logic                           ip_chksum_wrap_last;
    logic   [`IP_CHKSUM_W-1:0]      ip_chksum_wrap_csum;

    ip_pkt_hdr  ip_hdr_cast;

    assign ip_hdr_cast = ip_chksum_wrap_data[DATA_WIDTH-1 -: IP_HDR_W];

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= WAIT;
        end
        else begin
            state_reg <= state_next;
        end
    end

    assign ip_chksum_resp_result = ip_hdr_cast.chksum;

    always_comb begin
        ip_chksum_wrap_rdy = 1'b0;
        state_next = state_reg;
        ip_chksum_resp_val = 1'b0;
        case (state_reg)
            WAIT: begin
                ip_chksum_wrap_rdy = ip_chksum_resp_rdy;
                ip_chksum_resp_val = ip_chksum_wrap_val;
                
                // if the data becomes valid and we're accepting it
                if (ip_chksum_wrap_val & ip_chksum_resp_rdy) begin
                    // check if this is the last data packet
                    if (ip_chksum_wrap_last) begin
                        state_next = WAIT;
                    end
                    // otherwise, we need to drain the rest of the data, because the 
                    // stream formatter doesn't want to deal with it
                    else begin
                        state_next = DRAIN;
                    end
                end
                else begin
                    state_next = WAIT;
                end
            end
            // drain the excess data out of the checksum unit
            DRAIN: begin
                ip_chksum_resp_val = 1'b0;
                ip_chksum_wrap_rdy = 1'b1;
                if (ip_chksum_wrap_val) begin
                    if (ip_chksum_wrap_last) begin
                        state_next = WAIT;
                    end
                    else begin
                        state_next = DRAIN;
                    end
                end
                else begin
                    state_next = DRAIN;
                end
            end
            default: begin
                ip_chksum_wrap_rdy = 'X;
                state_next = UND;
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
    ) rx_ip_hdr_chksum (
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
        ,.s_axis_tdata              (ip_chksum_req_data)
        ,.s_axis_tkeep              (ip_chksum_req_keep)
        ,.s_axis_tvalid             (ip_chksum_req_val)
        ,.s_axis_tready             (ip_chksum_req_rdy)
        ,.s_axis_tlast              (ip_chksum_req_last)
        ,.s_axis_tid                ('0)
        ,.s_axis_tdest              ('0)
        ,.s_axis_tuser              ('0)

        /*
         * AXI output
         */
        ,.m_axis_tdata              (ip_chksum_wrap_data)
        ,.m_axis_tkeep              (ip_chksum_wrap_keep)
        ,.m_axis_tvalid             (ip_chksum_wrap_val )
        ,.m_axis_tready             (ip_chksum_wrap_rdy )
        ,.m_axis_tlast              (ip_chksum_wrap_last)
        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()
        ,.m_axis_tuser              ()

        ,.csum_result               (ip_chksum_wrap_csum)
    );
endmodule
