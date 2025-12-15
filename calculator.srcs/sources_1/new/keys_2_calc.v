`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.12.2025 18:15:55
// Design Name: 
// Module Name: keys_2_calc
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

module keys_2_calc(
    input clk,
    input [7:0] keycode,    // input from ps/2 receiver (1 byte ps/2 code)
    input start,            // sp/2 end-of-char         (1-tick high when keycode ready)
    output reg [31:0] out,  // output to accumulator
    output reg out_num,     // 1-tick pulse when output num ready
    output reg out_op,      // 1-tick pulse when output op ready   
    output reg enter
    );
    
    reg [9:0]  acc = 0;
    reg [31:0] num = 0;
    reg [1:0] count = 0;
    reg sign = 0; // 0 positive, 1 negative

    localparam GET_KEY = 0,     // Waiting for keyboard input
               PREP_NUM = 1,    // 3 digits entered, prepare num
               PUSH_NUM = 2;    // Number ready to push or send
    reg [1:0] state = GET_KEY;
    
    task digit(input [7:0] D); 
        begin
            acc <= (acc << 3) + (acc << 1) + D; // faster version of num <= num * 10 + D
            count <= count + 1;
            if (count == 2) begin
                state <= PREP_NUM;
            end
        end 
    endtask
    
    task opcode(input [3:0] O);
        begin
            out <= O;
            out_op <= 1;
        end
    endtask
    
    always@(posedge clk) begin
        out_num <= 0;
        out_op <= 0;
        enter <= 0;
        case (state)
        GET_KEY: begin
            if (start) begin
                case (keycode)
                8'h16: digit(8'd1);     // Digits [1-9, 0]
                8'h1E: digit(8'd2);
                8'h26: digit(8'd3);
                8'h25: digit(8'd4);
                8'h2E: digit(8'd5);
                8'h36: digit(8'd6);
                8'h3D: digit(8'd7);
                8'h3E: digit(8'd8);
                8'h46: digit(8'd9);
                8'h45: digit(8'd0);
                
                8'h4E: sign <= ~sign;   // Negative
                
                8'h15: opcode(0);       // Binary opcodes: [0-3, 10-11]
                8'h1D: opcode(1);
                8'h24: opcode(2);
                8'h2D: opcode(3);
                8'h1C: opcode(10);
                8'h1B: opcode(11);
                
                8'h2C: opcode(4);        // Unary opcodes: [4-9, 12-13]
                8'h35: opcode(5);
                8'h3C: opcode(6);
                8'h43: opcode(7);
                8'h44: opcode(8);
                8'h4D: opcode(9);
                8'h23: opcode(12);
                8'h2B: opcode(13);
                
                8'h5A: enter <= 1;       // Enter - print result
                endcase       
            end
        end
        
        PREP_NUM: begin
            if (acc != 0) begin
                if (!sign) num <= acc << 10;
                else num <= -(acc << 10);
            end
            state <= PUSH_NUM;
        end
        
        PUSH_NUM: begin
            out <= num;
            out_num <= 1;
            acc <= 0;
            num <= 0;
            count <= 0;
            sign <= 0;
            state <= GET_KEY;
        end
        endcase
    end
    
endmodule
