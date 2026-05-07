// =============================================================================
// Module      : vga_controller
// Purpose     : Generates standard 640x480 @ 60 Hz VGA timing signals.
//               Produces horizontal/vertical counters used by the display
//               scaler to address the frame buffer.
//
// Clock Domain: pixel_clk (25.175 MHz — use 25 MHz from Clocking Wizard)
//
// Ports:
//   clk        — 25 MHz pixel clock (from Clocking Wizard)
//   rst        — synchronous active-high reset
//   hcount     — horizontal pixel counter [0..799]
//   vcount     — vertical   line  counter [0..524]
//   hsync      — horizontal sync (active-low pulse)
//   vsync      — vertical   sync (active-low pulse)
//   active     — high only in the 640x480 visible region
//
// VGA 640x480 @ 60 Hz timing (pixel clock = 25.175 MHz ≈ 25 MHz):
//   Horizontal: 640 active + 16 FP + 96 sync + 48 BP = 800 total
//   Vertical  : 480 active +  10 FP +  2 sync + 33 BP = 525 total
//   hsync pulse: cols 656..751 (active-low)
//   vsync pulse: rows 490..491 (active-low)
//
// Pitfalls:
//   - Using 25 MHz instead of 25.175 MHz gives ~0.7 % frequency error;
//     most monitors accept this. The Clocking Wizard MMCM can get very close.
//   - Do NOT register 'active'; it must be combinational to align with
//     the unregistered hcount/vcount used by the display scaler.
// =============================================================================

module vga_controller (
    input  wire        clk,      // 25 MHz pixel clock
    input  wire        rst,      // synchronous active-high reset
    output reg  [9:0]  hcount,   // 0..799
    output reg  [9:0]  vcount,   // 0..524
    output wire        hsync,    // active-low during sync pulse
    output wire        vsync,    // active-low during sync pulse
    output wire        active    // 1 when pixel is in 640x480 region
);

    // -----------------------------------------------------------------------
    // VGA timing parameters
    // -----------------------------------------------------------------------
    localparam H_ACTIVE   = 640;
    localparam H_FP       = 16;    // front porch
    localparam H_SYNC     = 96;    // sync pulse width
    localparam H_BP       = 48;    // back porch
    localparam H_TOTAL    = 800;   // H_ACTIVE + H_FP + H_SYNC + H_BP

    localparam V_ACTIVE   = 480;
    localparam V_FP       = 10;
    localparam V_SYNC     = 2;
    localparam V_BP       = 33;
    localparam V_TOTAL    = 525;   // V_ACTIVE + V_FP + V_SYNC + V_BP

    // Sync pulse windows (beginning of each pulse)
    localparam H_SYNC_START = H_ACTIVE + H_FP;           // 656
    localparam H_SYNC_END   = H_ACTIVE + H_FP + H_SYNC;  // 752
    localparam V_SYNC_START = V_ACTIVE + V_FP;           // 490
    localparam V_SYNC_END   = V_ACTIVE + V_FP + V_SYNC;  // 492

    // -----------------------------------------------------------------------
    // Horizontal counter
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            hcount <= 10'd0;
        end else begin
            if (hcount == H_TOTAL - 1)
                hcount <= 10'd0;
            else
                hcount <= hcount + 10'd1;
        end
    end

    // -----------------------------------------------------------------------
    // Vertical counter — increments at end of each horizontal line
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            vcount <= 10'd0;
        end else begin
            if (hcount == H_TOTAL - 1) begin
                if (vcount == V_TOTAL - 1)
                    vcount <= 10'd0;
                else
                    vcount <= vcount + 10'd1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // Sync outputs (active-low)
    // -----------------------------------------------------------------------
    assign hsync  = ~((hcount >= H_SYNC_START) && (hcount < H_SYNC_END));
    assign vsync  = ~((vcount >= V_SYNC_START) && (vcount < V_SYNC_END));

    // -----------------------------------------------------------------------
    // Active region
    // -----------------------------------------------------------------------
    assign active = (hcount < H_ACTIVE) && (vcount < V_ACTIVE);

endmodule
