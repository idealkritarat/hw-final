# UART Testing Patterns in Cocotb

## UART Receiver Test (P2 Skilltest)

Testing UART byte reception with bit timing simulation:

```python
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

# Global variables for monitoring
expected_data_values = 0
expected_data_valid = 0
expected_data_count = 0
actual_data_count = 0
BitDelayNs = int(1000000000 / 115200)  # 115200 baud

async def monitor_signals(dut):
    """Monitor DUT outputs for verification"""
    global expected_data_values, expected_data_valid, actual_data_count
    while True:
        await RisingEdge(dut.clk)
        if dut.RxD_data_ready.value == 1:
            if expected_data_valid == 1:
                assert dut.RxD_data.value == expected_data_values, \
                    f"Data mismatch: {dut.RxD_data.value} != {expected_data_values}"
                expected_data_valid = 0
                actual_data_count += 1
            else:
                assert False, f"Unexpected data received"

async def send_byte(dut, data):
    """Send a byte via UART (LSB first)"""
    global expected_data_values, expected_data_valid, expected_data_count
    
    expected_data_values = data
    expected_data_valid = 1
    data_byte = [(data >> i) % 2 for i in range(8)]
    
    # Start bit
    dut.RxD.value = 0
    await Timer(BitDelayNs, units="ns")
    
    # Data bits (LSB first)
    for i in range(8):
        dut.RxD.value = data_byte[i]
        await Timer(BitDelayNs, units="ns")
    
    # Stop bit
    dut.RxD.value = 1
    await Timer(BitDelayNs, units="ns")
    
    # Idle time
    await Timer(BitDelayNs, units="ns")
    expected_data_count += 1

@cocotb.test()
async def uart_rx_test(dut):
    """Test UART receiver with multiple bytes"""
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    cocotb.start_soon(monitor_signals(dut))
    
    dut.RxD.value = 1
    await Timer(2000, units="ns")
    
    # Send test bytes
    test_bytes = [0x55, 0x54, 0xFF, 0x00, 0xAA, 0xF0, 0x0F]
    for byte in test_bytes:
        await send_byte(dut, byte)
    
    await Timer(BitDelayNs * 12, units="ns")
    assert expected_data_count == actual_data_count, \
        f"Packet count mismatch: expected {expected_data_count}, got {actual_data_count}"
```

## Advanced UART Testing with cocotbext (Lab5)

Using the cocotbext library for higher-level UART testing:

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner
from cocotbext.uart import UartSource, UartSink
import random

@cocotb.test()
async def test_uart_rx_stress(dut):
    """Stress test: Send A-Z with random handshake timing"""
    
    # Start 100MHz Clock
    cocotb.start_soon(Clock(dut.Clk, 10, unit="ns").start())
    
    # Create UART Source for transmitting to DUT
    uart_source = UartSource(dut.Rx, baud=115200, bits=8)
    
    # Reset sequence
    dut.Reset.value = 1
    dut.DataReady.value = 0
    await Timer(50, unit="ns")
    dut.Reset.value = 0
    
    # Test string
    test_string = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    
    # Start background transmission
    cocotb.start_soon(uart_source.write(test_string))
    
    for char_code in test_string:
        # Wait for data valid
        await RisingEdge(dut.DataValid)
        received_val = int(dut.DataOut.value)
        assert received_val == char_code, f"Expected {char_code}, got {received_val}"
        
        # Random backpressure simulation
        wait_time = random.randint(0, 500)
        await Timer(wait_time, unit="ns")
        dut.DataReady.value = 1
        await FallingEdge(dut.DataValid)
        dut.DataReady.value = 0
```

```python
@cocotb.test()
async def test_uart_tx_stress(dut):
    """Test UART transmitter with handshake"""
    
    cocotb.start_soon(Clock(dut.Clk, 10, unit="ns").start())
    uart_sink = UartSink(dut.Tx, baud=115200, bits=8, stop_bits=1)
    
    # Reset
    dut.Reset.value = 1
    dut.DataValid.value = 0
    dut.fifo_empty.value = 1
    await Timer(50, unit="ns")
    dut.Reset.value = 0
    
    test_string = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    
    for char_code in test_string:
        # Provide data
        dut.DataIn.value = char_code
        dut.fifo_empty.value = 0
        dut.DataValid.value = 1
        
        # Wait for transmitter ready
        while str(dut.DataReady.value) != "1":
            await RisingEdge(dut.Clk)
        
        # Deassert valid
        await RisingEdge(dut.Clk)
        dut.DataValid.value = 0
        dut.fifo_empty.value = 1
        
        # Verify transmission
        received_val = await uart_sink.read(1)
        assert received_val[0] == char_code, f"TX mismatch: expected {char_code}"
        
        # Random idle gap
        await Timer(random.randint(1, 20) * 10, unit="ns")
```

## Makefile for UART Tests

```makefile
# UART Test Makefile
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../../asyncrx.v $(PWD)/../../async_receiver_tb.v
TOPLEVEL = async_receiver_tb
MODULE = TB

WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim
```