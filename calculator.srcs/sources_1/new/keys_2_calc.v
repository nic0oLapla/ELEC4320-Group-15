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
    
    reg [31:0] num = 0;
    reg [1:0] count = 0;
    reg sign = 0; // 0 positive, 1 negative
    
    reg p_start = 0;
    localparam NUM = 0, U_OP = 1, B_OP = 2;
    reg [1:0] p_push = NUM; // Last item pushed

    // Stack (would have done this as a seperate module but then I'd need multiple clock cycles for multiple pushes/pops
    reg [31:0]  stack [0:31];
    reg [3:0]   rsp = 0;
    wire empty = rsp == 0;

    localparam KEY = 0,         // Waiting for keyboard input
               PREP_NUM = 1,    // 3 digits entered, prepare num
               PUSH_NUM = 2,    // Number ready to push or send
               RES = 3;         // Waiting for result from ALU
    reg [1:0] state = KEY;
    
    task digit(input [7:0] D); 
        begin
            num <= (8'd10 * num) + D;
            count <= count + 1;
            if (count == 2) begin
                state <= PREP_NUM;
            end
        end 
    endtask
    
    task binary(input [7:0] O);
        begin
            if (p_push == NUM) begin
                    stack[rsp] <= O;
                    rsp <= rsp + 1;
                end else begin
                    stack[rsp-1] <= O;  // Replace last entered operation (cannot have binary operation after anything except number)
                end
                p_push <= B_OP;
        end
    endtask
    
    task unary(input [7:0] O);
        begin               
            stack[rsp] <= O;
            rsp <= rsp + 1;
            p_push <= U_OP;
        end
    endtask
    
    always@(posedge clk) begin
    valid <= 0;
    print <= 0;
    
    if (idle) begin
        case (state)
        KEY: begin
            if (start && !p_start) begin   // Wait for signal from ps/2 receiver
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
            
            8'h15: binary(0);       // Binary opcodes: [0-3, 10-11]
            8'h1D: binary(1);
            8'h24: binary(2);
            8'h2D: binary(3);
            8'h1C: binary(10);
            8'h1B: binary(11);
            
            8'h2C: unary(4);        // Unary opcodes: [4-9, 12-13]
            8'h35: unary(5);
            8'h3C: unary(6);
            8'h43: unary(7);
            8'h44: unary(8);
            8'h4D: unary(9);
            8'h23: unary(12);
            8'h2B: unary(13);
            
            8'h5A: begin            // Enter - print result
                if (!empty) begin
                    final <= stack[rsp-1];
                    rsp <= rsp - 1;
                    print <= 1;
                end
            end           
            endcase
        end
        end
        
        PREP_NUM: begin
            if (num != 0) begin
                if (!sign) num <= num << 10;
                else num <= -(num << 10);
            end
            state <= PUSH_NUM;
        end
        
        PUSH_NUM: begin
            case (p_push) // If previous entry was a number replace it, else send calc to ALU
            NUM: begin
                if (empty) begin
                    stack[rsp] <= num;
                    rsp <= rsp + 1;
                end else begin
                    stack[rsp-1] <= num; 
                end 
                state <= KEY;
            end
            B_OP: begin
                op <= stack[rsp-1];
                A <= stack[rsp-2];
                B <= num;
                rsp <= rsp - 2;
                valid <= 1;
                state <= RES;
            end
            U_OP: begin
                op <= stack[rsp-1];
                A <= num;
                B <= 0;
                rsp <= rsp - 1;
                valid <= 1;
                state <= RES;
            end
            endcase   

            num <= 0;
            count <= 0;
            sign <= 0;
        end
    
        RES: begin                  // Already know ALU is idle because of top-level if (line 69)
            if (empty) begin
                stack[rsp] <= result;
                rsp <= rsp + 1;
                state <= KEY;
            end else begin
                case (stack[rsp-1]) // If stack is not empty after getting result, top will always be a queued opcode 
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
                state <= RES;
            end
        end
        
        endcase
    end
    p_start <= start;
    end
    
endmodule
