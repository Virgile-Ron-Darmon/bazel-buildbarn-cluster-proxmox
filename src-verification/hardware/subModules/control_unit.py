import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_control_unit_add(dut):
    dut.Instr.value = 0b0000000_00000_00000_000_00000_0110011  # add, funct7=0, funct3=000
    dut.Zero.value = 0
    await Timer(1, unit="ns")
    assert dut.RegWrite.value == 1
    assert dut.ALUControl.value == 0b000
    assert dut.ALUSrc.value == 0

@cocotb.test()
async def test_control_unit_lw(dut):
    dut.Instr.value = 0b000000000000_00000_010_00000_0000011  # lw, funct3=010
    dut.Zero.value = 0
    await Timer(1, unit="ns")
    assert dut.RegWrite.value == 1
    assert dut.ResultSrc.value == 0b01
    assert dut.MemWrite.value == 0