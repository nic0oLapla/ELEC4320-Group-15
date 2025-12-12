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
    input        rst,           // Added Reset
    input        valid_in,      // Handshake: new operation is valid
    input [31:0] in_A,
    input [31:0] in_B,
    input [3:0]  opcode,
    output reg   valid_out,     // Handshake: result is valid
    output reg [31:0] ALU_out
);

    reg [31:0] reg_A, reg_B;
    always @(posedge clk or posedge rst) begin
        reg_A <= in_A;
        reg_B <= in_B;
        if (rst) begin
            reg_A <= 32'b0;
            reg_B <= 32'b0;
            ALU_out <= 32'b0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            case (opcode)
                `ADD:     ALU_out <= reg_A + reg_B;
                `SUB:     ALU_out <= reg_A - reg_B;
                `MULT:    ALU_out <= reg_A * reg_B;
                `DIV:     ALU_out <= reg_A / reg_B;
                
                `SQRT:    ALU_out <= 32'b0;  // TODO: Square Root of reg_A
                `COS:     ALU_out <= 32'b0;  // TODO: Cosine of reg_A
                `TAN:     ALU_out <= 32'b0;  // TODO: Tangent of reg_A
                `ARCSIN:  ALU_out <= 32'b0;  // TODO: Arcsine of reg_A
                `ARCCOS:  ALU_out <= 32'b0;  // TODO: Arccosine of reg_A
                `ARCTAN:  ALU_out <= 32'b0;  // TODO: Arctangent of reg_A
                `LOG:     ALU_out <= 32'b0;  // TODO: Logarithm base reg_A of reg_B
                `POW:     ALU_out <= 32'b0;  // TODO: reg_A raised to power reg_B
                `EXP:     ALU_out <= 32'b0;  // TODO: e raised to power reg_A
                `FACT:    ALU_out <= 32'b0;  // TODO: Factorial of reg_A
                default:  ALU_out <= 32'b0;
            endcase
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end
endmodule