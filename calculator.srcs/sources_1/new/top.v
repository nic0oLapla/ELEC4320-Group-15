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
    output        tx,
    output        led_0,
    output        led_1
);

    wire [7:0]  keycode;
    wire        valid_ps2;
    reg  [31:0] result;
    reg         alu_idle;
    wire        A;
    wire        B;
    wire        op;
    wire        final;
    wire        valid_calc;
    wire        print;
    wire [7:0]  ascii;
    wire        uart_ready;

    reg         CLK50MHZ=0;
    always @(posedge(clk))begin
        CLK50MHZ<=~CLK50MHZ;
    end
    
    ps2_receiver ps2_in (
        .clk        (clk),
        .kb_clk     (PS2Clk),
        .kb_key     (PS2Data),
        
        .keycode    (keycode),
        .valid      (valid_ps2)
    );
    
    keys_2_calc(
        .clk(clk),
        .keycode(keycode),
        .result(result),
        .start(valid_ps2),        
        .idle(alu_idle),
                 
        .A(A),    
        .B(B),    
        .op(op),    
        .final(final),
        .valid(valid_calc),       
        .print(print)        
    );
    
    // fake calculator
    always@(posedge clk) begin
        if(valid_calc) begin
            alu_idle <= 0;
            result <= A + B + op;
        end else alu_idle <= 1;
    end
    
    num_2_ascii converter (
        .clk        (clk),
        .num        (final),
        .start      (print),
        .uart_ready (uart_ready),
        
        .char       (ascii),
        .uart_start (start)
    );
    
    uart_sender uart_out (
        .clk    (clk),
        .start  (start),
        .char   (ascii),
        
        .tx     (tx),
        .ready  (uart_ready)
    );

        ALU ALU(
        .clk        (clk_300MHz),
        .rst        (reset),           // Added Reset
        .valid_in   (valid_in),   // Handshake: new operation is valid
        .in_A       (ALU_in_A),
        .in_B       (ALU_in_B),
        .opcode     (OPcode),
        .valid_out  (valid_out),    // Handshake: result is valid
        .ALU_out    (ALU_out)
    );

    

endmodule
