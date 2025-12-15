`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.12.2025 22:08:11
// Design Name: 
// Module Name: controller_tb
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


module controller_tb;
    reg clk;
    
    wire        clk_300;

    reg  [7:0]  ps2_code;
    reg         ps2_valid;
    
    wire [31:0] key_out;
    wire        key_num;
    wire        key_op;
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
    reg         uart_ready;
    wire        uart_start;
    
    clk_300_mhz clk_gen_300 (
        .clk_in1(clk),
        .clk_out1(clk_300)
    );
    
    keys_2_calc k2c (
        .clk(clk_300),
        .keycode(ps2_code),
        .start(ps2_valid),        
                 
        .out(key_out),
        .out_num(key_num), 
        .out_op(key_op),
        .enter(key_enter)        
    );
    
    accumulator acc (
        .clk(clk_300),
        .key(key_out),
        .res(alu_result),
        .start_key_num(key_num),
        .start_key_op(key_op),
        .start_alu(alu_valid),
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
    
    initial begin
        clk = 1;
        forever #5 clk = ~clk;
      end

    initial begin
        ps2_code = 0; ps2_valid = 0; uart_ready = 1; #2000

        // 001
        ps2_code = 8'h45; ps2_valid = 1; #3.33
        ps2_valid = 0; #30
        ps2_code = 8'h45; ps2_valid = 1; #3.33
        ps2_valid = 0; #30
        ps2_code = 8'h16; ps2_valid = 1; #3.33
        ps2_valid = 0; #330
        
        // +
        ps2_code = 8'h15; ps2_valid = 1; #3.33
        ps2_valid = 0; #330
        
        // 001
        ps2_code = 8'h45; ps2_valid = 1; #3.33
        ps2_valid = 0; #30
        ps2_code = 8'h45; ps2_valid = 1; #3.33
        ps2_valid = 0; #30
        ps2_code = 8'h16; ps2_valid = 1; #3.33
        ps2_valid = 0; #330
        
        // +
        ps2_code = 8'h15; ps2_valid = 1; #3.33
        ps2_valid = 0; #330
        
        // half
        ps2_code = 8'h2C; ps2_valid = 1; #3.33
        ps2_valid = 0; #330
        
        // 002
        ps2_code = 8'h45; ps2_valid = 1; #3.33
        ps2_valid = 0; #30
        ps2_code = 8'h45; ps2_valid = 1; #3.33
        ps2_valid = 0; #30
        ps2_code = 8'h1E; ps2_valid = 1; #3.33
        ps2_valid = 0; #330

        // =
        ps2_code = 8'h5A; ps2_valid = 1; #3.33
        ps2_valid = 0; #3330
        
        // should print 3.000?

        $display("Simulation Finished at time %t", $time);
        $finish;
    end

endmodule
