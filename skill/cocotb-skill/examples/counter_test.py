# Counter Test Example (Lab1 Part3)
# BCD counter with reset and enable control

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import os
from pathlib import Path
from cocotb_tools.runner import get_runner

@cocotb.test()
async def counter_test(dut):
    """Test BCD counter with reset and enable"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Test vectors: (enable, reset, expected_output)
    test_vectors = [
        (0, 0, 0), (0, 1, 0), (0, 0, 0),  # Reset on 2nd cycle
        (1, 0, 0), (1, 0, 1), (1, 0, 2),  # Count up
        (1, 0, 3), (1, 0, 4), (1, 0, 5),
        (1, 0, 6), (1, 0, 7), (1, 0, 8),
        (1, 0, 9), (1, 0, 0),  # Rollover with carry
        (1, 0, 1),
    ]
    
    for enable, reset, expected in test_vectors:
        await RisingEdge(dut.clk)
        await Timer(2, units='ns')
        dut.reset.value = reset
        dut.enable.value = enable
        assert dut.counter_value.value == expected, \
            f"Counter mismatch: expected {expected}, got {dut.counter_value.value}"

def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "../src/counter.v"]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="counter",
        always=True,
        waves=True,
        timescale=('1ns', '1ps')
    )
    runner.test(
        hdl_toplevel="counter",
        test_module="counter_test",
        waves=True
    )

if __name__ == "__main__":
    runner()