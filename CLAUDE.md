# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Real-time video capture and processing system on the **Basys 3 FPGA** (Artix-7). Captures RGB565 video from an OV7670 camera, stores frames in Block RAM, applies switchable image filters, and outputs to a VGA monitor at 640×480 @ 60 Hz.

## Build & Development

This project uses **Xilinx Vivado**. There is no Makefile — all synthesis, implementation, and bitstream generation are performed through Vivado GUI or Tcl scripts using the `.xpr` project file (`ov7670_vga_system.xpr`).

To open the project:
```
vivado ov7670_vga_system.xpr
```

All HDL source files are in `hdl_sources/`. IP cores (BRAM generator, Clocking Wizard) live under `ov7670_vga_system.gen/` and `ov7670_vga_system.ip_user_files/`.

Constraints are in `hdl_sources/constraints.xdc`.

## Architecture

### Clock Domains (4 total)

| Domain | Frequency | Source | Purpose |
|---|---|---|---|
| `clk_100mhz` | 100 MHz | Board oscillator (W5) | System clock |
| `pixel_clk` | 25 MHz | Clocking Wizard | VGA timing |
| `cam_xclk` | 24 MHz | Clocking Wizard (DDR out) | Camera master clock |
| `cam_pclk` | ~12–25 MHz | Camera (async input) | Pixel capture |

### Data Flow

```
OV7670 Camera
  │  (SCCB config on startup)
  │  sccb_master.v ← ov7670_config.v
  │
  │  (pixel stream, cam_pclk domain)
  ▼
ov7670_capture.v  ──write──►  frame_buffer.v (BRAM, dual-port)
                                      │
                              (read, pixel_clk domain)
                                      ▼
                             display_scaler.v
                                      │
                             filter_engine.v
                                      │
                             vga_controller.v ──► VGA output
```

### Module Roles

- **`top.v`** — Integrates all modules; instantiates Clocking Wizard and BRAM IP; handles `frame_done` CDC via toggle synchronizer + edge detector.
- **`ov7670_capture.v`** — Captures 8-bit pixel pairs from camera in cam_pclk domain; implements edge-guarding crop to discard OV7670 dummy calibration data; generates BRAM write addresses.
- **`ov7670_config.v`** — Sequences 69 SCCB register writes at startup; enforces ≥2 ms inter-transaction delays; drives RGB565 mode, AEC/AGC/AWB, gamma curve.
- **`sccb_master.v`** — SCCB (3-wire I2C-like) master; handles ACK error detection; `sccb_ack_err` wire declared at top.
- **`frame_buffer.v`** — Thin wrapper around `blk_mem_gen_0` (true dual-port BRAM); stores 320×240 × 16-bit pixels (~1.2 Mbits, fits in Basys3's 1.8 Mbits BRAM).
- **`vga_controller.v`** — Generates standard 640×480 @ 60 Hz sync signals; exposes `hcount [0:799]` and `vcount [0:524]`.
- **`display_scaler.v`** — Maps frame buffer to display: pixel doubling (`buf_col = hcount >> 1`, `buf_row = vcount >> 1`), applies 90° CW rotation + horizontal mirror + 1.5× scale. Has a **2-cycle pipeline latency** — HSYNC/VSYNC are delayed 2 cycles to match.
- **`filter_engine.v`** — Applies filter selected by `SW[1:0]`: `00`=raw, `01`=grayscale (Rec.601 approximation), `10`=red-only, `11`=inversion. Outputs 4-bit RGB for VGA DACs.

### Critical Design Details

**Clock domain crossing**: `frame_done` pulse crosses from cam_pclk to pixel_clk via a toggle synchronizer; an edge detector produces `frame_valid` which gates display until a complete frame is captured (prevents garbage at startup).

**Pipeline alignment**: The 2-cycle read latency through BRAM + display scaler means sync signals must be delayed 2 cycles to keep pixel data aligned with HSYNC/VSYNC edges. Any change to the display pipeline must preserve this alignment.

**Capture addressing**: The capture module uses deterministic slot addressing to convert the streaming pixel data into correct BRAM addresses. The edge-guarding crop discards rows/columns at the frame boundary to eliminate OV7670 calibration artifacts (stripes, corner noise).

**BRAM addressing**: Write side (cam_pclk), read side (pixel_clk) — both are asynchronous ports on the true dual-port BRAM. Read address is computed combinationally from VGA counters.

### User Controls (Basys 3)

- `SW[1:0]` — Filter selection (see filter_engine.v above)
- `SW[15]` — Reserved/reset-adjacent
- VGA output on standard Basys 3 VGA header pins
- Camera pins mapped in `constraints.xdc`
