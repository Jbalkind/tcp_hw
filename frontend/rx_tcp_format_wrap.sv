`include "packet_defs.vh"
`include "soc_defs.vh"

import packet_struct_pkg::*;
module rx_tcp_format_wrap (
     input clk
    ,input rst
    
    // I/O from the MAC side
    ,input                                      src_tcp_format_rx_hdr_val
    ,output logic                               tcp_format_src_rx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]            src_tcp_format_rx_src_ip
    ,input          [`IP_ADDR_W-1:0]            src_tcp_format_rx_dst_ip
    ,input          [`TOT_LEN_W-1:0]            src_tcp_format_rx_tcp_len

    ,input                                      src_tcp_format_rx_data_val
    ,input          [`MAC_INTERFACE_W-1:0]      src_tcp_format_rx_data
    ,output logic                               tcp_format_src_rx_data_rdy
    ,input                                      src_tcp_format_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]       src_tcp_format_rx_padbytes

    // I/O to the TCP parser
    ,output                                     tcp_format_dst_rx_hdr_val
    ,input                                      dst_tcp_format_rx_hdr_rdy
    ,output logic   [`IP_ADDR_W-1:0]            tcp_format_dst_rx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]            tcp_format_dst_rx_dst_ip
    ,output logic   [`TOT_LEN_W-1:0]            tcp_format_dst_rx_tcp_tot_len
    ,output tcp_pkt_hdr                         tcp_format_dst_rx_tcp_hdr
    
    ,output logic                               tcp_format_dst_rx_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      tcp_format_dst_rx_data
    ,input                                      dst_tcp_format_rx_data_rdy
    ,output logic                               tcp_format_dst_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]       tcp_format_dst_rx_padbytes
);
    localparam DATA_WIDTH = `MAC_INTERFACE_W;
    localparam KEEP_WIDTH = DATA_WIDTH/8;
    localparam ID_ENABLE = 0;
    localparam DEST_ENABLE = 0;
    localparam USER_ENABLE = 0;
    localparam USE_INIT_VALUE = 1;
    
    logic                           req_cmd_val;
    logic                           req_cmd_csum_enable;
    logic   [7:0]                   req_cmd_csum_start;
    logic   [7:0]                   req_cmd_csum_offset;
    logic   [15:0]                  req_cmd_csum_init;
    logic                           req_cmd_rdy;
    
    logic   [DATA_WIDTH-1:0]        req_tdata;
    logic   [KEEP_WIDTH-1:0]        req_tkeep;
    logic                           req_tval;
    logic                           req_trdy;
    logic                           req_tlast;
    logic   [`TCP_CHKSUM_W-1:0] req_tuser;
    
    logic   [DATA_WIDTH-1:0]        resp_tdata;
    logic   [KEEP_WIDTH-1:0]        resp_tkeep;
    logic                           resp_tval;
    logic                           resp_trdy;
    logic                           resp_tlast;
    logic   [`TCP_CHKSUM_W-1:0]     resp_csum;

    rx_tcp_format_input_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH)
        ,.KEEP_WIDTH    (KEEP_WIDTH)
    ) rx_tcp_format_input_ctrl (
         .clk   (clk)
        ,.rst   (rst)
        
        // I/O from the MAC side
        ,.src_tcp_format_rx_hdr_val     (src_tcp_format_rx_hdr_val  )
        ,.tcp_format_src_rx_hdr_rdy     (tcp_format_src_rx_hdr_rdy  )
        ,.src_tcp_format_rx_src_ip      (src_tcp_format_rx_src_ip   )
        ,.src_tcp_format_rx_dst_ip      (src_tcp_format_rx_dst_ip   )
        ,.src_tcp_format_rx_tcp_len     (src_tcp_format_rx_tcp_len  )
        
        ,.src_tcp_format_rx_data_val    (src_tcp_format_rx_data_val )
        ,.src_tcp_format_rx_data        (src_tcp_format_rx_data     )
        ,.tcp_format_src_rx_data_rdy    (tcp_format_src_rx_data_rdy )
        ,.src_tcp_format_rx_last        (src_tcp_format_rx_last     )
        ,.src_tcp_format_rx_padbytes    (src_tcp_format_rx_padbytes )
        
        // I/O to the checksum engine
        
        /*
         * Control
         */
        ,.req_cmd_val                   (req_cmd_val            )
        ,.req_cmd_csum_enable           (req_cmd_csum_enable    )
        ,.req_cmd_csum_start            (req_cmd_csum_start     )
        ,.req_cmd_csum_offset           (req_cmd_csum_offset    )
        ,.req_cmd_csum_init             (req_cmd_csum_init      )
        ,.req_cmd_rdy                   (req_cmd_rdy            )
        
        /*
         * Data Output                  
         */
        ,.req_tdata                     (req_tdata      )
        ,.req_tkeep                     (req_tkeep      )
        ,.req_tval                      (req_tval       )
        ,.req_trdy                      (req_trdy       )
        ,.req_tlast                     (req_tlast      )
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
        ,.DATA_FIFO_DEPTH       (16384      )
        ,.CHECKSUM_FIFO_DEPTH   (16384/64   )
    ) rx_tcp_chksum (
         .clk   (clk)
        ,.rst   (rst)
        /*
         * Control
         */
        ,.s_axis_cmd_csum_enable    (req_cmd_csum_enable    )
        ,.s_axis_cmd_csum_start     (req_cmd_csum_start     )
        ,.s_axis_cmd_csum_offset    (req_cmd_csum_offset    )
        ,.s_axis_cmd_csum_init      (req_cmd_csum_init      )
        ,.s_axis_cmd_valid          (req_cmd_val            )
        ,.s_axis_cmd_ready          (req_cmd_rdy            )

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
        ,.s_axis_tuser              ('0)

        /*
         * AXI output
         */
        ,.m_axis_tdata              (resp_tdata)
        ,.m_axis_tkeep              (resp_tkeep)
        ,.m_axis_tvalid             (resp_tval )
        ,.m_axis_tready             (resp_trdy )
        ,.m_axis_tlast              (resp_tlast)
        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()
        ,.m_axis_tuser              ()

        ,.csum_result               (resp_csum)
    );

    rx_tcp_format_output_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH)
        ,.KEEP_WIDTH    (KEEP_WIDTH)
    ) rx_tcp_format_output_ctrl (
         .clk   (clk)
        ,.rst   (rst)
        
        /*
         * Data Input
         */ 
        ,.resp_tdata                    (resp_tdata                     )
        ,.resp_tkeep                    (resp_tkeep                     )
        ,.resp_tval                     (resp_tval                      )
        ,.resp_trdy                     (resp_trdy                      )
        ,.resp_tlast                    (resp_tlast                     )
        ,.resp_csum                     (resp_csum                      )
        
        ,.tcp_format_dst_rx_hdr_val     (tcp_format_dst_rx_hdr_val      )
        ,.dst_tcp_format_rx_hdr_rdy     (dst_tcp_format_rx_hdr_rdy      )
        ,.tcp_format_dst_rx_src_ip      (tcp_format_dst_rx_src_ip       )
        ,.tcp_format_dst_rx_dst_ip      (tcp_format_dst_rx_dst_ip       )
        ,.tcp_format_dst_rx_tcp_tot_len (tcp_format_dst_rx_tcp_tot_len  )
        ,.tcp_format_dst_rx_tcp_hdr     (tcp_format_dst_rx_tcp_hdr      )
                                                                                
        ,.tcp_format_dst_rx_data_val    (tcp_format_dst_rx_data_val     )
        ,.tcp_format_dst_rx_data        (tcp_format_dst_rx_data         )
        ,.tcp_format_dst_rx_last        (tcp_format_dst_rx_last         )
        ,.tcp_format_dst_rx_padbytes    (tcp_format_dst_rx_padbytes     )
        ,.dst_tcp_format_rx_data_rdy    (dst_tcp_format_rx_data_rdy     )
    );
    
endmodule
