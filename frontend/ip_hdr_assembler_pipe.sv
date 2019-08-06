`include "packet_defs.vh"
`include "soc_defs.vh"
module ip_hdr_assembler_pipe 
import packet_struct_pkg::*;
import ip_hdr_assembler_pkg::*;
import tracker_pkg::*;
#(
     parameter DATA_W = -1
    ,parameter DATA_PADBYTES = DATA_W/8
    ,parameter DATA_PADBYTES_W = $clog2(DATA_PADBYTES)
)(
     input clk
    ,input rst

    ,input                                  src_assembler_req_val
    ,input  [`IP_ADDR_W-1:0]                src_assembler_src_ip_addr
    ,input  [`IP_ADDR_W-1:0]                src_assembler_dst_ip_addr
    ,input  [`TOT_LEN_W-1:0]                src_assembler_data_payload_len
    ,input  [`PROTOCOL_W-1:0]               src_assembler_protocol
    ,input  tracker_stats_struct            src_assembler_timestamp
    ,output logic                           assembler_src_req_rdy 

    ,input  logic                           src_assembler_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]  src_assembler_data
    ,input  logic                           src_assembler_data_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]   src_assembler_data_padbytes
    ,output logic                           assembler_src_data_rdy

    ,output logic                           assembler_dst_hdr_val
    ,output tracker_stats_struct            assembler_dst_timestamp
    ,output ip_pkt_hdr                      assembler_dst_ip_hdr
    ,input                                  dst_assembler_hdr_rdy

    ,output logic                           assembler_dst_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]  assembler_dst_data
    ,output logic   [`MAC_PADBYTES_W-1:0]   assembler_dst_data_padbytes
    ,output logic                           assembler_dst_data_last
    ,input  logic                           dst_assembler_data_rdy
);

    localparam KEEP_W = DATA_W/8;
    logic                           in_chksum_cmd_enable;
    logic   [7:0]                   in_chksum_cmd_start;
    logic   [7:0]                   in_chksum_cmd_offset;
    logic   [15:0]                  in_chksum_cmd_init;
    logic                           in_chksum_cmd_val;
    logic                           chksum_in_cmd_rdy;

    logic   [DATA_W-1:0]            in_chksum_req_data;
    logic   [KEEP_W-1:0]            in_chksum_req_keep;
    tracker_stats_struct            in_chksum_req_user;
    logic                           in_chksum_req_val;
    logic                           in_chksum_req_last;
    logic                           chksum_in_req_rdy;

    logic                           in_data_fifo_wr_req;
    fifo_struct                     in_data_fifo_wr_data;
    logic                           data_fifo_in_full;
    
    logic   [DATA_W-1:0]            chksum_out_resp_data;
    tracker_stats_struct            chksum_out_resp_user;
    logic                           chksum_out_resp_val;
    logic                           out_chksum_resp_rdy;

    logic                           out_data_fifo_rd_req;
    logic                           data_fifo_out_empty;
    fifo_struct                     data_fifo_out_data;

    ip_hdr_assembler_pipe_in #(
         .DATA_W    (DATA_W )
    ) pipe_in (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.src_assembler_req_val             (src_assembler_req_val          )
        ,.src_assembler_src_ip_addr         (src_assembler_src_ip_addr      )
        ,.src_assembler_dst_ip_addr         (src_assembler_dst_ip_addr      )
        ,.src_assembler_data_payload_len    (src_assembler_data_payload_len )
        ,.src_assembler_protocol            (src_assembler_protocol         )
        ,.src_assembler_timestamp           (src_assembler_timestamp        )
        ,.assembler_src_req_rdy             (assembler_src_req_rdy          )
                                                                            
        ,.src_assembler_data_val            (src_assembler_data_val         )
        ,.src_assembler_data                (src_assembler_data             )
        ,.src_assembler_data_last           (src_assembler_data_last        )
        ,.src_assembler_data_padbytes       (src_assembler_data_padbytes    )
        ,.assembler_src_data_rdy            (assembler_src_data_rdy         )

        ,.in_chksum_cmd_enable              (in_chksum_cmd_enable           )
        ,.in_chksum_cmd_start               (in_chksum_cmd_start            )
        ,.in_chksum_cmd_offset              (in_chksum_cmd_offset           )
        ,.in_chksum_cmd_init                (in_chksum_cmd_init             )
        ,.in_chksum_cmd_val                 (in_chksum_cmd_val              )
        ,.chksum_in_cmd_rdy                 (chksum_in_cmd_rdy              )
                                                                            
        ,.in_chksum_req_data                (in_chksum_req_data             )
        ,.in_chksum_req_keep                (in_chksum_req_keep             )
        ,.in_chksum_req_user                (in_chksum_req_user             )
        ,.in_chksum_req_val                 (in_chksum_req_val              )
        ,.in_chksum_req_last                (in_chksum_req_last             )
        ,.chksum_in_req_rdy                 (chksum_in_req_rdy              )
                                                                            
        ,.in_data_fifo_wr_req               (in_data_fifo_wr_req            )
        ,.in_data_fifo_wr_data              (in_data_fifo_wr_data           )
        ,.data_fifo_in_full                 (data_fifo_in_full              )
    );

    chksum_calc #(
        // Width of AXI stream interfaces in bits
         .DATA_WIDTH            (DATA_W)
        // AXI stream tkeep signal width (words per cycle)
        ,.KEEP_WIDTH            (KEEP_W)
        // Propagate tid signal
        ,.ID_ENABLE             (0)
        // Propagate tdest signal
        ,.DEST_ENABLE           (0)
        // Propagate tuser signal
        ,.USER_ENABLE           (1)
        ,.USER_WIDTH            (TRACKER_STATS_W) 
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
        ,.s_axis_cmd_csum_enable    (in_chksum_cmd_enable   )
        ,.s_axis_cmd_csum_start     (in_chksum_cmd_start    )
        ,.s_axis_cmd_csum_offset    (in_chksum_cmd_offset   )
        ,.s_axis_cmd_csum_init      (in_chksum_cmd_init     )
        ,.s_axis_cmd_valid          (in_chksum_cmd_val      )
        ,.s_axis_cmd_ready          (chksum_in_cmd_rdy      )

        /*
         * AXI input
         */
        ,.s_axis_tvalid             (in_chksum_req_val      )
        ,.s_axis_tdata              (in_chksum_req_data     )
        ,.s_axis_tkeep              (in_chksum_req_keep     )
        ,.s_axis_tlast              (in_chksum_req_last     )
        ,.s_axis_tuser              (in_chksum_req_user     )
        ,.s_axis_tready             (chksum_in_req_rdy      )
        ,.s_axis_tid                ('0)
        ,.s_axis_tdest              ('0)

        /*
         * AXI output
         */
        ,.m_axis_tdata              (chksum_out_resp_data   )
        ,.m_axis_tvalid             (chksum_out_resp_val    )
        ,.m_axis_tuser              (chksum_out_resp_user   )
        ,.m_axis_tready             (out_chksum_resp_rdy    )
        ,.m_axis_tkeep              ()
        ,.m_axis_tlast              ()
        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()

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


    ip_hdr_assembler_pipe_out #(
        .DATA_W (DATA_W )
    ) pipe_out (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.chksum_out_resp_data          (chksum_out_resp_data           )
        ,.chksum_out_resp_user          (chksum_out_resp_user           )
        ,.chksum_out_resp_val           (chksum_out_resp_val            )
        ,.out_chksum_resp_rdy           (out_chksum_resp_rdy            )
                                                                        
        ,.out_data_fifo_rd_req          (out_data_fifo_rd_req           )
        ,.data_fifo_out_empty           (data_fifo_out_empty            )
        ,.data_fifo_out_data            (data_fifo_out_data             )
                                                                        
        ,.assembler_dst_hdr_val         (assembler_dst_hdr_val          )
        ,.assembler_dst_timestamp       (assembler_dst_timestamp        )
        ,.assembler_dst_ip_hdr          (assembler_dst_ip_hdr           )
        ,.dst_assembler_hdr_rdy         (dst_assembler_hdr_rdy          )
                                                                        
        ,.assembler_dst_data_val        (assembler_dst_data_val         )
        ,.assembler_dst_data            (assembler_dst_data             )
        ,.assembler_dst_data_padbytes   (assembler_dst_data_padbytes    )
        ,.assembler_dst_data_last       (assembler_dst_data_last        )
        ,.dst_assembler_data_rdy        (dst_assembler_data_rdy         )
    );
endmodule
