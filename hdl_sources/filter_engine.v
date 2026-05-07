`default_nettype none

// =============================================================================
// Module      : filter_engine
// Purpose     : Combinational logic to apply various image filters to a
//               16-bit RGB565 pixel based on switch inputs.
//
// Filters:
//   sw = 00 -> Pass-through (Raw)
//   sw = 01 -> Grayscale (Rec.601 luminance)
//   sw = 10 -> Color Isolation (Red channel only)
//   sw = 11 -> Color Inversion (Negative)
//
// Ports:
//   pixel_in  [15:0] — 16-bit RGB565 input pixel
//   sw        [1:0]  — 2-bit filter selection
//   pixel_out [15:0] — 16-bit RGB565 filtered output pixel
// =============================================================================

module filter_engine (
    input  wire [15:0] pixel_in,
    input  wire [1:0]  sw,
    output reg  [15:0] pixel_out
);

    // Extract RGB565 components
    // R: [15:11] (5 bits), G: [10:5] (6 bits), B: [4:0] (5 bits)
    wire [4:0] r5 = pixel_in[15:11];
    wire [5:0] g6 = pixel_in[10:5];
    wire [4:0] b5 = pixel_in[4:0];

    // -----------------------------------------------------------------------
    // Grayscale Conversion (Rec.601)
    // Formula: Y = (R5*54 + G6*183 + B5*18) >> 8
    // Note: R5 is 5 bits, G6 is 6 bits, B5 is 5 bits.
    // -----------------------------------------------------------------------
    wire [13:0] y_scaled = (r5 * 14'd54) + (g6 * 14'd183) + (b5 * 14'd18);
    wire [7:0]  y = y_scaled[13:6]; // Use bits [13:6] to get the result of >>8 
                                    // Wait: (R*54 + G*183 + B*18) >> 8
                                    // Let's re-calculate: 
                                    // Max value: 31*54 + 63*183 + 31*18 = 1674 + 11529 + 558 = 13761
                                    // 13761 >> 8 = 53.75
                                    // Wait, Y should fit in 6 bits for G, 5 bits for R/B.
                                    // Actually, if we use Rec.601 coefficients scaled to 256:
                                    // 0.299 * 256 = 76.5
                                    // 0.587 * 256 = 150.2
                                    // 0.114 * 256 = 29.1
                                    // The requirement said: Y = (R5*54 + G6*183 + B5*18) >> 8
                                    // Let's check these coefficients:
                                    // 54/256 = 0.21, 183/256 = 0.71, 18/256 = 0.07
                                    // This is a custom weighting. I will stick to the requirement.
    
    wire [5:0] y_6bit = y_scaled[13:8] > 6'd63 ? 6'd63 : y_scaled[13:8];
    wire [4:0] y_5bit = y_6bit[5:1];

    // -----------------------------------------------------------------------
    // Filter selection
    // -----------------------------------------------------------------------
    always @(*) begin
        case (sw)
            2'b00: begin // Raw
                pixel_out = pixel_in;
            end
            2'b01: begin // Grayscale
                pixel_out = {y_5bit, y_6bit, y_5bit};
            end
            2'b10: begin // Color Isolation (Red)
                pixel_out = {r5, 6'b0, 5'b0};
            end
            2'b11: begin // Color Inversion
                pixel_out = ~pixel_in;
            end
            default: pixel_out = pixel_in;
        endcase
    end

endmodule
