package noc_struct_pkg;
`include "noc_defs.vh"

    import tcp_pkg::*;

    typedef struct packed {
        logic   [`MSG_DST_CHIPID_WIDTH-1:0] dst_chip_id;
        logic   [`MSG_DST_X_WIDTH-1:0]      dst_x_coord;
        logic   [`MSG_DST_Y_WIDTH-1:0]      dst_y_coord;
        logic   [`MSG_DST_FBITS_WIDTH-1:0]  fbits;
        logic   [`MSG_LENGTH_WIDTH-1:0]     msg_len;
        logic   [`MSG_TYPE_WIDTH-1:0]       msg_type;
    } noc_header_flit_1;

    typedef struct packed {
        logic   [`MSG_ADDR_WIDTH-1:0]       addr;
        logic   [`MSG_OPTIONS_2_WIDTH-1:0]  rsvd;
    } noc_header_flit_2;

    typedef struct packed {
        logic   [`MSG_SRC_CHIPID_WIDTH-1:0] src_chip_id;
        logic   [`MSG_SRC_X_WIDTH-1:0]      src_x_coord;
        logic   [`MSG_SRC_Y_WIDTH-1:0]      src_y_coord;
        logic   [`MSG_SRC_FBITS_WIDTH-1:0]  src_fbits;
        logic   [`MSG_DATA_SIZE_WIDTH-1:0]  data_size;
    } noc_header_flit_3;

    localparam HDR_PADDING_W = 80;
    typedef struct packed {
        logic   [`MSG_DST_CHIPID_WIDTH-1:0] dst_chip_id;
        logic   [`MSG_DST_X_WIDTH-1:0]      dst_x_coord;
        logic   [`MSG_DST_Y_WIDTH-1:0]      dst_y_coord;
        logic   [`MSG_DST_FBITS_WIDTH-1:0]  fbits;
        logic   [`MSG_LENGTH_WIDTH-1:0]     msg_len;
        logic   [`MSG_TYPE_WIDTH-1:0]       msg_type;
        logic   [`MSG_ADDR_WIDTH-1:0]       addr;
        logic   [`MSG_SRC_CHIPID_WIDTH-1:0] src_chip_id;
        logic   [`MSG_SRC_X_WIDTH-1:0]      src_x_coord;
        logic   [`MSG_SRC_Y_WIDTH-1:0]      src_y_coord;
        logic   [`MSG_SRC_FBITS_WIDTH-1:0]  src_fbits;
        logic   [`MSG_DATA_SIZE_WIDTH-1:0]  data_size;
        logic   [HDR_PADDING_W-1:0]        padding;
    } noc_hdr_flit;

endpackage
