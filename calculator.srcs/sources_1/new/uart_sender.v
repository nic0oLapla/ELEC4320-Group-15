`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.12.2025 10:58:11
// Design Name: 
// Module Name: uart_sender
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


module uart_sender(
    input clk,
    input [7:0] char,
    input start,
    output tx,
    output ready
    );
    
    reg [9:0] frame;    // UART frame
    reg out = 1;        // start idle
    reg running = 0;    // start idle
    reg [3:0] i = 0;    // frame bit counter
    reg [15:0] j = 0;   // baud tick counter
    
    localparam BAUD = 10416; // 100MHz/9600Hz 
    
    always@(posedge clk) begin
        if (running) begin
            out <= frame[i];
            if (j == BAUD) begin
                j <= 0;
                
                if (i == 9) begin
                    i <= 0;
                    running <= 0;
                    out <= 1;
                end else begin
                    i <= i + 1;
                end
            end else begin
                j <= j + 1;
            end  
        end else if (start) begin
            running <= 1'b1;
            i <= 0;
            j <= 0;
            frame <= {1'b1, char, 1'b0};
        end 
    end
    
    assign tx = running ? out : 1'b1;
    assign ready = (~running) & (~start);
endmodule
