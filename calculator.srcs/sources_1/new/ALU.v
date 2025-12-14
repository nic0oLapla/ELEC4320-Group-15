`timescale 1ns / 1ps
`include "define.v"

module ALU(
    input        clk,
    input        reset,           // Added Reset
    input        alu_active,      // ALU active signal
    
    input [31:0] in_A,
    input [31:0] in_B,
    input [3:0]  opcode,

    output reg   alu_done,     // Handshake: result is valid
    output reg [31:0] ALU_out
);

    reg [31:0] reg_A, reg_B;
    reg [3:0]  reg_op;

     always @(posedge clk or posedge reset) begin
         if (reset) begin
            reg_A <= 32'b0;
            reg_B <= 32'b0;
            reg_op <= 4'b0;
            ALU_out <= 32'b0;
            alu_done <= 1'b0;
            end else if (alu_active) begin
                reg_A <= in_A;
                reg_B <= in_B;
                reg_op <= opcode;
                case (opcode)
                    `ADD:     ALU_out <= in_A + in_B;
                    `SUB:     ALU_out <= in_A - in_B;
                    `MULT:    ALU_out <= in_A * in_B;
                    `DIV:     ALU_out <= in_A / in_B;
                    `SQRT:    ALU_out <= 32'b0;  // TODO: Square Root of in_A
                    `COS:     ALU_out <= 32'b0;  // TODO: Cosine of in_A
                    `TAN:     ALU_out <= 32'b0;  // TODO: Tangent of in_A
                    `ARCSIN:  ALU_out <= 32'b0;  // TODO: Arcsine of in_A
                    `ARCCOS:  ALU_out <= 32'b0;  // TODO: Arccosine of in_A
                    `ARCTAN:  ALU_out <= 32'b0;  // TODO: Arctangent of in_A
                    `LOG:     ALU_out <= 32'b0;  // TODO: Logarithm base in_A of in_B
                    `POW:     ALU_out <= 32'b0;  // TODO: in_A raised to power in_B
                    `EXP:     ALU_out <= 32'b0;  // TODO: e raised to power in_A
                    `FACT:    ALU_out <= 32'b0;  // TODO: Factorial of in_A
                    default:  ALU_out <= 32'b0;
                endcase
                alu_done <= 1'b1;
            end else begin
                alu_done <= 1'b0;
            end
        end









    //   always @(posedge clk or posedge reset) begin
    //  if (reset) begin
    //     reg_A <= 32'b0;
    //     reg_B <= 32'b0;
    //     reg_op <= 4'b0;
    //     ALU_out <= 32'b0;
    //     alu_done <= 1'b0;
    //     end 
    //     else if (alu_active) begin end 
    //     else begin
    //          reg_A <= in_A;
    //          reg_B <= in_B;
    //      end
    //      else if begin
    //          case (opcode)
    //              `ADD:     ALU_out <= reg_A + reg_B;
    //              `SUB:     ALU_out <= reg_A - reg_B;
    //              `MULT:    ALU_out <= reg_A * reg_B;
    //              `DIV:     ALU_out <= reg_A / reg_B;
    //              `SQRT:    ALU_out <= 32'b0;  // TODO: Square Root of reg_A
    //              `COS:     ALU_out <= 32'b0;  // TODO: Cosine of reg_A
    //              `TAN:     ALU_out <= 32'b0;  // TODO: Tangent of reg_A
    //              `ARCSIN:  ALU_out <= 32'b0;  // TODO: Arcsine of reg_A
    //              `ARCCOS:  ALU_out <= 32'b0;  // TODO: Arccosine of reg_A
    //              `ARCTAN:  ALU_out <= 32'b0;  // TODO: Arctangent of reg_A
    //              `LOG:     ALU_out <= 32'b0;  // TODO: Logarithm base reg_A of reg_B
    //              `POW:     ALU_out <= 32'b0;  // TODO: reg_A raised to power reg_B
    //              `EXP:     ALU_out <= 32'b0;  // TODO: e raised to power reg_A
    //              `FACT:    ALU_out <= 32'b0;  // TODO: Factorial of reg_A
    //              default:  ALU_out <= 32'b0;
    //          endcase
    //          alu_done <= 1'b1;
    //      end else begin
    //          alu_done <= 1'b0;
    //      end
    //  end

endmodule