// =============================================================================
// Module      : ov7670_config
// Purpose     : Sequences all required SCCB write transactions to configure
//               the OV7670 camera for RGB444 output at QVGA (320x240),
//               then holds the camera in running state.
//
// Clock Domain: clk (100 MHz system clock)
//
// Ports:
//   clk        — 100 MHz system clock
//   rst        — synchronous active-high reset
//   sccb_done  — from sccb_master: pulses when a transaction completes
//   sccb_start — to sccb_master: initiate one transaction
//   reg_addr   — 8-bit register address sent to sccb_master
//   reg_data   — 8-bit data sent to sccb_master
//   cfg_done   — goes high and stays high when all registers are written
//
// Register sequence:
//   1. COM7[7] = 1 → soft reset (registers return to defaults)
//   2. ~2 ms delay after reset
//   3. CLKRC divisor, COM7 (QVGA + RGB444), COM15 (full range),
//      COM9 (AGC), BRIGHT, CONTRAS, and other recommended OV7670 defaults.
//
// Pitfalls:
//   - After COM7 soft reset, at least one SCCB idle period (~100 µs) is
//     needed before the next write; this design uses a large counter delay.
//   - The OV7670 application note recommends driving XCLK at 24 MHz;
//     the Clocking Wizard output is routed through an ODDR to cam_xclk.
//   - RGB444 ordering from OV7670: first byte bits[3:0]=G2G1G0B3,
//     second byte=B2B1B0R3R2R1R0.  The capture module reconstructs RGB.
// =============================================================================

module ov7670_config (
    input  wire        clk,
    input  wire        rst,

    // sccb_master interface
    input  wire        sccb_done,
    output reg         sccb_start,
    output reg  [7:0]  reg_addr,
    output reg  [7:0]  reg_data,

    output reg         cfg_done
);

    // -----------------------------------------------------------------------
    // Register ROM — {addr, data} pairs
    // -----------------------------------------------------------------------
    reg [15:0] current_reg;
    reg [6:0]  rom_idx;

    always @(*) begin
        case (rom_idx)
            // ---- 1. Soft Reset ----
            7'd0:  current_reg = {8'h12, 8'h80}; // COM7: soft reset

            // ---- 2. Clocking & PLL (60fps @ 24 MHz XCLK) ----
            7'd1:  current_reg = {8'h11, 8'h00}; // CLKRC: no prescaler
            7'd2:  current_reg = {8'h6b, 8'h4a}; // DBLV: PLL x4
            7'd3:  current_reg = {8'h3b, 8'h0a}; // COM11: Night mode OFF

            // ---- 3. Output Format ----
            7'd4:  current_reg = {8'h12, 8'h04}; // COM7: RGB + QVGA
            7'd5:  current_reg = {8'h40, 8'hD0}; // COM15: RGB565, full range [00-FF]
            7'd6:  current_reg = {8'h3a, 8'h04}; // TSLB: normal byte order
            7'd7:  current_reg = {8'h3d, 8'hC0}; // COM13: Gamma ON, UV auto-adjust ON

            // ---- 4. Scaling & DCW (fixes zoom) ----
            7'd8:  current_reg = {8'h0c, 8'h04}; // COM3: enable DCW
            7'd9:  current_reg = {8'h3e, 8'h19}; // COM14: PCLK scaling + manual DCW
            7'd10: current_reg = {8'h70, 8'h3a}; // SCALING_XSC
            7'd11: current_reg = {8'h71, 8'h35}; // SCALING_YSC
            7'd12: current_reg = {8'h72, 8'h11}; // SCALING_DCWCTR
            7'd13: current_reg = {8'h73, 8'hf1}; // SCALING_PCLK_DIV
            7'd14: current_reg = {8'ha2, 8'h02}; // SCALING_PCLK_DELAY

            // ---- 5. Windowing ----
            7'd15: current_reg = {8'h17, 8'h13}; // HSTART
            7'd16: current_reg = {8'h18, 8'h01}; // HSTOP
            7'd17: current_reg = {8'h32, 8'hbf}; // HREF
            7'd18: current_reg = {8'h19, 8'h02}; // VSTART
            7'd19: current_reg = {8'h1a, 8'h7a}; // VSTOP
            7'd20: current_reg = {8'h03, 8'h0a}; // VREF

            // ---- 6. Color Matrix (Standard OV7670 for RGB) ----
            7'd21: current_reg = {8'h4f, 8'h80}; // MTX1
            7'd22: current_reg = {8'h50, 8'h80}; // MTX2
            7'd23: current_reg = {8'h51, 8'h00}; // MTX3
            7'd24: current_reg = {8'h52, 8'h22}; // MTX4
            7'd25: current_reg = {8'h53, 8'h5e}; // MTX5
            7'd26: current_reg = {8'h54, 8'h80}; // MTX6
            7'd27: current_reg = {8'h58, 8'h9e}; // MTXS

            // ---- 7. AEC / AGC / AWB ----
            7'd28: current_reg = {8'h13, 8'hE7}; // COM8: AEC+AGC+AWB ON
            7'd29: current_reg = {8'h14, 8'h4a}; // COM9: AGC gain ceiling
            7'd30: current_reg = {8'h24, 8'h95}; // AEW
            7'd31: current_reg = {8'h25, 8'h33}; // AEB
            7'd32: current_reg = {8'h26, 8'he3}; // VPT

            // ---- 8. White Balance Gains (fight green tint) ----
            7'd33: current_reg = {8'h01, 8'h50}; // BLUE channel gain
            7'd34: current_reg = {8'h02, 8'h68}; // RED  channel gain
            7'd35: current_reg = {8'h6c, 8'h0a}; // AWB Control 1
            7'd36: current_reg = {8'h6d, 8'h55}; // AWB Control 2
            7'd37: current_reg = {8'h6e, 8'h11}; // AWB Control 3
            7'd38: current_reg = {8'h6f, 8'h9f}; // AWB Control 4
            7'd39: current_reg = {8'h6a, 8'h40}; // GGAIN: Green channel gain

            // ---- 9. Gamma Curve ----
            7'd40: current_reg = {8'h7a, 8'h20};
            7'd41: current_reg = {8'h7b, 8'h10};
            7'd42: current_reg = {8'h7c, 8'h1e};
            7'd43: current_reg = {8'h7d, 8'h35};
            7'd44: current_reg = {8'h7e, 8'h5a};
            7'd45: current_reg = {8'h7f, 8'h69};
            7'd46: current_reg = {8'h80, 8'h76};
            7'd47: current_reg = {8'h81, 8'h80};
            7'd48: current_reg = {8'h82, 8'h88};
            7'd49: current_reg = {8'h83, 8'h8f};
            7'd50: current_reg = {8'h84, 8'h96};
            7'd51: current_reg = {8'h85, 8'ha3};
            7'd52: current_reg = {8'h86, 8'haf};
            7'd53: current_reg = {8'h87, 8'hc4};
            7'd54: current_reg = {8'h88, 8'hd7};
            7'd55: current_reg = {8'h89, 8'he8};

            // ---- 10. DSP & Denoise ----
            7'd56: current_reg = {8'h41, 8'h08}; // COM16: Denoise ON
            7'd57: current_reg = {8'h3c, 8'h78}; // COM12
            7'd58: current_reg = {8'h69, 8'h00}; // GFIX
            7'd59: current_reg = {8'h74, 8'h00}; // REG74

            // ---- 11. Saturation & Contrast ----
            7'd60: current_reg = {8'h67, 8'hC0}; // U saturation gain
            7'd61: current_reg = {8'h68, 8'hC0}; // V saturation gain
            7'd62: current_reg = {8'h56, 8'h40}; // Contrast

            // ---- 12. Misc / Stability ----
            7'd63: current_reg = {8'h15, 8'h00}; // COM10
            7'd64: current_reg = {8'h0e, 8'h61}; // COM5
            7'd65: current_reg = {8'h42, 8'h00}; // COM17: Color bar OFF
            7'd66: current_reg = {8'h1e, 8'h07}; // MVFP: Mirror + VFlip

            default: current_reg = {8'hFF, 8'hFF}; // sentinel
        endcase
    end

    // -----------------------------------------------------------------------
    // Sequencer — wait after soft reset, then write all registers
    // -----------------------------------------------------------------------
    // After the soft reset (REG00), we must wait ~2 ms (200 000 cycles at 100 MHz).
    localparam RESET_WAIT = 200_000;

    reg [17:0] wait_cnt;

    localparam S_RESET_WAIT = 2'd0;
    localparam S_START_TX   = 2'd1;
    localparam S_WAIT_DONE  = 2'd2;
    localparam S_DONE       = 2'd3;

    reg [1:0] state;

    always @(posedge clk) begin
        if (rst) begin
            state       <= S_RESET_WAIT;
            rom_idx     <= 7'd0;
            sccb_start  <= 1'b0;
            reg_addr    <= 8'd0;
            reg_data    <= 8'd0;
            cfg_done    <= 1'b0;
            wait_cnt    <= 18'd0;
        end else begin
            sccb_start <= 1'b0;  // default

            case (state)
                // -----------------------------------------------------------
                // Wait after power-on / reset before touching SCCB
                // -----------------------------------------------------------
                S_RESET_WAIT: begin
                    if (wait_cnt == RESET_WAIT - 1) begin
                        wait_cnt <= 18'd0;
                        state    <= S_START_TX;
                    end else begin
                        wait_cnt <= wait_cnt + 18'd1;
                    end
                end

                // -----------------------------------------------------------
                // Drive sccb_start for one cycle with current register
                // -----------------------------------------------------------
                S_START_TX: begin
                    if (current_reg == 16'hFFFF) begin
                        // sentinel reached — configuration complete
                        cfg_done <= 1'b1;
                        state    <= S_DONE;
                    end else begin
                        reg_addr   <= current_reg[15:8];
                        reg_data   <= current_reg[7:0];
                        sccb_start <= 1'b1;
                        state      <= S_WAIT_DONE;

                        // Special case: after soft-reset register, add extra wait
                        if (rom_idx == 7'd0)
                            wait_cnt <= 18'd0;
                    end
                end

                // -----------------------------------------------------------
                // Wait for sccb_master to complete
                // -----------------------------------------------------------
                S_WAIT_DONE: begin
                    if (sccb_done) begin
                        rom_idx <= rom_idx + 7'd1;
                        // Inter-register gap — OV7670 needs >= 2 ms between writes
                        // At 100 kHz SCCB that's already ~2 ms per transaction,
                        // but add small extra delay to be safe
                        wait_cnt <= 18'd0;
                        state    <= S_RESET_WAIT;  // reuse the wait state
                    end
                end

                S_DONE: begin
                    cfg_done <= 1'b1;
                end

                default: state <= S_RESET_WAIT;
            endcase
        end
    end

endmodule
