`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.12.2025 21:10:10
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "define.v"

module ALU(
    input        clk,
    input        valid_in,      // Handshake: new operation is valid
    input [31:0] in_A,
    input [31:0] in_B,
    input [3:0]  opcode,
    output reg   valid_out,     // Handshake: result is valid
    output reg [31:0] ALU_out,
    output reg   idle
);

    always @(posedge clk) begin
        idle <= 1;
        if (valid_in) begin
            case (opcode)
                0:  ALU_out <= in_A + in_B;
                1:  ALU_out <= in_A - in_B;
                2:  ALU_out <= in_A * in_B;
                3:  ALU_out <= in_A / in_B;
               
                4:  ALU_out <= in_A / 2;  // TODO: Square Root of reg_A
                5:  ALU_out <= 32'b0;  // TODO: Cosine of reg_A
                6:  ALU_out <= 32'b0;  // TODO: Tangent of reg_A
                7:  ALU_out <= 32'b0;  // TODO: Arcsine of reg_A
                8:  ALU_out <= 32'b0;  // TODO: Arccosine of reg_A
                9:  ALU_out <= 32'b0;  // TODO: Arctangent of reg_A
                
                10: ALU_out <= 32'b0;  // TODO: Logarithm base reg_A of reg_B
                11: ALU_out <= 32'b0;  // TODO: reg_A raised to power reg_B
                
                12: ALU_out <= 32'b0;  // TODO: e raised to power reg_A
                13: ALU_out <= 32'b0;  // TODO: Factorial of reg_A
                default:  ALU_out <= 32'b0;
            endcase
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end
endmodule