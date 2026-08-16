
module risc_v(output logic [31:0] CPUOut,
                input logic [31:0] CPUIn,
                input logic Reset, CLK);

logic [31:0] Instr, WD3, RD1, RD2, SrcA, SrcB, ALUResult, WD, RD, Result, ImmExt, PCTarget, PCNext, PC, PCPlus4;
logic [4:0]  A1, A2, A3;
logic        MemWrite, ALUSrc, RegWrite;
logic [2:0]  ALUControl;
logic [2:0]  ImmSrc;
logic [1:0]  ResultSrc;
logic [1:0]  PCSrc;

// Enter your code here
logic Zero;

  

// Instantiate data_memory_and_io module
  data_memory_and_io data_mem_inst (
    .RD(RD),
    .CPUOut(CPUOut),
    .A(ALUResult),
    .WD(WD),
    .CPUIn(CPUIn),
    .WE(MemWrite),
    .CLK(CLK)
  );



// Instantiate control_unit module
  control_unit control_unit_inst (
    .PCSrc(PCSrc),
    .ResultSrc(ResultSrc),
    .MemWrite(MemWrite),
    .ALUSrc(ALUSrc),
    .RegWrite(RegWrite),
    .ALUControl(ALUControl),
    .ImmSrc(ImmSrc),
    .Instr(Instr),
    .Zero(Zero)
  );


  // Instantiate extend module
  extend extend_inst (
    .ImmExt(ImmExt),
    .Instr(Instr),
    .ImmSrc(ImmSrc)
  );

  


// Instantiate instruction_memory module
  instruction_memory instruction_memory_inst (
    .Instr(Instr),
    .PC(PC)
  );


// Instantiate program_counter module
  program_counter pc_inst (
    .CLK(CLK),
    .Reset(Reset),
    .PC(PC),
    .PCPlus4(PCPlus4),
    .PCSrc(PCSrc),
    .PCTarget(PCTarget),
    .ALUResult(ALUResult)
  );


// Instantiate reg_file module
  reg_file reg_file_inst (
    .RD1(RD1),
    .RD2(RD2),
    .WD3(Result),
    .A1(Instr[19:15]),
    .A2(Instr[24:20]),
    .A3(Instr[11:7]),
    .WE3(RegWrite),
    .CLK(CLK)
  );


  // Instantiate alu module
  alu alu_inst (
    .ALUResult(ALUResult),
    .Zero(Zero),
    .SrcA(SrcA),
    .SrcB(SrcB),
    .ALUControl(ALUControl)
  );

  always_comb begin
    case(ResultSrc)
        2'b00 : Result = ALUResult;
        2'b01 : Result = RD;
        2'b10 : Result = PCPlus4;
        default : Result = 32'bx;
    endcase
  end

  always_comb begin
    case(ALUSrc)
        1'b0 : SrcB = RD2;
        1'b1 : SrcB = ImmExt;
        default : SrcB = 32'bx;
    endcase
  end


  assign SrcA = RD1;
  assign WD = RD2;
  assign PCTarget = PC + ImmExt;

endmodule

