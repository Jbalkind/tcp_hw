`include "packet_defs.vh"
module ip_stream_format_pipe 
import packet_struct_pkg::*;
import ip_stream_format_pkg::*;
import tracker_pkg::*;
#(
     parameter DATA_WIDTH = -1
    ,parameter DATA_BYTES = DATA_WIDTH/8
    ,parameter PADBYTES_WIDTH = $clog2(DATA_BYTES)
)(
     input clk
    ,input rst
    
    // Data stream in from MAC
    ,input                                  src_ip_format_rx_val
    ,input  tracker_stats_struct            src_ip_format_rx_timestamp
    ,output logic                           ip_format_src_rx_rdy
    ,input          [DATA_WIDTH-1:0]        src_ip_format_rx_data
    ,input                                  src_ip_format_rx_last
    ,input          [PADBYTES_WIDTH-1:0]    src_ip_format_rx_padbytes

    // Header and data out
    ,output logic                           ip_format_dst_rx_hdr_val
    ,input                                  dst_ip_format_rx_hdr_rdy
    ,output ip_pkt_hdr                      ip_format_dst_rx_ip_hdr
    ,output tracker_stats_struct            ip_format_dst_rx_timestamp

    ,output logic                           ip_format_dst_rx_data_val
    ,input                                  dst_ip_format_rx_data_rdy
    ,output logic   [DATA_WIDTH-1:0]        ip_format_dst_rx_data
    ,output logic                           ip_format_dst_rx_last
    ,output logic   [PADBYTES_WIDTH-1:0]    ip_format_dst_rx_padbytes
);

    localparam KEEP_WIDTH = DATA_WIDTH/8;
    
    logic                           ip_chksum_resp_rdy;
    logic   [DATA_WIDTH-1:0]        ip_chksum_resp_data;
    logic                           ip_chksum_resp_last;
    logic                           ip_chksum_resp_val;
    
    logic                           out_data_fifo_rd_req;
    logic                           data_fifo_out_empty;
    fifo_struct                     data_fifo_out_data;
    
    logic                           ip_chksum_cmd_val;
    logic                           ip_chksum_cmd_enable;
    logic   [7:0]                   ip_chksum_cmd_start;
    logic   [7:0]                   ip_chksum_cmd_offset;
    logic   [15:0]                  ip_chksum_cmd_init;
    logic                           ip_chksum_cmd_rdy;

    logic   [DATA_WIDTH-1:0]        ip_chksum_req_data;
    logic   [KEEP_WIDTH-1:0]        ip_chksum_req_keep;
    logic                           ip_chksum_req_val;
    logic                           ip_chksum_req_rdy;
    logic                           ip_chksum_req_last;

    logic                           in_data_fifo_wr_req;
    fifo_struct                     in_data_fifo_wr_data;
    logic                           data_fifo_in_full;

    ip_stream_format_pipe_in #(
        .DATA_WIDTH(DATA_WIDTH  )
    ) pipe_in (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.src_ip_format_rx_val          (src_ip_format_rx_val       )
        ,.src_ip_format_rx_timestamp    (src_ip_format_rx_timestamp )
        ,.ip_format_src_rx_rdy          (ip_format_src_rx_rdy       )
        ,.src_ip_format_rx_data         (src_ip_format_rx_data      )
        ,.src_ip_format_rx_last         (src_ip_format_rx_last      )
        ,.src_ip_format_rx_padbytes     (src_ip_format_rx_padbytes  )
                                                                    
        ,.ip_chksum_cmd_val             (ip_chksum_cmd_val          )
        ,.ip_chksum_cmd_enable          (ip_chksum_cmd_enable       )
        ,.ip_chksum_cmd_start           (ip_chksum_cmd_start        )
        ,.ip_chksum_cmd_offset          (ip_chksum_cmd_offset       )
        ,.ip_chksum_cmd_init            (ip_chksum_cmd_init         )
        ,.ip_chksum_cmd_rdy             (ip_chksum_cmd_rdy          )
                                                                    
        ,.ip_chksum_req_data            (ip_chksum_req_data         )
        ,.ip_chksum_req_keep            (ip_chksum_req_keep         )
        ,.ip_chksum_req_val             (ip_chksum_req_val          )
        ,.ip_chksum_req_rdy             (ip_chksum_req_rdy          )
        ,.ip_chksum_req_last            (ip_chksum_req_last         )
                                                                    
        ,.in_data_fifo_wr_req           (in_data_fifo_wr_req        )
        ,.in_data_fifo_wr_data          (in_data_fifo_wr_data       )
        ,.data_fifo_in_full             (data_fifo_in_full          )
    );
    
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
        ,.m_axis_tdata              (ip_chksum_resp_data)
        ,.m_axis_tkeep              ()
        ,.m_axis_tvalid             (ip_chksum_resp_val )
        ,.m_axis_tready             (ip_chksum_resp_rdy )
        ,.m_axis_tlast              (ip_chksum_resp_last)
        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()
        ,.m_axis_tuser              ()

        ,.csum_result               ()
    );

    fifo_1r1w #(
         .width_p       (FIFO_STRUCT_W  )
        ,.log2_els_p    (6              )
    ) data_fifo (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.rd_req    (out_data_fifo_rd_req   )
        ,.rd_data   (data_fifo_out_data     )
        ,.empty     (data_fifo_out_empty    )

        ,.wr_req    (in_data_fifo_wr_req    )
        ,.wr_data   (in_data_fifo_wr_data   )
        ,.full      (data_fifo_in_full      )
    );



    ip_stream_format_pipe_out #(
        .DATA_WIDTH(DATA_WIDTH  )
    ) pipe_out (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.ip_chksum_resp_rdy            (ip_chksum_resp_rdy         )
        ,.ip_chksum_resp_data           (ip_chksum_resp_data        )
        ,.ip_chksum_resp_last           (ip_chksum_resp_last        )
        ,.ip_chksum_resp_val            (ip_chksum_resp_val         )
                                                                    
        ,.out_data_fifo_rd_req          (out_data_fifo_rd_req       )
        ,.data_fifo_out_empty           (data_fifo_out_empty        )
        ,.data_fifo_out_data            (data_fifo_out_data         )
                                                                    
        ,.ip_format_dst_rx_hdr_val      (ip_format_dst_rx_hdr_val   )
        ,.dst_ip_format_rx_hdr_rdy      (dst_ip_format_rx_hdr_rdy   )
        ,.ip_format_dst_rx_ip_hdr       (ip_format_dst_rx_ip_hdr    )
        ,.ip_format_dst_rx_timestamp    (ip_format_dst_rx_timestamp )
                                                                    
        ,.ip_format_dst_rx_data_val     (ip_format_dst_rx_data_val  )
        ,.dst_ip_format_rx_data_rdy     (dst_ip_format_rx_data_rdy  )
        ,.ip_format_dst_rx_data         (ip_format_dst_rx_data      )
        ,.ip_format_dst_rx_last         (ip_format_dst_rx_last      )
        ,.ip_format_dst_rx_padbytes     (ip_format_dst_rx_padbytes  )
    );

endmodule
