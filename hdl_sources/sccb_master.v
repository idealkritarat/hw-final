// =============================================================================
// Module      : sccb_master
// Purpose     : Implements a 3-wire SCCB write-only master compatible with
//               the OV7670's serial camera control bus. Transmits 3-phase
//               write cycles: [ID address | sub-address | data].
//
// Clock Domain: clk (system clock, any frequency ≥ 1 MHz)
//               Internal clock divider generates ~100 kHz SCCB clock.
//
// Ports:
//   clk        — system clock (100 MHz typical)
//   rst        — synchronous active-high reset
//   start      — pulse high for 1 cycle to begin a transaction
//   dev_addr   — 7-bit SCCB device address (OV7670 = 7'h21)
//   reg_addr   — 8-bit register address
//   reg_data   — 8-bit data to write
//   scl        — SCCB clock output
//   sda        — SCCB data output (open-drain compatible; drive low or Z)
//   done       — pulses high for 1 cycle when transaction is complete
//   busy       — high while a transaction is in progress
//
// SCCB vs I2C differences:
//   - No ACK/NAK bits are read back (don't-care phase instead of ACK)
//   - SDA is only driven by master; no pull-up read-back required in RTL
//   - Each write cycle: START, [8-bit ID addr + W bit], [8-bit reg addr],
//                       [8-bit data], STOP
//
// Pitfalls:
//   - The OV7670 requires ≥ 2 ms between SCCB writes (add delay in ov7670_config).
//   - Driving SDA as a regular output (not open-drain) is acceptable in most
//     FPGA systems because we only write; ensure the camera's SDA line has
//     a pull-up resistor on the PCB.
//   - SCL must be stable before SDA transitions (setup/hold respected here by
//     toggling SDA only while SCL is low).
// =============================================================================

module sccb_master #(
    parameter CLK_FREQ   = 100_000_000,  // system clock frequency in Hz
    parameter SCCB_FREQ  = 100_000       // target SCCB clock in Hz
) (
    input  wire       clk,
    input  wire       rst,

    // Transaction interface
    input  wire       start,
    input  wire [6:0] dev_addr,   // 7-bit device address
    input  wire [7:0] reg_addr,   // 8-bit register address
    input  wire [7:0] reg_data,   // 8-bit write data

    // SCCB pins
    output reg        scl,
    output reg        sda,

    // Status
    output reg        done,
    output reg        busy,
    output reg        ack_err    // High if a NAK is detected during any 9th bit
);

    // -----------------------------------------------------------------------
    // Clock divider — generate quarter-period tick for SCL generation
    // One SCL period = 4 ticks: low0, low1 (SDA change here), high0, high1
    // -----------------------------------------------------------------------
    localparam CLK_DIV = CLK_FREQ / (SCCB_FREQ * 4);  // quarter-period count

    reg [$clog2(CLK_DIV+1)-1:0] clk_cnt;
    reg                          tick;   // 1-cycle pulse at each quarter period

    always @(posedge clk) begin
        if (rst) begin
            clk_cnt <= 0;
            tick    <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
                tick    <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // State machine
    // -----------------------------------------------------------------------
    localparam ST_IDLE      = 4'd0;
    localparam ST_START     = 4'd1;
    localparam ST_ID        = 4'd2;  // transmit device address + W bit
    localparam ST_DC_ID     = 4'd3;  // don't-care bit after ID byte
    localparam ST_REG       = 4'd4;  // transmit register address
    localparam ST_DC_REG    = 4'd5;  // don't-care bit after reg byte
    localparam ST_DATA      = 4'd6;  // transmit data byte
    localparam ST_DC_DATA   = 4'd7;  // don't-care bit after data byte
    localparam ST_STOP      = 4'd8;
    localparam ST_DONE      = 4'd9;

    reg [3:0]  state;
    reg [3:0]  bit_cnt;   // counts 7..0 during byte transmission
    reg [1:0]  phase;     // quarter-period phase: 0=SCL low, 1=SDA change,
                          //                       2=SCL rise, 3=SCL high
    reg [7:0]  tx_byte;   // current byte being shifted out

    // Assembled 8-bit ID byte = {dev_addr[6:0], 1'b0} (write)
    wire [7:0] id_byte = {dev_addr, 1'b0};

    always @(posedge clk) begin
        if (rst) begin
            state   <= ST_IDLE;
            scl     <= 1'b1;
            sda     <= 1'b1;
            done    <= 1'b0;
            busy    <= 1'b0;
            ack_err <= 1'b0;
            bit_cnt <= 4'd7;
            phase   <= 2'd0;
            tx_byte <= 8'd0;
        end else begin
            done <= 1'b0;  // default: done is a single-cycle pulse

            case (state)
                // -----------------------------------------------------------
                ST_IDLE: begin
                    scl     <= 1'b1;
                    sda     <= 1'b1;
                    busy    <= 1'b0;
                    ack_err <= 1'b0;
                    if (start) begin
                        busy    <= 1'b1;
                        tx_byte <= id_byte;
                        bit_cnt <= 4'd7;
                        phase   <= 2'd0;
                        state   <= ST_START;
                    end
                end

                // -----------------------------------------------------------
                // START condition: SDA falls while SCL is high
                // -----------------------------------------------------------
                ST_START: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b1; sda <= 1'b1; phase <= 2'd1; end
                            2'd1: begin sda <= 1'b0; phase <= 2'd2; end   // SDA↓ while SCL=1
                            2'd2: begin scl <= 1'b0; phase <= 2'd3; end
                            2'd3: begin
                                phase   <= 2'd0;
                                bit_cnt <= 4'd7;
                                tx_byte <= id_byte;
                                state   <= ST_ID;
                            end
                        endcase
                    end
                end

                // -----------------------------------------------------------
                // Generic bit-by-bit byte transmit — reused for ID/REG/DATA
                // -----------------------------------------------------------
                ST_ID, ST_REG, ST_DATA: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b0; phase <= 2'd1; end
                            2'd1: begin sda <= tx_byte[bit_cnt]; phase <= 2'd2; end
                            2'd2: begin scl <= 1'b1; phase <= 2'd3; end
                            2'd3: begin
                                phase <= 2'd0;
                                if (bit_cnt == 4'd0) begin
                                    // move to don't-care phase
                                    case (state)
                                        ST_ID:   state <= ST_DC_ID;
                                        ST_REG:  state <= ST_DC_REG;
                                        ST_DATA: state <= ST_DC_DATA;
                                        default: state <= ST_STOP;
                                    endcase
                                end else begin
                                    bit_cnt <= bit_cnt - 4'd1;
                                end
                            end
                        endcase
                    end
                end

                // -----------------------------------------------------------
                // Don't-care (9th bit) — SDA released (high); SCL pulses once
                // -----------------------------------------------------------
                ST_DC_ID, ST_DC_REG, ST_DC_DATA: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b0; sda <= 1'b1; phase <= 2'd1; end
                            2'd1: begin phase <= 2'd2; end
                            2'd2: begin 
                                scl <= 1'b1; 
                                phase <= 2'd3;
                                // Sample SDA during SCL high to check for ACK (0) or NAK (1)
                                if (sda == 1'b1) begin
                                    ack_err <= 1'b1; // Slave didn't pull SDA low
                                end
                            end
                            2'd3: begin
                                phase   <= 2'd0;
                                scl     <= 1'b0;
                                bit_cnt <= 4'd7;
                                case (state)
                                    ST_DC_ID: begin
                                        tx_byte <= reg_addr;
                                        state   <= ST_REG;
                                    end
                                    ST_DC_REG: begin
                                        tx_byte <= reg_data;
                                        state   <= ST_DATA;
                                    end
                                    ST_DC_DATA: state <= ST_STOP;
                                    default:    state <= ST_STOP;
                                endcase
                            end
                        endcase
                    end
                end

                // -----------------------------------------------------------
                // STOP condition: SDA rises while SCL is high
                // -----------------------------------------------------------
                ST_STOP: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b0; sda <= 1'b0; phase <= 2'd1; end
                            2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                            2'd2: begin sda <= 1'b1; phase <= 2'd3; end   // SDA↑ while SCL=1
                            2'd3: begin
                                phase <= 2'd0;
                                state <= ST_DONE;
                            end
                        endcase
                    end
                end

                // -----------------------------------------------------------
                ST_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
