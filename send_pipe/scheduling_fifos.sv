module scheduling_fifos 
import tcp_pkg::*;
(
     input clk
    ,input rst

    ,input                  app_send_tx_wr_req
    ,input  [FLOWID_W-1:0]  app_send_tx_wr_flowid
    ,output                 send_app_tx_wr_full

    ,input                  main_pipe_wr_req
    ,input  [FLOWID_W-1:0]  main_pipe_wr_flowid
    ,output                 main_pipe_wr_full

    ,output [FLOWID_W-1:0]  main_pipe_flowid
    ,input                  main_pipe_rd_req
    ,output                 main_pipe_rd_empty
);

    logic main_pipe_fifo_full;
    logic main_pipe_fifo_data_avail;

    assign send_app_tx_wr_full = main_pipe_fifo_full;
    assign main_pipe_rd_empty = ~main_pipe_fifo_data_avail;
    assign main_pipe_wr_full = main_pipe_fifo_full;

    fifo_2w #(
         .FIFO_WIDTH    (FLOWID_W       )
        ,.FIFO_DEPTH    (MAX_FLOW_CNT   )
    ) main_pipe_fifo (
         .clk   (clk)
        ,.rst_n (~rst)
    
        ,.w_val_0       (app_send_tx_wr_req         )
        ,.w_data_0      (app_send_tx_wr_flowid      )

        ,.w_val_1       (main_pipe_wr_req           )
        ,.w_data_1      (main_pipe_wr_flowid        )

        ,.r_val         (main_pipe_rd_req           )
        ,.r_data        (main_pipe_flowid           )
   
        ,.size          ()
        ,.full          (main_pipe_fifo_full        )
        ,.data_avail    (main_pipe_fifo_data_avail  )
    );
    

endmodule
