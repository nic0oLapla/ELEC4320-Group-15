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
    input [31:0] result,    // output from ALU          (2's C fixed-point, 1-21-10)
    input start,            // sp/2 end-of-char         (1-tick high when keycode ready)
    input idle,             // ALU state                (high = ALU idle, low = ALU running)
    output reg [31:0] A,    // first operand            (2's C fixed-point, 1-21-10)
    output reg [31:0] B,    // second operand           (2's C fixed-point, 1-21-10)
    output reg [3:0] op,    // opcode                   (4-bit 0-13)
    output reg [31:0] final,// final result for UART    (2's C fixed-point, 1-21-10)
    output reg valid,       // valid calc for ALU       (1-tick high when A,B,op ready to calc)
    output reg print        // ready to print for UART  (1-tick high when final ready to print)
    );
    
    reg [3:0] digit = 0;
    reg [1:0] count = 0;
    reg sign = 0; // 0 positive, 1 negative
    
    reg p_start = 0;
    localparam DIG = 0, U_OP = 1, B_OP = 2;
    reg [1:0] p_push = DIG; // Last item pushed

    // Stack (would have done this as a seperate module but then I'd need multiple clock cycles for multiple pushes/pops
    reg [31:0]  stack [0:31];
    reg [3:0]   rsp = 0;
    wire empty = rsp == 0;

    localparam KEY = 0,         // Waiting for keyboard input
               PREP_NUM = 1,    // 3 digits entered, prepare num
               PUSH_NUM = 2,    // Number ready to push or send
               RES = 3;         // Waiting for result from ALU
    reg [1:0] state = KEY;
    
    always@(posedge clk) begin
    valid <= 0;    // set valid back to zero for 1-tick pulse
    if (idle) begin
        case (state)
        KEY: begin
            if (start && !p_start) begin   // Wait for signal from ps/2 receiver
            case (keycode)
            8'h16, 8'h1E, 8'h26, 8'h25, 8'h2E, 8'h36, 8'h3D, 8'h3E, 8'h46, 8'h45: begin // Digits [1-9, 0]
                digit <= (8'd10 * digit) + keycode;
                count <= count + 1;
                if (count == 3) begin
                    state <= PREP_NUM;
                end
            end
            
            8'h4E: sign <= ~sign;                                                       // Negative
            
            8'h15, 8'h1D, 8'h24, 8'h2D, 8'h1C, 8'h1B: begin                             // Binary opcodes: [0-3, 10-11]
                stack [rsp] <= keycode;
                rsp <= rsp + 1;
                p_push <= B_OP;
            end
            
            8'h2C, 8'h35, 8'h3C, 8'h43, 8'h44, 8'h4D, 8'h23, 8'h2B: begin               // Unary opcodes: [4-9, 12-13]
                if (p_push == DIG) begin
                    stack[rsp] <= keycode;
                    rsp <= rsp + 1;
                end else begin
                    stack[rsp-1] <= keycode;  // Replace last entered operation (cannot have binary operation after anything except digit)
                end
            end
            
            8'h5A: begin                                                                // Enter - print result
                
            end           
            endcase
            count <= count + 1;
        end
        end
        
        PREP_NUM: begin
            if (digit != 0) begin
                if (!sign) digit <= digit << 10;
                else digit <= -(digit << 10);
            end
            state <= PUSH_NUM;
        end
        
        PUSH_NUM: begin
            case (p_push) // If previous entry was an operation, send to ALU, else replace last entered number
            DIG: begin
                stack[rsp-1] <= digit;  
                p_push <= DIG;
                state <= KEY;
            end
            B_OP: begin
                op <= stack[rsp-1];
                A <= stack[rsp-2];
                B <= digit;
                rsp <= rsp - 2;
                valid <= 1;
                state <= RES;
            end
            U_OP: begin
                op <= stack[rsp-1];
                A <= digit;
                B <= 0;
                rsp <= rsp - 1;
                valid <= 1;
                state <= RES;
            end
            endcase   

            digit <= 0;
            count <= 0;
            sign <= 0;
        end
    
        RES: begin                  // Already know ALU is idle because of top-level if (line 69)
            if (empty) begin
                stack[rsp] <= result;
                rsp <= rsp + 1;
                state <= KEY;
            end else begin
                case (stack[rsp-1]) // If stack is not empty after getting result, top will always be opcode 
                0, 1, 2, 3, 10, 11: begin       // Binary OP
                    op <= stack[rsp-1];
                    A <= stack[rsp-2];
                    B <= result;
                    rsp <= rsp - 2;
                end
                4, 5, 6, 7, 8, 9, 12, 13: begin // Unary OP
                    op <= stack[rsp-1];
                    A <= result;
                    B <= 0;
                    rsp <= rsp - 1;
                end
                endcase
                valid <= 1; // Tell ALU we have a calculation for it
            end
        end
        
        endcase
    end
    p_start <= start;
    end
    
endmodule
