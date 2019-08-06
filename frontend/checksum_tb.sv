module testbench();
    parameter DATA_WIDTH = 64;
    parameter KEEP_WIDTH = (DATA_WIDTH/8);
    parameter ID_ENABLE = 0;
    parameter ID_WIDTH = 8;
    parameter DEST_ENABLE = 0;
    parameter DEST_WIDTH = 8;
    parameter USER_ENABLE = 0;
    parameter USER_WIDTH = 1;
    parameter USE_INIT_VALUE = 1;
    parameter DATA_FIFO_DEPTH = 4096;
    parameter CHECKSUM_FIFO_DEPTH = 4;

    // Simulation Parameters
    localparam  CLOCK_PERIOD      = 10000;
    localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
    localparam  RST_TIME          = (10) * CLOCK_PERIOD;

    logic clk;
    logic rst;
    
    /*
     * AXI input
     */
    logic   [DATA_WIDTH-1:0]  s_axis_tdata;
    logic   [KEEP_WIDTH-1:0]  s_axis_tkeep;
    logic                     s_axis_tvalid;
    logic                     s_axis_tready;
    logic                     s_axis_tlast;
    logic   [ID_WIDTH-1:0]    s_axis_tid;
    logic   [DEST_WIDTH-1:0]  s_axis_tdest;
    logic   [USER_WIDTH-1:0]  s_axis_tuser;

    /*
     * AXI output
     */
    logic   [DATA_WIDTH-1:0]  m_axis_tdata;
    logic   [KEEP_WIDTH-1:0]  m_axis_tkeep;
    logic                     m_axis_tvalid;
    logic                     m_axis_tready;
    logic                     m_axis_tlast;
    logic   [ID_WIDTH-1:0]    m_axis_tid;
    logic   [DEST_WIDTH-1:0]  m_axis_tdest;
    logic   [USER_WIDTH-1:0]  m_axis_tuser;

    /*
     * Control
     */
    logic                     s_axis_cmd_csum_enable;
    logic   [7:0]             s_axis_cmd_csum_start;
    logic   [7:0]             s_axis_cmd_csum_offset;
    logic   [15:0]            s_axis_cmd_csum_init;
    logic                     s_axis_cmd_valid;
    logic                     s_axis_cmd_ready;

    assign s_axis_tid = '0;
    assign s_axis_tdest = '0;
    assign s_axis_tuser = '0;

    initial begin
        clk = 0;
        forever begin
            #(CLOCK_HALF_PERIOD) clk = ~clk;
        end
    end

    initial begin
        rst = 1'b1;
        #RST_TIME rst = 1'b0; 
    end

    checksum_tester tester (
         .clk   (clk)
        ,.rst   (rst)
        
        ,.req_axis_cmd_csum_enable  (s_axis_cmd_csum_enable )
        ,.req_axis_cmd_csum_start   (s_axis_cmd_csum_start  )
        ,.req_axis_cmd_csum_offset  (s_axis_cmd_csum_offset )
        ,.req_axis_cmd_csum_init    (s_axis_cmd_csum_init   )
        ,.req_axis_cmd_valid        (s_axis_cmd_valid       )
        ,.req_axis_cmd_ready        (s_axis_cmd_ready       )
        
        ,.req_axis_tdata            (s_axis_tdata           )
        ,.req_axis_tkeep            (s_axis_tkeep           )
        ,.req_axis_tvalid           (s_axis_tvalid          )
        ,.req_axis_tready           (s_axis_tready          )
        ,.req_axis_tlast            (s_axis_tlast           )

        ,.resp_axis_tdata           (m_axis_tdata           )
        ,.resp_axis_tkeep           (m_axis_tkeep           )
        ,.resp_axis_tvalid          (m_axis_tvalid          )
        ,.resp_axis_tready          (m_axis_tready          )
        ,.resp_axis_tlast           (m_axis_tlast           )
    );

    tx_checksum #(
         .DATA_WIDTH            (DATA_WIDTH             )
        ,.KEEP_WIDTH            (KEEP_WIDTH             )
        ,.ID_ENABLE             (ID_ENABLE              )
        ,.ID_WIDTH              (ID_WIDTH               )
        ,.DEST_ENABLE           (DEST_ENABLE            )
        ,.DEST_WIDTH            (DEST_WIDTH             )
        ,.USER_ENABLE           (USER_ENABLE            )
        ,.USER_WIDTH            (USER_WIDTH             )
        ,.USE_INIT_VALUE        (USE_INIT_VALUE         )
        ,.DATA_FIFO_DEPTH       (DATA_FIFO_DEPTH        )
        ,.CHECKSUM_FIFO_DEPTH   (CHECKSUM_FIFO_DEPTH    )
    ) DUT (
         .clk   (clk)
        ,.rst   (rst)
    
        ,.s_axis_tdata              (s_axis_tdata           )
        ,.s_axis_tkeep              (s_axis_tkeep           )
        ,.s_axis_tvalid             (s_axis_tvalid          )
        ,.s_axis_tready             (s_axis_tready          )
        ,.s_axis_tlast              (s_axis_tlast           )
        ,.s_axis_tid                (s_axis_tid             )
        ,.s_axis_tdest              (s_axis_tdest           )
        ,.s_axis_tuser              (s_axis_tuser           )

        ,.m_axis_tdata              (m_axis_tdata           )
        ,.m_axis_tkeep              (m_axis_tkeep           )
        ,.m_axis_tvalid             (m_axis_tvalid          )
        ,.m_axis_tready             (m_axis_tready          )
        ,.m_axis_tlast              (m_axis_tlast           )
        ,.m_axis_tid                (m_axis_tid             )
        ,.m_axis_tdest              (m_axis_tdest           )
        ,.m_axis_tuser              (m_axis_tuser           )

        ,.s_axis_cmd_csum_enable    (s_axis_cmd_csum_enable )
        ,.s_axis_cmd_csum_start     (s_axis_cmd_csum_start  )
        ,.s_axis_cmd_csum_offset    (s_axis_cmd_csum_offset )
        ,.s_axis_cmd_csum_init      (s_axis_cmd_csum_init   )
        ,.s_axis_cmd_valid          (s_axis_cmd_valid       )
        ,.s_axis_cmd_ready          (s_axis_cmd_ready       )
        
    );
endmodule
