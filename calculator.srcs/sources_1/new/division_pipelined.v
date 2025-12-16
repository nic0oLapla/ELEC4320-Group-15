`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// Fixed-point restoring divider, parameterized by width (N) and fractional bits (Q).
// Handshake aligns with the pipelined multiplier: in_valid/ready, out_valid.
// Latency: ~2*(N+Q) cycles for the two-phase micro-steps.
module divider_pipelined #(
    parameter integer Q = `FRAC,
    parameter integer N = `WIDTH
)(
    input  wire              clk,
    input  wire              reset,
    input  wire              in_valid,
    input  wire [N-1:0]      dividend,
    input  wire [N-1:0]      divisor,
    output wire              in_ready,
    output reg               out_valid,
    output reg               out_overflow,
    output reg  [N-1:0]      quotient
);

    // Working registers
    reg [2*N+Q-3:0] acc_quotient;
    reg [N-2+Q:0]   acc_dividend;
    reg [2*N+Q-3:0] acc_divisor;
    reg [N-1:0]     step_count;
    reg             quotient_sign;
    reg             cmp_ge;     // compare result pipeline
    reg             phase_sub;  // 0: compare/shift, 1: subtract/bit set
    reg [2*N+Q-3:0] next_quot;  // holds tentative quotient with current bit
    reg             busy;

    assign in_ready = !busy;

    wire divisor_zero = (divisor[N-2:0] == { (N-1){1'b0} });
    wire [2*N+Q-3:0] div_shift = acc_divisor >> 1;

    // Idle when busy is low
    always @(posedge clk) begin
        if (reset) begin
            out_valid         <= 1'b0;
            out_overflow      <= 1'b0;
            quotient          <= { N{1'b0} };
            quotient_sign     <= 1'b0;
            acc_quotient      <= { (2*N+Q-2){1'b0} };
            acc_dividend      <= { (N+Q-1){1'b0} };
            acc_divisor       <= { (2*N+Q-2){1'b0} };
            step_count        <= { N{1'b0} };
            cmp_ge            <= 1'b0;
            phase_sub         <= 1'b0;
            next_quot         <= { (2*N+Q-2){1'b0} };
            busy              <= 1'b0;
        end else begin
            out_valid <= 1'b0; // pulse when finishing

            if (!busy && in_valid) begin
                // Start a new division
                if (divisor_zero) begin
                    out_valid    <= 1'b1;
                    out_overflow <= 1'b1;
                    quotient     <= { N{1'b0} };
                end else begin
                    busy         <= 1'b1;
                    out_overflow <= 1'b0;
                    step_count   <= N+Q-1;
                    acc_quotient <= { (2*N+Q-2){1'b0} };
                    acc_dividend <= { (N+Q-1){1'b0} };
                    acc_dividend[N+Q-2:Q] <= dividend[N-2:0];
                    acc_divisor  <= { (2*N+Q-2){1'b0} };
                    acc_divisor[2*N+Q-3:N+Q-1] <= divisor[N-2:0];
                    quotient_sign <= dividend[N-1] ^ divisor[N-1];
                    phase_sub <= 1'b0;
                end
            end else if (busy) begin
                if (!phase_sub) begin
                    // Phase 0: shift divisor and compare
                    acc_divisor <= div_shift;
                    cmp_ge      <= (acc_dividend >= div_shift);
                    phase_sub   <= 1'b1;
                end else begin
                    // Phase 1: optional subtract and set quotient bit
                    next_quot = acc_quotient;
                    if (cmp_ge)
                        next_quot[step_count] = 1'b1;

                    if (step_count == 0) begin
                        out_valid    <= 1'b1;
                        out_overflow <= (next_quot[2*N+Q-3:N] != 0);
                        quotient[N-2:0] <= next_quot[N-2:0];
                        quotient[N-1]   <= quotient_sign;
                        busy         <= 1'b0;
                        phase_sub    <= 1'b0;
                    end else begin
                        if (cmp_ge) begin
                            acc_dividend <= acc_dividend - acc_divisor;
                            acc_quotient <= next_quot;
                        end
                        step_count <= step_count - 1;
                        phase_sub  <= 1'b0;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
