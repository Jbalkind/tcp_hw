module sched_req_fill
import tcp_pkg::*;
import tcp_misc_pkg::*;
(
     input  logic   [FLOWID_W-1:0]  flowid
    ,output sched_cmd_struct        filled_req
);
    assign filled_req = '0;
endmodule
