// =============================================================================
// Module      : ov7670_capture
// Purpose     : Standard Native-Clock Capture (60fps Optimized).
// =============================================================================

module ov7670_capture #(
    parameter FRAME_WIDTH  = 320,
    parameter FRAME_HEIGHT = 240
)(
    input  wire        pclk,        // Native Camera PCLK
    input  wire        rst,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_d,

    output reg         wr_en,
    output reg  [16:0] wr_addr,
    output reg  [15:0] wr_data,
    output reg         frame_done,
    input  wire        byte_swap
);

    localparam FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;

    reg [7:0]  first_byte;
    reg        byte_cnt;
    reg        vsync_prev;

    always @(negedge pclk) begin
        if (rst) begin
            wr_addr    <= 17'd0;
            byte_cnt   <= 1'b0;
            wr_en      <= 1'b0;
            frame_done <= 1'b0;
        end else begin
            wr_en      <= 1'b0;
            frame_done <= 1'b0;
            vsync_prev <= cam_vsync;

            // Frame Reset on VSYNC (Active High)
            if (cam_vsync) begin
                wr_addr  <= 17'd0;
                byte_cnt <= 1'b0;
            end
            
            // Pulse frame_done at the end of VSYNC
            if (!cam_vsync && vsync_prev) begin
                frame_done <= 1'b1;
            end

            // Pixel Capture on HREF
            if (cam_href) begin
                if (!byte_cnt) begin
                    first_byte <= cam_d;
                    byte_cnt   <= 1'b1;
                end else begin
                    wr_data <= byte_swap ? {cam_d, first_byte} : {first_byte, cam_d};
                    
                    if (wr_addr < FRAME_PIXELS) begin
                        wr_en   <= 1'b1;
                        wr_addr <= wr_addr + 17'd1;
                    end
                    byte_cnt <= 1'b0;
                end
            end else begin
                byte_cnt <= 1'b0; // Reset byte count between lines
            end
        end
    end

endmodule
