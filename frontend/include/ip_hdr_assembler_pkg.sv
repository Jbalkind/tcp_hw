package ip_hdr_assembler_pkg;
    `include "soc_defs.vh"

    typedef struct packed {
        logic   [`MAC_INTERFACE_W-1:0]  data;
        logic   [`MAC_PADBYTES_W-1:0]   padbytes;
        logic                           last;
    } fifo_struct;
    localparam FIFO_STRUCT_W = $bits(fifo_struct);
endpackage
