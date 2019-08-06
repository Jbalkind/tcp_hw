`include "packet_defs.vh"
`include "noc_defs.vh"
`include "soc_defs.vh"

module frontend_tx_payload_engine 
import packet_struct_pkg::*;
import tcp_pkg::*;
#( 
     parameter SRC_X = 0
    ,parameter SRC_Y = 0
    ,parameter TX_DRAM_X = 0
    ,parameter TX_DRAM_Y = 0
    ,parameter FBITS = 0
) (
     input clk
    ,input rst

    // I/O for the NoC
    ,output logic                                   tx_payload_noc0_val
    ,output logic   [`NOC_DATA_WIDTH-1:0]           tx_payload_noc0_data
    ,input                                          noc0_tx_payload_rdy
   
    ,input                                          noc0_tx_payload_val
    ,input          [`NOC_DATA_WIDTH-1:0]           noc0_tx_payload_data
    ,output logic                                   tx_payload_noc0_rdy
    
    // Read req
    ,input                                          src_payload_tx_val
    ,output logic                                   payload_src_tx_rdy
    ,input          [FLOWID_W-1:0]                  src_payload_tx_flowid
    ,input          [`IP_ADDR_W-1:0]                src_payload_tx_src_ip
    ,input          [`IP_ADDR_W-1:0]                src_payload_tx_dst_ip
    ,input  tcp_pkt_hdr                             src_payload_tx_tcp_hdr
    ,input  payload_buf_struct                      src_payload_tx_payload_entry
 
    // Read resp
    ,output logic                                   payload_dst_tx_hdr_val
    ,input                                          dst_payload_tx_hdr_rdy
    ,output logic   [`IP_ADDR_W-1:0]                payload_dst_tx_src_ip
    ,output logic   [`IP_ADDR_W-1:0]                payload_dst_tx_dst_ip
    ,output logic   [`TOT_LEN_W-1:0]                payload_dst_tx_payload_len
    ,output tcp_pkt_hdr                             payload_dst_tx_tcp_hdr
    
    ,output logic                                   payload_dst_tx_data_val
    ,output logic   [`MAC_INTERFACE_W-1:0]          payload_dst_tx_data
    ,output logic                                   payload_dst_tx_data_last
    ,output logic   [`MAC_PADBYTES_W-1:0]           payload_dst_tx_data_padbytes
    ,input                                          dst_payload_tx_data_rdy
);

    typedef enum logic [2:0] {
        READY = 3'd0,
        WAIT_RD_RESP = 3'd1,
        DATA_OUTPUT = 3'd2,
        PAYLOAD_WAIT_TX_FIN = 3'd3,
        UND = 'X
    } states_e;

    typedef enum logic [1:0] {
        WAITING = 2'd0,
        TCP_HDR_OUTPUT = 2'd1,
        HDR_WAIT_TX_FIN = 2'd2,
        UNDEF = 'X
    } hdr_state_e;

    states_e state_reg;
    states_e state_next;

    hdr_state_e hdr_state_reg;
    hdr_state_e hdr_state_next;
    
    
    logic   [`IP_ADDR_W-1:0]        src_payload_tx_src_ip_reg;
    logic   [`IP_ADDR_W-1:0]        src_payload_tx_src_ip_next;
    logic   [`IP_ADDR_W-1:0]        src_payload_tx_dst_ip_reg;
    logic   [`IP_ADDR_W-1:0]        src_payload_tx_dst_ip_next;

    tcp_pkt_hdr                     src_payload_tx_tcp_hdr_reg;
    tcp_pkt_hdr                     src_payload_tx_tcp_hdr_next;

    payload_buf_struct              src_payload_tx_payload_entry_reg;
    payload_buf_struct              src_payload_tx_payload_entry_next;
    payload_buf_struct              src_payload_tx_payload_entry_cast;
    
    logic                                   ctrl_rd_mem_tx_req_val;
    logic   [FLOWID_W-1:0]                  ctrl_rd_mem_tx_req_flowid;
    logic   [TX_PAYLOAD_PTR_W-1:0]          ctrl_rd_mem_tx_req_offset;
    logic   [`MSG_DATA_SIZE_WIDTH-1:0]      ctrl_rd_mem_tx_req_size;
    logic                                   rd_mem_ctrl_tx_req_rdy;

    assign src_payload_tx_payload_entry_cast = src_payload_tx_payload_entry;

    assign payload_dst_tx_src_ip = src_payload_tx_src_ip_reg;
    assign payload_dst_tx_dst_ip = src_payload_tx_dst_ip_reg;
    assign payload_dst_tx_payload_len = src_payload_tx_payload_entry_reg.payload_len;
    assign payload_dst_tx_tcp_hdr = src_payload_tx_tcp_hdr_reg;

    
    rd_circ_buf_new #(
         .BUF_PTR_W     (TX_PAYLOAD_PTR_W   )
        ,.SRC_X         (SRC_X              )
        ,.SRC_Y         (SRC_Y              )
        ,.DST_DRAM_X    (TX_DRAM_X          )
        ,.DST_DRAM_Y    (TX_DRAM_Y          )
        ,.FBITS         (FBITS              )
    ) rd_buf_engine (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.rd_buf_noc0_val           (tx_payload_noc0_val            )
        ,.rd_buf_noc0_data          (tx_payload_noc0_data           )
        ,.noc0_rd_buf_rdy           (noc0_tx_payload_rdy            )
                                                                    
        ,.noc0_rd_buf_val           (noc0_tx_payload_val            )
        ,.noc0_rd_buf_data          (noc0_tx_payload_data           )
        ,.rd_buf_noc0_rdy           (tx_payload_noc0_rdy            )
                                                                        
        ,.src_rd_buf_req_val        (ctrl_rd_mem_tx_req_val         )
        ,.src_rd_buf_req_flowid     (ctrl_rd_mem_tx_req_flowid      )
        ,.src_rd_buf_req_offset     (ctrl_rd_mem_tx_req_offset      )
        ,.src_rd_buf_req_size       (ctrl_rd_mem_tx_req_size        )
        ,.rd_buf_src_req_rdy        (rd_mem_ctrl_tx_req_rdy         )
                                                                    
        ,.rd_buf_src_data_val       (payload_dst_tx_data_val        )
        ,.rd_buf_src_data           (payload_dst_tx_data            )
        ,.rd_buf_src_data_last      (payload_dst_tx_data_last       )
        ,.rd_buf_src_data_padbytes  (payload_dst_tx_data_padbytes   )
        ,.src_rd_buf_data_rdy       (dst_payload_tx_data_rdy        )
    );



    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            hdr_state_reg <= WAITING;

            src_payload_tx_src_ip_reg <= '0;
            src_payload_tx_dst_ip_reg <= '0;
            src_payload_tx_tcp_hdr_reg <= '0;
            src_payload_tx_payload_entry_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            hdr_state_reg <= hdr_state_next;
            
            src_payload_tx_src_ip_reg <= src_payload_tx_src_ip_next;
            src_payload_tx_dst_ip_reg <= src_payload_tx_dst_ip_next;
            src_payload_tx_tcp_hdr_reg <= src_payload_tx_tcp_hdr_next;
            src_payload_tx_payload_entry_reg <= src_payload_tx_payload_entry_next;
        end
    end

    assign ctrl_rd_mem_tx_req_flowid = src_payload_tx_flowid;
    assign ctrl_rd_mem_tx_req_offset = src_payload_tx_payload_entry_cast.payload_addr;
    assign ctrl_rd_mem_tx_req_size = src_payload_tx_payload_entry_cast.payload_len;

    always_comb begin
        state_next = state_reg;

        src_payload_tx_src_ip_next = src_payload_tx_src_ip_reg;
        src_payload_tx_dst_ip_next = src_payload_tx_dst_ip_reg;
        src_payload_tx_tcp_hdr_next = src_payload_tx_tcp_hdr_reg;
        src_payload_tx_payload_entry_next = src_payload_tx_payload_entry_reg;

        payload_src_tx_rdy = 1'b0;
        ctrl_rd_mem_tx_req_val = 1'b0;
        case (state_reg)
            READY: begin
                payload_src_tx_rdy = rd_mem_ctrl_tx_req_rdy;
                if (src_payload_tx_val) begin
                    src_payload_tx_src_ip_next = src_payload_tx_src_ip;
                    src_payload_tx_dst_ip_next = src_payload_tx_dst_ip;
                    src_payload_tx_tcp_hdr_next = src_payload_tx_tcp_hdr;
                    src_payload_tx_payload_entry_next = src_payload_tx_payload_entry;

                    if ((src_payload_tx_payload_entry_cast.payload_len != 0) &&
                        rd_mem_ctrl_tx_req_rdy) begin
                        ctrl_rd_mem_tx_req_val = 1'b1;
                        state_next = DATA_OUTPUT;
                    end
                    else begin
                        state_next = PAYLOAD_WAIT_TX_FIN;
                    end
                end
                else begin
                    state_next = READY;
                end
            end
            DATA_OUTPUT: begin
                if (payload_dst_tx_data_val 
                    & dst_payload_tx_data_rdy & payload_dst_tx_data_last) begin
                    state_next = PAYLOAD_WAIT_TX_FIN;
                end
                else begin
                    state_next = DATA_OUTPUT;
                end
            end
            PAYLOAD_WAIT_TX_FIN: begin
                if (hdr_state_reg == HDR_WAIT_TX_FIN) begin
                    state_next = READY;
                end
                else begin
                    state_next = PAYLOAD_WAIT_TX_FIN;
                end
            end
            default: begin
                state_next = UND;

                src_payload_tx_src_ip_next = 'X;
                src_payload_tx_dst_ip_next = 'X;
                src_payload_tx_tcp_hdr_next = 'X;
                src_payload_tx_payload_entry_next = 'X;
            end
        endcase
    end

    always_comb begin
        hdr_state_next = hdr_state_reg;
        payload_dst_tx_hdr_val = 1'b0;

        case (hdr_state_reg)
            WAITING: begin
                if ((state_reg == READY) & (state_next != READY)) begin
                    hdr_state_next = TCP_HDR_OUTPUT;
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            TCP_HDR_OUTPUT: begin
                payload_dst_tx_hdr_val = 1'b1;
                if (dst_payload_tx_hdr_rdy) begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
                else begin
                    hdr_state_next = TCP_HDR_OUTPUT;
                end

            end
            HDR_WAIT_TX_FIN: begin
                if (state_reg == PAYLOAD_WAIT_TX_FIN) begin
                    hdr_state_next = WAITING;
                end
                else begin
                    hdr_state_next = HDR_WAIT_TX_FIN;
                end
            end
            default: begin
                payload_dst_tx_hdr_val = 1'bX;
                hdr_state_next = UNDEF;
            end
        endcase
    end

endmodule
