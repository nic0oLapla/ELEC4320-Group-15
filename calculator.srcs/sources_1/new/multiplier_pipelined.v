`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// 32x32 pipelined multiplier using a balanced adder tree.
// Fully pipelined: accepts one input per cycle, fixed latency of `MULT_LAT cycles.
module multiplier_pipelined #(
    parameter integer N = `WIDTH
  )(
    input  wire                clk,
    input  wire                reset,
    input  wire                in_valid,
    input  wire [N-1:0]        a,
    input  wire [N-1:0]        b,
    output wire                in_ready,
    output reg                 out_valid,
    output reg  [2*N-1:0]      p
  );

  assign in_ready = 1'b1;  // no backpressure in this implementation

  // Partial products
  wire [2*N-1:0] partial [0:N-1];
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1)
    begin : gen_partial
      assign partial[i] = b[i] ? ({ {N{1'b0}}, a } << i) : {2*N{1'b0}};
    end
  endgenerate

  integer idx;

  // Stage 0: register partial products
  reg [2*N-1:0] level0_r [0:N-1];
  reg           valid0;
  always @(posedge clk)
  begin
    if (reset)
    begin
      valid0 <= 1'b0;
      for (idx = 0; idx < N; idx = idx + 1)
        level0_r[idx] <= {2*N{1'b0}};
    end
    else
    begin
      valid0 <= in_valid;
      for (idx = 0; idx < N; idx = idx + 1)
        level0_r[idx] <= partial[idx];
    end
  end

  // Stage 1: 32 -> 16
  wire [2*N-1:0] level1 [0:(N/2)-1];
  generate
    for (i = 0; i < N/2; i = i + 1)
    begin : gen_level1
      assign level1[i] = level0_r[2*i] + level0_r[2*i+1];
    end
  endgenerate

  reg [2*N-1:0] level1_r [0:(N/2)-1];
  reg           valid1;
  always @(posedge clk)
  begin
    if (reset)
    begin
      valid1 <= 1'b0;
      for (idx = 0; idx < N/2; idx = idx + 1)
        level1_r[idx] <= {2*N{1'b0}};
    end
    else
    begin
      valid1 <= valid0;
      for (idx = 0; idx < N/2; idx = idx + 1)
        level1_r[idx] <= level1[idx];
    end
  end

  // Stage 2: 16 -> 8
  wire [2*N-1:0] level2 [0:(N/4)-1];
  generate
    for (i = 0; i < N/4; i = i + 1)
    begin : gen_level2
      assign level2[i] = level1_r[2*i] + level1_r[2*i+1];
    end
  endgenerate

  reg [2*N-1:0] level2_r [0:(N/4)-1];
  reg           valid2;
  always @(posedge clk)
  begin
    if (reset)
    begin
      valid2 <= 1'b0;
      for (idx = 0; idx < N/4; idx = idx + 1)
        level2_r[idx] <= {2*N{1'b0}};
    end
    else
    begin
      valid2 <= valid1;
      for (idx = 0; idx < N/4; idx = idx + 1)
        level2_r[idx] <= level2[idx];
    end
  end

  // Stage 3: 8 -> 4
  wire [2*N-1:0] level3 [0:(N/8)-1];
  generate
    for (i = 0; i < N/8; i = i + 1)
    begin : gen_level3
      assign level3[i] = level2_r[2*i] + level2_r[2*i+1];
    end
  endgenerate

  reg [2*N-1:0] level3_r [0:(N/8)-1];
  reg           valid3;
  always @(posedge clk)
  begin
    if (reset)
    begin
      valid3 <= 1'b0;
      for (idx = 0; idx < N/8; idx = idx + 1)
        level3_r[idx] <= {2*N{1'b0}};
    end
    else
    begin
      valid3 <= valid2;
      for (idx = 0; idx < N/8; idx = idx + 1)
        level3_r[idx] <= level3[idx];
    end
  end

  // Stage 4: 4 -> 2
  wire [2*N-1:0] level4 [0:(N/16)-1];
  generate
    for (i = 0; i < N/16; i = i + 1)
    begin : gen_level4
      assign level4[i] = level3_r[2*i] + level3_r[2*i+1];
    end
  endgenerate

  reg [2*N-1:0] level4_r [0:(N/16)-1];
  reg           valid4;
  always @(posedge clk)
  begin
    if (reset)
    begin
      valid4 <= 1'b0;
      for (idx = 0; idx < N/16; idx = idx + 1)
        level4_r[idx] <= {2*N{1'b0}};
    end
    else
    begin
      valid4 <= valid3;
      for (idx = 0; idx < N/16; idx = idx + 1)
        level4_r[idx] <= level4[idx];
    end
  end

  // Stage 5: 2 -> 1 (final sum + output register)
  wire [2*N-1:0] level5_sum = level4_r[0] + level4_r[1];

  always @(posedge clk)
  begin
    if (reset)
    begin
      out_valid <= 1'b0;
      p         <= {2*N{1'b0}};
    end
    else
    begin
      out_valid <= valid4;
      p         <= level5_sum;
    end
  end

endmodule

`default_nettype wire
