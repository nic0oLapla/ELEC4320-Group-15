`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// Fixed-point logarithm with arbitrary base using change of base:
// log_a(b) = log2(b) / log2(a)
// The log2 is computed iteratively (digit-by-digit) over FRAC_STEPS cycles.
// Handshake: assert in_valid for one cycle when in_ready=1. out_valid pulses when done.
module log_base_fixed #(
    parameter integer N = `WIDTH,
    parameter integer Q = `FRAC,
    parameter integer FRAC_STEPS = 12  // depth of fractional refinement
)(
    input  wire              clk,
    input  wire              reset,
    input  wire              in_valid,
    input  wire [N-1:0]      base,     // logarithm base  (Q format, >0 and !=1)
    input  wire [N-1:0]      val,      // argument value  (Q format, >0)
    output wire              in_ready,
    output reg               out_valid,
    output reg  [N-1:0]      log_out
);

    localparam signed [N-1:0] ONE = 1 <<< Q;
    localparam signed [N-1:0] TWO = 2 <<< Q;

    // Return MSB index of x (0-based). -1 if x==0.
    function automatic integer lead_one_pos;
        input [N-1:0] x;
        integer i;
        begin
            lead_one_pos = -1;
            for (i = N-1; i >= 0; i = i - 1)
                if (lead_one_pos == -1 && x[i])
                    lead_one_pos = i;
        end
    endfunction

    localparam [2:0] S_IDLE      = 3'd0;
    localparam [2:0] S_PREP_BASE = 3'd1;
    localparam [2:0] S_ITER_BASE = 3'd2;
    localparam [2:0] S_PREP_VAL  = 3'd3;
    localparam [2:0] S_ITER_VAL  = 3'd4;
    localparam [2:0] S_DIV_REQ   = 3'd5;
    localparam [2:0] S_DIV_WAIT  = 3'd6;

    reg [N-1:0]      base_reg, val_reg;
    reg [N-1:0]      work_x;
    reg signed [N-1:0] work_log;
    reg signed [N-1:0] log2_base, log2_val;
    reg [5:0]        step;
    reg              div_req;
    reg [2:0]        state;

    wire             div_in_ready;
    wire             div_out_valid;
    wire             div_overflow;
    wire [N-1:0]     div_q;

    divider_pipelined #(.Q(Q), .N(N)) u_div (
        .clk         (clk),
        .reset       (reset),
        .in_valid    (div_req),
        .dividend    (log2_val),
        .divisor     (log2_base),
        .in_ready    (div_in_ready),
        .out_valid   (div_out_valid),
        .out_overflow(div_overflow),
        .quotient    (div_q)
    );

    assign in_ready = (state == S_IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state     <= S_IDLE;
            out_valid <= 1'b0;
            log_out   <= {N{1'b0}};
            base_reg  <= {N{1'b0}};
            val_reg   <= {N{1'b0}};
            work_x    <= {N{1'b0}};
            work_log  <= {N{1'b0}};
            log2_base <= {N{1'b0}};
            log2_val  <= {N{1'b0}};
            step      <= 6'd0;
            div_req   <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            div_req   <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                        // Reject invalid domains (<=0 or base==1).
                        if (base[N-1] || val[N-1] || base == {N{1'b0}} || val == {N{1'b0}} || base == ONE) begin
                            log_out   <= {N{1'b0}};
                            out_valid <= 1'b1;
                            state     <= S_IDLE;
                        end else begin
                            base_reg <= base;
                            val_reg  <= val;
                            state    <= S_PREP_BASE;
                        end
                    end
                end

                S_PREP_BASE: begin
                    integer e_base;
                    integer shift_amt;
                    reg [N-1:0] norm;
                    e_base    = lead_one_pos(base_reg) - Q;
                    shift_amt = (e_base >= 0) ? e_base : -e_base;
                    if (shift_amt >= N)
                        norm = {N{1'b0}};
                    else if (e_base >= 0)
                        norm = base_reg >> shift_amt;
                    else
                        norm = base_reg << shift_amt;

                    work_x   <= norm;
                    work_log <= $signed(e_base <<< Q);
                    step     <= 0;
                    state    <= S_ITER_BASE;
                end

                S_ITER_BASE: begin
                    reg signed [2*N-1:0] mult;
                    reg signed [N-1:0]   squared;
                    reg signed [N-1:0]   next_x;
                    reg signed [N-1:0]   next_log;
                    reg signed [N-1:0]   delta;

                    mult     = $signed(work_x) * $signed(work_x);
                    squared  = mult >>> Q;
                    next_x   = squared;
                    next_log = work_log;
                    delta    = (step < Q) ? $signed(ONE >>> (step + 1)) : {N{1'b0}};

                    if (squared >= TWO) begin
                        next_x   = squared >>> 1;
                        next_log = work_log + delta;
                    end

                    work_x   <= next_x;
                    work_log <= next_log;
                    if (step == FRAC_STEPS-1) begin
                        log2_base <= next_log;
                        state     <= S_PREP_VAL;
                    end
                    step <= step + 1'b1;
                end

                S_PREP_VAL: begin
                    integer e_val;
                    integer shift_amt;
                    reg [N-1:0] norm;
                    e_val    = lead_one_pos(val_reg) - Q;
                    shift_amt = (e_val >= 0) ? e_val : -e_val;
                    if (shift_amt >= N)
                        norm = {N{1'b0}};
                    else if (e_val >= 0)
                        norm = val_reg >> shift_amt;
                    else
                        norm = val_reg << shift_amt;

                    work_x   <= norm;
                    work_log <= $signed(e_val <<< Q);
                    step     <= 0;
                    state    <= S_ITER_VAL;
                end

                S_ITER_VAL: begin
                    reg signed [2*N-1:0] mult;
                    reg signed [N-1:0]   squared;
                    reg signed [N-1:0]   next_x;
                    reg signed [N-1:0]   next_log;
                    reg signed [N-1:0]   delta;

                    mult     = $signed(work_x) * $signed(work_x);
                    squared  = mult >>> Q;
                    next_x   = squared;
                    next_log = work_log;
                    delta    = (step < Q) ? $signed(ONE >>> (step + 1)) : {N{1'b0}};

                    if (squared >= TWO) begin
                        next_x   = squared >>> 1;
                        next_log = work_log + delta;
                    end

                    work_x   <= next_x;
                    work_log <= next_log;
                    if (step == FRAC_STEPS-1) begin
                        log2_val <= next_log;
                        state    <= S_DIV_REQ;
                    end
                    step <= step + 1'b1;
                end

                S_DIV_REQ: begin
                    if (log2_base == {N{1'b0}}) begin
                        log_out   <= {N{1'b0}};
                        out_valid <= 1'b1;
                        state     <= S_IDLE;
                    end else if (div_in_ready) begin
                        div_req <= 1'b1;
                        state   <= S_DIV_WAIT;
                    end
                end

                S_DIV_WAIT: begin
                    if (div_out_valid) begin
                        // Clamp final output to Q22.10 bounds (saturate on overflow)
                        if (div_overflow) begin
                            log_out <= (div_q[N-1] ? `MIN_Q : `MAX_Q);
                        end else begin
                            log_out <= div_q;
                        end
                        out_valid <= 1'b1;
                        state     <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule

`default_nettype wire
