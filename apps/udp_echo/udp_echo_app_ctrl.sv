module udp_echo_app_ctrl (
     input clk
    ,input rst
    
    ,input  logic                           src_udp_echo_app_rx_hdr_val
    ,output logic                           udp_echo_app_src_rx_hdr_rdy

    ,input  logic                           src_udp_echo_app_rx_data_val
    ,input  logic                           src_udp_echo_app_rx_last
    ,output logic                           udp_echo_app_src_rx_data_rdy
    
    ,input                                  udp_echo_app_dst_hdr_val
    ,output logic                           dst_udp_echo_app_hdr_rdy
    
    ,input                                  udp_echo_app_dst_data_val
    ,input                                  udp_echo_app_dst_data_last
    ,output logic                           dst_udp_echo_app_data_rdy

    ,output logic                           ctrl_datap_save_inputs
);

endmodule
