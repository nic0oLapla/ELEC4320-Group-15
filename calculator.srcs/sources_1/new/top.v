`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.12.2025 20:12:17
// Design Name: 
// Module Name: top
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


module top(
    input         clk,
    input         PS2Data,
    input         PS2Clk,
    output        tx
);
    wire        clk_300;

    wire [7:0]  ps2_code;
    wire        ps2_valid;
    
    wire [31:0] key_out;
    wire        key_type;
    wire        key_valid;
    wire        key_enter;
    
    wire [31:0] A;
    wire [31:0] B;
    wire [3:0]  op;
    wire [31:0] acc_final;
    wire        acc_valid;
    wire        acc_print;
    
    wire [31:0] alu_result;
    wire        alu_idle;
    wire        alu_valid;
    
    wire [7:0]  ascii;
    wire        uart_ready;
    wire        uart_start;
    
    clk_300_mhz clk_gen_300 (
        .clk_in1(clk),
        .clk_out1(clk_300)
    );
    
    ps2_receiver ps2_in (
        .clk        (clk_300),
        .kb_clk     (PS2Clk),
        .kb_key     (PS2Data),
        
        .keycode    (ps2_code),
        .valid      (ps2_valid)
    );
    
    keys_2_calc k2c (
        .clk(clk_300),
        .keycode(ps2_code),
        .start(ps2_valid),        
                 
        .out(key_out),
        .out_type(key_type), 
        .out_valid(key_valid),
        .enter(key_enter)        
    );
    
    accumulator acc (
        .clk(clk_300),
        .key(key_out),
        .res(alu_result),
        .start_key(key_valid),
        .start_alu(alu_valid),
        .type_key(key_type),
        .idle(alu_idle),
        .enter(key_enter),
        
        .A(A),
        .B(B),
        .op(op),
        .valid(acc_valid),
        .final(acc_final),
        .print(acc_print)
    );
    
    ALU alu (
        .clk(clk_300),
        .valid_in(acc_valid),      // Handshake: new operation is valid
        .in_A(A),
        .in_B(B),
        .opcode(op),
        
        .valid_out(alu_valid),     // Handshake: result is valid
        .ALU_out(alu_result),
        .idle(alu_idle)
    );
    
    num_2_ascii n2a (
        .clk        (clk_300),
        .num        (acc_final),
        .start      (acc_print),
        .uart_ready (uart_ready),
        
        .char       (ascii),
        .uart_start (uart_start)
    );
    
    uart_sender uart_out (
        .clk    (clk_300),
        .start  (uart_start),
        .char   (ascii),
        
        .tx     (tx),
        .ready  (uart_ready)
    );
    
endmodule
