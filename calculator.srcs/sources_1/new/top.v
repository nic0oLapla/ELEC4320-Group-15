`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.12.2025 20:12:17
// Design Name: 
// Module Name: top
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


module top(
    input         clk,
    input         reset,
    input         PS2Data,
    input         PS2Clk,
    output        tx
);
    wire        clk_300;

    wire [7:0]  ps2_code;
    wire        ps2_valid;
    
    wire [31:0] key_out;
    wire        key_num;
    wire        key_op;
    wire        key_enter;
    
    wire [31:0] A;
    wire [31:0] B;
    wire [3:0]  op;
    wire [31:0] acc_final;
    wire        acc_valid;
    wire        acc_print;
    
    wire [31:0] alu_result;
    wire        alu_idle;
    wire        alu_valid;
    
    wire [7:0]  ascii;
    wire        uart_ready;
    wire        uart_start;
    
    clk_300_mhz clk_gen_300 (
        .clk_in1(clk),
        .clk_out1(clk_300)
    );
    
    ps2_receiver ps2_in (
        .clk        (clk_300),
        .kb_clk     (PS2Clk),
        .kb_key     (PS2Data),
        
        .keycode    (ps2_code),
        .valid      (ps2_valid)
    );
    
    keys_2_calc k2c (
        .clk(clk_300),
        .keycode(ps2_code),
        .start(ps2_valid),        
                 
        .out(key_out),
        .out_num(key_num), 
        .out_op(key_op),
        .enter(key_enter)        
    );
    
    accumulator acc (
        .clk(clk_300),
        .key(key_out),
        .res(alu_result),
        .start_key_num(key_num),
        .start_key_op(key_op),
        .start_alu(alu_valid),
        .idle(alu_idle),
        .enter(key_enter),
        
        .A(A),
        .B(B),
        .op(op),
        .valid(acc_valid),
        .final(acc_final),
        .print(acc_print)
    );
    
    ALU #(
        .N(32),
        .Q(10)
    ) alu (
        .clk(clk_300),
        .reset(reset),
        .valid_in(acc_valid),      // Handshake: new operation is valid
        .in_A(A),
        .in_B(B),
        .opcode(op),
        
        .valid_out(alu_valid),     // Handshake: result is valid
        .ALU_out(alu_result),
        .idle(alu_idle)
    );
    
    num_2_ascii n2a (
        .clk        (clk_300),
        .num        (acc_final),
        .start      (acc_print),
        .uart_ready (uart_ready),
        
        .char       (ascii),
        .uart_start (uart_start)
    );
    
    uart_sender uart_out (
        .clk    (clk_300),
        .start  (uart_start),
        .char   (ascii),
        
        .tx     (tx),
        .ready  (uart_ready)
    );

    // -------------------------------------------------------------------------
    // Passive FSM monitor (debug only) mapped to existing valid/ready protocol.
    // Does NOT drive datapath; useful for waveform visibility and integration
    // with legacy state naming. Synchronous reset per best_practices.md.
    // States: STARTUP -> INPUT -> CALC -> OUTPUT -> INPUT
    //   - INPUT  : waiting for acc_valid (operation prepared)
    //   - CALC   : after acc_valid until alu_valid
    //   - OUTPUT : after alu_valid while printing is in progress
    // STARTUP exits after first cycle post reset.
    // -------------------------------------------------------------------------
    localparam [1:0] ST_STARTUP = 2'd0,
                     ST_INPUT   = 2'd1,
                     ST_CALC    = 2'd2,
                     ST_OUTPUT  = 2'd3;

    reg  [1:0] fsm_cs;
    reg        print_busy;         // set on acc_print pulse; cleared after quiet window
    reg  [3:0] print_quiet_cnt;    // counts idle cycles with no uart_start activity

    // Track printing activity window heuristically (no explicit done from n2a)
    always @(posedge clk_300) begin
        if (reset) begin
            print_busy      <= 1'b0;
            print_quiet_cnt <= 4'd0;
        end else begin
            // Start of a new print sequence
            if (acc_print)
                print_busy <= 1'b1;

            // Count quiet cycles when no UART start strobe occurs
            if (print_busy) begin
                if (uart_start) begin
                    print_quiet_cnt <= 4'd0;
                end else if (print_quiet_cnt != 4'hF) begin
                    print_quiet_cnt <= print_quiet_cnt + 4'd1;
                end

                // Consider printing done after a quiet window and UART ready
                if (print_quiet_cnt >= 4 && uart_ready) begin
                    print_busy      <= 1'b0;
                    print_quiet_cnt <= 4'd0;
                end
            end else begin
                print_quiet_cnt <= 4'd0;
            end
        end
    end

    // Synchronous FSM monitor
    always @(posedge clk_300) begin
        if (reset) begin
            fsm_cs <= ST_STARTUP;
        end else begin
            case (fsm_cs)
                ST_STARTUP: begin
                    // Exit startup after reset is deasserted for one cycle
                    fsm_cs <= ST_INPUT;
                end
                ST_INPUT: begin
                    if (acc_valid)
                        fsm_cs <= ST_CALC;
                    else
                        fsm_cs <= ST_INPUT;
                end
                ST_CALC: begin
                    if (alu_valid)
                        fsm_cs <= ST_OUTPUT;
                    else
                        fsm_cs <= ST_CALC;
                end
                ST_OUTPUT: begin
                    if (!print_busy)
                        fsm_cs <= ST_INPUT;
                    else
                        fsm_cs <= ST_OUTPUT;
                end
                default: begin
                    fsm_cs <= ST_STARTUP;
                end
            endcase
        end
    end

endmodule
`default_nettype wire
