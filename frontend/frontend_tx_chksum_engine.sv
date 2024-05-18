`include "packet_defs.vh"
`include "soc_defs.vh"

import packet_struct_pkg::*;
module frontend_tx_chksum_engine #(
     parameter DATA_WIDTH = 256
    ,parameter KEEP_WIDTH = DATA_WIDTH/8
    ,parameter USER_WIDTH = `PKT_TIMESTAMP_W
)(
     input clk
    ,input rst

    // I/O from the payload engine
    ,input                                  src_chksum_tx_hdr_val
    ,output logic                           chksum_src_tx_hdr_rdy
    ,input          [`IP_ADDR_W-1:0]        src_chksum_tx_src_ip
    ,input          [`IP_ADDR_W-1:0]        src_chksum_tx_dst_ip
    ,input          [`TOT_LEN_W-1:0]        src_chksum_tx_payload_len
    ,input  tcp_pkt_hdr                     src_chksum_tx_tcp_hdr
                                                                      
    ,input                                  src_chksum_tx_data_val
    ,input          [`MAC_INTERFACE_W-1:0]  src_chksum_tx_data
    ,input                                  src_chksum_tx_data_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_chksum_tx_data_padbytes
    ,output logic                           chksum_src_tx_data_rdy


    // I/O to the MAC side
    ,output logic                           chksum_dst_tx_hdr_val
    ,input                                  dst_chksum_tx_hdr_rdy
    ,output logic   [`IP_ADDR_W-1:0]        chksum_dst_tx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]        chksum_dst_tx_dst_ip
    ,output logic   [`TOT_LEN_W-1:0]        chksum_dst_tx_tcp_len

    ,output logic                           chksum_dst_tx_data_val
    ,input                                  dst_chksum_tx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  chksum_dst_tx_data
    ,output logic                           chksum_dst_tx_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   chksum_dst_tx_data_padbytes
);

    localparam ID_ENABLE = 0;
    localparam DEST_ENABLE = 0;
    localparam USER_ENABLE = 1;
    localparam USE_INIT_VALUE = 1;
    
    logic                           req_cmd_csum_enable;
    logic   [7:0]                   req_cmd_csum_start;
    logic   [7:0]                   req_cmd_csum_offset;
    logic   [15:0]                  req_cmd_csum_init;
    logic                           req_cmd_valid;
    logic                           req_cmd_ready;
    
    logic   [DATA_WIDTH-1:0]        req_tdata;
    logic   [KEEP_WIDTH-1:0]        req_tkeep;
    logic   [USER_WIDTH-1:0]        req_tuser;
    logic                           req_tvalid;
    logic                           req_tready;
    logic                           req_tlast;
    
    logic   [DATA_WIDTH-1:0]        resp_tdata;
    logic   [KEEP_WIDTH-1:0]        resp_tkeep;
    logic   [USER_WIDTH-1:0]        resp_tuser;
    logic                           resp_tvalid;
    logic                           resp_tready;
    logic                           resp_tlast;
    logic   [15:0]                  csum_result;

    tcp_tx_chksum_input_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH )
        ,.USER_WIDTH    (USER_WIDTH )
    ) in_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_chksum_tx_hdr_val         (src_chksum_tx_hdr_val          )
        ,.chksum_src_tx_hdr_rdy         (chksum_src_tx_hdr_rdy          )
        ,.src_chksum_tx_src_ip          (src_chksum_tx_src_ip           )
        ,.src_chksum_tx_dst_ip          (src_chksum_tx_dst_ip           )
        ,.src_chksum_tx_payload_len     (src_chksum_tx_payload_len      )
        ,.src_chksum_tx_timestamp       ('0)
        ,.src_chksum_tx_tcp_hdr         (src_chksum_tx_tcp_hdr          )
                                                                        
        ,.src_chksum_tx_data_val        (src_chksum_tx_data_val         )
        ,.chksum_src_tx_data_rdy        (chksum_src_tx_data_rdy         )
        ,.src_chksum_tx_data            (src_chksum_tx_data             )
        ,.src_chksum_tx_data_last       (src_chksum_tx_data_last        )
        ,.src_chksum_tx_data_padbytes   (src_chksum_tx_data_padbytes    )
                                                                        
        ,.req_cmd_csum_enable           (req_cmd_csum_enable            )
        ,.req_cmd_csum_start            (req_cmd_csum_start             )
        ,.req_cmd_csum_offset           (req_cmd_csum_offset            )
        ,.req_cmd_csum_init             (req_cmd_csum_init              )
        ,.req_cmd_val                   (req_cmd_valid                  )
        ,.req_cmd_rdy                   (req_cmd_ready                  )
                                                                        
        ,.req_tdata                     (req_tdata                      )
        ,.req_tkeep                     (req_tkeep                      )
        ,.req_tuser                     (req_tuser                      )
        ,.req_tval                      (req_tvalid                     )
        ,.req_trdy                      (req_tready                     )
        ,.req_tlast                     (req_tlast                      )
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
        ,.s_axis_cmd_valid          (req_cmd_valid          )
        ,.s_axis_cmd_ready          (req_cmd_ready          )

    
        /*
         * AXI input
         */
        ,.s_axis_tdata              (req_tdata              )
        ,.s_axis_tkeep              (req_tkeep              )
        ,.s_axis_tvalid             (req_tvalid             )
        ,.s_axis_tready             (req_tready             )
        ,.s_axis_tlast              (req_tlast              )
        ,.s_axis_tuser              (req_tuser              )
        ,.s_axis_tid                ('0                     )
        ,.s_axis_tdest              ('0                     )

        /*
         * AXI output
         */
        ,.m_axis_tdata              (resp_tdata             )
        ,.m_axis_tkeep              (resp_tkeep             )
        ,.m_axis_tuser              (resp_tuser             )
        ,.m_axis_tvalid             (resp_tvalid            )
        ,.m_axis_tready             (resp_tready            )
        ,.m_axis_tlast              (resp_tlast             )
        ,.csum_result               (csum_result            )

        ,.m_axis_tid                ()
        ,.m_axis_tdest              ()

    );

    tcp_tx_chksum_output_ctrl #(
         .DATA_WIDTH    (DATA_WIDTH )
        ,.USER_WIDTH    (USER_WIDTH )
    ) out_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.resp_tdata                    (resp_tdata                     )
        ,.resp_tkeep                    (resp_tkeep                     )
        ,.resp_tval                     (resp_tvalid                    )
        ,.resp_trdy                     (resp_tready                    )
        ,.resp_tlast                    (resp_tlast                     )
        ,.resp_tuser                    ()
        
        ,.chksum_dst_tx_hdr_val         (chksum_dst_tx_hdr_val          )
        ,.dst_chksum_tx_hdr_rdy         (dst_chksum_tx_hdr_rdy          )
        ,.chksum_dst_tx_src_ip          (chksum_dst_tx_src_ip           )
        ,.chksum_dst_tx_dst_ip          (chksum_dst_tx_dst_ip           )
        ,.chksum_dst_tx_tcp_len         (chksum_dst_tx_tcp_len          )
        ,.chksum_dst_tx_timestamp       ()
                                                                        
        ,.chksum_dst_tx_data_val        (chksum_dst_tx_data_val         )
        ,.dst_chksum_tx_data_rdy        (dst_chksum_tx_data_rdy         )
        ,.chksum_dst_tx_data            (chksum_dst_tx_data             )
        ,.chksum_dst_tx_data_last       (chksum_dst_tx_data_last        )
        ,.chksum_dst_tx_data_padbytes   (chksum_dst_tx_data_padbytes    )
    );

endmodule
