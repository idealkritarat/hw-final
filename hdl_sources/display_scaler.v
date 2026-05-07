// =============================================================================
// Module      : display_scaler
// Purpose     : Reads pixel data from the frame buffer (BRAM Port B) and
//               drives the VGA RGB outputs using pixel doubling.
//               Pixel doubling maps 320x240 frame buffer pixels to the
//               640x480 VGA display region (Section 5 of project spec):
//                 buf_col = hcount >> 1
//                 buf_row = vcount >> 1
//                 rd_addr = buf_row * 320 + buf_col
//               Additionally implements three switchable image filters:
//                 sw[1:0] = 00 → raw RGB
//                 sw[1:0] = 01 → grayscale
//                 sw[1:0] = 10 → color channel isolation (red only)
//                 sw[1:0] = 11 → color inversion (negative)
//
// Clock Domain: pixel_clk (25 MHz) — same as VGA controller
//
// Ports:
//   clk         — 25 MHz pixel clock
//   rst         — synchronous active-high reset
//   hcount      — from vga_controller [9:0]
//   vcount      — from vga_controller [9:0]
//   active      — from vga_controller
//   frame_valid — from top.v CDC: high once camera has completed >= 1 full frame
//   rd_data     — 12-bit pixel {R,G,B} from BRAM Port B
//   rd_addr     — read address to BRAM Port B [16:0]
//   sw          — 2-bit switch for filter selection
//   vga_r       — 4-bit VGA red   output
//   vga_g       — 4-bit VGA green output
//   vga_b       — 4-bit VGA blue  output
//
// Pipeline (2 stages, BRAM output register DISABLED in IP wizard):
//   Stage 1 (posedge): rd_addr latched, active_d1 latched
//   BRAM read: 1 cycle (addr is registered inside BRAM primitive)
//   Stage 2 (posedge): vga_r/g/b latched, gated by active_d2
//   => active must be delayed by 2 cycles to align with rd_data.
//
// Pitfalls:
//   - Using active_d1 with the BRAM output register ENABLED causes
//     a 1-cycle misalignment (left-edge garbage pixel). Use active_d2.
//   - The multiply (buf_row * 320) is (row<<8)+(row<<6) — no DSP48.
//   - When not active or frame not valid, drive RGB outputs to 0.
// =============================================================================

module display_scaler (
    input  wire        clk,
    input  wire        rst,

    // From VGA controller
    input  wire [9:0]  hcount,
    input  wire [9:0]  vcount,
    input  wire        active,

    // Frame ready flag (from top.v CDC — prevents displaying garbage frames)
    input  wire        frame_valid,

    // BRAM Port B (read)
    input  wire [15:0] rd_data,    // {R[4:0], G[5:0], B[4:0]}
    output reg  [16:0] rd_addr,    // read address into frame buffer

    // Filter select
    input  wire [1:0]  sw,

    // VGA outputs
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    // -----------------------------------------------------------------------
    // Address calculation — Rotate 90 CW, Horizontal Mirror, 1.5x Scale, Center
    // -----------------------------------------------------------------------
    // Center a 360x480 image on a 640x480 screen (offset X by 140)
    wire valid_area = (hcount >= 10'd140 && hcount < 10'd500 && vcount < 10'd480);
    wire [8:0] screen_x = hcount - 10'd140; // 0 to 359
    
    // Scale down from 360x480 to 240x320 using factor 171/256 (~0.667)
    wire [16:0] scaled_x_full = screen_x * 8'd171;
    wire [17:0] scaled_y_full = vcount   * 8'd171;
    
    // Extract integer part (right shift by 8)
    wire [7:0] rot_x = scaled_x_full[15:8]; // 0 to 239
    wire [8:0] rot_y = scaled_y_full[16:8]; // 0 to 319

    // Mathematical transformation for "Rotate 90 CW + Horizontal Mirror":
    // Original image: 320(W) x 240(H)
    // Rotated + Mirrored coordinates map perfectly to:
    // img_x = rot_y
    // img_y = rot_x
    wire [8:0] img_x = rot_y; // 0 to 319
    wire [7:0] img_y = rot_x; // 0 to 239

    // Combinational address (drives BRAM; data available next cycle)
    // addr = img_y * 320 + img_x = (img_y << 8) + (img_y << 6) + img_x
    wire [16:0] addr_next = ({9'd0, img_y} << 8) + ({9'd0, img_y} << 6) + {8'd0, img_x};

    // -----------------------------------------------------------------------
    // Pipeline stage 1: register address and active (cycle 0 → cycle 1)
    // -----------------------------------------------------------------------
    reg active_d1;  // active delayed 1 cycle
    reg active_d2;  // active delayed 2 cycles — aligns with rd_data valid

    always @(posedge clk) begin
        if (rst) begin
            rd_addr   <= 17'd0;
            active_d1 <= 1'b0;
            active_d2 <= 1'b0;
        end else begin
            rd_addr   <= (active && valid_area) ? addr_next : 17'd0;
            active_d1 <= (active && valid_area);
            active_d2 <= active_d1;
        end
    end

    // -----------------------------------------------------------------------
    // Image Filtering (combinational, stage 2)
    // -----------------------------------------------------------------------
    wire [15:0] filtered_pixel;
    filter_engine u_filter (
        .pixel_in  (rd_data),
        .sw        (sw),
        .pixel_out (filtered_pixel)
    );

    // -----------------------------------------------------------------------
    // Pipeline stage 2: drive VGA outputs
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end else begin
            // Gate with active_d2 and frame_valid.
            if (!active_d2 || !frame_valid) begin
                vga_r <= 4'd0;
                vga_g <= 4'd0;
                vga_b <= 4'd0;
            end else begin
                // Map RGB565 to 4-bit VGA DACs (take MSBs)
                vga_r <= filtered_pixel[15:12];
                vga_g <= filtered_pixel[10:7];
                vga_b <= filtered_pixel[4:1];
            end
        end
    end

endmodule

