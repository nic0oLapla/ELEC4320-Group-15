`timescale 1ns / 1ps
`include "define.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.12.2025 11:55:24
// Design Name: 
// Module Name: clk_gen
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


module clk_gen(
    clk_in, 
    clk_300_mhz, 
    reset,
    locked
    );

input clk_in; // 100MHz
output clk_300_mhz;
output locked;
input reset;

clk_300_mhz CLKGEN(
  .clk_out1(clk_300_mhz),
  .reset(reset),
  .locked(locked),
  .clk_in1(clk_in)
 );
 
endmodule
