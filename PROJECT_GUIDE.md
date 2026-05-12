# Real-Time Video Capture & Processing System — Project Guide

A beginner-friendly walkthrough of the entire project, from physical hardware to every line of logic.

---

## Table of Contents

| Section | What You'll Learn |
|---|---|
| [1. What Does This Project Do?](#1-what-does-this-project-do) | The big picture in plain English |
| [2. What Hardware Do You Need?](#2-what-hardware-do-you-need) | Physical components list |
| [3. How to Use It](#3-how-to-use-it) | Operating the board after programming |
| [4. Background: FPGAs and Verilog](#4-background-fpgas-and-verilog) | Core concepts before reading code |
| [5. Background: The Camera](#5-background-the-camera) | How the OV7670 works |
| [6. Background: VGA](#6-background-vga) | How the monitor standard works |
| [7. Background: Block RAM and Clocks](#7-background-block-ram-and-clocks) | Memory and timing inside the FPGA |
| [8. System Architecture](#8-system-architecture) | How all the pieces connect |
| [9. Module-by-Module Walkthrough](#9-module-by-module-walkthrough) | Every Verilog file explained |
| [10. Key Concepts Deep-Dive](#10-key-concepts-deep-dive) | Technical details for curious readers |

---

## 1. What Does This Project Do?

This project turns a Basys 3 FPGA board into a **live camera + monitor system**:

- An **OV7670 camera module** captures video and streams raw pixels to the FPGA.
- The FPGA **stores** each frame in its internal memory.
- It **applies a real-time image filter** chosen by the user.
- It **displays** the result on a VGA monitor at 60 frames per second.

In short: **camera → FPGA → filtered live video → monitor.**

```
 ┌──────────────┐    video bytes    ┌─────────────────────────────┐
 │  OV7670      │ ──────────────►  │         Basys 3 FPGA        │
 │  Camera      │                  │                             │
 └──────────────┘                  │  Capture → Store → Filter  │
                                   │                             │
 ┌──────────────┐    RGB + sync    │                             │
 │  VGA Monitor │ ◄──────────────  │                             │
 └──────────────┘                  └─────────────────────────────┘
```

---

## 2. What Hardware Do You Need?

| Hardware | Description |
|---|---|
| **Basys 3 board** | The FPGA development board (Xilinx Artix-7 chip) |
| **OV7670 camera module** | A small, cheap parallel-output camera |
| **VGA monitor** | Any monitor with a VGA input |
| **VGA cable** | Standard DB-15 connector |
| **USB cable** | To program the Basys 3 from your PC |
| **Jumper wires** | To connect the camera to the Basys 3 Pmod headers |

---

## 3. How to Use It

Once the FPGA is programmed with the bitstream:

1. **Power on** the Basys 3 via USB.
2. The camera initializes automatically — takes about 1–2 seconds.
3. Live video appears on the VGA monitor.
4. Use **slide switches SW0 and SW1** to pick a filter:

| SW1 | SW0 | Filter |
|-----|-----|--------|
| 0 | 0 | Raw (normal color, no processing) |
| 0 | 1 | Grayscale (black-and-white) |
| 1 | 0 | Red channel only |
| 1 | 1 | Color inversion (like a photo negative) |

5. Press the **center button (BTNC)** to reset if the image looks wrong.

---

## 4. Background: FPGAs and Verilog

### What Is an FPGA?

An **FPGA** (Field-Programmable Gate Array) is a chip you configure to behave like almost any digital circuit. Unlike a CPU — which runs software instructions one at a time — an FPGA implements hardware logic directly as wires and gates, configured anew each time you program it.

| | CPU | FPGA | ASIC |
|---|---|---|---|
| What it is | General processor | Reprogrammable logic chip | Fixed-purpose chip |
| Speed | Moderate (runs code) | Very fast (parallel hardware) | Fastest |
| Flexibility | Fully flexible | Reprogrammable | Fixed forever |
| Example | Your laptop | This project | iPhone chip |

**Key idea:** When you write Verilog for an FPGA, you describe *what hardware to build*, not *what instructions to run*. Everything runs in parallel — there is no "line 1 before line 2."

### What Is Verilog?

**Verilog** is a Hardware Description Language (HDL). It looks like code, but actually describes circuits.

- A `module` is like a chip with specific inputs and outputs.
- `always @(posedge clk)` means "on every rising clock edge, do this" — this is how flip-flops (memory elements) are described.
- `assign` describes combinational logic (wires and gates, no memory).
- Multiple `always` blocks run **simultaneously** — they are parallel hardware.

### The Basys 3 Board

```
┌─────────────────────────────────────────────┐
│                  Basys 3                    │
│                                             │
│  [USB/JTAG]  [VGA port]  [Pmod headers]    │
│                                             │
│  ■ Xilinx Artix-7 FPGA (xc7a35t)          │
│  ■ 16 slide switches (SW0–SW15)            │
│  ■ 5 push buttons (BTNC = center/reset)    │
│  ■ 16 LEDs                                 │
│  ■ 12 Pmod connector ports                 │
└─────────────────────────────────────────────┘
```

The Artix-7 chip inside has:
- ~33,000 logic cells (the reprogrammable switches)
- **Block RAM (BRAM):** 1,800 Kbits of fast on-chip memory
- **DSP slices:** Hardware multipliers
- **MMCM/PLL:** Clock generation circuits (used to make 25 MHz and 24 MHz from the 100 MHz oscillator)

---

## 5. Background: The Camera

The **OV7670** is a cheap (≈$2) image sensor that sends video as raw digital bytes.

- **Resolution:** 640×480 pixels, but this project downsamples to **320×240**.
- **Output format:** 8 data pins (`D0`–`D7`), sending one byte at a time. Two bytes make one pixel (16-bit **RGB565** format — explained in Section 10).
- **Sync signals:**
  - `HREF` — High when a valid row of pixels is being transmitted
  - `VSYNC` — Pulses once per frame to indicate a new frame is starting
- **Control interface:** SCCB (a 2-wire serial bus nearly identical to I2C). The FPGA uses this to configure the camera on startup.
- **Clock:** The camera needs a master clock from the FPGA (`XCLK`). It then generates its own output clock (`PCLK`) to say "data is ready now."

---

## 6. Background: VGA

**VGA** is a classic analog video standard from 1987, still widely supported. The Basys 3 has a built-in VGA port with a resistor ladder that converts 4-bit digital values to analog voltages.

VGA carries five signals:
- **R, G, B** — analog color voltages (this project uses 4-bit values per channel, resistor-ladder converted)
- **HSYNC** — a pulse at the end of each horizontal line
- **VSYNC** — a pulse at the end of each frame

The 640×480 @ 60 Hz standard requires a **25 MHz pixel clock** — one pixel per clock cycle. The monitor expects precise timing; wrong timing produces no image or a scrambled one.

**One horizontal line is not just 640 pixels wide** — it includes "blank" periods on both sides where the FPGA is not sending visible pixels. These are called porches:

```
        640 active            16    96     48
┌──────────────────────────┬────┬──────┬──────┐
│    Visible pixels        │ FP │HSYNC │  BP  │
└──────────────────────────┴────┴──────┴──────┘
Total = 800 pixel clocks per line
```

Similarly, a full frame is 525 lines total (480 visible + 45 blank). This gives:
```
800 × 525 = 420,000 clocks per frame
25,000,000 Hz ÷ 420,000 ≈ 59.5 Hz (close enough to 60 Hz for monitors)
```

---

## 7. Background: Block RAM and Clocks

### What Is BRAM?

**Block RAM (BRAM)** is fast memory built into the FPGA. Unlike external RAM on a laptop, BRAM:
- Is accessed in **one clock cycle**
- Can have **two independent ports** — one reads while the other writes, on different clocks simultaneously
- Has limited capacity — the Artix-7 has 1,800 Kbits total

This project uses BRAM as a **frame buffer**: the camera writes pixels into it at the same time the display reads from it, using different ports and different clocks. This is called **true dual-port, dual-clock BRAM**.

Frame buffer size:
```
320 pixels wide × 240 pixels tall × 16 bits/pixel
= 76,800 pixels × 16 bits
= 1,228,800 bits ≈ 1.2 Mbits   ← fits in the 1,800 Kbits available
```

### What Is a Clock Domain?

A **clock** is a regular on/off signal. All flip-flops that share a clock signal are in the same **clock domain**. This project has three independent clocks:

| Clock | Frequency | Purpose |
|---|---|---|
| `clk_100mhz` | 100 MHz | System clock, camera configuration |
| `pixel_clk` | 25 MHz | VGA output and display logic |
| `cam_pclk` | ~12–25 MHz | Camera pixel capture (comes from the camera itself) |

When a signal crosses from one clock domain to another, **metastability** can occur — a flip-flop samples a changing signal and gets stuck in an undefined state, producing garbage output. Special techniques (described in Section 10) are used to prevent this.

### How 25 MHz and 24 MHz Clocks Are Generated

The Basys 3 has a 100 MHz crystal oscillator. A built-in **Clocking Wizard** IP (MMCM — Mixed-Mode Clock Manager) divides and multiplies this to produce:
- **25 MHz** → for VGA pixel timing (`pixel_clk`)
- **24 MHz** → sent out to the camera as its master clock (`cam_xclk`)

---

## 8. System Architecture

### Big Picture

```
                         ┌─────────────────────────────────────────────────┐
                         │                  Basys 3 FPGA                  │
                         │                                                 │
 OV7670 Camera           │  ┌─────────────┐      ┌─────────────────────┐  │
 ┌──────────────┐        │  │  ov7670     │      │   VGA Pipeline      │  │
 │              │ 8 data │  │  capture    │      │                     │  │
 │  cam_d[7:0]  │───────►│  │             │      │  display_scaler     │  │
 │  cam_href    │───────►│  │  (cam_pclk) │◄────►│  + filter_engine   │  │
 │  cam_vsync   │───────►│  └──────┬──────┘ BRAM │  (pixel_clk)       │  │
 │  cam_pclk    │───────►│         │              └─────────────────────┘  │
 │              │        │  ┌──────▼──────┐                               │
 │  cam_xclk   ◄│────────│  │  ov7670     │                               │
 │  cam_scl    ◄│────────│  │  config +   │                               │
 │  cam_sda   ◄►│────────│  │  sccb_master│                               │
 └──────────────┘        │  │  (100 MHz)  │                               │
                         │  └─────────────┘                               │
                         └──────────────────┬──────────────────────────────┘
                                            │ VGA (R[3:0], G[3:0], B[3:0], HSYNC, VSYNC)
                                            ▼
                                     VGA Monitor
```

### Step-by-Step Data Flow

#### Step 1 — Camera Configuration (once at startup, 100 MHz domain)

- `ov7670_config` sequences through 70 register writes to the camera.
- Each write is sent over the SCCB serial bus by `sccb_master`.
- This programs the camera to output RGB565 format at 640×480.
- Takes ~200 ms to complete.

#### Step 2 — Pixel Capture (continuous, cam_pclk domain)

- `ov7670_capture` reads 8-bit bytes from `cam_d[7:0]` on each falling edge of `cam_pclk`.
- Every two bytes combine into one 16-bit RGB565 pixel.
- Only even-numbered pixels and even-numbered rows are kept, downsampling 640×480 → 320×240.
- Each accepted pixel is written to the **frame buffer BRAM** (Port A).
- A `frame_done` pulse fires at the end of each frame.

#### Step 3 — Frame Buffer (the shared memory)

The BRAM has two independent ports running simultaneously:
- **Port A (write):** `ov7670_capture` writes new pixels (cam_pclk clock)
- **Port B (read):** `display_scaler` reads pixels to display (pixel_clk clock)

#### Step 4 — Cross-Domain Handoff

The `frame_done` pulse cannot cross directly between cam_pclk and pixel_clk (different clocks = metastability risk). The solution:

```
cam_pclk domain:          pixel_clk domain:
  frame_done              3-stage synchronizer    edge detector
  → toggle flip-flop  ──► [FF0] → [FF1] → [FF2] → XOR → frame_done_pix
                                                          → frame_valid (sticky)
```

`frame_valid` goes high after the first complete frame arrives and stays high forever, preventing garbage from being displayed at startup.

#### Step 5 — Display Pipeline (continuous, pixel_clk domain)

- `vga_controller` counts pixels left-to-right (`hcount` 0–799) and lines top-to-bottom (`vcount` 0–524).
- `display_scaler` maps each screen position to a frame buffer address, applies rotation/scale, reads the pixel.
- `filter_engine` modifies the pixel based on the switch settings.
- The result drives the 4-bit VGA DACs on the Basys 3.

#### Step 6 — VGA Sync Alignment

The display pipeline has a **3-cycle latency** (2 cycles from BRAM + 1 from the output register). The HSYNC and VSYNC signals are delayed 3 cycles to stay aligned with the pixel data:

```verilog
// In top.v: shift register that delays sync signals
hsync_delay <= {hsync_delay[2:0], hsync_raw};
assign vga_hsync = hsync_delay[2];   // 3-cycle delay
```

### Clock Domains Map

```
┌─────────────────────────────────────────────────────────────┐
│  Clock         │ Frequency │  Used By                      │
├─────────────────────────────────────────────────────────────┤
│  clk_100mhz    │  100 MHz  │  sccb_master, ov7670_config,  │
│  (board osc)   │           │  reset counter                │
├─────────────────────────────────────────────────────────────┤
│  pixel_clk     │  25 MHz   │  vga_controller,              │
│  (from MMCM)   │           │  display_scaler,              │
│                │           │  filter_engine, BRAM Port B   │
├─────────────────────────────────────────────────────────────┤
│  cam_pclk      │ ~12–25MHz │  ov7670_capture, BRAM Port A  │
│  (from camera) │           │                               │
└─────────────────────────────────────────────────────────────┘

cam_xclk (24 MHz from MMCM) → driven OUT to camera via ODDR primitive
```

---

## 9. Module-by-Module Walkthrough

### `top.v` — The Master Wiring File

**Role:** Plugs all other modules together. Contains no significant application logic — it is the "circuit board" that connects everything.

**What it does:**
- Instantiates the Clocking Wizard (`clk_wiz_0`): 100 MHz → 25 MHz pixel_clk + 24 MHz cam_xclk
- Drives `cam_xclk` through an **ODDR** (Output Double-Data-Rate) primitive to guarantee a clean 50% duty cycle on the physical pin
- Manages **power-on reset**: a 24-bit counter counts ~168 ms at 100 MHz while waiting for the PLL to lock, then releases reset to all modules
- Synchronizes `global_rst` into `pixel_clk` and `cam_pclk` domains using 2-FF synchronizers
- Implements the **toggle CDC** for `frame_done` (see Section 10)
- Delays HSYNC/VSYNC by 3 cycles to match the display pipeline latency

**Key I/O:**

| Signal | Direction | Description |
|---|---|---|
| `clk_100mhz` | in | 100 MHz board oscillator (pin W5) |
| `rst` | in | Center button BTNC, active-high |
| `cam_d[7:0]` | in | 8-bit pixel data from camera |
| `cam_pclk` | in | Pixel clock from camera |
| `cam_xclk` | out | 24 MHz master clock to camera |
| `vga_r/g/b[3:0]` | out | 4-bit RGB to VGA DAC |
| `vga_hsync/vsync` | out | VGA sync signals |
| `sw[1:0]` | in | Filter selection |

---

### `ov7670_capture.v` — Camera Pixel Reader

**Role:** Reads the raw byte stream from the OV7670 and writes complete pixels to the frame buffer.

**Clock domain:** `cam_pclk` — runs on the **falling edge** (`negedge pclk`). This is intentional: the camera places valid data before the falling edge, so sampling there gives more timing margin.

**How it works:**

The OV7670 sends one byte at a time. Every pixel is 16 bits (2 bytes) in RGB565 format:

```
Byte 1 captured first    Byte 2 captured second
[ R4 R3 R2 R1 R0 G5 G4 G3 ]   [ G2 G1 G0 B4 B3 B2 B1 B0 ]
Combined: {first_byte, second_byte} = 16-bit RGB565
```

The module then decides whether to store this pixel:
- Only pixels where `h_cnt` (horizontal index) is even **and** `v_cnt` (vertical index) is even are stored.
- This discards every other pixel in each direction: 640×480 → 320×240.
- **Edge-guarding crop:** Skips pixels where `h_cnt < 4` or `v_cnt < 4` to discard the OV7670's dummy calibration data that causes stripes at the image border.

The write address into BRAM uses slot addressing to map the clean window:
```
addr = ((v_cnt/2) - 2) × 320 + ((h_cnt/2) - 2)
```

At the end of each frame (when `cam_vsync` falls), it pulses `frame_done` for one cycle.

---

### `sccb_master.v` — Camera Serial Bus Controller

**Role:** Sends configuration commands to the OV7670 over a 2-wire serial interface.

**Clock domain:** `clk_100mhz`

**What SCCB is:**
SCCB (Serial Camera Control Bus) is nearly identical to I2C. Two wires:
- `SCL` — clock line, controlled by the FPGA
- `SDA` — data line, driven by the FPGA

Each transaction sequence: START → camera address (`0x42`, the 8-bit write form of 7-bit address `0x21`) → register address → data byte → STOP.

**Clock generation:**
The module divides 100 MHz to produce ~100 kHz SCCB clock using a counter:
```
Quarter-period count = 100 MHz / (100 kHz × 4) = 250 counts
```
Each SCCB clock period has 4 phases: SCL-low / change-SDA / SCL-rise / SCL-high.

**State machine:** 10 states: IDLE → START → ID byte → don't-care bit → REG byte → don't-care bit → DATA byte → don't-care bit → STOP → DONE.

Outputs a `done` pulse when the transaction completes, and `ack_err` if the camera didn't acknowledge.

---

### `ov7670_config.v` — Camera Configuration Sequencer

**Role:** Sends 70 register writes to the OV7670 on startup.

**Clock domain:** `clk_100mhz`

**Sequence:**
1. Sends a **soft reset** (`COM7 register = 0x80`) first to put the camera in a known state.
2. Waits ~2 ms for the reset to complete (OV7670 requires ≥2 ms between SCCB writes).
3. Sends 69 more register writes, one per `sccb_done` acknowledgment.

**What gets configured:**
- Output format: RGB565 (2 bytes per pixel)
- Resolution: 640×480 active area
- Color matrix: corrects the camera's natural greenish color bias
- Auto Exposure (AEC), Auto Gain (AGC), Auto White Balance (AWB)
- Gamma curve (16-point tone mapping)
- Saturation boost and noise reduction

---

### `frame_buffer.v` — BRAM Wrapper

**Role:** Wraps the Xilinx Block RAM IP core (`blk_mem_gen_0`) with a clean interface.

**Memory spec:**
- 76,800 addresses × 16 bits = one 320×240 frame in RGB565
- True dual-port: Port A and Port B are completely independent (different clocks, simultaneous access)

**Port A (write):**
- Clock: `cam_pclk`
- `addra [16:0]` — write address
- `dina [15:0]` — pixel data in
- `wea` — write enable

**Port B (read):**
- Clock: `pixel_clk`
- `addrb [16:0]` — read address (computed by display_scaler)
- `doutb [15:0]` — pixel data out (registered — 1-cycle latency)

---

### `vga_controller.v` — VGA Timing Generator

**Role:** Generates pixel counters and sync pulses for a standard 640×480 @ 60 Hz VGA signal.

**Clock domain:** `pixel_clk` (25 MHz)

**How it works:**

Two counters sweep through all positions on screen:
- `hcount`: 0–799 (800 total, 640 visible)
- `vcount`: 0–524 (525 total, 480 visible)

`hcount` increments every clock cycle; `vcount` increments when `hcount` wraps from 799 to 0.

**Sync signals** (active-low):
```
hsync = LOW  when hcount is in [656, 751]   (96-cycle pulse)
vsync = LOW  when vcount is in [490, 491]   (2-line pulse)
```

**`active`** is high only when `hcount < 640 AND vcount < 480` — the visible region. When `active` is low, the display_scaler outputs black.

---

### `display_scaler.v` — Screen Mapper

**Role:** For each VGA screen position, reads the correct frame buffer pixel and outputs it through the filter.

**Clock domain:** `pixel_clk`

**The transformation:**

Instead of simple pixel doubling, this module applies **90° clockwise rotation + horizontal mirror + 1.5× scaling** to correct for the physical camera mounting orientation. It also centers the resulting 360×480 image on the 640×480 screen with a 140-pixel left margin.

The math for each (hcount, vcount):
```
screen_x = hcount - 140           (remove left margin)
scaled_x = screen_x × 171 / 256  (divide by 1.5)
scaled_y = vcount   × 171 / 256

img_x = scaled_y   (rotation maps Y → X)
img_y = scaled_x   (rotation maps X → Y)

BRAM address = img_y × 320 + img_x
             = (img_y << 8) + (img_y << 6) + img_x
```

**Pipeline (2 registered stages):**
```
Cycle 0: Compute address combinationally, send to BRAM
Cycle 1: BRAM outputs data (registered output)
Cycle 2: Filter applied, output to VGA pins (registered)
```
This 2-cycle latency is compensated by the 3-cycle sync delay in `top.v`.

Only pixels in the 140–499 horizontal range are displayed; outside this range, the output is black (letterbox bars).

---

### `filter_engine.v` — Image Filter

**Role:** Applies the selected image filter to a 16-bit RGB565 pixel. Pure **combinational** logic — zero clock cycles, zero latency.

**Input:** `pixel_in[15:0]` — pixel from BRAM
**Output:** `pixel_out[15:0]` — filtered pixel
**Control:** `sw[1:0]`

**The four filters:**

```
sw = 00  Raw
     pixel_out = pixel_in       (no change)

sw = 01  Grayscale (Rec.601 approximation)
     Y = (R5×54 + G6×183 + B5×18) >> 8
     pixel_out = {Y_5bit, Y_6bit, Y_5bit}  (same brightness on all channels → gray)

sw = 10  Red channel only
     pixel_out = {r5, 6'b0, 5'b0}          (keep red, zero green and blue)

sw = 11  Color inversion
     pixel_out = ~pixel_in                 (flip every bit → photo negative)
```

---

### `constraints.xdc` — Pin Assignment File

**Role:** Maps Verilog port names to physical FPGA pins. Not Verilog code — Tcl syntax read by Vivado.

**Key pin assignments:**

| Signal | Pin | Notes |
|---|---|---|
| `clk_100mhz` | W5 | 100 MHz board oscillator |
| `vga_r[3:0]` | G19–N19 | 4-bit red DAC |
| `vga_g[3:0]` | J17–H17 | 4-bit green DAC |
| `vga_b[3:0]` | J18–L18 | 4-bit blue DAC |
| `vga_hsync` | P19 | VGA HSYNC |
| `vga_vsync` | R19 | VGA VSYNC |
| `cam_xclk` | C15 | 24 MHz clock to camera |
| `cam_d[7:0]` | P17–B16 | 8-bit parallel data from camera |
| `cam_href` | A17 | Camera line-valid |
| `cam_pclk` | A16 | Camera pixel clock |
| `cam_vsync` | B15 | Camera frame-valid |
| `cam_scl` | A14 | SCCB clock |
| `cam_sda` | A15 | SCCB data |
| `sw[0]`, `sw[1]` | V17, V16 | Filter selection |
| `rst` (BTNC) | U18 | Reset button |

The file also marks `cam_pclk` and `pixel_clk` as **asynchronous clocks** so Vivado doesn't analyze timing paths between them (they don't need to be in sync — the CDC logic handles that).

---

## 10. Key Concepts Deep-Dive

### RGB565 — How Color Fits in 16 Bits

Standard 24-bit color uses 8 bits per channel (R, G, B). That would need 4.7 Mbits for 320×240 — more than the BRAM. Instead, the camera uses **RGB565** (16 bits per pixel):

```
Bit:  15 14 13 12 11 | 10  9  8  7  6  5 |  4  3  2  1  0
      ─────────────────────────────────────────────────────
      R4 R3 R2 R1 R0   G5 G4 G3 G2 G1 G0   B4 B3 B2 B1 B0
      ─── Red (5 bits) ── ── Green (6 bits) ─ ─ Blue (5 bits) ─
```

Green gets an extra bit because human eyes are most sensitive to green.

**Extracting components in Verilog (from filter_engine.v):**
```verilog
wire [4:0] r5 = pixel_in[15:11];  // top 5 bits
wire [5:0] g6 = pixel_in[10:5];   // middle 6 bits
wire [4:0] b5 = pixel_in[4:0];    // bottom 5 bits
```

**Converting to 4-bit VGA (from display_scaler.v):**
```verilog
vga_r <= filtered_pixel[15:12];  // top 4 of R's 5 bits
vga_g <= filtered_pixel[10:7];   // top 4 of G's 6 bits
vga_b <= filtered_pixel[4:1];    // top 4 of B's 5 bits
```

---

### Clock Domain Crossing — The Toggle Trick

When a signal crosses from one clock domain to another, there is a risk of **metastability**: a flip-flop samples a signal that is changing exactly at the clock edge, leaving its output in an undefined voltage. The flip-flop can take a very long time to settle — long enough to corrupt downstream logic.

**Standard fix for stable signals:** a 2- or 3-stage synchronizer (several flip-flops in series, all clocked by the destination domain). Each stage gives the signal more time to settle.

**Problem with short pulses:** A 1-cycle pulse in cam_pclk might be missed entirely by pixel_clk (different rates, not aligned).

**The toggle technique solves this:**

```
cam_pclk domain:
  On each frame_done pulse:
    frame_done_toggle <= ~frame_done_toggle   ← flips between 0 and 1

pixel_clk domain:
  fd_sync <= {fd_sync[1:0], frame_done_toggle}  ← 3-stage synchronizer

  frame_done_pix = fd_sync[2] ^ fd_sync[1]      ← XOR detects a toggle
  This pulse = "a new frame arrived safely"
```

The toggle stays at its new value until the next frame, making it stable long enough for the 3 synchronizer FFs to capture it reliably.

After the first frame, `frame_valid` goes high permanently, telling the display "real data is available — show it."

---

### VGA Timing in Detail

```
One horizontal line (800 pixel clocks):

  hcount:    0                639 | 640 655 | 656      751 | 752   799 |
             ──────────────────── | ─────── | ─────────── | ───────── |
  region:      Visible (640)      |  Front  |    HSYNC    |   Back    |
                                  |  Porch  |   (active   |   Porch   |
                                  |  (16)   |    low, 96) |   (48)    |
  active:    ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾_________________________________________
  hsync:     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾___________________________‾‾‾‾

One full frame (525 lines):

  vcount:    0..479 visible  →  480..489 front porch  →  490..491 vsync  →  492..524 back porch
```

The monitor (originally designed for CRT electron beams) needs the blank periods so the beam can reset position. Modern LCD monitors maintain the same protocol for compatibility.

---

### The Grayscale Formula (Rec.601)

Human eyes are not equally sensitive to all colors. The Rec.601 standard defines the correct weighting:
```
Y = 0.299 × R + 0.587 × G + 0.114 × B
```

Floating-point math is expensive in hardware. The design approximates with integers (from filter_engine.v):
```verilog
wire [13:0] y_scaled = (r5 * 14'd54) + (g6 * 14'd183) + (b5 * 14'd18);
wire [5:0]  y_6bit   = y_scaled[13:8];   // equivalent to >> 8
wire [4:0]  y_5bit   = y_6bit[5:1];

// Then replicate across all channels:
pixel_out = {y_5bit, y_6bit, y_5bit};    // R=G=B → gray
```

Checking: 54/256 ≈ 0.21, 183/256 ≈ 0.71, 18/256 ≈ 0.07 — reasonable Rec.601 approximation.

---

### Reset Synchronization

When power is applied:
1. The PLL (which generates pixel_clk and cam_xclk) needs time to **lock**.
2. Using the output clocks before lock gives undefined behavior.

**The design's approach (from top.v):**
```verilog
// Count ~168 ms at 100 MHz (2^24 cycles)
if (rst || !pll_locked)
    rst_cnt <= 0;
else if (rst_cnt < 24'hFFFFFF)
    rst_cnt <= rst_cnt + 1;
else
    global_rst <= 0;   // release reset only after PLL locks AND counter done
```

Then `global_rst` is re-synchronized into each clock domain through 2-FF chains before reaching any module in that domain.

---

### Downsampling and Pixel Doubling

**Why downsample?**
Storing 640×480 would need 4.7 Mbits. BRAM only has 1.8 Mbits. Keeping every other pixel and every other line gives 320×240 = 1.2 Mbits — it fits.

**In capture (from ov7670_capture.v):**
```verilog
if (h_cnt[0] == 1'b0 && v_cnt[0] == 1'b0) begin
    // only store even-column, even-row pixels
end
```

**On the display side:** The `display_scaler` maps the 320×240 buffer back to the 640×480 screen using the 1.5× scaling + rotation transform rather than simple 2× doubling, which also corrects the camera's physical orientation.

---

*End of Project Guide*