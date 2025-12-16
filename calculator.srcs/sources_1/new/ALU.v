`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 11.12.2025 21:10:10
// Design Name:
// Module Name: ALU
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
`include "define.v"

// ALU with mixed single-cycle and pipelined multi-cycle ops (mul/div/fact/log/tan/atan).
// Flow:
//   - Single-cycle ops (`ADD`,`SUB`, placeholders like `COS`) produce ALU_out/valid_out immediately.
//   - Multi-cycle ops launch only when idle and the target sub-block reports in_ready.
//   - active_op tracks which engine is busy; ALU blocks new requests until out_valid from that engine.
//   - operand_a/operand_b latch the inputs for the duration of a multi-cycle op.
module ALU #(
    parameter integer N = `WIDTH,   // datapath width
    parameter integer Q = `FRAC     // fractional bits (reserved for fixed-point ops)
)(
    input              clk,
    input              reset,
    input              valid_in,      // Handshake: new operation is valid
    input      [N-1:0] in_A,
    input      [N-1:0] in_B,
    input      [3:0]   opcode,
    output reg         valid_out,     // Handshake: result is valid
    output reg  [N-1:0] ALU_out,
    output reg         idle
);

    // Tracks the current multi-cycle engine in flight (not the opcode itself)
    localparam OPSTATE_NONE  = 3'd0;
    localparam OPSTATE_MUL   = 3'd1;
    localparam OPSTATE_DIV   = 3'd2;
    localparam OPSTATE_FACT  = 3'd3;
    localparam OPSTATE_LOG   = 3'd4;
    localparam OPSTATE_TAN   = 3'd5;
    localparam OPSTATE_ATAN  = 3'd6;

    reg  [2:0]  active_op;
    reg  [N-1:0] op_a;
    reg  [N-1:0] op_b;

    wire [N-1:0] operand_a = (active_op == OPSTATE_NONE) ? in_A : op_a;
    wire [N-1:0] operand_b = (active_op == OPSTATE_NONE) ? in_B : op_b;

    // Pipelined multiplier
    wire        mult_in_ready;
    wire        mult_out_valid;
    wire [2*N-1:0] mult_p;
    wire        mult_start = (active_op == OPSTATE_NONE) && valid_in && opcode == `MULT && mult_in_ready;

    multiplier_pipelined #(.N(N)) u_mult (
        .clk      (clk),
        .reset    (reset),
        .in_valid (mult_start),
        .a        (operand_a),
        .b        (operand_b),
        .in_ready (mult_in_ready),
        .out_valid(mult_out_valid),
        .p        (mult_p)
    );

    // Pipelined divider
    wire        div_in_ready;
    wire        div_out_valid;
    wire [N-1:0] div_q;
    wire        div_start = (active_op == OPSTATE_NONE) && valid_in && opcode == `DIV && div_in_ready;

    divider_pipelined #(.Q(Q), .N(N)) u_div (
        .clk         (clk),
        .reset       (reset),
        .in_valid    (div_start),
        .dividend    (operand_a),
        .divisor     (operand_b),
        .in_ready    (div_in_ready),
        .out_valid   (div_out_valid),
        .out_overflow(), // ignored
        .quotient    (div_q)
    );

    // Pipelined factorial (iterative, built atop multiplier)
    wire        fact_in_ready;
    wire        fact_out_valid;
    wire [N-1:0] fact_result;
    wire        fact_start = (active_op == OPSTATE_NONE) && valid_in && opcode == `FACT && fact_in_ready;

    factorial_pipelined #(.N(N)) u_fact (
        .clk       (clk),
        .reset     (reset),
        .in_valid  (fact_start),
        .n         (operand_a),
        .in_ready  (fact_in_ready),
        .out_valid (fact_out_valid),
        .overflow  (), // ignored
        .result    (fact_result)
    );

    // Pipelined logarithm 
    wire        log_in_ready;
    wire        log_out_valid;
    wire [N-1:0] log_result;
    wire        log_start = (active_op == OPSTATE_NONE) && valid_in && opcode == `LOG && log_in_ready;

    log_base_fixed #(.N(N), .Q(Q)) u_log (
        .clk      (clk),
        .reset    (reset),
        .in_valid (log_start),
        .base     (operand_a),
        .val      (operand_b),
        .in_ready (log_in_ready),
        .out_valid(log_out_valid),
        .log_out  (log_result)
    );

    // Pipelined tangent (CORDIC -> divide)
    wire         tan_in_ready;
    wire         tan_out_valid;
    wire [N-1:0] tan_result;
    wire         tan_start = (active_op == OPSTATE_NONE) && valid_in && opcode == `TAN && tan_in_ready;

    cordic_tan #(.N(N), .Q(Q)) u_tan (
        .clk      (clk),
        .reset    (reset),
        .in_valid (tan_start),
        .angle    (operand_a),
        .in_ready (tan_in_ready),
        .out_valid(tan_out_valid),
        .tan_out  (tan_result)
    );

    // Pipelined arctangent (CORDIC vectoring)
    wire         atan_in_ready;
    wire         atan_out_valid;
    wire [N-1:0] atan_result;
    wire         atan_start = (active_op == OPSTATE_NONE) && valid_in && opcode == `ARCTAN && atan_in_ready;

    cordic_arctan #(.N(N), .Q(Q)) u_atan (
        .clk      (clk),
        .reset    (reset),
        .in_valid (atan_start),
        .y_in     (operand_a),
        .x_in     (operand_b),
        .in_ready (atan_in_ready),
        .out_valid(atan_out_valid),
        .angle_out(atan_result)
    );

    always @(posedge clk) begin
        if (reset) begin
            idle       <= 1'b1;
            valid_out  <= 1'b0;
            ALU_out    <= {N{1'b0}};
            active_op  <= OPSTATE_NONE;
            op_a       <= {N{1'b0}};
            op_b       <= {N{1'b0}};
        end else begin
            idle      <= (active_op == OPSTATE_NONE);
            valid_out <= 1'b0;  // default low unless we produce a result this cycle

        // Completion handling for multi-cycle ops
        if (active_op == OPSTATE_MUL && mult_out_valid) begin
            ALU_out   <= mult_p[N-1:0]; // Truncate to datapath width
            valid_out <= 1'b1;
            active_op <= OPSTATE_NONE;
        end else if (active_op == OPSTATE_DIV && div_out_valid) begin
            ALU_out   <= div_q;
            valid_out <= 1'b1;
            active_op <= OPSTATE_NONE;
        end else if (active_op == OPSTATE_FACT && fact_out_valid) begin
            ALU_out   <= fact_result;
            valid_out <= 1'b1;
            active_op <= OPSTATE_NONE;
        end else if (active_op == OPSTATE_LOG && log_out_valid) begin
            ALU_out   <= log_result;
            valid_out <= 1'b1;
            active_op <= OPSTATE_NONE;
        end else if (active_op == OPSTATE_TAN && tan_out_valid) begin
            ALU_out   <= tan_result;
            valid_out <= 1'b1;
            active_op <= OPSTATE_NONE;
        end else if (active_op == OPSTATE_ATAN && atan_out_valid) begin
            ALU_out   <= atan_result;
            valid_out <= 1'b1;
            active_op <= OPSTATE_NONE;
        end else if (active_op == OPSTATE_NONE && valid_in) begin
            case (opcode)
                `ADD:  begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end
                `SUB:  begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end
                `MULT: begin
                    if (mult_start) begin
                        op_a      <= in_A;
                        op_b      <= in_B;
                        active_op <= OPSTATE_MUL;
                    end
                end
                `DIV: begin
                    if (div_start) begin
                        op_a      <= in_A;
                        op_b      <= in_B;
                        active_op <= OPSTATE_DIV;
                    end
                end

                `SQRT:   begin ALU_out <= in_A / 2; valid_out <= 1'b1; end // TODO: Square Root of reg_A
                `COS:    begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end    // TODO: Cosine of reg_A
                `TAN:    begin
                    if (tan_start) begin
                        op_a      <= in_A;
                        op_b      <= in_B;
                        active_op <= OPSTATE_TAN;
                    end
                end
                `ARCSIN: begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end    // TODO: Arcsine of reg_A
                `ARCCOS: begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end    // TODO: Arccosine of reg_A
                `ARCTAN: begin
                    if (atan_start) begin
                        op_a      <= in_A; // y input
                        op_b      <= in_B; // x input
                        active_op <= OPSTATE_ATAN;
                    end
                end

                `LOG: begin
                    if (log_start) begin
                        op_a      <= in_A;
                        op_b      <= in_B;
                        active_op <= OPSTATE_LOG;
                    end
                end
                `POW:  begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end // TODO: reg_A raised to power reg_B

                `EXP:  begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end // TODO: e raised to power reg_A
                `FACT: begin
                    if (fact_start) begin
                        op_a      <= in_A;
                        op_b      <= {N{1'b0}};
                        active_op <= OPSTATE_FACT;
                    end
                end
                default: begin ALU_out <= {N{1'b0}}; valid_out <= 1'b1; end
            endcase
        end
        end
    end
endmodule
