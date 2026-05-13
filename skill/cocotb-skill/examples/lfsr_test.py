# LFSR Test Example (P1 Skilltest)
# Linear Feedback Shift Register verification

import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def tb_reset(dut):
    """Test reset functionality"""
    dut._log.info("----------------------------------------")
    dut._log.info("Starting Reset Test")
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.reset.value = 1
    dut.enable.value = 0
    await Timer(10, units="ns")
    dut.reset.value = 0

    await Timer(10, units="ns")
    assert dut.lfsr_out.value == 0xffff, "Reset Fail: LFSR should be 0xFFFF"

    dut._log.info("Reset Test Finished")
    dut._log.info("----------------------------------------")
    await Timer(50, units="ns")

@cocotb.test()
async def tb_lfsr_sequence(dut):
    """Test LFSR output sequence"""
    dut._log.info("----------------------------------------")
    dut._log.info("Starting LFSR Sequence Test")
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    expected_output = [
        0xfffe, 0xfffc, 0xfff8, 0xfff0, 0xffe1,
        0xffc3, 0xff87, 0xff0f, 0xfe1e, 0xfc3c,
        0xf878, 0xf0f0, 0xe1e1, 0xc3c2, 0x8784, 0x0f09
    ]

    dut.reset.value = 1
    dut.enable.value = 0
    await Timer(10, units="ns")
    dut.reset.value = 0

    for i in range(16):
        dut.enable.value = 1
        await Timer(10, units="ns")
        assert dut.lfsr_out.value == expected_output[i], \
            f"LFSR Test Fail: Expected {expected_output[i]:#06x}"
        dut.enable.value = 0
        await Timer(10, units="ns")

    dut._log.info("LFSR Sequence Test Finished")
    dut._log.info("----------------------------------------")
    await Timer(50, units="ns")