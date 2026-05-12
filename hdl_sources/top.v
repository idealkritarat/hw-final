// =============================================================================
// Module      : top
// Purpose     : Top-level integration of the Real-Time Video Capture and
//               Processing System. Connects:
//                 • Clocking Wizard (100 MHz → 25 MHz pixel_clk, 24 MHz cam_xclk)
//                 • OV7670 camera capture (PCLK domain)
//                 • SCCB master + OV7670 config sequencer (100 MHz domain)
//                 • Frame buffer BRAM (true dual-port, async clocks)
//                 • VGA controller (25 MHz domain)
//                 • Display scaler with image filters (25 MHz domain)
//                 • 2-FF synchronizers for cross-domain control signals
//
// Clock Domains:
//   clk_100mhz  — system clock (100 MHz, from oscillator)
//   pixel_clk   — 25 MHz VGA pixel clock (from Clocking Wizard)
//   cam_xclk    — 25 MHz master clock driven to camera (from Clocking Wizard)
//   cam_pclk    — pixel clock from OV7670 (asynchronous input, ~12-25 MHz)
//
// Cross-Domain Crossings:
//   cam_vsync, cam_href: OV7670 inputs, captured in cam_pclk domain.
//   frame_done: 1-cycle pulse from ov7670_capture (cam_pclk) -> Toggle CDC
//               into pixel_clk domain as frame_valid (sticky flag).
//
// VGA Sync Alignment:
//   The display scaler/filter pipeline has a 3-cycle latency.
//   vga_hsync and vga_vsync must be delayed by 3 cycles to match the data.
// =============================================================================

module top (
    // System
    input  wire        clk_100mhz,   // W5
    input  wire        rst,           // BTNC (U18), active-high

    // OV7670 camera

    input  wire [7:0]  cam_d,         // D7..D0 pixel data
    input  wire        cam_pclk,      // pixel clock from camera
    input  wire        cam_href,      // horizontal reference
    input  wire        cam_vsync,     // vertical sync (active-high)
    output wire        cam_xclk,      // master clock to camera
    output wire        cam_pwdn,      // power-down (drive LOW)
    output wire        cam_rst_n,     // reset (drive HIGH to operate)
    output wire        cam_scl,       // SCCB clock
    inout  wire        cam_sda,       // SCCB data

    // VGA
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync,

    // Slide Switches (Only 2 needed for filter selection)
    input  wire [1:0]  sw,

    // Diagnostic LEDs
    output wire [2:0]  led
);


    // -----------------------------------------------------------------------
    // Clock generation (Clocking Wizard IP: clk_wiz_0)
    // -----------------------------------------------------------------------
    wire pixel_clk;
    wire cam_xclk_int;
    wire pll_locked;

    clk_wiz_0 u_clk_wiz (
        .clk_in1   (clk_100mhz),
        .clk_out1  (pixel_clk),       // 25 MHz
        .clk_out2  (cam_xclk_int),    // 24 MHz (Preferred for OV7670)
        .reset     (rst),
        .locked    (pll_locked)
    );

    ODDR #(
        .DDR_CLK_EDGE ("OPPOSITE_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) u_oddr_xclk (
        .Q  (cam_xclk),
        .C  (cam_xclk_int),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );

    assign cam_pwdn  = 1'b0;
    assign cam_rst_n = 1'b1;

    // -----------------------------------------------------------------------
    // Power-on Reset Counter
    // Ensures all modules start in a known state after clocks are stable.
    // -----------------------------------------------------------------------
    reg [23:0] rst_cnt = 24'd0;
    reg        global_rst = 1'b1;
    always @(posedge clk_100mhz) begin
        if (rst || !pll_locked) begin
            rst_cnt    <= 24'd0;
            global_rst <= 1'b1;
        end else if (rst_cnt < 24'hFFFFFF) begin
            rst_cnt    <= rst_cnt + 24'd1;
            global_rst <= 1'b1;
        end else begin
            global_rst <= 1'b0;
        end
    end

    // Synchronize global_rst to each domain
    reg pix_rst_sync1, pix_rst;
    always @(posedge pixel_clk) begin
        pix_rst_sync1 <= global_rst;
        pix_rst       <= pix_rst_sync1;
    end

    reg cam_rst_sync1, cam_rst;
    always @(posedge cam_pclk) begin
        cam_rst_sync1 <= global_rst;
        cam_rst       <= cam_rst_sync1;
    end

    // -----------------------------------------------------------------------
    // SCCB Master & Config
    // -----------------------------------------------------------------------
    wire        sccb_start, sccb_done, cfg_done;
    wire [7:0]  sccb_reg_addr, sccb_reg_data;
    wire        sda_out;
    wire        sccb_ack_err;

    sccb_master #(
        .CLK_FREQ  (100_000_000),
        .SCCB_FREQ (100_000)
    ) u_sccb (
        .clk      (clk_100mhz),
        .rst      (global_rst),
        .start    (sccb_start),
        .dev_addr (7'h21),
        .reg_addr (sccb_reg_addr),
        .reg_data (sccb_reg_data),
        .scl      (cam_scl),
        .sda      (sda_out),
        .done     (sccb_done),
        .busy     (),
        .ack_err  (sccb_ack_err)
    );


    assign cam_sda = sda_out ? 1'bz : 1'b0;

    ov7670_config u_cfg (
        .clk       (clk_100mhz),
        .rst       (global_rst),
        .sccb_done (sccb_done),
        .sccb_start(sccb_start),
        .reg_addr  (sccb_reg_addr),
        .reg_data  (sccb_reg_data),
        .cfg_done  (cfg_done)
    );

    // -----------------------------------------------------------------------
    // Camera Capture
    // -----------------------------------------------------------------------
    wire        wr_en;
    wire [16:0] wr_addr;
    wire [15:0] wr_data;
    wire        frame_done;

    ov7670_capture u_capture (
        .pclk      (cam_pclk), // Back to native clock
        .rst       (cam_rst),
        .cam_vsync (cam_vsync),
        .cam_href  (cam_href),
        .cam_d     (cam_d),
        .wr_en     (wr_en),
        .wr_addr   (wr_addr),
        .wr_data   (wr_data),
        .frame_done(frame_done)
    );



    // -----------------------------------------------------------------------
    // Frame-done CDC: Pulse-to-Toggle -> Synchronizer -> Pulse-from-Toggle
    // -----------------------------------------------------------------------
    reg  frame_done_toggle = 1'b0;
    always @(posedge cam_pclk) begin
        if (cam_rst) frame_done_toggle <= 1'b0;
        else if (frame_done) frame_done_toggle <= ~frame_done_toggle;
    end

    reg [2:0] fd_sync;
    always @(posedge pixel_clk) begin
        if (pix_rst) fd_sync <= 3'b0;
        else fd_sync <= {fd_sync[1:0], frame_done_toggle};
    end
    wire frame_done_pix = fd_sync[2] ^ fd_sync[1]; // detect edge

    reg frame_valid = 1'b0;
    always @(posedge pixel_clk) begin
        if (pix_rst) frame_valid <= 1'b0;
        else if (frame_done_pix) frame_valid <= 1'b1;
    end

    // -----------------------------------------------------------------------
    // Frame Buffer
    // -----------------------------------------------------------------------
    wire [16:0] rd_addr;
    wire [15:0] rd_data;

    frame_buffer u_bram (
        .clka  (cam_pclk),
        .ena   (1'b1),
        .wea   (wr_en),
        .addra (wr_addr),
        .dina  (wr_data),
        .clkb  (pixel_clk),
        .enb   (1'b1),
        .addrb (rd_addr),
        .doutb (rd_data)
    );

    // -----------------------------------------------------------------------
    // VGA Controller
    // -----------------------------------------------------------------------
    wire [9:0] hcount, vcount;
    wire       active, hsync_raw, vsync_raw;

    vga_controller u_vga (
        .clk    (pixel_clk),
        .rst    (pix_rst),
        .hcount (hcount),
        .vcount (vcount),
        .hsync  (hsync_raw),
        .vsync  (vsync_raw),
        .active (active)
    );

    // -----------------------------------------------------------------------
    // Display Scaler + Filter
    // -----------------------------------------------------------------------
    wire [3:0] scaler_r, scaler_g, scaler_b;

    display_scaler u_scaler (
        .clk         (pixel_clk),
        .rst         (pix_rst),
        .hcount      (hcount),
        .vcount      (vcount),
        .active      (active),
        .frame_valid (frame_valid),
        .rd_data     (rd_data),
        .rd_addr     (rd_addr),
        .sw          (sw),
        .vga_r       (scaler_r),
        .vga_g       (scaler_g),
        .vga_b       (scaler_b)
    );

    assign vga_r = scaler_r;
    assign vga_g = scaler_g;
    assign vga_b = scaler_b;

    // -----------------------------------------------------------------------
    // VGA Sync Delay Compensation (4 cycles)

    // Align hsync/vsync with the pixel data from display_scaler.
    // -----------------------------------------------------------------------
    reg [3:0] hsync_delay, vsync_delay;
    always @(posedge pixel_clk) begin
        if (pix_rst) begin
            hsync_delay <= 4'b1111;
            vsync_delay <= 4'b1111;
        end else begin
            hsync_delay <= {hsync_delay[2:0], hsync_raw};
            vsync_delay <= {vsync_delay[2:0], vsync_raw};
        end
    end
    assign vga_hsync = hsync_delay[2];
    assign vga_vsync = vsync_delay[2];

    // -----------------------------------------------------------------------
    // Diagnostic LEDs (Not used)
    // -----------------------------------------------------------------------
    assign led = 3'b000;

endmodule



