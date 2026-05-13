# Cocotb Basics: Test Structure and Setup

## Makefile Configuration (Traditional Approach)

```makefile
# defaults
SIM ?= icarus                    # Simulator (icarus, verilator, questa, etc.)
TOPLEVEL_LANG ?= verilog        # Language: verilog or vhdl

# Source files
VERILOG_SOURCES += $(PWD)/../module.v

# Module names
TOPLEVEL = module_name           # Top-level HDL module name
MODULE = TB                      # Python test module name

WAVES = 1                        # Enable waveform dumping

# Include cocotb's make rules
include $(shell cocotb-config --makefiles)/Makefile.sim
```

## Basic Test Structure

```python
import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_name(dut):
    """Test description"""
    dut._log.info("Starting test")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Initialize inputs
    dut.reset.value = 1
    await Timer(10, units="ns")
    
    # Apply stimulus
    dut.reset.value = 0
    dut.enable.value = 1
    
    # Verify outputs
    await Timer(10, units="ns")
    assert dut.output.value == expected, "Error message"
```

## Key Concepts

### Clock Generation
```python
cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
```

### Timer Delays
```python
await Timer(10, units="ns")     # Time delay in nanoseconds
await Timer(1000, units="us")   # Microseconds
await Timer(1, units="ps")      # Picoseconds
```

### Signal Access
```python
dut.signal_name.value = 1        # Drive signal (binary, hex, or int)
x = dut.signal_name.value        # Read signal value

# Formatting values
dut.value = 0b1010               # Binary
dut.value = 0xFF                 # Hex
dut.value = 255                  # Decimal
```

### Logging
```python
dut._log.info("Message")
dut._log.error("Error message")
dut._log.debug("Debug info")
```

## Basic Test Examples

### Combinatorial Logic Test (XOR Gate)
```python
@cocotb.test()
async def test_xor(dut):
    """Test XOR gate with all input combinations"""
    for a in [0, 1]:
        for b in [0, 1]:
            dut.a.value = a
            dut.b.value = b
            await Timer(1, units="ns")
            assert dut.y.value == (a ^ b), f"XOR failed: {a} ^ {b}"
```

### Sequential Logic Test (Flip-Flop)
```python
@cocotb.test()
async def test_dff(dut):
    """Test D flip-flop with clock"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset sequence
    dut.d.value = 0
    dut.rst.value = 1
    await Timer(20, units="ns")
    dut.rst.value = 0
    
    # Test toggle
    dut.d.value = 1
    await Timer(20, units="ns")
    assert dut.q.value == 1, "Q should be 1"
```