`include "packet_defs.vh"
`include "state_defs.vh"
`include "noc_defs.vh"
`include "soc_defs.vh"

module frontend_parser(
     input clk
    ,input rst
   
    // I/O for the MAC
    ,input                                  mac_engine_rx_val
    ,input          [`MAC_INTERFACE_W-1:0]  mac_engine_rx_data
    ,output logic                           engine_mac_rx_rdy
    ,input                                  mac_engine_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]   mac_engine_rx_padbytes
    
    ,output logic                           engine_mac_tx_val
    ,input                                  mac_engine_tx_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  engine_mac_tx_data
    ,output logic                           engine_mac_tx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   engine_mac_tx_padbytes
    
    // I/O for the NoC
    ,output logic                           tx_parser_noc0_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]   tx_parser_noc0_data
    ,input                                  noc0_tx_parser_rdy
    
    ,input                                  noc0_tx_parser_val
    ,input          [`NOC_DATA_WIDTH-1:0]   noc0_tx_parser_data
    ,output                                 tx_parser_noc0_rdy

    // I/O for the TCP engine
    ,output                                 parser_tcp_rx_hdr_val
    ,input                                  tcp_parser_rx_rdy
    ,output         [`IP_ADDR_W-1:0]        parser_tcp_rx_src_ip
    ,output         [`IP_ADDR_W-1:0]        parser_tcp_rx_dst_ip
    ,output         [`TCP_HDR_W-1:0]        parser_tcp_rx_tcp_hdr

    ,output                                 parser_tcp_rx_payload_val
    ,output [`PAYLOAD_ENTRY_ADDR_W-1:0]     parser_tcp_rx_payload_addr
    ,output [`PAYLOAD_ENTRY_LEN_W-1:0]      parser_tcp_rx_payload_len
    
    ,input                                  tcp_parser_tx_val
    ,output                                 parser_tcp_tx_rdy
    ,input  [`FLOW_ID_W-1:0]                tcp_parser_tx_flowid
    ,input  [`IP_ADDR_W-1:0]                tcp_parser_tx_src_ip
    ,input  [`IP_ADDR_W-1:0]                tcp_parser_tx_dst_ip
    ,input  [`TCP_HDR_W-1:0]                tcp_parser_tx_tcp_hdr
    ,input  [`PAYLOAD_ENTRY_W-1:0]          tcp_parser_tx_payload_entry
    
    ,input  logic                               store_buf_tmp_buf_store_rx_rd_req_val
    ,input  logic   [`PAYLOAD_ENTRY_ADDR_W-1:0] store_buf_tmp_buf_store_rx_rd_req_addr
    ,output logic                               tmp_buf_store_store_buf_rx_rd_req_rdy

    ,output logic                               tmp_buf_store_store_buf_rx_rd_resp_val
    ,output logic   [`MAC_INTERFACE_W-1:0]      tmp_buf_store_store_buf_rx_rd_resp_data
    ,input  logic                               store_buf_tmp_buf_store_rx_rd_resp_rdy

    ,input  logic                               store_buf_tmp_buf_free_slab_rx_req_val
    ,input  logic   [`RX_TMP_BUF_ADDR_W-1:0]    store_buf_tmp_buf_free_slab_rx_req_addr
    ,output logic                               tmp_buf_free_slab_store_buf_rx_req_rdy
);

    localparam els_p = `MAC_INTERFACE_W/`NOC_DATA_WIDTH;
    localparam ETH_IP_Q_DATA_W = `MAC_INTERFACE_W + 1 + `MAC_PADBYTES_W;

    localparam fbits_rx = 4'b1000;
    localparam fbits_tx = 4'b1001;

    logic                           payload_chksum_tx_hdr_val;
    logic                           chksum_payload_tx_hdr_rdy;
    logic   [`IP_ADDR_W-1:0]        payload_chksum_tx_src_ip;
    logic   [`IP_ADDR_W-1:0]        payload_chksum_tx_dst_ip;
    logic   [`TOT_LEN_W-1:0]        payload_chksum_tx_payload_len;
    tcp_pkt_hdr                     payload_chksum_tx_tcp_hdr;
    
    logic                           payload_chksum_tx_data_val;
    logic   [`MAC_INTERFACE_W-1:0]  payload_chksum_tx_data;
    logic                           payload_chksum_tx_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   payload_chksum_tx_data_padbytes;
    logic                           chksum_payload_tx_data_rdy;
    
    eth_hdr                         eth_format_ip_format_rx_eth_hdr;
    logic                           eth_format_ip_format_rx_hdr_val;
    logic                           ip_format_eth_format_rx_hdr_rdy;

    logic                           eth_format_q_rx_data_val;
    logic   [`MAC_INTERFACE_W-1:0]  eth_format_q_rx_data;
    logic                           eth_format_q_rx_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   eth_format_q_rx_data_padbytes;
    logic                           q_eth_format_rx_data_rdy;

    logic                           eth_ip_q_wr_req;
    logic   [ETH_IP_Q_DATA_W-1:0]   eth_ip_q_wr_data;
    logic                           eth_ip_q_full;
    
    logic                           eth_ip_q_rd_req;
    logic   [ETH_IP_Q_DATA_W-1:0]   eth_ip_q_rd_data;
    logic                           eth_ip_q_empty;
    
    logic                           q_ip_format_rx_data_val;
    logic   [`MAC_INTERFACE_W-1:0]  q_ip_format_rx_data;
    logic                           q_ip_format_rx_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   q_ip_format_rx_data_padbytes;
    logic                           ip_format_q_rx_data_rdy;
    
    logic                           ip_format_tcp_format_rx_hdr_val;
    logic                           tcp_format_ip_format_rx_hdr_rdy;
    ip_pkt_hdr                      ip_format_tcp_format_rx_ip_hdr;

    logic                           ip_format_tcp_format_rx_data_val;
    logic                           tcp_format_ip_format_rx_data_rdy;
    logic   [`MAC_INTERFACE_W-1:0]  ip_format_tcp_format_rx_data;
    logic                           ip_format_tcp_format_rx_last;
    logic   [`MAC_PADBYTES_W-1:0]   ip_format_tcp_format_rx_padbytes;
    
    logic                           tcp_format_payload_rx_hdr_val;
    logic                           payload_tcp_format_rx_hdr_rdy;
    logic   [`IP_ADDR_W-1:0]        tcp_format_payload_rx_src_ip;
    logic   [`IP_ADDR_W-1:0]        tcp_format_payload_rx_dst_ip;
    logic   [`TOT_LEN_W-1:0]        tcp_format_payload_rx_tcp_tot_len;
    tcp_pkt_hdr                     tcp_format_payload_rx_tcp_hdr;

    logic                           tcp_format_payload_rx_data_val;
    logic                           payload_tcp_format_rx_data_rdy;
    logic   [`MAC_INTERFACE_W-1:0]  tcp_format_payload_rx_data;
    logic                           tcp_format_payload_rx_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   tcp_format_payload_rx_data_padbytes;

    logic                           chksum_tcp_to_ipstream_tx_hdr_val;
    logic                           tcp_to_ipstream_chksum_tx_hdr_rdy;
    logic   [`IP_ADDR_W-1:0]        chksum_tcp_to_ipstream_tx_src_ip;
    logic   [`IP_ADDR_W-1:0]        chksum_tcp_to_ipstream_tx_dst_ip;
    logic   [`TOT_LEN_W-1:0]        chksum_tcp_to_ipstream_tx_tcp_len;
    tcp_pkt_hdr                     chksum_tcp_to_ipstream_tx_tcp_hdr;
    
    logic                           tcp_to_ipstream_ip_to_ethstream_tx_hdr_val;
    ip_pkt_hdr                      tcp_to_ipstream_ip_to_ethstream_tx_ip_hdr;
    logic                           ip_to_ethstream_tcp_to_ipstream_tx_hdr_rdy;

    logic                           tcp_to_ipstream_ip_to_ethstream_tx_data_val;
    logic   [`MAC_INTERFACE_W-1:0]  tcp_to_ipstream_ip_to_ethstream_tx_data;
    logic                           tcp_to_ipstream_ip_to_ethstream_tx_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   tcp_to_ipstream_ip_to_ethstream_tx_data_padbytes;
    logic                           ip_to_ethstream_tcp_to_ipstream_tx_data_rdy;
    
    logic                           ip_to_ethstream_eth_hdrtostream_tx_eth_hdr_val;
    eth_hdr                         ip_to_ethstream_eth_hdrtostream_tx_eth_hdr;
    logic                           eth_hdrtostream_ip_to_ethsteram_tx_eth_hdr_rdy;

    logic                           ip_to_ethstream_eth_hdrtostream_tx_data_val;
    logic   [`MAC_INTERFACE_W-1:0]  ip_to_ethstream_eth_hdrtostream_tx_data;
    logic                           ip_to_ethstream_eth_hdrtostream_tx_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   ip_to_ethstream_eth_hdrtostream_tx_data_padbytes;
    logic                           eth_hdrtostream_ip_to_ethstream_tx_data_rdy;

    logic                           chksum_tcp_to_ipstream_tx_data_val;
    logic                           tcp_to_ipstream_chksum_tx_data_rdy;
    logic   [`MAC_INTERFACE_W-1:0]  chksum_tcp_to_ipstream_tx_data;
    logic                           chksum_tcp_to_ipstream_tx_data_last;
    logic   [`MAC_PADBYTES_W-1:0]   chksum_tcp_to_ipstream_tx_data_padbytes;

    payload_buf_entry               parser_tcp_rx_payload_entry;


    eth_frame_format rx_eth_format (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_eth_format_val            (mac_engine_rx_val                  )
        ,.src_eth_format_data           (mac_engine_rx_data                 )
        ,.src_eth_format_data_last      (mac_engine_rx_last                 )
        ,.src_eth_format_data_padbytes  (mac_engine_rx_padbytes             )
        ,.eth_format_src_rdy            (engine_mac_rx_rdy                  )

        ,.eth_format_dst_eth_hdr        (eth_format_ip_format_rx_eth_hdr    )
        ,.eth_format_dst_hdr_val        (eth_format_ip_format_rx_hdr_val    )
        ,.dst_eth_format_hdr_rdy        (ip_format_eth_format_rx_hdr_rdy    )

        ,.eth_format_dst_data_val       (eth_format_q_rx_data_val           )
        ,.eth_format_dst_data           (eth_format_q_rx_data               )
        ,.eth_format_dst_data_last      (eth_format_q_rx_data_last          )
        ,.eth_format_dst_data_padbytes  (eth_format_q_rx_data_padbytes      )
        ,.dst_eth_format_data_rdy       (q_eth_format_rx_data_rdy           )
    );

    // fifo to relieve timing pressure

    assign eth_ip_q_wr_req = eth_format_q_rx_data_val & ~eth_ip_q_full;
    assign eth_ip_q_wr_data = {eth_format_q_rx_data,
                               eth_format_q_rx_data_last,
                               eth_format_q_rx_data_padbytes};
    assign q_eth_format_rx_data_rdy = ~eth_ip_q_full;

    fifo_1r1w #(
         .width_p    (ETH_IP_Q_DATA_W)
        ,.log2_els_p (4)
    ) eth_ip_q (
         .clk     (clk)
        ,.rst     (rst)

        ,.wr_req  (eth_ip_q_wr_req  )
        ,.wr_data (eth_ip_q_wr_data )
        ,.full    (eth_ip_q_full    )

        ,.rd_req  (eth_ip_q_rd_req  )
        ,.rd_data (eth_ip_q_rd_data )
        ,.empty   (eth_ip_q_empty   )
    );

    assign eth_ip_q_rd_req = ip_format_q_rx_data_rdy & ~eth_ip_q_empty;
    assign {q_ip_format_rx_data,
            q_ip_format_rx_data_last,
            q_ip_format_rx_data_padbytes} = eth_ip_q_rd_data;
    assign q_ip_format_rx_data_val = ~eth_ip_q_empty;
   
    assign ip_format_eth_format_rx_hdr_rdy = 1'b1;
    ip_stream_format rx_ip_format (
         .clk   (clk)
        ,.rst   (rst)
        
        // Data stream in from MAC
        ,.src_ip_format_rx_val       (q_ip_format_rx_data_val           )
        ,.src_ip_format_rx_data      (q_ip_format_rx_data               )
        ,.src_ip_format_rx_last      (q_ip_format_rx_data_last          )
        ,.src_ip_format_rx_padbytes  (q_ip_format_rx_data_padbytes      )
        ,.ip_format_src_rx_rdy       (ip_format_q_rx_data_rdy           )
    
        // Header and data out
        ,.ip_format_dst_rx_hdr_val   (ip_format_tcp_format_rx_hdr_val   )
        ,.dst_ip_format_rx_hdr_rdy   (tcp_format_ip_format_rx_hdr_rdy   )
        ,.ip_format_dst_rx_ip_hdr    (ip_format_tcp_format_rx_ip_hdr    )
    
        ,.ip_format_dst_rx_data_val  (ip_format_tcp_format_rx_data_val  )
        ,.dst_ip_format_rx_data_rdy  (tcp_format_ip_format_rx_data_rdy  )
        ,.ip_format_dst_rx_data      (ip_format_tcp_format_rx_data      )
        ,.ip_format_dst_rx_last      (ip_format_tcp_format_rx_last      )
        ,.ip_format_dst_rx_padbytes  (ip_format_tcp_format_rx_padbytes  )
    );

    rx_tcp_format_wrap  rx_tcp_format (
         .clk   (clk)
        ,.rst   (rst)
        
        // I/O from the MAC side
        ,.src_tcp_format_rx_hdr_val     (ip_format_tcp_format_rx_hdr_val        )
        ,.tcp_format_src_rx_hdr_rdy     (tcp_format_ip_format_rx_hdr_rdy        )
        ,.src_tcp_format_rx_ip_hdr      (ip_format_tcp_format_rx_ip_hdr         )

        ,.src_tcp_format_rx_data_val    (ip_format_tcp_format_rx_data_val       )
        ,.src_tcp_format_rx_data        (ip_format_tcp_format_rx_data           )
        ,.tcp_format_src_rx_data_rdy    (tcp_format_ip_format_rx_data_rdy       )
        ,.src_tcp_format_rx_last        (ip_format_tcp_format_rx_last           )
        ,.src_tcp_format_rx_padbytes    (ip_format_tcp_format_rx_padbytes       )

        // I/O to the TCP parser
        ,.tcp_format_dst_rx_hdr_val     (tcp_format_payload_rx_hdr_val          )
        ,.dst_tcp_format_rx_hdr_rdy     (payload_tcp_format_rx_hdr_rdy          )
        ,.tcp_format_dst_rx_src_ip      (tcp_format_payload_rx_src_ip           )
        ,.tcp_format_dst_rx_dst_ip      (tcp_format_payload_rx_dst_ip           )
        ,.tcp_format_dst_rx_tcp_tot_len (tcp_format_payload_rx_tcp_tot_len      )
        ,.tcp_format_dst_rx_tcp_hdr     (tcp_format_payload_rx_tcp_hdr          )
        
        ,.tcp_format_dst_rx_data_val    (tcp_format_payload_rx_data_val         )
        ,.tcp_format_dst_rx_data        (tcp_format_payload_rx_data             )
        ,.dst_tcp_format_rx_data_rdy    (payload_tcp_format_rx_data_rdy         )
        ,.tcp_format_dst_rx_last        (tcp_format_payload_rx_data_last        )
        ,.tcp_format_dst_rx_padbytes    (tcp_format_payload_rx_data_padbytes    )
    );

    logic [`TOT_LEN_W-1:0]  tcp_payload_len;
    
    assign tcp_payload_len = tcp_format_payload_rx_tcp_tot_len - 
                            (tcp_format_payload_rx_tcp_hdr.raw_data_offset << 2);

    assign parser_tcp_rx_payload_addr = parser_tcp_rx_payload_entry.pkt_payload_addr;
    assign parser_tcp_rx_payload_len = parser_tcp_rx_payload_entry.pkt_payload_len;
    tcp_tmp_rx_buf_wrap rx_tmp_buf_store (
         .clk   (clk)
        ,.rst   (rst)
        
        // Write req inputs
        ,.src_tmp_buf_rx_hdr_val            (tcp_format_payload_rx_hdr_val              )
        ,.tmp_buf_src_rx_hdr_rdy            (payload_tcp_format_rx_hdr_rdy              )
        ,.src_tmp_buf_rx_src_ip             (tcp_format_payload_rx_src_ip               )
        ,.src_tmp_buf_rx_dst_ip             (tcp_format_payload_rx_dst_ip               )
        ,.src_tmp_buf_rx_tcp_payload_len    (tcp_payload_len                            )
        ,.src_tmp_buf_rx_tcp_hdr            (tcp_format_payload_rx_tcp_hdr              )

        ,.src_tmp_buf_rx_data_val           (tcp_format_payload_rx_data_val             )
        ,.src_tmp_buf_rx_data               (tcp_format_payload_rx_data                 )
        ,.src_tmp_buf_rx_data_last          (tcp_format_payload_rx_data_last            )
        ,.src_tmp_buf_rx_data_padbytes      (tcp_format_payload_rx_data_padbytes        )
        ,.tmp_buf_src_rx_data_rdy           (payload_tcp_format_rx_data_rdy             )
        
        // Write resp
        ,.tmp_buf_dst_rx_hdr_val            (parser_tcp_rx_hdr_val                      )
        ,.dst_tmp_buf_rx_rdy                (tcp_parser_rx_rdy                          )
        ,.tmp_buf_dst_rx_src_ip             (parser_tcp_rx_src_ip                       )
        ,.tmp_buf_dst_rx_dst_ip             (parser_tcp_rx_dst_ip                       )
        ,.tmp_buf_dst_rx_tcp_hdr            (parser_tcp_rx_tcp_hdr                      )

        ,.tmp_buf_dst_rx_payload_val        (parser_tcp_rx_payload_val                  )
        ,.tmp_buf_dst_rx_payload_entry      (parser_tcp_rx_payload_entry                )

        ,.src_tmp_buf_store_rd_req_val      (store_buf_tmp_buf_store_rx_rd_req_val      )
        ,.src_tmp_buf_store_rd_req_addr     (store_buf_tmp_buf_store_rx_rd_req_addr     )
        ,.tmp_buf_store_src_rd_req_rdy      (tmp_buf_store_store_buf_rx_rd_req_rdy      )
                                                                                        
        ,.tmp_buf_store_src_rd_resp_val     (tmp_buf_store_store_buf_rx_rd_resp_val     )
        ,.tmp_buf_store_src_rd_resp_data    (tmp_buf_store_store_buf_rx_rd_resp_data    )
        ,.src_tmp_buf_store_rd_resp_rdy     (store_buf_tmp_buf_store_rx_rd_resp_rdy     )
                                                                                        
        ,.src_tmp_buf_free_slab_req_val     (store_buf_tmp_buf_free_slab_rx_req_val     )
        ,.src_tmp_buf_free_slab_req_addr    (store_buf_tmp_buf_free_slab_rx_req_addr    )
        ,.tmp_buf_free_slab_src_req_rdy     (tmp_buf_free_slab_store_buf_rx_req_rdy     )
    );

    frontend_tx_payload_engine #(
         .SRC_X     (0)
        ,.SRC_Y     (0)
        ,.TX_DRAM_X (1)
        ,.TX_DRAM_Y (0)
    ) tx_payload_engine (
         .clk(clk)
        ,.rst(rst)
    
        // I/O for the NoC
        ,.tx_payload_noc0_val           (tx_parser_noc0_val             )
        ,.tx_payload_noc0_data          (tx_parser_noc0_data            )
        ,.noc0_tx_payload_rdy           (noc0_tx_parser_rdy             )

        ,.noc0_tx_payload_val           (noc0_tx_parser_val             )
        ,.noc0_tx_payload_data          (noc0_tx_parser_data            )
        ,.tx_payload_noc0_rdy           (tx_parser_noc0_rdy             )
        
        // Read req
        ,.src_payload_tx_val            (tcp_parser_tx_val              )
        ,.payload_src_tx_rdy            (parser_tcp_tx_rdy              )
        ,.src_payload_tx_flowid         (tcp_parser_tx_flowid           )
        ,.src_payload_tx_src_ip         (tcp_parser_tx_src_ip           )
        ,.src_payload_tx_dst_ip         (tcp_parser_tx_dst_ip           )
        ,.src_payload_tx_tcp_hdr        (tcp_parser_tx_tcp_hdr          )
        ,.src_payload_tx_payload_entry  (tcp_parser_tx_payload_entry    )
 
        // Read resp
        ,.payload_dst_tx_hdr_val        (payload_chksum_tx_hdr_val      )
        ,.dst_payload_tx_hdr_rdy        (chksum_payload_tx_hdr_rdy      )
        ,.payload_dst_tx_src_ip         (payload_chksum_tx_src_ip       )
        ,.payload_dst_tx_dst_ip         (payload_chksum_tx_dst_ip       )
        ,.payload_dst_tx_payload_len    (payload_chksum_tx_payload_len  )
        ,.payload_dst_tx_tcp_hdr        (payload_chksum_tx_tcp_hdr      )
        
        ,.payload_dst_tx_data_val       (payload_chksum_tx_data_val     )
        ,.payload_dst_tx_data           (payload_chksum_tx_data         )
        ,.payload_dst_tx_data_last      (payload_chksum_tx_data_last    )
        ,.payload_dst_tx_data_padbytes  (payload_chksum_tx_data_padbytes)
        ,.dst_payload_tx_data_rdy       (chksum_payload_tx_data_rdy     )
        
    );
    
    frontend_tx_chksum_engine tx_chksum_engine (
         .clk   (clk    )
        ,.rst   (rst    )
    
        // I/O from the payload engine
        ,.src_chksum_tx_hdr_val         (payload_chksum_tx_hdr_val              )
        ,.chksum_src_tx_hdr_rdy         (chksum_payload_tx_hdr_rdy              )
        ,.src_chksum_tx_src_ip          (payload_chksum_tx_src_ip               )
        ,.src_chksum_tx_dst_ip          (payload_chksum_tx_dst_ip               )
        ,.src_chksum_tx_payload_len     (payload_chksum_tx_payload_len          )
        ,.src_chksum_tx_tcp_hdr         (payload_chksum_tx_tcp_hdr              )

        ,.src_chksum_tx_data_val        (payload_chksum_tx_data_val             )
        ,.src_chksum_tx_data            (payload_chksum_tx_data                 )
        ,.src_chksum_tx_data_last       (payload_chksum_tx_data_last            )
        ,.src_chksum_tx_data_padbytes   (payload_chksum_tx_data_padbytes        )
        ,.chksum_src_tx_data_rdy        (chksum_payload_tx_data_rdy             )
    
        // I/O to the MAC side
        ,.chksum_dst_tx_hdr_val         (chksum_tcp_to_ipstream_tx_hdr_val      )
        ,.dst_chksum_tx_hdr_rdy         (tcp_to_ipstream_chksum_tx_hdr_rdy      )
        ,.chksum_dst_tx_src_ip          (chksum_tcp_to_ipstream_tx_src_ip       )
        ,.chksum_dst_tx_dst_ip          (chksum_tcp_to_ipstream_tx_dst_ip       )
        ,.chksum_dst_tx_tcp_len         (chksum_tcp_to_ipstream_tx_tcp_len      )
        ,.chksum_dst_tx_tcp_hdr         (chksum_tcp_to_ipstream_tx_tcp_hdr      )
    
        ,.chksum_dst_tx_data_val        (chksum_tcp_to_ipstream_tx_data_val     )
        ,.dst_chksum_tx_data_rdy        (tcp_to_ipstream_chksum_tx_data_rdy     )
        ,.chksum_dst_tx_data            (chksum_tcp_to_ipstream_tx_data         )
        ,.chksum_dst_tx_data_last       (chksum_tcp_to_ipstream_tx_data_last    )
        ,.chksum_dst_tx_data_padbytes   (chksum_tcp_to_ipstream_tx_data_padbytes)
    );

    tcp_to_ipstream tx_tcp_to_ipstream (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.src_tcp_to_ipstream_hdr_val       (chksum_tcp_to_ipstream_tx_hdr_val                  )
        ,.src_tcp_to_ipstream_src_ip_addr   (chksum_tcp_to_ipstream_tx_src_ip                   )
        ,.src_tcp_to_ipstream_dst_ip_addr   (chksum_tcp_to_ipstream_tx_dst_ip                   )
        ,.src_tcp_to_ipstream_tcp_len       (chksum_tcp_to_ipstream_tx_tcp_len                  )
        ,.src_tcp_to_ipstream_tcp_hdr       (chksum_tcp_to_ipstream_tx_tcp_hdr                  )
        ,.tcp_to_ipstream_src_hdr_rdy       (tcp_to_ipstream_chksum_tx_hdr_rdy                  )
        
        ,.src_tcp_to_ipstream_data_val      (chksum_tcp_to_ipstream_tx_data_val                 )
        ,.tcp_to_ipstream_src_data_rdy      (tcp_to_ipstream_chksum_tx_data_rdy                 )
        ,.src_tcp_to_ipstream_data          (chksum_tcp_to_ipstream_tx_data                     )
        ,.src_tcp_to_ipstream_data_last     (chksum_tcp_to_ipstream_tx_data_last                )
        ,.src_tcp_to_ipstream_data_padbytes (chksum_tcp_to_ipstream_tx_data_padbytes            )

        ,.tcp_to_ipstream_dst_hdr_val       (tcp_to_ipstream_ip_to_ethstream_tx_hdr_val         )
        ,.tcp_to_ipstream_dst_ip_hdr        (tcp_to_ipstream_ip_to_ethstream_tx_ip_hdr          )
        ,.dst_tcp_to_ipstream_hdr_rdy       (ip_to_ethstream_tcp_to_ipstream_tx_hdr_rdy         )
        
        // Stream output
        ,.tcp_to_ipstream_dst_val           (tcp_to_ipstream_ip_to_ethstream_tx_data_val        )
        ,.dst_tcp_to_ipstream_rdy           (ip_to_ethstream_tcp_to_ipstream_tx_data_rdy        )
        ,.tcp_to_ipstream_dst_data          (tcp_to_ipstream_ip_to_ethstream_tx_data            )
        ,.tcp_to_ipstream_dst_last          (tcp_to_ipstream_ip_to_ethstream_tx_data_last       )
        ,.tcp_to_ipstream_dst_padbytes      (tcp_to_ipstream_ip_to_ethstream_tx_data_padbytes   )
    );

    ip_to_ethstream tx_ip_to_ethstream (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_ip_to_ethstream_hdr_val       (tcp_to_ipstream_ip_to_ethstream_tx_hdr_val         )
        ,.src_ip_to_ethstream_ip_hdr        (tcp_to_ipstream_ip_to_ethstream_tx_ip_hdr          )
        ,.ip_to_ethstream_src_hdr_rdy       (ip_to_ethstream_tcp_to_ipstream_tx_hdr_rdy         )

        ,.src_ip_to_ethstream_data_val      (tcp_to_ipstream_ip_to_ethstream_tx_data_val        )
        ,.src_ip_to_ethstream_data          (tcp_to_ipstream_ip_to_ethstream_tx_data            )
        ,.src_ip_to_ethstream_data_last     (tcp_to_ipstream_ip_to_ethstream_tx_data_last       )
        ,.src_ip_to_ethstream_data_padbytes (tcp_to_ipstream_ip_to_ethstream_tx_data_padbytes   )
        ,.ip_to_ethstream_src_data_rdy      (ip_to_ethstream_tcp_to_ipstream_tx_data_rdy        )

        ,.ip_to_ethstream_dst_hdr_val       (ip_to_ethstream_eth_hdrtostream_tx_eth_hdr_val     )
        ,.ip_to_ethstream_dst_eth_hdr       (ip_to_ethstream_eth_hdrtostream_tx_eth_hdr         )
        ,.dst_ip_to_ethstream_hdr_rdy       (eth_hdrtostream_ip_to_ethsteram_tx_eth_hdr_rdy     )

        ,.ip_to_ethstream_dst_data_val      (ip_to_ethstream_eth_hdrtostream_tx_data_val        )
        ,.ip_to_ethstream_dst_data          (ip_to_ethstream_eth_hdrtostream_tx_data            )
        ,.ip_to_ethstream_dst_data_last     (ip_to_ethstream_eth_hdrtostream_tx_data_last       )
        ,.ip_to_ethstream_dst_data_padbytes (ip_to_ethstream_eth_hdrtostream_tx_data_padbytes   )
        ,.dst_ip_to_ethstream_data_rdy      (eth_hdrtostream_ip_to_ethstream_tx_data_rdy        )
    );

    eth_hdrtostream tx_eth_hdrtostream (
         .clk   (clk)
        ,.rst   (rst)

        ,.src_eth_hdrtostream_eth_hdr_val   (ip_to_ethstream_eth_hdrtostream_tx_eth_hdr_val     )
        ,.src_eth_hdrtostream_eth_hdr       (ip_to_ethstream_eth_hdrtostream_tx_eth_hdr         )
        ,.eth_hdrtostream_src_eth_hdr_rdy   (eth_hdrtostream_ip_to_ethsteram_tx_eth_hdr_rdy     )

        ,.src_eth_hdrtostream_data_val      (ip_to_ethstream_eth_hdrtostream_tx_data_val        )
        ,.src_eth_hdrtostream_data          (ip_to_ethstream_eth_hdrtostream_tx_data            )
        ,.src_eth_hdrtostream_data_last     (ip_to_ethstream_eth_hdrtostream_tx_data_last       )
        ,.src_eth_hdrtostream_data_padbytes (ip_to_ethstream_eth_hdrtostream_tx_data_padbytes   )
        ,.eth_hdrtostream_src_data_rdy      (eth_hdrtostream_ip_to_ethstream_tx_data_rdy        )

        ,.eth_hdrtostream_dst_data_val      (engine_mac_tx_val      )
        ,.eth_hdrtostream_dst_data          (engine_mac_tx_data     )
        ,.eth_hdrtostream_dst_data_last     (engine_mac_tx_last     )
        ,.eth_hdrtostream_dst_data_padbytes (engine_mac_tx_padbytes )
        ,.dst_eth_hdrtostream_data_rdy      (mac_engine_tx_rdy      )
    );

endmodule
