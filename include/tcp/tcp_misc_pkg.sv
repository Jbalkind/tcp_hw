package tcp_misc_pkg;
    typedef struct packed {
        logic   dummy;
    } sched_cmd_struct;
    localparam SCHED_CMD_STRUCT_W = $bits(sched_cmd_struct);
endpackage
