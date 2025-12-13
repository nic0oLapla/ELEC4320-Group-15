`timescale 1ns / 1ps
`include "define.v"
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
    input         PS2Data,
    input         PS2Clk,
    output        tx,
    output        led_0,
    output        led_1
);

    wire [7:0]  keycode;
    wire        valid_ps2;
    wire [31:0] A;
    wire [31:0] B;
    wire [3:0]  op;
    wire [31:0] final;
    wire        valid_calc;
    wire        print;
    wire [7:0]  ascii;
    wire        uart_ready;
    wire        uart_start;
    
    reg  [31:0] result = 21 << 10;
    wire        alu_idle;
    
    ps2_receiver ps2_in (
        .clk        (clk),
        .kb_clk     (PS2Clk),
        .kb_key     (PS2Data),
        
        .keycode    (keycode),
        .valid      (valid_ps2)
    );
    
    keys_2_calc controller (
        .clk(clk),
        .keycode(keycode),
        .result(result),
        .start(valid_ps2),        
        .idle(alu_idle),
                 
        .A(A),    
        .B(B),    
        .op(op),    
        .final(final),
        .valid(valid_calc),       
        .print(print)        
    );
    
    wire        locked;
    wire        clk_300MHz;
    wire        reset = 0; // Assuming active-high reset, connect to a button if available

    // FSM state definitions in define.v
    reg [1:0] state = `S_STARTUP, next_state;

    // ALU signals
    reg         alu_valid_in;
    wire        alu_valid_out;
    wire [31:0] ALU_out;
    
    // Connect LEDs
    assign led_0 = locked;
    assign led_1 = ~state[0]; // Example: led_1 is on when not in IDLE

    clk_300_mhz clk_gen (
        .clk_out1(clk_300MHz),
        .reset(reset),
        .locked(locked),
        .clk_in1(clk)
    );

    
    num_2_ascii converter (
        .clk        (clk),
        .num        (final),
        .start      (print),
        .uart_ready (uart_ready),
        
        .char       (ascii),
        .uart_start (uart_start)
    );
    
    uart_sender uart_out (
        .clk    (clk),
        .start  (uart_start),
        .char   (ascii),
        
        .tx     (tx),
        .ready  (uart_ready)
    );
    
    ALU ALU_inst (
        .clk(clk_300MHz),
        .rst(reset),
        .valid_in(alu_valid_in),
        .in_A(A),
        .in_B(B),
        .opcode(op),
        .valid_out(alu_valid_out),
        .ALU_out(ALU_out)
    );

    

    always @(posedge clk_300MHz) begin
        case (state)
            `S_STARTUP: begin
                if (locked)
                    next_state = `S_IDLE;
            end
            `S_IDLE: begin
                if (valid_calc) begin
                    alu_valid_in = 1'b1;
                    next_state <= `S_CALC;
                end
            end
            `S_CALC: begin
                if (alu_valid_out)
                    next_state <= `S_RESULT_READY;
            end
            `S_RESULT_READY: begin
                //fix
                next_state = `S_IDLE;
            end
        endcase
    end

    assign alu_idle = (state == `S_IDLE);

endmodule
