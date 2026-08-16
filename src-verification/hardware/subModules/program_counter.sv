module program_counter (output logic [31:0] PC, PCPlus4,
                        input logic [31:0] PCTarget, ALUResult,
                        input logic [1:0] PCSrc, 
                        input logic Reset, CLK);

logic [31:0] PCNext;
always_comb
case(PCSrc)
    2'b00 : PCNext = PC+4;
    2'b01 : PCNext = PCTarget;
    2'b10 : PCNext = ALUResult;
default : PCNext = 32'bx;

endcase

always_ff @ (posedge CLK)
 if (Reset)begin
 PC <= 0;
 end
 else begin
 PC <= PCNext;
 end


assign PCPlus4 = PC+4;

endmodule
