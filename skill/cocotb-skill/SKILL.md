---
name: cocotb
description: Comprehensive cocotb framework patterns for VHDL/Verilog verification using Python. Includes basic tests, UART testing, runner patterns, and examples from lab assignments. Use when writing hardware testbenches or verifying digital designs.
---

# Cocotb Hardware Verification Framework

## Overview
Cocotb is a coroutine-based cosimulation library for writing VHDL and Verilog testbenches in Python. This skill provides comprehensive patterns and examples for hardware verification.

## Project Structure
```
cocotb_project/
├── Makefile              # Build configuration (traditional approach)
├── top_module.v        # DUT (Design Under Test)
└── testbench/
    └── TB.py           # Python testbench
```

## Quick Start
Choose one of two approaches:

### 1. Traditional Makefile Approach
See [01_basics.md](01_basics.md) for Makefile and basic test structure.

### 2. Python Runner Approach
See [04_runner_patterns.md](04_runner_patterns.md) for self-contained Python testbenches.

## Test Pattern Categories
- [Basic Tests](01_basics.md) - Combinatorial and simple sequential tests
- [Common Patterns](02_test_patterns.md) - Clock-based, state machines, counters
- [UART Testing](03_uart_testing.md) - UART protocol verification
- [Runner Patterns](04_runner_patterns.md) - Python-only simulation flow

## Examples
See the `examples/` directory for complete testbenches from lab assignments covering:
- LFSR (Linear Feedback Shift Register)
- UART Receiver/Transmitter
- Counters and FSMs
- Combinatorial logic verification