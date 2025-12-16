`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.12.2025 21:29:25
// Design Name: 
// Module Name: define
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

// Basic Arithmetic Operations
`define ADD           4'd0    // Latency: 2 cycles
`define SUB           4'd1    // Latency: 2 cycles
`define MULT          4'd2    // Latency: 2 cycles
`define DIV           4'd3    // Latency: 3 cycles

// Advanced Mathematical Operations
`define SQRT          4'd4    // Latency: 5 cycles
`define COS           4'd5    // Latency: 4 cycles
`define TAN           4'd6    // Latency: 4 cycles
`define ARCSIN        4'd7    // Latency: 6 cycles
`define ARCCOS        4'd8    // Latency: 4 cycles
`define ARCTAN        4'd9    // Latency: 6 cycles
`define LOG           4'd10   // Latency: 5 cycles (Logarithm)
`define POW           4'd11   // Latency: 5 cycles (Power)
`define EXP           4'd12   // Latency: 4 cycles (Exponential)
`define FACT          4'd13   // Latency: 3 cycles (Factorial)

// Fixed-point standard parameters (Q format: signed WIDTH bits, FRAC fractional bits)
// Global Q22.10 contract: two's-complement 32-bit with 10 fractional bits.
// All module inputs/outputs must be 32-bit Q22.10. Modules are responsible for emitting
// final 32-bit Q22.10 results with standardized truncation to 32 bits at their output stage.
// Rounding policy: default is truncation toward zero unless otherwise documented per module.
`define WIDTH         32
`define FRAC          10
`define INT           (`WIDTH-`FRAC-1)

// Two's-complement min/max for saturation
`define MAX_Q         32'h7FFFFFFF
`define MIN_Q         32'h80000000

// Rounding bias helper for optional round-to-nearest implementations
`define RND_BIAS      (1<<(`FRAC-1))

// Common latencies (cycles) for pipelined blocks
`define MULT_LAT      5
`define DIV_LAT_EST   84   // ~2*(WIDTH+FRAC); actual divider latency is data-independent but ~84 for 32/10
