`timescale 1ns / 1ps
`include "define.v"


module state(
  input wire clk,
  input wire reset,
  input wire locked,
  input wire valid_input,
  input wire alu_done,
  input wire output_done,

  output reg [1:0] cs
);

  // use state macros from define.v

  // synchronous state register (control-state only)
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      cs <= `STARTUP;
    end else begin
      case (cs)
        `STARTUP: begin
          if (locked)
            cs <= `INPUT;
          else
            cs <= `STARTUP;
        end

        `INPUT: begin
          if (valid_input)
            cs <= `CALC;
          else
            cs <= `INPUT;
        end

        `CALC: begin
          if (alu_done)
            cs <= `OUTPUT;
          else
            cs <= `CALC;
        end

        `OUTPUT: begin
          if (output_done)
            cs <= `INPUT;  
          else
            cs <= `OUTPUT;
        end

        default: begin
          cs <= `STARTUP;
        end
      endcase
    end
  end

endmodule
