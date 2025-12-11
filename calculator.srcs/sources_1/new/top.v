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
    wire        ready;
    wire        start;
    wire        valid;
    wire [7:0]  keycode;
    wire [7:0]  ascii;

    reg         CLK50MHZ=0;
    always @(posedge(clk))begin
        CLK50MHZ<=~CLK50MHZ;
    end
    
    ps2_receiver ps2_in (
        .clk        (clk),
        .kb_clk     (PS2Clk),
        .kb_key     (PS2Data),
        .keycode    (keycode),
        .valid_out  (valid),
        .led        ({led_1, led_0})
    );
    
    
    
    num_2_ascii converter (
        .clk        (clk),
        .num        ({8'd0,keycode}),
        .valid      (valid),
        .uart_ready (ready),
        .char       (ascii),
//        .running    (),
        .uart_start (start)
    );
    
    uart_sender uart_out (
        .clk    (clk),
        .start  (start),
        .char   (ascii),
        .tx     (tx),
        .ready  (ready)
    );
    
endmodule
