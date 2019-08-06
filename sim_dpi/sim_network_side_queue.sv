`include "packet_defs.vh"
`include "state_defs.vh"
`include "soc_defs.vh"
module sim_network_side_queue (
     input clk
    ,input rst

    // RX testing interface
    ,output logic                           mac_engine_rx_val
    ,input                                  engine_mac_rx_rdy
    ,output logic   [`MAC_INTERFACE_W-1:0]  mac_engine_rx_data
    ,output logic                           mac_engine_rx_last
    ,output logic   [`MAC_PADBYTES_W-1:0]   mac_engine_rx_padbytes

    
    // TX testing interface
    ,input                                  engine_mac_tx_val
    ,output logic                           mac_engine_tx_rdy
    ,input          [`MAC_INTERFACE_W-1:0]  engine_mac_tx_data
    ,input                                  engine_mac_tx_last
    ,input          [`MAC_PADBYTES_W-1:0]   engine_mac_tx_padbytes
);

/*******************************************************************
 * Receive side
 ******************************************************************/
    typedef enum logic [1:0] {
        READY = 0,
        RX_PACKET = 1,
        UNDEFINED = 'X
    } recv_states_e;

    typedef struct packed {
        logic   [`MAC_INTERFACE_W-1:0]  data;
        logic                           last;
        logic   [`MAC_PADBYTES_W-1:0]   padbytes;
    } queue_entry;

    `define RECV_QUEUE_ENTRY_W (`MAC_INTERFACE_W + 1 + `MAC_PADBYTES_W)

    recv_states_e recv_state_reg;
    recv_states_e recv_state_next;

    logic                           rx_val_dpi;
    logic                           rx_val_dpi_reg;
    logic   [`MAC_INTERFACE_W-1:0]  rx_data_dpi;
    logic                           rx_last_dpi;
    logic   [`MAC_PADBYTES_W-1:0]   rx_padbytes_dpi;
    logic   [`MAC_INTERFACE_W-1:0]  rx_data_dpi_reg;
    logic                           rx_last_dpi_reg;
    logic   [`MAC_PADBYTES_W-1:0]   rx_padbytes_dpi_reg;

    logic                           rx_fifo_deq_val;
    queue_entry                     rx_fifo_deq_entry;
    logic                           rx_fifo_deq_rdy;

    logic                           rx_fifo_enq_rdy;

    logic                           tx_fifo_deq_val;
    queue_entry                     tx_fifo_deq_data;
    logic                           tx_fifo_deq_rdy;

    assign mac_engine_rx_val = rx_fifo_deq_val;
    assign mac_engine_rx_data = rx_fifo_deq_entry.data;
    assign mac_engine_rx_last = rx_fifo_deq_entry.last;
    assign mac_engine_rx_padbytes = rx_fifo_deq_entry.padbytes;
    assign rx_fifo_deq_rdy = engine_mac_rx_rdy;

    logic packet_start_val;

    import "DPI-C" context function void get_data();
    always_ff @(negedge clk) begin
        if (rx_fifo_enq_rdy & ~rst) begin
            get_data();
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_val_dpi_reg <= '0;
            rx_data_dpi_reg <= '0;
            rx_last_dpi_reg <= '0;
            rx_padbytes_dpi_reg <= '0;
        end
        else begin
            rx_val_dpi_reg <= rx_val_dpi;
            rx_data_dpi_reg <= rx_data_dpi;
            rx_last_dpi_reg <= rx_last_dpi;
            rx_padbytes_dpi_reg <= rx_padbytes_dpi;
        end
    end

    logic rx_fifo_rdy;
    export "DPI-C" function drive_rx_if;
    function void drive_rx_if(input bit val,
                              input bit[`MAC_INTERFACE_W-1:0] data, 
                              input bit last, input int padbytes);
        rx_val_dpi = val;
        rx_data_dpi = data;
        rx_last_dpi = last;
        rx_padbytes_dpi = padbytes;
    endfunction

    queue_entry rx_enq_entry;
    assign rx_enq_entry.data = rx_data_dpi_reg;
    assign rx_enq_entry.last = rx_last_dpi_reg;
    assign rx_enq_entry.padbytes = rx_padbytes_dpi_reg;

    bsg_fifo_1r1w_small #( 
         .width_p   (`RECV_QUEUE_ENTRY_W)
        ,.els_p     (32)
    ) rx_fifo (
         .clk_i     (clk)
        ,.reset_i   (rst)

        ,.v_i       (rx_val_dpi_reg     )
        ,.ready_o   (rx_fifo_enq_rdy    )
        ,.data_i    (rx_enq_entry       )

        ,.v_o       (rx_fifo_deq_val    )
        ,.data_o    (rx_fifo_deq_entry  )
        ,.yumi_i    (rx_fifo_deq_rdy & rx_fifo_deq_val  )
    );
    
    queue_entry tx_enq_entry;
    assign tx_enq_entry.data = engine_mac_tx_data;
    assign tx_enq_entry.last = engine_mac_tx_last;
    assign tx_enq_entry.padbytes = engine_mac_tx_padbytes;
    bsg_fifo_1r1w_small #(
         .width_p   (`RECV_QUEUE_ENTRY_W)
        ,.els_p     (32)
    ) tx_fifo (
         .clk_i     (clk)
        ,.reset_i   (rst)

        ,.v_i       (engine_mac_tx_val  )
        ,.ready_o   (mac_engine_tx_rdy  )
        ,.data_i    (tx_enq_entry       )

        ,.v_o       (tx_fifo_deq_val    )
        ,.data_o    (tx_fifo_deq_data   )
        ,.yumi_i    (tx_fifo_deq_val & tx_fifo_deq_rdy)
    );

    assign tx_fifo_deq_rdy = 1'b1;

import "DPI-C" context function void put_data(input bit[`MAC_INTERFACE_W-1:0] data,
                                              input bit last,
                                              input int padbytes);
    always @(negedge clk) begin
        if (tx_fifo_deq_val) begin
            put_data(tx_fifo_deq_data.data, tx_fifo_deq_data.last, tx_fifo_deq_data.padbytes);
        end
    end

    /* **************************************************************************
    * Simulation init
    * *************************************************************************/
    import "DPI-C" context function void init_network_side_state();
    initial begin
        init_network_side_state();
    end
    
    export "DPI-C" function finish_from_c;
    function void finish_from_c();
        $finish;
    endfunction

endmodule
