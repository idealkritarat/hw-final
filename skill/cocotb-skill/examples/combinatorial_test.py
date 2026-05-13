# Combinatorial Logic Test Example
# Tests XOR/XNOR gates with all input combinations

import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_combinatorial(dut):
    """Test all input combinations for combinational logic"""
    
    # Truth table: (in1, in2, in3, expected_output)
    test_cases = [
        (0, 0, 0, 1),  # (0 XNOR 0) XOR 0 = 1 XOR 0 = 1
        (0, 0, 1, 0),  # (0 XNOR 0) XOR 1 = 1 XOR 1 = 0
        (0, 1, 0, 0),  # (0 XNOR 1) XOR 0 = 0 XOR 0 = 0
        (0, 1, 1, 1),  # (0 XNOR 1) XOR 1 = 0 XOR 1 = 1
        (1, 0, 0, 0),  # (1 XNOR 0) XOR 0 = 0 XOR 0 = 0
        (1, 0, 1, 1),  # (1 XNOR 0) XOR 1 = 0 XOR 1 = 1
        (1, 1, 0, 1),  # (1 XNOR 1) XOR 0 = 1 XOR 0 = 1
        (1, 1, 1, 0),  # (1 XNOR 1) XOR 1 = 1 XOR 1 = 0
    ]
    
    for in1, in2, in3, expected in test_cases:
        dut.in1.value = in1
        dut.in2.value = in2
        dut.in3.value = in3
        
        await Timer(1, unit="ns")
        
        actual = dut.out.value
        assert actual == expected, \
            f"Mismatch: in1={in1}, in2={in2}, in3={in3}, got {actual}, expected {expected}"
    
    dut._log.info("All 8 combinations passed!")


# Test for 4-bit full adder with exhaustive testing
import os
from pathlib import Path
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_full_adder_4bit(dut):
    """Test 4-bit full adder with all possible combinations"""
    
    passed_count = 0
    total_count = 0
    
    for a in range(16):
        for b in range(16):
            for cin in range(2):
                dut.a.value = a
                dut.b.value = b
                dut.cin.value = cin
                
                await Timer(1, unit="ns")
                
                result = a + b + cin
                expected_sum = result & 0xF
                expected_cout = (result >> 4) & 0x1
                
                total_count += 1
                
                assert int(dut.sum.value) == expected_sum, \
                    f"Sum mismatch at a={a}, b={b}, cin={cin}"
                assert int(dut.cout.value) == expected_cout, \
                    f"Cout mismatch at a={a}, b={b}, cin={cin}"
                passed_count += 1
    
    dut._log.info(f"All {passed_count}/{total_count} tests passed!")


def runner():
    verilog_files = ["../src/combinatorial.v"]
    runner = get_runner(os.getenv("SIM", "icarus"))
    runner.build(
        sources=[Path(__file__).resolve().parent / f for f in verilog_files],
        hdl_toplevel="combinatorial",
        always=True,
        waves=True,
    )
    runner.test(hdl_toplevel="combinatorial", test_module="__name__.replace('.py', '')")

if __name__ == "__main__":
    runner()