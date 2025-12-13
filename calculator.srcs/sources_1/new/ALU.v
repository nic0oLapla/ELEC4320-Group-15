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

    //initialize cordic and factorial modules here

  // Fixed-point division (using non-restoring division)
    wire [31:0] div_result;
    divider divider_inst (
        .clk(clk),
        .start(start && op==OP_DIV),
        .dividend(a),
        .divisor(b),
        .quotient(div_result),
        .done(div_done)
    );

    // Square root (using non-restoring square root algorithm)
    wire [31:0] sqrt_result;
    sqrt sqrt_inst (
        .clk(clk),
        .start(start && op==OP_SQRT),
        .radicand(a),
        .root(sqrt_result),
        .done(sqrt_done)
    );

    // Trigonometric and hyperbolic functions using CORDIC
    wire [31:0] cos_result, sin_result, tan_result;
    wire [31:0] arccos_result, arcsin_result, arctan_result;
    wire [31:0] log_result, exp_result, power_result;

    // CORDIC module for circular functions
    wire [31:0] cordic_circular_x, cordic_circular_y, cordic_circular_z;
    wire cordic_circular_done;
    cordic_circular cordic_circular_inst (
        .clk(clk),
        .start(start && (op==OP_COS || op==OP_SIN || op==OP_TAN || op==OP_ARCCOS || op==OP_ARCSIN || op==OP_ARCTAN)),
        .mode(op==OP_ARCTAN || op==OP_ARCSIN || op==OP_ARCCOS ? 1 : 0), // 0 for rotation, 1 for vectoring
        .x_in(a),
        .y_in(b),
        .z_in(op==OP_ARCTAN ? b : a), // for arctan, we set x=a, y=b, so that result = arctan(y/x)
        .x_out(cordic_circular_x),
        .y_out(cordic_circular_y),
        .z_out(cordic_circular_z),
        .done(cordic_circular_done)
    );

    // CORDIC module for hyperbolic functions
    wire [31:0] cordic_hyperbolic_x, cordic_hyperbolic_y, cordic_hyperbolic_z;
    wire cordic_hyperbolic_done;
    cordic_hyperbolic cordic_hyperbolic_inst (
        .clk(clk),
        .start(start && (op==OP_LOG || op==OP_EXP || op==OP_POWER)),
        .mode(op==OP_LOG ? 1 : 0), // 0 for rotation, 1 for vectoring
        .x_in(a),
        .y_in(b),
        .z_in(b),
        .x_out(cordic_hyperbolic_x),
        .y_out(cordic_hyperbolic_y),
        .z_out(cordic_hyperbolic_z),
        .done(cordic_hyperbolic_done)
    );

    // Factorial
    wire [31:0] fact_result;
    wire fact_done;
    factorial factorial_inst (
        .clk(clk),
        .start(start && op==OP_FACT),
        .n(a),
        .result(fact_result),
        .done(fact_done)
    );

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