`include "packet_defs.vh"
`include "bsg_defines.v"
module flowid_to_addr
import tcp_pkg::*;
import packet_struct_pkg::*;
(
     input clk
    ,input rst

    // Write control
    ,input                      wr_req_val
    ,input [FLOWID_W-1:0]       wr_req_flowid
    ,output                     wr_req_rdy

    // Write data
    ,input four_tuple_struct    wr_req_flow_entry

    // Read control
    ,input                      rd_req_val
    ,input  [FLOWID_W-1:0]      rd_req_flowid
    ,output                     rd_req_rdy

    // Read data
    ,output                     rd_resp_val
    ,output four_tuple_struct   rd_resp_flow_entry
    ,input                      rd_resp_rdy
);


    ram_1r1w_sync_backpressure #(
         .width_p   (FOUR_TUPLE_STRUCT_W    )
        ,.els_p     (MAX_FLOW_CNT           )
    ) flowid_to_addr_mem (
         .clk(clk)
        ,.rst(rst)

        ,.wr_req_val    (wr_req_val         )
        ,.wr_req_addr   (wr_req_flowid      )
        ,.wr_req_data   (wr_req_flow_entry  )
        ,.wr_req_rdy    (wr_req_rdy         )

        ,.rd_req_val    (rd_req_val         )
        ,.rd_req_addr   (rd_req_flowid      )
        ,.rd_req_rdy    (rd_req_rdy         )

        ,.rd_resp_val   (rd_resp_val        )
        ,.rd_resp_data  (rd_resp_flow_entry )
        ,.rd_resp_rdy   (rd_resp_rdy        )
    );

endmodule
