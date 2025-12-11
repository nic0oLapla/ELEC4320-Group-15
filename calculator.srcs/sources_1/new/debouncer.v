`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.12.2025 20:22:42
// Design Name: 
// Module Name: debouncer
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


module debouncer(
    input       clk,
    input       sig_in,
    output reg  sig_out
    );
    
    reg [7:0] i = 0;
    reg state = 0;
    
    always@(posedge clk)
        if (sig_in == state) begin
            if (i == 199)
                sig_out <= sig_in;
            else
                i <= i + 1'b1;
        end else begin
            i <= 0;
            state <= sig_in;
        end
    
endmodule
