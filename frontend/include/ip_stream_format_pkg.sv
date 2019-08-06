package ip_stream_format_pkg;
    `include "soc_defs.vh"
    import tracker_pkg::*;

    typedef struct packed {
        logic   [`MAC_INTERFACE_W-1:0]  data;
        logic   [`MAC_PADBYTES_W-1:0]   padbytes;
        logic                           last;
        tracker_stats_struct            timestamp;
    } fifo_struct;
    localparam FIFO_STRUCT_W = $bits(fifo_struct);
endpackage
