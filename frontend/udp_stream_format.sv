`include "packet_defs.vh"
`include "soc_defs.vh"
import packet_struct_pkg::*;
module udp_stream_format 
    import tracker_pkg::*;
#(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
    ,parameter USER_WIDTH = TRACKER_STATS_W
)(
     input clk
    ,input rst

    // IP header in
    ,input                                  src_udp_formatter_rx_hdr_val
    ,input          [`IP_ADDR_W-1:0]        src_udp_formatter_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]        src_udp_formatter_rx_dst_ip
    ,input          [`TOT_LEN_W-1:0]        src_udp_formatter_rx_udp_len
    ,input  tracker_stats_struct            src_udp_formatter_rx_timestamp
    ,output logic                           udp_formatter_src_rx_hdr_rdy

    // Data stream in from MAC-side
    ,input                                  src_udp_formatter_rx_data_val
    ,output logic                           udp_formatter_src_rx_data_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_udp_formatter_rx_data
    ,input                                  src_udp_formatter_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_udp_formatter_rx_padbytes
    
    // Headers and data out
    ,output logic                           udp_formatter_dst_rx_hdr_val
    ,output logic   [`IP_ADDR_W-1:0]        udp_formatter_dst_rx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        udp_formatter_dst_rx_dst_ip
    ,output udp_pkt_hdr                     udp_formatter_dst_rx_udp_hdr
    ,output tracker_stats_struct            udp_formatter_dst_rx_timestamp
    ,input                                  dst_udp_formatter_rx_hdr_rdy

    ,output logic                           udp_formatter_dst_rx_data_val
    ,input                                  dst_udp_formatter_rx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  udp_formatter_dst_rx_data
    ,output logic                           udp_formatter_dst_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   udp_formatter_dst_rx_padbytes
);
    
    typedef struct packed {
        logic   [DATA_WIDTH-1:0]    data;
        logic                       last;
        logic   [KEEP_WIDTH-1:0]    keep;
    } data_q_struct;
    localparam DATA_Q_STRUCT_W = DATA_WIDTH + 1 + KEEP_WIDTH;

    
    logic                           req_cmd_val;
    logic                           req_cmd_rdy;
    logic                           req_cmd_csum_enable;
    logic   [7:0]                   req_cmd_csum_start;
    logic   [7:0]                   req_cmd_csum_offset;
    logic   [15:0]                  req_cmd_csum_init;
    
    logic   [DATA_WIDTH-1:0]        req_tdata;
    logic   [KEEP_WIDTH-1:0]        req_tkeep;
    logic                           req_tval;
    logic                           req_trdy;
    logic   [USER_WIDTH-1:0]        req_tuser;
    logic                           req_tlast;
    
    logic   [DATA_WIDTH-1:0]        resp_tdata;
    logic   [KEEP_WIDTH-1:0]        resp_tkeep;
    logic   [USER_WIDTH-1:0]        resp_tuser;
    logic                           resp_tval;
    logic                           resp_trdy;
    logic                           resp_tlast;
    logic   [`UDP_CHKSUM_W-1:0]     resp_csum;

    logic           data_q_wr_req;
    data_q_struct   data_q_wr_data;
    logic           data_q_full;
    logic           data_q_rd_req;
    data_q_struct   data_q_rd_data;
    logic           data_q_empty;

    udp_rx_chksum_input_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH )
        ,.KEEP_WIDTH    (KEEP_WIDTH )
        ,.USER_WIDTH    (USER_WIDTH )
    ) input_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.src_udp_formatter_rx_hdr_val  (src_udp_formatter_rx_hdr_val   )
        ,.src_udp_formatter_rx_src_ip   (src_udp_formatter_rx_src_ip    )
        ,.src_udp_formatter_rx_dst_ip   (src_udp_formatter_rx_dst_ip    )
        ,.src_udp_formatter_rx_udp_len  (src_udp_formatter_rx_udp_len   )
        ,.src_udp_formatter_rx_timestamp(src_udp_formatter_rx_timestamp )
        ,.udp_formatter_src_rx_hdr_rdy  (udp_formatter_src_rx_hdr_rdy   )
                                                                        
        ,.src_udp_formatter_rx_data_val (src_udp_formatter_rx_data_val  )
        ,.udp_formatter_src_rx_data_rdy (udp_formatter_src_rx_data_rdy  )
        ,.src_udp_formatter_rx_data     (src_udp_formatter_rx_data      )
        ,.src_udp_formatter_rx_last     (src_udp_formatter_rx_last      )
        ,.src_udp_formatter_rx_padbytes (src_udp_formatter_rx_padbytes  )
        
        ,.req_cmd_csum_enable           (req_cmd_csum_enable            )
        ,.req_cmd_csum_start            (req_cmd_csum_start             )
        ,.req_cmd_csum_offset           (req_cmd_csum_offset            )
        ,.req_cmd_csum_init             (req_cmd_csum_init              )
        ,.req_cmd_val                   (req_cmd_val                    )
        ,.req_cmd_rdy                   (req_cmd_rdy                    )
                                                                        
        ,.req_tdata                     (req_tdata                      )
        ,.req_tkeep                     (req_tkeep                      )
        ,.req_tval                      (req_tval                       )
        ,.req_trdy                      (req_trdy                       )
        ,.req_tlast                     (req_tlast                      )
        ,.req_tuser                     (req_tuser                      )
    );
   
    //early_mrp_logger early_logger (
    //     .clk   (clk    )
    //    ,.rst   (rst    )

    //    ,.src_early_logger_rx_data_val      (req_tval   )
    //    ,.src_early_logger_rx_data          (req_tdata  )
    //    ,.src_early_logger_rx_last          (req_tlast  )
    //    ,.src_early_logger_rx_padbytes      ('0         )
    //    ,.src_early_logger_rx_rdy           (req_trdy   )
    //    ,.src_early_logger_chksum           ('0         )

    //    ,.early_logger_rd_cmd_queue_empty   (early_logger_rd_cmd_queue_empty    )
    //    ,.early_logger_rd_cmd_queue_rd_req  (early_logger_rd_cmd_queue_rd_req   )
    //    ,.early_logger_rd_cmd_queue_rd_data (early_logger_rd_cmd_queue_rd_data  )

    //    ,.early_logger_rd_resp_val          (early_logger_rd_resp_val           )
    //    ,.early_logger_shell_reg_rd_data    (early_logger_shell_reg_rd_data     )
    //);

    //assign req_cmd_rdy = 1'b1;
    //assign resp_csum = '0;
    
    //assign data_q_wr_req = req_tval & ~data_q_full;
    //assign data_q_wr_data.data = req_tdata;
    //assign data_q_wr_data.last = req_tlast;
    //assign data_q_wr_data.keep = req_tkeep;
    //assign req_trdy = ~data_q_full;

    //fifo_1r1w #(
    //     .width_p       (DATA_Q_STRUCT_W    )
    //    ,.log2_els_p    (6)
    //) fake_chksum_fifo (
    //     .clk   (clk    )
    //    ,.rst   (rst    )

    //    ,.rd_req    (data_q_rd_req  )
    //    ,.rd_data   (data_q_rd_data )
    //    ,.empty     (data_q_empty   )

    //    ,.wr_req    (data_q_wr_req  )
    //    ,.wr_data   (data_q_wr_data )
    //    ,.full      (data_q_full    )
    //);

    //assign data_q_rd_req = ~data_q_empty & resp_trdy;
    //assign resp_tval = ~data_q_empty;
    //assign resp_tdata = data_q_rd_data.data;
    //assign resp_tkeep = data_q_rd_data.keep;
    //assign resp_tlast = data_q_rd_data.last;

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
        ,.USER_ENABLE           (1)
        ,.USER_WIDTH            (USER_WIDTH)
        // Use checksum init value
        ,.USE_INIT_VALUE        (1)
        ,.DATA_FIFO_DEPTH       (16384)
        ,.CHECKSUM_FIFO_DEPTH   (16384/64)
    ) rx_udp_chksum (
         .clk   (clk)
        ,.rst   (rst)
        /*
         * Control
         */
        ,.s_axis_cmd_csum_enable    (req_cmd_csum_enable    )
        ,.s_axis_cmd_csum_start     (req_cmd_csum_start     )
        ,.s_axis_cmd_csum_offset    (req_cmd_csum_offset    )
        ,.s_axis_cmd_csum_init      (req_cmd_csum_init      )
        ,.s_axis_cmd_valid          (req_cmd_val)
        ,.s_axis_cmd_ready          (req_cmd_rdy)

        /*
         * AXI input
         */
        ,.s_axis_tdata              (req_tdata)
        ,.s_axis_tkeep              (req_tkeep)
        ,.s_axis_tvalid             (req_tval)
        ,.s_axis_tready             (req_trdy)
        ,.s_axis_tlast              (req_tlast)
        ,.s_axis_tid                ('0)
        ,.s_axis_tdest              ('0)
        ,.s_axis_tuser              (req_tuser)

        /*
         * AXI output
         */
        ,.m_axis_tdata              (resp_tdata)
        ,.m_axis_tkeep              (resp_tkeep)
        ,.m_axis_tvalid             (resp_tval )
        ,.m_axis_tready             (resp_trdy )
        ,.m_axis_tlast              (resp_tlast)
        ,.m_axis_tuser              (resp_tuser)
        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()

        ,.csum_result               (resp_csum)
    );
    

    udp_rx_chksum_output_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH )
        ,.KEEP_WIDTH    (KEEP_WIDTH )
    ) output_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.resp_tdata                    (resp_tdata                     )
        ,.resp_tkeep                    (resp_tkeep                     )
        ,.resp_tval                     (resp_tval                      )
        ,.resp_trdy                     (resp_trdy                      )
        ,.resp_tlast                    (resp_tlast                     )
        ,.resp_tuser                    (resp_tuser                     )
        ,.resp_csum                     (resp_csum                      )
    
        ,.udp_formatter_dst_rx_hdr_val  (udp_formatter_dst_rx_hdr_val   )
        ,.udp_formatter_dst_rx_src_ip   (udp_formatter_dst_rx_src_ip    )
        ,.udp_formatter_dst_rx_dst_ip   (udp_formatter_dst_rx_dst_ip    )
        ,.udp_formatter_dst_rx_udp_hdr  (udp_formatter_dst_rx_udp_hdr   )
        ,.udp_formatter_dst_rx_timestamp(udp_formatter_dst_rx_timestamp )
        ,.dst_udp_formatter_rx_hdr_rdy  (dst_udp_formatter_rx_hdr_rdy   )
                                                                        
        ,.udp_formatter_dst_rx_data_val (udp_formatter_dst_rx_data_val  )
        ,.dst_udp_formatter_rx_data_rdy (dst_udp_formatter_rx_data_rdy  )
        ,.udp_formatter_dst_rx_data     (udp_formatter_dst_rx_data      )
        ,.udp_formatter_dst_rx_last     (udp_formatter_dst_rx_last      )
        ,.udp_formatter_dst_rx_padbytes (udp_formatter_dst_rx_padbytes  )
    );
endmodule
