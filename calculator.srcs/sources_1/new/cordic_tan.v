`timescale 1ns / 1ps
`include "define.v"
`default_nettype none

// CORDIC-based tangent (rotation mode) with no LUT memory.
// Computes tan(theta) by first producing sin/cos via iterative CORDIC, then divides.
// Fixed-point: signed N-bit with Q fractional bits.
module cordic_tan #(
    parameter integer N    = `WIDTH,
    parameter integer Q    = `FRAC,
    parameter integer ITER = 16
)(
    input  wire             clk,
    input  wire             reset,
    input  wire             in_valid,
    input  wire signed [N-1:0] angle,   // input angle (radians, signed fixed)
    output wire             in_ready,
    output reg              out_valid,
    output reg  signed [N-1:0] tan_out
);

    // Angle constants (arctan(2^-i) in fixed-point) generated at elaboration, not stored in a ROM
    function automatic signed [N-1:0] cordic_angle_const;
        input integer i;
        real ang;
        begin
            ang = $atan(1.0/(2.0**i));
            cordic_angle_const = $rtoi(ang * (1<<Q));
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
    localparam [1:0] S_ROTATE = 2'd1;
    localparam [1:0] S_DIV    = 2'd2;

    reg [1:0] state = S_IDLE;
    reg [$clog2(ITER):0] iter;
    reg signed [N-1:0] x, y, z;
    reg signed [N-1:0] sin_reg, cos_reg;

    // Divider for tan = sin/cos
    wire        div_in_ready;
    wire        div_out_valid;
    wire [N-1:0] div_q;
    wire        div_start = (state == S_DIV) && div_in_ready;

    divider_pipelined #(.Q(Q), .N(N)) u_div (
        .clk         (clk),
        .reset       (reset),
        .in_valid    (div_start),
        .dividend    (sin_reg),
        .divisor     (cos_reg),
        .in_ready    (div_in_ready),
        .out_valid   (div_out_valid),
        .out_overflow(), // ignored
        .quotient    (div_q)
    );

    assign in_ready = (state == S_IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state     <= S_IDLE;
            iter      <= 0;
            x         <= {N{1'b0}};
            y         <= {N{1'b0}};
            z         <= {N{1'b0}};
            sin_reg   <= {N{1'b0}};
            cos_reg   <= {N{1'b0}};
            tan_out   <= {N{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0; // default low

            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                        // Initialize vector (unity magnitude in fixed-point)
                        x    <= { { (N-Q-1){1'b0} }, {1'b1}, {Q{1'b0}} }; // 1.0 in Q format
                        y    <= {N{1'b0}};
                        z    <= angle;
                        iter <= 0;
                        state <= S_ROTATE;
                    end
                end

                S_ROTATE: begin
                    // Rotation mode step
                    // Use temporaries to avoid read-after-write
                    reg signed [N-1:0] x_new;
                    reg signed [N-1:0] y_new;
                    reg signed [N-1:0] z_new;
                    reg signed [1:0]   d;
                    d     = (z >= 0) ? 1 : -1;
                    x_new = x - (d * (y >>> iter));
                    y_new = y + (d * (x >>> iter));
                    z_new = z - (d * angle_const[iter]);

                    x <= x_new;
                    y <= y_new;
                    z <= z_new;

                    if (iter == ITER-1) begin
                        sin_reg <= y_new;
                        cos_reg <= x_new;
                        state   <= S_DIV;
                    end
                    iter <= iter + 1'b1;
                end

                S_DIV: begin
                    if (div_start) begin
                        // wait for divider pipeline to finish
                    end
                    if (div_out_valid) begin
                        tan_out   <= div_q;
                        out_valid <= 1'b1;
                        state     <= S_IDLE;
                    end
                end
            endcase
        end
    end

endmodule

`default_nettype wire
