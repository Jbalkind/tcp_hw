`include "packet_defs.vh"
`include "soc_defs.vh"
module udp_to_stream 
    import tracker_pkg::*;
import packet_struct_pkg::*;
#(
    parameter DATA_WIDTH = 256
)(
     input clk
    ,input rst
    
    ,input                                  src_udp_to_stream_hdr_val
    ,input          [`IP_ADDR_W-1:0]        src_udp_to_stream_src_ip_addr
    ,input          [`IP_ADDR_W-1:0]        src_udp_to_stream_dst_ip_addr
    ,input  udp_pkt_hdr                     src_udp_to_stream_udp_hdr
    ,input  tracker_stats_struct            src_udp_to_stream_timestamp
    ,output logic                           udp_to_stream_src_hdr_rdy
    
    ,input                                  src_udp_to_stream_data_val
    ,output logic                           udp_to_stream_src_data_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_udp_to_stream_data
    ,input                                  src_udp_to_stream_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_udp_to_stream_data_padbytes

    ,output logic                           udp_to_stream_dst_hdr_val
    ,output logic   [`IP_ADDR_W-1:0]        udp_to_stream_dst_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        udp_to_stream_dst_dst_ip
    ,output logic   [`TOT_LEN_W-1:0]        udp_to_stream_dst_udp_len
    ,output logic   [`PROTOCOL_W-1:0]       udp_to_stream_dst_protocol
    ,output tracker_stats_struct            udp_to_stream_dst_timestamp
    ,input                                  dst_udp_to_stream_hdr_rdy
    
    // Stream output
    ,output logic                           udp_to_stream_dst_val
    ,input                                  dst_udp_to_stream_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  udp_to_stream_dst_data
    ,output logic                           udp_to_stream_dst_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   udp_to_stream_dst_padbytes
);
    localparam KEEP_WIDTH = DATA_WIDTH/8;
    localparam ID_ENABLE = 0;
    localparam DEST_ENABLE = 0;
    localparam USER_ENABLE = 1;
    localparam USER_WIDTH = TRACKER_STATS_W;
    localparam USE_INIT_VALUE = 1;


    logic                           req_cmd_csum_enable;
    logic   [7:0]                   req_cmd_csum_start;
    logic   [7:0]                   req_cmd_csum_offset;
    logic   [15:0]                  req_cmd_csum_init;
    logic                           req_cmd_val;
    logic                           req_cmd_rdy;

    logic   [DATA_WIDTH-1:0]        req_tdata;
    logic   [KEEP_WIDTH-1:0]        req_tkeep;
    logic   [USER_WIDTH-1:0]        req_tuser;
    logic                           req_tval;
    logic                           req_trdy;
    logic                           req_tlast;
    
    logic   [DATA_WIDTH-1:0]        resp_tdata;
    logic   [KEEP_WIDTH-1:0]        resp_tkeep;
    logic   [USER_WIDTH-1:0]        resp_tuser;
    logic                           resp_tval;
    logic                           resp_trdy;
    logic                           resp_tlast;
    logic   [`UDP_CHKSUM_W-1:0]     csum_result;

    assign udp_to_stream_dst_protocol = `IPPROTO_UDP;

    udp_tx_chksum_input_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH )
        ,.USER_WIDTH    (USER_WIDTH )
    ) udp_tx_chksum_input (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.src_udp_to_stream_hdr_val         (src_udp_to_stream_hdr_val          )
        ,.src_udp_to_stream_src_ip_addr     (src_udp_to_stream_src_ip_addr      )
        ,.src_udp_to_stream_dst_ip_addr     (src_udp_to_stream_dst_ip_addr      )
        ,.src_udp_to_stream_udp_hdr         (src_udp_to_stream_udp_hdr          )
        ,.src_udp_to_stream_timestamp       (src_udp_to_stream_timestamp        )
        ,.udp_to_stream_src_hdr_rdy         (udp_to_stream_src_hdr_rdy          )
                                                                                
        ,.src_udp_to_stream_data_val        (src_udp_to_stream_data_val         )
        ,.udp_to_stream_src_data_rdy        (udp_to_stream_src_data_rdy         )
        ,.src_udp_to_stream_data            (src_udp_to_stream_data             )
        ,.src_udp_to_stream_data_last       (src_udp_to_stream_data_last        )
        ,.src_udp_to_stream_data_padbytes   (src_udp_to_stream_data_padbytes    )
        
        ,.req_cmd_csum_enable               (req_cmd_csum_enable                )
        ,.req_cmd_csum_start                (req_cmd_csum_start                 )
        ,.req_cmd_csum_offset               (req_cmd_csum_offset                )
        ,.req_cmd_csum_init                 (req_cmd_csum_init                  )
        ,.req_cmd_val                       (req_cmd_val                        )
        ,.req_cmd_rdy                       (req_cmd_rdy                        )
                                                                                
        ,.req_tdata                         (req_tdata                          )
        ,.req_tkeep                         (req_tkeep                          )
        ,.req_tuser                         (req_tuser                          )
        ,.req_tval                          (req_tval                           )
        ,.req_trdy                          (req_trdy                           )
        ,.req_tlast                         (req_tlast                          )
    );
    
    chksum_calc #(
         .DATA_WIDTH            (DATA_WIDTH     )
        ,.ID_ENABLE             (ID_ENABLE      )
        ,.DEST_ENABLE           (DEST_ENABLE    )
        ,.USER_ENABLE           (USER_ENABLE    )
        ,.USER_WIDTH            (USER_WIDTH     )
        ,.USE_INIT_VALUE        (USE_INIT_VALUE )
        ,.DATA_FIFO_DEPTH       (16384          )
        ,.CHECKSUM_FIFO_DEPTH   (16384/64       )
    ) chksum (
         .clk(clk)
        ,.rst(rst)
        
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
        ,.s_axis_tdata              (req_tdata              )
        ,.s_axis_tkeep              (req_tkeep              )
        ,.s_axis_tvalid             (req_tval               )
        ,.s_axis_tready             (req_trdy               )
        ,.s_axis_tlast              (req_tlast              )
        ,.s_axis_tid                ('0                     )
        ,.s_axis_tdest              ('0                     )
        ,.s_axis_tuser              (req_tuser              )

        /*
         * AXI output
         */
        ,.m_axis_tdata              (resp_tdata             )
        ,.m_axis_tkeep              (resp_tkeep             )
        ,.m_axis_tvalid             (resp_tval              )
        ,.m_axis_tready             (resp_trdy              )
        ,.m_axis_tlast              (resp_tlast             )
        ,.m_axis_tuser              (resp_tuser             )
        ,.csum_result               (csum_result            )

        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()
    );

    udp_tx_chksum_output_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH )
        ,.USER_WIDTH    (USER_WIDTH )
    ) udp_tx_chksum_output (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.resp_tdata                            (resp_tdata                     )
        ,.resp_tkeep                            (resp_tkeep                     )
        ,.resp_tuser                            (resp_tuser                     )
        ,.resp_tval                             (resp_tval                      )
        ,.resp_trdy                             (resp_trdy                      )
        ,.resp_tlast                            (resp_tlast                     )
                                                                        
        ,.udp_to_stream_dst_tx_hdr_val          (udp_to_stream_dst_hdr_val      )
        ,.dst_udp_to_stream_tx_hdr_rdy          (dst_udp_to_stream_hdr_rdy      )
        ,.udp_to_stream_dst_tx_src_ip           (udp_to_stream_dst_src_ip       )
        ,.udp_to_stream_dst_tx_dst_ip           (udp_to_stream_dst_dst_ip       )
        ,.udp_to_stream_dst_tx_data_len         (udp_to_stream_dst_udp_len      )
        ,.udp_to_stream_dst_tx_timestamp        (udp_to_stream_dst_timestamp    )
                                                                      
        ,.udp_to_stream_dst_tx_data_val         (udp_to_stream_dst_val          )
        ,.dst_udp_to_stream_tx_data_rdy         (dst_udp_to_stream_rdy          )
        ,.udp_to_stream_dst_tx_data             (udp_to_stream_dst_data         )
        ,.udp_to_stream_dst_tx_data_last        (udp_to_stream_dst_last         )
        ,.udp_to_stream_dst_tx_data_padbytes    (udp_to_stream_dst_padbytes     )
    );

endmodule
