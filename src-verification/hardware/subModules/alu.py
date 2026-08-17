import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_alu_add(dut):
    dut.SrcA.value = 10
    dut.SrcB.value = 5
    dut.ALUControl.value = 0b000  # add
    await Timer(1, unit="ns")
    assert dut.ALUResult.value == 15
    assert dut.Zero.value == 0

@cocotb.test()
async def test_alu_zero_flag(dut):
    dut.SrcA.value = 7
    dut.SrcB.value = 7
    dut.ALUControl.value = 0b001  # subtract
    await Timer(1, unit="ns")
    assert dut.ALUResult.value == 0
    assert dut.Zero.value == 1