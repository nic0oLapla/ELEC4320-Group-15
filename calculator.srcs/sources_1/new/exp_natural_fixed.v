`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// Natural exponential in Q-format (two's complement, Q fractional bits).
// Uses exp(x) = 2^(x / ln(2)) with fractional exponent evaluated by multiplicative method.
module exp_natural_fixed #(
    parameter integer N    = `WIDTH,
    parameter integer Q    = `FRAC,
    parameter integer FRAC_STEPS = 10  // number of fractional bits processed
)(
    input  wire              clk,
    input  wire              reset,
    input  wire              in_valid,
    input  wire signed [N-1:0] x,        // exponent input (Q-format)
    output wire              in_ready,
    output reg               out_valid,
    output reg  [N-1:0]      exp_out
);

    localparam signed [N-1:0] ONE = 1 <<< Q;
    localparam signed [N-1:0] INV_LN2 = $rtoi((1.0/0.6931471805599453) * (1<<<Q));

    // pow2 fractional constants: 2^(2^-k) for k=1..FRAC_STEPS
    function automatic signed [N-1:0] pow2_const;
        input integer idx; // 0-based, corresponds to bit weight 2^-(idx+1)
        real v;
        begin
            v = 2.0**(1.0/(2.0**(idx+1)));
            pow2_const = $rtoi(v * (1<<<Q));
        end
    endfunction

    wire signed [N-1:0] pow_const [0:FRAC_STEPS-1];
    genvar gi;
    generate
        for (gi = 0; gi < FRAC_STEPS; gi = gi + 1) begin : gen_pow_consts
            localparam signed [N-1:0] PC = pow2_const(gi);
            assign pow_const[gi] = PC;
        end
    endgenerate

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_PROC = 2'd1;

    reg [1:0] state = S_IDLE;
    reg signed [N-1:0] k_fixed;
    reg signed [N-1:0] result;
    reg signed [15:0]  int_k;
    reg [Q-1:0]        frac_k;
    reg [4:0]          step;

    // Procedural temporary variables (declare at module scope for Verilog)
    reg signed [N+Q-1:0] mult_tmp;
    reg signed [N-1:0]   res_shifted;
    reg signed [2*N-1:0] mult;
    reg signed [N-1:0]   shifted_k;

    assign in_ready = (state == S_IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state     <= S_IDLE;
            k_fixed   <= 0;
            result    <= ONE;
            int_k     <= 0;
            frac_k    <= 0;
            step      <= 0;
            out_valid <= 1'b0;
            exp_out   <= {N{1'b0}};
        end else begin
            out_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                        // convert to log2 domain: k = x / ln2 ~= x * inv_ln2
                        mult_tmp = x * INV_LN2;
                        shifted_k = mult_tmp >>> Q;
                        k_fixed  <= shifted_k;
                        int_k    <= (mult_tmp >>> (2*Q)); // integer part of k_fixed (signed)
                        frac_k   <= shifted_k[Q-1:0];
                        result   <= ONE;
                        step     <= 0;
                        state    <= S_PROC;
                    end
                end

                S_PROC: begin
                    // apply integer part
                    res_shifted = result;
                    if (step == 0) begin
                        if (int_k >= 0) begin
                            if (int_k < N-Q)
                                res_shifted = result <<< int_k;
                            else
                                res_shifted = {N{1'b0}}; // overflow -> clamp to 0
                        end else begin
                            if (-int_k < N)
                                res_shifted = result >>> (-int_k);
                            else
                                res_shifted = {N{1'b0}};
                        end
                        result <= res_shifted;
                        step   <= 1;
                    end else if (step <= FRAC_STEPS) begin
                        // fractional multiplicative refinement
                        if (frac_k[Q-step]) begin
                            mult   = res_shifted * pow_const[step-1];
                            result <= mult >>> Q;
                        end
                        step <= step + 1'b1;
                        if (step == FRAC_STEPS) begin
                            exp_out   <= result;
                            out_valid <= 1'b1;
                            state     <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end
endmodule

`default_nettype wire
