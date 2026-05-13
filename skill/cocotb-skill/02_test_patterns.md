# Common Cocotb Test Patterns

## Pattern 1: LFSR Test (P1 Skilltest)

Testing a 16-bit Linear Feedback Shift Register with reset and enable:

```python
import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def tb_1(dut):
    """Test reset functionality"""
    dut._log.info("Starting Test 1")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Initialize and reset
    dut.reset.value = 1
    dut.enable.value = 0
    await Timer(10, units="ns")
    dut.reset.value = 0

    # Verify reset state
    await Timer(10, units="ns")
    assert dut.lfsr_out.value == 0xffff, "Reset Fail: LFSR should be 0xFFFF"

@cocotb.test()
async def tb_2(dut):
    """Test LFSR sequence"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    expected_output = [0xfffe, 0xfffc, 0xfff8, 0xfff0, 0xffe1]
    
    # Initialize
    dut.reset.value = 1
    dut.enable.value = 0
    await Timer(10, units="ns")
    dut.reset.value = 0

    # Test sequence
    for i in range(len(expected_output)):
        dut.enable.value = 1
        await Timer(10, units="ns")
        assert dut.lfsr_out.value == expected_output[i], \
            f"LFSR Test Fail: Expected {expected_output[i]:#06x}"
```

## Pattern 2: FSM State Testing (P3 Skilltest)

Helper function for structured state-based testing:

```python
async def apply_and_check(dut, inp, out, state_comment):
    """Helper to apply input and verify output"""
    dut.inp.value = inp
    await Timer(5, units="ns")
    dut._log.info(f"State: {state_comment}, Input: {inp}, Expected Output: {out}")
    assert dut.out.value == out, f"{state_comment} Fail: Output should be {out}"
    await Timer(5, units="ns")

@cocotb.test()
async def tb_abc(dut):
    """Test state machine transitions"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset sequence
    dut.reset.value = 1
    dut.inp.value = 0
    await Timer(20, units="ns")
    dut.reset.value = 0
    await Timer(12, units="ns")
    
    # Test transitions
    await apply_and_check(dut, 0, 0, "A->A")
    await apply_and_check(dut, 1, 1, "A->B")
    await apply_and_check(dut, 0, 0, "B->B")
    await apply_and_check(dut, 0, 0, "C->A")
```

## Pattern 3: Counter Test (Lab1 Part3)

Testing with RisingEdge and ReadOnly triggers:

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly

@cocotb.test()
async def counter_test(dut):
    """Test BCD counter with reset and enable"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    enable = (0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0)
    reset = (0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    output = (0, 0, 0, 0, 1, 2, 2, 3, 0, 1, 1, 1)
    
    for i in range(len(enable)):
        await RisingEdge(dut.clk)
        await Timer(2, units='ns')
        dut.reset.value = reset[i]
        dut.enable.value = enable[i]
        assert dut.counter_value.value == output[i]
```

## Pattern 4: Moore FSM Test (Lab2)

State encoding and verification:

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly

state_map = {
    0: 0b000, 1: 0b011, 2: 0b100,
    3: 0b101, 4: 0b010, 5: 0b001,
}

@cocotb.test()
async def moore_fsm_test(dut):
    clock = Clock(dut.clk, 10, unit="ns")
    clock.start()
    
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await ReadOnly()
    assert int(dut.out.value) == 0
    
    testing_set = (1, 0, 1, 1, 0)
    expected_states = (1, 2, 1, 2, 3)
    
    for i in range(len(testing_set)):
        await RisingEdge(dut.clk)
        dut['in'].value = testing_set[i]
        await ReadOnly()
        assert dut.out.value == state_map[expected_states[i]], \
            f"State mismatch at step {i}"
```

## Pattern 5: Bit-Accurate FF Test (Lab1 Part2)

Testing on both rising and falling edges:

```python
@cocotb.test()
async def jkff_test(dut):
    j = (0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0)
    k = (1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0)
    q = (None, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0)
    
    clock = Clock(dut.clk, 10, unit="ns")
    clock.start(start_high=False)
    
    for i in range(0, len(j), 2):
        dut.J.value = j[i]
        dut.K.value = k[i]
        await Timer(1, unit='ns')
        if q[i] is not None:
            assert dut.Q.value == q[i], f"[Assertion {i}] Expected q={q[i]}"
        await RisingEdge(dut.clk)
        
        if i+1 < len(j):
            dut.J.value = j[i+1]
            dut.K.value = k[i+1]
            await Timer(1, unit='ns')
            if q[i+1] is not None:
                assert dut.Q.value == q[i+1], f"[Assertion {i+1}] Expected q={q[i+1]}"
            await FallingEdge(dut.clk)
```