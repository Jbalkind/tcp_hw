`include "soc_defs.vh"
module ip_stream_format_pipe_wrap 
import packet_struct_pkg::*;
#(
    parameter DATA_WIDTH = -1
)(
     input clk
    ,input rst
    
    // Data stream in from MAC
    ,input                                  src_ip_format_rx_val
    ,input          [`PKT_TIMESTAMP_W-1:0]  src_ip_format_rx_timestamp
    ,output logic                           ip_format_src_rx_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  src_ip_format_rx_data
    ,input                                  src_ip_format_rx_last
    ,input          [`MAC_PADBYTES_W-1:0]   src_ip_format_rx_padbytes

    // Header and data out
    ,output logic                           ip_format_dst_rx_hdr_val
    ,input                                  dst_ip_format_rx_hdr_rdy
    ,output logic   [IP_HDR_W-1:0]          ip_format_dst_rx_ip_hdr
    ,output logic   [`PKT_TIMESTAMP_W-1:0]  ip_format_dst_rx_timestamp

    ,output logic                           ip_format_dst_rx_data_val
    ,input                                  dst_ip_format_rx_data_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  ip_format_dst_rx_data
    ,output logic                           ip_format_dst_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   ip_format_dst_rx_padbytes
);
    
    logic   [DATA_WIDTH-1:0]    unmasked_data;
   
    data_masker #(
         .width_p   (DATA_WIDTH )
    ) masker (  
         .unmasked_data (unmasked_data              )
        ,.padbytes      (ip_format_dst_rx_padbytes  )
        ,.last          (ip_format_dst_rx_last      )
    
        ,.masked_data   (ip_format_dst_rx_data      )
    );

    ip_stream_format_pipe #(
        .DATA_WIDTH(DATA_WIDTH  )        
    ) DUT (
         .clk   (clk   )
        ,.rst   (rst   )

        ,.src_ip_format_rx_val          (src_ip_format_rx_val       )
        ,.src_ip_format_rx_timestamp    (src_ip_format_rx_timestamp )
        ,.ip_format_src_rx_rdy          (ip_format_src_rx_rdy       )
        ,.src_ip_format_rx_data         (src_ip_format_rx_data      )
        ,.src_ip_format_rx_last         (src_ip_format_rx_last      )
        ,.src_ip_format_rx_padbytes     (src_ip_format_rx_padbytes  )
                                                                    
        ,.ip_format_dst_rx_hdr_val      (ip_format_dst_rx_hdr_val   )
        ,.dst_ip_format_rx_hdr_rdy      (dst_ip_format_rx_hdr_rdy   )
        ,.ip_format_dst_rx_ip_hdr       (ip_format_dst_rx_ip_hdr    )
        ,.ip_format_dst_rx_timestamp    (ip_format_dst_rx_timestamp )
                                                                    
        ,.ip_format_dst_rx_data_val     (ip_format_dst_rx_data_val  )
        ,.dst_ip_format_rx_data_rdy     (dst_ip_format_rx_data_rdy  )
        ,.ip_format_dst_rx_data         (unmasked_data              )
        ,.ip_format_dst_rx_last         (ip_format_dst_rx_last      )
        ,.ip_format_dst_rx_padbytes     (ip_format_dst_rx_padbytes  )
    );
endmodule
