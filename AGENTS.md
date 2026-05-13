# Repository Guidelines

## Project Structure & Module Organization

This repository implements a Basys 3 FPGA video pipeline from an OV7670 camera to VGA output. Main RTL is in `hdl_sources/`: `top.v` wires the system together, while modules such as `ov7670_capture.v`, `sccb_master.v`, `frame_buffer.v`, `display_scaler.v`, `filter_engine.v`, and `vga_controller.v` cover the pipeline stages. Board constraints are in `hdl_sources/constraints.xdc`. Cocotb tests live in `sim/`, and generated simulator output goes to `sim_build/`. Vivado project files and reference material are in `project-description/`. Treat `ov7670_vga_system.gen/`, `.runs/`, `.cache/`, `.srcs/`, and `.ip_user_files/` as Vivado-generated outputs.

## Build, Test, and Development Commands

- `vivado project-description/ov7670_vga_system.xpr` opens the Vivado project for synthesis, implementation, and bitstream generation.
- `python sim/test_filter_engine.py` runs the filter combinational logic tests with the default simulator.
- `python sim/test_vga_controller.py` checks VGA counters, sync timing, and active-region behavior.
- `python sim/test_ov7670_capture.py` validates camera byte packing, downsampling, and write addressing.
- `python sim/test_sccb_master.py` tests SCCB transaction sequencing.
- `for t in sim/test_*.py; do python "$t"; done` runs all cocotb benches sequentially.

## Coding Style & Naming Conventions

Use the existing Verilog-2001 style: 4-space indentation, one module per file, lower_snake_case signals, explicit clock/reset names, and named port connections. Prefix instances with `u_`, for example `u_capture` or `u_vga`. Keep clock-domain names clear (`clk_100mhz`, `pixel_clk`, `cam_pclk`) and document CDC, timing latency, and generated-IP assumptions only where they affect hardware behavior.

## Testing Guidelines

Tests use cocotb with `cocotb_tools.runner` and are named `sim/test_<module>.py`. Add or update tests when changing video timing, SCCB state machines, capture addressing, filter math, reset handling, or clock-domain crossings. Keep Python reference models aligned with RTL formulas. No formal coverage threshold is defined, so use the existing per-module assertions as the baseline.

## Commit & Pull Request Guidelines

Git history is mostly short imperative messages, with some inconsistent placeholders. Prefer descriptive commits such as `Fix VGA sync alignment` or `Add OV7670 capture tests`. Pull requests should summarize the hardware behavior changed, list simulations run, note Vivado synthesis/implementation status when applicable, and include board-validation notes for Basys 3, OV7670, or VGA-visible changes.

## Agent-Specific Instructions

Do not hand-edit Vivado-generated outputs unless explicitly regenerating project artifacts. Preserve the true dual-port BRAM clock split and the `frame_done` CDC path when modifying the display or capture pipeline.
