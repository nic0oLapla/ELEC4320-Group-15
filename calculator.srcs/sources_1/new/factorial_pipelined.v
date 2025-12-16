`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// Iterative factorial using the pipelined multiplier.
// Accepts one request at a time: in_valid when in_ready=1, then asserts out_valid when done.
// Latency: ~ (n-1) * mult_latency for n >= 2.
module factorial_pipelined #(
    parameter integer N = `WIDTH
)(
    input  wire             clk,
    input  wire             reset,
    input  wire             in_valid,
    input  wire [N-1:0]     n,
    output wire             in_ready,
    output reg              out_valid,
    output reg              overflow,
    output reg  [N-1:0]     result
);

    
    reg             busy;
    reg             waiting_mult;
    reg [N-1:0]     acc;
    reg [N-1:0]     count;
    reg             mult_req;
    reg [N-1:0]     mult_a;
    reg [N-1:0]     mult_b;

    wire            mult_out_valid;
    wire [2*N-1:0]  mult_p;

    assign in_ready = !busy;

    multiplier_pipelined #(.N(N)) u_mult (
        .clk      (clk),
        .reset    (reset),
        .in_valid (mult_req),
        .a        (mult_a),
        .b        (mult_b),
        .in_ready (),               // always ready internally
        .out_valid(mult_out_valid),
        .p        (mult_p)
    );

    always @(posedge clk) begin
        if (reset) begin
            busy         <= 1'b0;
            waiting_mult <= 1'b0;
            mult_req     <= 1'b0;
            acc          <= {N{1'b0}};
            count        <= {N{1'b0}};
            mult_a       <= {N{1'b0}};
            mult_b       <= {N{1'b0}};
            overflow     <= 1'b0;
            result       <= {N{1'b0}};
            out_valid    <= 1'b0;
        end else begin
            mult_req  <= 1'b0;   // default: no request
            out_valid <= 1'b0;   // pulse when finishing
            overflow  <= 1'b0;   // overflow ignored in this design

            if (!busy && in_valid) begin
                // New transaction
                if (n <= 1) begin
                    result    <= { { (N-1){1'b0} }, 1'b1 };
                    overflow  <= 1'b0;
                    out_valid <= 1'b1;
                    busy      <= 1'b0;
                    waiting_mult <= 1'b0;
                end else begin
                    acc          <= { { (N-1){1'b0} }, 1'b1 }; // start at 1
                    count        <= n;
                    mult_a       <= { { (N-1){1'b0} }, 1'b1 };
                    mult_b       <= n;
                    mult_req     <= 1'b1;
                    waiting_mult <= 1'b1;
                    overflow     <= 1'b0;
                    busy         <= 1'b1;
                end
            end else if (busy) begin
                if (mult_out_valid && waiting_mult) begin
                    // Captured one product
                    if (count <= 2) begin
                        result       <= mult_p[N-1:0];
                        out_valid    <= 1'b1;
                        busy         <= 1'b0;
                        waiting_mult <= 1'b0;
                    end else begin
                        acc          <= mult_p[N-1:0];
                        count        <= count - 1;
                        waiting_mult <= 1'b0; // Ready to launch next multiply on next cycle
                    end
                end else if (!waiting_mult) begin
                    // Launch next multiply using updated acc and count
                    mult_a       <= acc;
                    mult_b       <= count;
                    mult_req     <= 1'b1;
                    waiting_mult <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
