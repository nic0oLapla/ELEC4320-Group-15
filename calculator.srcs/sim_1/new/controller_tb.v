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
    reg [7:0] keycode;
    reg [31:0] result;
    reg start;
    reg idle;
    
    wire [31:0] A;
    wire [31:0] B;
    wire [3:0] op;
    wire [31:0] final;
    wire valid;
    wire print;
    
    reg uart_ready;
    
    wire [7:0] ascii;
    wire uart_start;
    
    keys_2_calc k2c (
        .clk(clk),
        .keycode(keycode),
        .result(result),
        .start(start),        
        .idle(idle),
                 
        .A(A),    
        .B(B),    
        .op(op),    
        .final(final),
        .valid(valid),       
        .print(print)        
    );
    
    num_2_ascii n2a (
        .clk        (clk),
        .num        (final),
        .start      (print),
        .uart_ready (uart_ready),
        
        .char       (ascii),
        .uart_start (uart_start)
    );
    
    initial begin
        clk = 1;
        forever #5 clk = ~clk;
      end

    initial begin
        keycode = 0; result = 0; start = 0; idle = 1; uart_ready = 1; #100

        keycode = 8'h16; start = 1; #10;
        start = 0; #90
        keycode = 8'h1E; start = 1; #10;
        start = 0; #90
        keycode = 8'h16; start = 1; #10;
        start = 0; #90
        
        keycode = 8'h5A; start = 1; #10;
        start = 0; uart_ready = 1; #9000
        

        $display("Simulation Finished at time %t", $time);
        $finish;
    end

endmodule
