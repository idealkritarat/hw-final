# Python Runner Patterns for Cocotb

The Python runner approach uses `cocotb_tools.runner` to create self-contained testbenches that can run without Makefiles.

## Basic Runner Structure

```python
import os
from pathlib import Path
from cocotb_tools.runner import get_runner

def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    
    # Source files
    sources = [proj_path / "../src/module.v"]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="module_name",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )
    runner.test(
        hdl_toplevel="module_name",
        test_module="test_module_name",
        waves=True,
    )

if __name__ == "__main__":
    runner()
```

## Complete Testbench Template

```python
import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_name(dut):
    """Test description"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    # Reset sequence
    dut.reset.value = 1
    await Timer(50, unit="ns")
    dut.reset.value = 0
    
    # Test stimulus and verification
    # ... test code ...

def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "../src/module.v"]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="module_name",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )
    runner.test(
        hdl_toplevel="module_name",
        test_module="test_module",
        waves=True,
    )

if __name__ == "__main__":
    runner()
```

## Running Tests

```bash
# Run with default simulator (icarus)
python test_module.py

# Run with specific simulator
SIM=verilator python test_module.py

# Run with multiple simulators for comparison
for sim in icarus verilator; do
    SIM=$sim python test_module.py
done
```

## Multiple Source Files

```python
def runner():
    verilog_files = [
        "../src/top_module.v",
        "../src/submodule1.v",
        "../src/submodule2.v",
    ]
    
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / Path(f) for f in verilog_files]
    
    runner = get_runner(os.getenv("SIM", "icarus"))
    runner.build(
        sources=sources,
        hdl_toplevel="top_module",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )
```

## Using cocotbext Libraries

```python
# With cocotbext extensions (install via pip)
# pip install cocotbext-uart cocotbext-axi etc.

from cocotbext.uart import UartSource, UartSink

@cocotb.test()
async def test_with_extensions(dut):
    # UART at specific baud rate
    uart = UartSource(dut.serial_in, baud=115200, bits=8)
    
    # AXI4 interface
    from cocotbext.axi import AxiBus, AxiMaster
    axim = AxiMaster(AxiBus.from_prefix(dut, "axi"))
```

## Parameterized Modules

```python
def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "../src/parameterized_module.v"]
    
    # Parameters for the HDL module
    parameters = {
        'WIDTH': 8,
        'DEPTH': 16
    }
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="parameterized_module",
        parameters=parameters,  # Pass to build
        always=True,
        waves=True,
    )
    runner.test(
        hdl_toplevel="parameterized_module",
        test_module="test_module",
        parameters=parameters,  # Pass to test
    )
```

## Key Differences: Makefile vs Runner

| Feature | Makefile | Python Runner |
|---------|----------|--------------|
| Configuration | Makefile syntax | Python code |
| Multiple tests | One module per run | Multiple test functions |
| IDE integration | Limited | Full (breakpoints, debug) |
| Waveform viewing | gtkwave | gtkwave |
| Parameterization | Environment vars | Python variables |