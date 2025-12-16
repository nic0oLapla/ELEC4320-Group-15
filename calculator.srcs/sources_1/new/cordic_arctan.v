`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// CORDIC-based arctangent (vectoring mode) with no LUT memory.
// Computes atan2(y, x) using iterative shifts and compile-time-generated angle constants.
// Fixed-point: signed N-bit with Q fractional bits.
module cordic_arctan #(
    parameter integer N    = `WIDTH,
    parameter integer Q    = `FRAC,
    parameter integer ITER = 16
)(
    input  wire              clk,
    input  wire              reset,
    input  wire              in_valid,
    input  wire signed [N-1:0] y_in,
    input  wire signed [N-1:0] x_in,
    output wire              in_ready,
    output reg               out_valid,
    output reg  signed [N-1:0] angle_out
);

    function automatic signed [N-1:0] cordic_angle_const;
        input integer i;
        real ang;
        begin
            ang = $atan(1.0/(2.0**i));
            cordic_angle_const = $rtoi(ang * (1<<Q));
        end
    endfunction

    function automatic signed [N-1:0] const_pi;
        real p;
        begin
            p = 3.14159265358979323846;
            const_pi = $rtoi(p * (1<<Q));
        end
    endfunction

    wire signed [N-1:0] angle_const [0:ITER-1];
    genvar gi;
    generate
        for (gi = 0; gi < ITER; gi = gi + 1) begin : gen_angle_consts
            localparam signed [N-1:0] ANG = cordic_angle_const(gi);
            assign angle_const[gi] = ANG;
        end
    endgenerate

    localparam [1:0] S_IDLE   = 2'd0;
    localparam [1:0] S_VECTOR = 2'd1;

    reg [1:0] state = S_IDLE;
    reg [$clog2(ITER):0] iter;
    reg signed [N-1:0] x, y, z;
    reg signed [N-1:0] z_offset;

    assign in_ready = (state == S_IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state     <= S_IDLE;
            iter      <= 0;
            x         <= {N{1'b0}};
            y         <= {N{1'b0}};
            z         <= {N{1'b0}};
            z_offset  <= {N{1'b0}};
            angle_out <= {N{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0; // default low

            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                        // Quadrant correction to keep x positive for vectoring
                        if (x_in < 0) begin
                            x        <= -x_in;
                            y        <= -y_in;
                            z_offset <= (y_in < 0) ? -const_pi() : const_pi();
                        end else begin
                            x        <= x_in;
                            y        <= y_in;
                            z_offset <= {N{1'b0}};
                        end
                        z    <= {N{1'b0}};
                        iter <= 0;
                        state <= S_VECTOR;
                    end
                end

                S_VECTOR: begin
                    reg signed [N-1:0] x_new;
                    reg signed [N-1:0] y_new;
                    reg signed [N-1:0] z_new;
                    reg signed [1:0]   d;
                    d     = (y >= 0) ? 1 : -1;
                    x_new = x + (d * (y >>> iter));
                    y_new = y - (d * (x >>> iter));
                    z_new = z + (d * angle_const[iter]);

                    x <= x_new;
                    y <= y_new;
                    z <= z_new;

                    if (iter == ITER-1) begin
                    // Saturate final angle to Q22.10 bounds
                    reg signed [N-1:0] angle_tmp;
                    angle_tmp = z_new + z_offset;
                    if (angle_tmp[N-1] && angle_tmp != `MIN_Q && angle_tmp < `MIN_Q) begin
                    angle_out <= `MIN_Q;
                    end else if (!angle_tmp[N-1] && angle_tmp > `MAX_Q) begin
                    angle_out <= `MAX_Q;
                    end else begin
                    angle_out <= angle_tmp;
                    end
                    out_valid <= 1'b1;
                    state     <= S_IDLE;
                    end
                    iter <= iter + 1'b1;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
