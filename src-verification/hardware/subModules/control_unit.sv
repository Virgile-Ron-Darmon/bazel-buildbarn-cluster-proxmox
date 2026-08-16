module control_unit (output logic [1:0] PCSrc, 
                    output logic [1:0] ResultSrc,
                    output logic MemWrite, ALUSrc, RegWrite,
                    output logic [2:0] ALUControl,
                    output logic [2:0] ImmSrc,
                    input logic [31:0] Instr,
                    input logic Zero);

// Extract bits [6:0] from the input
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    assign opcode = Instr[6:0];
    assign funct3 = Instr[14:12];
    assign funct7 = Instr[31:25];



    // Switch case based on opcode
    always_comb begin
        case(opcode)
            7'b0110011: begin // R type
                
                case(funct3)
                    3'b000 : begin
                        case(funct7)
                            7'b0000000 : begin
                                RegWrite = 1; // add
                                ImmSrc = 3'b000;
                                ALUSrc = 0;
                                ALUControl = 3'b000;
                                MemWrite = 0;
                                ResultSrc = 2'b00;
                                PCSrc = 2'b00;
                                
                            end
                            7'b0100000 : begin
                                RegWrite = 1; // sub
                                ImmSrc = 3'b000;
                                ALUSrc = 0;
                                ALUControl = 3'b001;
                                MemWrite = 0;
                                ResultSrc = 2'b00;
                                PCSrc = 2'b00;
                            end
                        endcase
                    end
                    3'b110 : begin
                        case(funct7)
                            7'b0000000 : begin
                                RegWrite = 1; // or
                                ImmSrc = 3'b000;
                                ALUSrc = 0;
                                ALUControl = 3'b011;
                                MemWrite = 0;
                                ResultSrc = 2'b00;
                                PCSrc = 2'b00;
                            end
                        endcase
                    end
                    3'b111 : begin
                        case(funct7)
                            7'b0000000 : begin
                                RegWrite = 1; // and
                                ImmSrc = 3'b000;
                                ALUSrc = 0;
                                ALUControl = 3'b010;
                                MemWrite = 0;
                                ResultSrc = 2'b00;
                                PCSrc = 2'b00;
                            end
                        endcase
                    end
                    3'b010 : begin
                        case(funct7)
                            7'b0000000 : begin
                                RegWrite = 1; // slt
                                ImmSrc = 3'b000;
                                ALUSrc = 0;
                                ALUControl = 3'b101;
                                MemWrite = 0;
                                ResultSrc = 2'b00;
                                PCSrc = 2'b00;
                            end
                        endcase
                    end
                endcase
                

            end
            7'b0010011 : begin // I type
                
                case(funct3)
                    3'b000 : begin // addi
                        RegWrite = 1;
                        ImmSrc = 3'b000;
                        ALUSrc = 1;
                        ALUControl = 3'b000;
                        MemWrite = 0;
                        ResultSrc = 2'b00;
                        PCSrc = 2'b00;
                    end
                    3'b110 : begin // ori
                        RegWrite = 1;
                        ImmSrc = 3'b000;
                        ALUSrc = 1;
                        ALUControl = 3'b011;
                        MemWrite = 0;
                        ResultSrc = 2'b00;
                        PCSrc = 2'b00;
                    end
                    3'b111 : begin // andi
                        RegWrite = 1;
                        ImmSrc = 3'b000;
                        ALUSrc = 1;
                        ALUControl = 3'b101;
                        MemWrite = 0;
                        ResultSrc = 2'b00;
                        PCSrc =2'b00;
                    end
                endcase
                
            end
            7'b0000011 : begin // I lw type
                
                case(funct3)
                    3'b010 : begin
                        RegWrite = 1;
                        ImmSrc = 3'b000;
                        ALUSrc = 1;
                        ALUControl = 3'b000;
                        MemWrite = 0;
                        ResultSrc = 2'b01;
                        PCSrc = 2'b00;
                    end
                endcase
                
            end
            7'b0100011 : begin // S sw type
                
                case(funct3)
                    3'b010 : begin
                        RegWrite = 0;
                        ImmSrc = 3'b001;
                        ALUSrc = 1;
                        ALUControl = 3'b000;
                        MemWrite = 1;
                        ResultSrc = 2'bxx;
                        PCSrc = 2'b00;
                    end
                endcase
                
            end
            7'b1100011 : begin // B beq type
                
                case(funct3)
                    3'b000 : begin
                        RegWrite = 0;
                        ImmSrc = 3'b010;
                        ALUSrc = 0;
                        ALUControl = 3'b001;
                        MemWrite = 0;
                        ResultSrc = 2'bxx;
                        PCSrc = {1'b0, Zero};
                    end
                endcase
                
            end
            7'b1101111 : begin // J jal type
                
                RegWrite = 1;
                ImmSrc = 3'b011;
                ALUSrc = 0;
                ALUControl = 3'bxxx;
                MemWrite = 0;
                ResultSrc = 2'b10;
                PCSrc = 2'b01;
                
            end
            7'b1100111 : begin // I jalr type
                
                case(funct3)
                    3'b000 : begin
                        RegWrite = 1;
                        ImmSrc = 3'b000;
                        ALUSrc = 1;
                        ALUControl = 3'b000;
                        MemWrite = 0;
                        ResultSrc = 2'b00;
                        PCSrc = 2'b10;
                    end
                endcase
                
            end
            7'b0110111 : begin // U lui type
                
                RegWrite = 1;
                ImmSrc = 3'b100;
                ALUSrc = 1;
                ALUControl = 3'b100;
                MemWrite = 0;
                ResultSrc = 2'b00;
                PCSrc = 2'b00;
                
            end
            default: begin //  type
                
                RegWrite = 1'bx;
                ImmSrc = 3'bx;
                ALUSrc = 1'bx;
                ALUControl = 3'bx;
                MemWrite = 1'bx;
                ResultSrc = 2'bx;
                PCSrc = 2'bx;
                
            end
        endcase
    end

endmodule
