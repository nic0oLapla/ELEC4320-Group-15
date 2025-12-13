`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.12.2025 17:18:20
// Design Name: 
// Module Name: accumulator
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


module accumulator(
    input clk,
    input [31:0] key,       // input from keyboard
    input [31:0] res,       // input from ALU
    input start_key,        // start signal from keyboard
    input start_alu,        // start signal from ALU
    input type_key,         // type of input from keyboard: high = num, low = opcode
    input idle,             // idle signal from ALU
    input enter,            // print signal from keyboard
    output reg [31:0] A,    // first operand            (2's C fixed-point, 1-21-10)
    output reg [31:0] B,    // second operand           (2's C fixed-point, 1-21-10)
    output reg [3:0] op,    // opcode                   (4-bit 0-13)
    output reg valid,       // valid calc for ALU       (1-tick high when A,B,op ready to calc)
    output reg [31:0] final,// final result for UART    (2's C fixed-point, 1-21-10)
    output reg print        // ready to print for UART  (1-tick high when final ready to print)
    );
    
    reg p_start = 0;
    localparam IDLE = 0, NUM = 1, U_OP = 2, B_OP = 3;
    reg [1:0] prev = NUM; // Last item pushed - pseudostate

    // Stack (would have done this as a seperate module but then I'd need multiple clock cycles for multiple pushes/pops)
    reg [31:0]  stack [0:31];
    reg [3:0]   rsp = 0;
    wire empty = rsp == 0;
    
    task printf(input [31:0] num);
        begin
            final <= num; 
            print <= 1;
        end
    endtask
    
    always @(posedge clk) begin
    valid <= 0;
    print <= 0;
    if (idle) begin
        // USER REQUESTED PRINT RESULT
        if (enter) begin
            if (!empty) begin
                printf(stack[rsp-1]);
                rsp <= rsp - 1;
            end else printf(0); // print 0 if nothing in stack?
        end
        
        // RESULT FROM ALU
        else if (start_alu) begin
            if (!valid) begin
            if (empty) begin
                stack[rsp] <= res;
                rsp <= rsp + 1;
                prev <= NUM;
            end else begin
                case (stack[rsp-1]) // If stack is not empty after getting result, top will always be a queued opcode 
                0, 1, 2, 3, 10, 11: begin       // Binary OP
                    op <= stack[rsp-1];
                    A <= stack[rsp-2];
                    B <= res;
                    rsp <= rsp - 2;
                end
                4, 5, 6, 7, 8, 9, 12, 13: begin // Unary OP
                    op <= stack[rsp-1];
                    A <= res;
                    B <= 0;
                    rsp <= rsp - 1;
                end
                endcase
                valid <= 1; // Tell ALU we have a calculation for it
            end
            end
        end 
        
        // INPUT FROM KEYBOARD
        else if (start_key) begin
            // NUMBER FROM KEYBOARD
            if (type_key) begin 
                case (prev) 
                NUM: begin  // If empty push, else top is NUM: replace
                    if (empty) begin
                        stack[rsp] <= key;                                                                                                                                                                                                                                                                                                                                                        
                        rsp <= rsp + 1;
                    end else begin
                        stack[rsp-1] <= key; 
                    end
                    // Prev is already num
                end
                B_OP: begin // Top is binary op, send to ALU
                    op <= stack[rsp-1];
                    A <= stack[rsp-2];
                    B <= key;
                    rsp <= rsp - 2;
                    valid <= 1;
                end
                U_OP: begin // Top is unary op, send to ALU
                    op <= stack[rsp-1];
                    A <= key;
                    B <= 0;
                    rsp <= rsp - 1;
                    valid <= 1;
                end
                endcase
                printf(key); // print input
            end 
            
            // OPCODE FROM KEYBOARD
            else begin
                case (key)
                0, 1, 2, 3, 10, 11: begin // Binary OP
                    if (prev == NUM) begin
                        stack[rsp] <= key;
                        rsp <= rsp + 1;
                    end else begin
                        stack[rsp-1] <= key;
                    end
                    prev <= B_OP;
                end
                4, 5, 6, 7, 8, 9, 12, 13: begin // Unary OP
                    stack[rsp] <= key;
                    rsp <= rsp + 1;
                    prev <= U_OP;
                end
                endcase
                printf(key << 10); // print raw opcode
            end
        end
    end
    end
    
endmodule
