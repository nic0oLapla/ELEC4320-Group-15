`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// Signed two's-complement fixed-point divider for Q-format (Q fractional bits).
// - Inputs/outputs are signed Q22.10 (by default WIDTH=32, FRAC=10)
// - Internal algorithm: restoring division on magnitudes over (N+Q) steps to produce Q-scaled result
// - Rounding: truncation toward zero (default policy)
// - Saturation: outputs saturate to MIN_Q/MAX_Q on overflow or divide-by-zero
// Handshake: in_valid when in_ready=1; out_valid pulses 1 cycle when result is available
module divider_pipelined #(
    parameter integer Q = `FRAC,
    parameter integer N = `WIDTH
) (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    in_valid,
    input  wire signed [N-1:0]     dividend,
    input  wire signed [N-1:0]     divisor,
    output wire                    in_ready,
    output reg                     out_valid,
    output reg                     out_overflow,
    output reg  signed [N-1:0]     quotient
);

    localparam integer WQ = N + Q; // total quotient bits (integer+fractional)

    // Control
    reg                     busy;
    assign in_ready = !busy;

    // Latched transaction
    reg                     sign_res;
    reg [N-1:0]             a_mag;   // |dividend|
    reg [N-1:0]             b_mag;   // |divisor|

    // Restoring division state
    reg [WQ-1:0]            num_shift; // holds {a_mag, Q zeros} and shifts left each step
    reg [N:0]               rem;       // remainder up to N+1 bits
    reg [WQ-1:0]            quot_mag;  // unsigned magnitude of quotient (Q-scaled)
    reg [$clog2(WQ+1)-1:0]  step_cnt;  // counts down WQ..1

    // Temporary procedural variables (moved to module scope for Verilog compatibility)
    reg [N:0]               rem_shift;
    reg [WQ-1:0]            qs_next;
    reg [N-1:0]             magN;
    reg signed [N-1:0]      res_signed;
    reg                     pos_over;
    reg                     neg_over;

    // Constants
    localparam [N-1:0] MIN_MAG = {1'b1, {N-1{1'b0}}}; // 0x8000..0 (abs(MIN_Q))

    // Absolute value helpers (unsigned magnitudes)
    function automatic [N-1:0] abs_tc;
        input signed [N-1:0] x;
        begin
            abs_tc = x[N-1] ? -x : x; // two's complement abs (note: abs(MIN_Q) = MIN_MAG)
        end
    endfunction

    // Division by zero immediate policy: saturate toward +/- infinity by dividend sign
    wire div_by_zero = (divisor == {N{1'b0}});

    always @(posedge clk) begin
        if (reset) begin
            busy         <= 1'b0;
            out_valid    <= 1'b0;
            out_overflow <= 1'b0;
            quotient     <= {N{1'b0}};
            sign_res     <= 1'b0;
            a_mag        <= {N{1'b0}};
            b_mag        <= {N{1'b0}};
            num_shift    <= {WQ{1'b0}};
            rem          <= {N+1{1'b0}};
            quot_mag     <= {WQ{1'b0}};
            step_cnt     <= {($clog2(WQ+1)){1'b0}};
        end else begin
            out_valid    <= 1'b0; // default low
            out_overflow <= 1'b0;

            if (!busy && in_valid) begin
                if (div_by_zero) begin
                    // Saturate by dividend sign
                    quotient     <= dividend[N-1] ? `MIN_Q : `MAX_Q;
                    out_overflow <= 1'b1;
                    out_valid    <= 1'b1;
                    busy         <= 1'b0;
                end else begin
                    // Latch operands and initialize state
                    sign_res  <= dividend[N-1] ^ divisor[N-1];
                    a_mag     <= abs_tc(dividend);
                    b_mag     <= abs_tc(divisor);
                    num_shift <= {abs_tc(dividend), {Q{1'b0}}};
                    rem       <= {N+1{1'b0}};
                    quot_mag  <= {WQ{1'b0}};
                    step_cnt  <= WQ;
                    busy      <= 1'b1;
                end
            end else if (busy) begin
                // One restoring division micro-step per cycle
                // Bring down next bit from num_shift MSB, shift remainder
                // rem' = (rem << 1) | msb(num_shift)
                // Compare/subtract with b_mag
                // Shift num_shift left by 1
                // Set quotient bit at position step_cnt-1
                rem_shift = {rem[N-1:0], num_shift[WQ-1]};
                num_shift <= num_shift << 1;
                qs_next   = quot_mag;
                if (rem_shift >= {1'b0, b_mag}) begin
                    rem      <= rem_shift - {1'b0, b_mag};
                    qs_next[step_cnt-1] = 1'b1;
                end else begin
                    rem      <= rem_shift;
                    qs_next[step_cnt-1] = 1'b0;
                end
                quot_mag <= qs_next;

                if (step_cnt == 1) begin
                    // Finalize
                    // Extract N-bit magnitude (drop Q fractional LSBs)
                    magN = qs_next[WQ-1:Q];
                    // Apply sign and saturate
                    pos_over = (!sign_res) && magN[N-1];
                    neg_over = ( sign_res) && (magN > MIN_MAG);
                    if (pos_over) begin
                        quotient     <= `MAX_Q;
                        out_overflow <= 1'b1;
                    end else if (neg_over) begin
                        quotient     <= `MIN_Q;
                        out_overflow <= 1'b1;
                    end else begin
                        res_signed   = sign_res ? -$signed(magN) : $signed(magN);
                        quotient     <= res_signed;
                    end
                    out_valid <= 1'b1;
                    busy      <= 1'b0;
                end

                if (step_cnt != 0)
                    step_cnt <= step_cnt - 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
