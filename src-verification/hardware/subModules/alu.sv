module alu (output logic [31:0] ALUResult,
            output logic Zero,
            input logic [31:0] SrcA, SrcB,
            input logic [2:0] ALUControl);

always_comb begin //used to declare a combinational logic operation as a cyclic behaviour
    case(ALUControl)
        3'b000 : ALUResult = SrcA + SrcB; // addition a + b
        3'b001 : ALUResult = SrcA - SrcB; // subtraction a - b
        3'b010 : ALUResult = SrcA & SrcB; // bitwise a AND b
        3'b011 : ALUResult = SrcA | SrcB; // bitwise a OR b
        3'b100 : ALUResult = SrcB; // just b
        3'b101 : ALUResult = (SrcA < SrcB) ? 1:0;
        default : ALUResult = 32'bx;
    endcase
    Zero = (ALUResult == 0) ? 1 : 0;
end

endmodule
