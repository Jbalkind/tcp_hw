`include "packet_defs.vh"
`include "soc_defs.vh"
module ip_hdr_assembler_pipe_wrap 
import packet_struct_pkg::*;
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
    ,input  [`PKT_TIMESTAMP_W-1:0]          src_assembler_timestamp
    ,output logic                           assembler_src_req_rdy 

    ,input  logic                           src_assembler_data_val
    ,input  logic   [`MAC_INTERFACE_W-1:0]  src_assembler_data
    ,input  logic                           src_assembler_data_last
    ,input  logic   [`MAC_PADBYTES_W-1:0]   src_assembler_data_padbytes
    ,output logic                           assembler_src_data_rdy

    ,output logic                           assembler_dst_hdr_val
    ,output logic   [`PKT_TIMESTAMP_W-1:0]  assembler_dst_timestamp
    ,output logic   [IP_HDR_W-1:0]          assembler_dst_ip_hdr
    ,input                                  dst_assembler_hdr_rdy

    ,output logic                           assembler_dst_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]  assembler_dst_data
    ,output logic   [`MAC_PADBYTES_W-1:0]   assembler_dst_data_padbytes
    ,output logic                           assembler_dst_data_last
    ,input  logic                           dst_assembler_data_rdy
);

    ip_hdr_assembler_pipe #(
         .DATA_W    (DATA_W )
    ) DUT (
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
                                                                            
        ,.assembler_dst_hdr_val             (assembler_dst_hdr_val          )
        ,.assembler_dst_timestamp           (assembler_dst_timestamp        )
        ,.assembler_dst_ip_hdr              (assembler_dst_ip_hdr           )
        ,.dst_assembler_hdr_rdy             (dst_assembler_hdr_rdy          )
                                                                            
        ,.assembler_dst_data_val            (assembler_dst_data_val         )
        ,.assembler_dst_data                (assembler_dst_data             )
        ,.assembler_dst_data_padbytes       (assembler_dst_data_padbytes    )
        ,.assembler_dst_data_last           (assembler_dst_data_last        )
        ,.dst_assembler_data_rdy            (dst_assembler_data_rdy         )
);
endmodule
