# UART Receiver Test Example (P2 Skilltest - TB1/TB2)
# Tests UART byte reception with bit-accurate timing

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

# Global variables for monitoring
expected_data_values = 0
expected_data_valid = 0
expected_data_count = 0
actual_data_count = 0
BitDelayNs = int(1000000000 / 115200)  # 115200 baud = ~8681 ns per bit

async def monitor_signals(dut):
    """Monitor DUT outputs and verify received data"""
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
    
    # Start bit (low)
    dut.RxD.value = 0
    await Timer(BitDelayNs, units="ns")
    
    # Data bits (8 bits, LSB first)
    for i in range(8):
        dut.RxD.value = data_byte[i]
        await Timer(BitDelayNs, units="ns")
    
    # Stop bit (high)
    dut.RxD.value = 1
    await Timer(BitDelayNs, units="ns")
    
    # Idle time between bytes
    await Timer(BitDelayNs, units="ns")
    expected_data_count += 1

@cocotb.test()
async def uart_byte_test(dut):
    """Test UART receiver with multiple bytes"""
    dut._log.info("----------------------------------------")
    dut._log.info("Starting UART Byte Test")

    # Create clock and monitor
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
        f"Expected {expected_data_count} packets, received {actual_data_count}"

    dut._log.info("UART Byte Test Finished")
    dut._log.info("----------------------------------------")
    await Timer(50, units="ns")