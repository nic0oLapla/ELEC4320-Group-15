`timescale 1ns / 1ps
`include "define.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/13/2020 01:32:12 AM
// Design Name: 
// Module Name: piano
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


module electronic_calculator_top(
    input         clk,
    input         PS2Data,
    input         PS2Clk,
    
    output        tx,
    output        led_0,
    output        led_1
    
//    input  clk_in,
//    input  reset,
//    input  [31:0] in_A,
//    input  [31:0] in_B,
//    input  [3:0]  in_OP,
//    input  input_done,
//    //input  alu_done, //testing purpose for state machine, remove with ALU implementation
//    //input  [31:0] result_reg_manipulation, //testing purpose for state machine, remove with ALU implementation

//    output [31:0] out_RESULT,
//    output [1:0] current_state //testing purpose for state machine, remove with ALU implementation


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
    
    reg         alu_valid_in;
    wire        alu_valid_out;
    wire [31:0] ALU_out;
    
    // FSM state definitions in define.v
    reg [1:0] state;
    // Connect LEDs
    assign led_0 = locked;
    assign led_1 = ~state[0]; // Example: led_1 is on when not in IDLE

    clk_300_mhz clk_gen (
        .clk_out1(clk_300MHz),
        .reset(reset),
        .locked(locked),
        .clk_in1(clk)
    );
    wire clk_300_mhz;
    wire locked;
    wire [31:0] ALU_out;
    wire [1:0] cs;

    //data control signals
    reg input_active;
    reg alu_active;
    reg output_active;

    reg output_done;

    reg [31:0] valid_in_A;
    reg [31:0] valid_in_B;
    reg [3:0] valid_in_OP;
    
    wire [31:0] alu_in_A;
    wire [31:0] alu_in_B;
    wire [3:0]  alu_in_OP;
    
    assign alu_in_A = valid_in_A;
    assign alu_in_B = valid_in_B;
    assign alu_in_OP = valid_in_OP;

    reg [31:0] result_reg;
    assign out_RESULT = result_reg;

    //wire alu_done;
    assign current_state = cs; //for testing purpose, external monitoring of state machine

    clk_gen CLK_300_MHz (
        .clk_in         (clk_in),
        .clk_300_mhz    (clk_300_mhz),
        .reset          (reset),
        .locked         (locked)
    );

    state STATE(
        .clk            (clk_300_mhz),
        .reset          (reset),
        .locked         (locked),
        .valid_input    (input_done),
        .alu_done       (alu_done),
        .output_done    (output_done),

        .cs             (cs)
    );

    ALU ALU(
        .clk            (clk_300_mhz),
        .reset          (reset), 
        .alu_active     (alu_active), // To control when ALU should process inputs

        .in_A           (alu_in_A),
        .in_B           (alu_in_B),
        .opcode         (alu_in_OP),

        .alu_done       (alu_done),
        .ALU_out        (ALU_out)
    );

    // This top-level currently only instantiates the clocking primitive.
    // Control and ALU logic can be added here; the `state` module is
    // tested separately via the provided testbench `state_tb.v`.

    //state machine control logic to be added here
    always @(posedge clk_300_mhz or posedge reset) begin
    if (reset) begin
        input_active <= 1'b0;
        output_active <= 1'b0;
        output_done <= 1'b0;     
    end else begin
        // State machine transitions if needed
        case (cs)
            `STARTUP: begin
                // Initialization logic 
                input_active <= 1'b0;
                alu_active <= 1'b0;
                output_active <= 1'b0;
                output_done <= 1'b0;
            end
            `INPUT: begin
                // Input handling logic if needed
                input_active <= 1'b1;
                alu_active <= 1'b0;
                output_active <= 1'b0;
                output_done <= 1'b0;
            end
            `CALC: begin
                // Calculation handling logic if needed
                input_active <= 1'b0;
                alu_active <= 1'b1;
                output_active <= 1'b0;

            end
            `OUTPUT: begin
                // Output handling logic if needed
                output_active <= 1'b1;
                alu_active <= 1'b0;
                input_active <= 1'b0;
            end
            default: begin
                // Default case handling if needed
                input_active <= 1'b0;
                alu_active <= 1'b0;
                output_active <= 1'b0;
            end
        endcase
    end
    end

    always @(posedge clk_300_mhz or posedge reset) begin
        if (reset) begin
            valid_in_A <= 32'b0;
            valid_in_B <= 32'b0;
            valid_in_OP <= 4'b0;
        end else if (input_done) begin //or should it be input_active?
            valid_in_A <= in_A;
            valid_in_B <= in_B;
            valid_in_OP <= in_OP;
        end 
        
    end

    always @(posedge clk_300_mhz or posedge reset) begin
        if (reset) begin
            result_reg <= 32'b0;
        end else if (alu_done) begin
            result_reg <= ALU_out;
            //result_reg <= result_reg_manipulation; //for testing only
            output_done <= 1'b1;
        end        
    end

endmodule
