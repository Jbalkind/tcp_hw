// A synchronous read ram that won't let you read if there is a read address collision
// You can also backpressure the output though
module tb_ram_1r1w_sync_no_collision #(
	 parameter DATA_W = 32
	,parameter DEPTH = 8
	,parameter ADDR_W = $clog2(DEPTH)
)(
     input clk
    ,input rst
    
    ,input                          wr_en_a
    ,input          [ADDR_W-1:0]    wr_addr_a
    ,input          [DATA_W-1:0]    wr_data_a
    ,output logic                   wr_rdy_a

    ,input                          rd_req_en_a
    ,input          [ADDR_W-1:0]    rd_req_addr_a
    ,output logic                   rd_req_rdy_a
    
    ,output logic                   rd_resp_val_a
    ,output logic   [DATA_W-1:0]    rd_resp_data_a
    ,input                          rd_resp_rdy_a
);
    ram_1r1w_sync_no_collision #(
    	 .DATA_W    (DATA_W )
    	,.DEPTH     (DEPTH  )
    ) DUT (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.wr_en_a           (wr_en_a        )
        ,.wr_addr_a         (wr_addr_a      )
        ,.wr_data_a         (wr_data_a      )
        ,.wr_rdy_a          (wr_rdy_a       )
                                            
        ,.rd_req_en_a       (rd_req_en_a    )
        ,.rd_req_addr_a     (rd_req_addr_a  )
        ,.rd_req_rdy_a      (rd_req_rdy_a   )
                                            
        ,.rd_resp_val_a     (rd_resp_val_a  )
        ,.rd_resp_data_a    (rd_resp_data_a )
        ,.rd_resp_rdy_a     (rd_resp_rdy_a  )
    );
endmodule
