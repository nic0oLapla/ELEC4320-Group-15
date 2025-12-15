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
    input start_key_num,    // start signal from keyboard (num)
    input start_key_op,     // start signal from keyboard (op)
    input start_alu,        // start signal from ALU
    input idle,             // idle signal from ALU
    input enter,            // print signal from keyboard
    output reg [31:0] A,    // first operand            (2's C fixed-point, 1-21-10)
    output reg [31:0] B,    // second operand           (2's C fixed-point, 1-21-10)
    output reg [3:0] op,    // opcode                   (4-bit 0-13)
    output reg valid,       // valid calc for ALU       (1-tick high when A,B,op ready to calc)
    output reg [31:0] final,// final result for UART    (2's C fixed-point, 1-21-10)
    output reg print        // ready to print for UART  (1-tick high when final ready to print)
    );
    
    localparam IDLE = 0, RES = 1, KEY_N = 2, KEY_B = 3, KEY_U = 4, PUSH_N = 5, READ_CALC = 6, SEND_B = 7, SEND_U = 8, PRINT = 9;
    reg [3:0] state = IDLE;
    localparam NUM = 0, U_OP = 1, B_OP = 2;
    reg [1:0] prev = NUM; // Last item pushed - pseudostate

    // Stack
    reg [3:0]  rsp = 0;
    reg [3:0]  top = -1; // precalculate rsp-1 at the end of every cycle
    reg [3:0]  nex = -2; // precalculate rsp-2 at the end of every cycle
    reg        empty = 1;
    (* keep = "true", max_fanout = 8 *) reg [3:0] addr; // try to eliminiate multiplexing stack write address, pre-load before cycle
    (* ram_style = "distribute" *) reg [31:0] stack [0:15];
    
    reg [3:0] cached_op;
    
    task printf(input [31:0] num);
        begin
            final <= num; 
            print <= 1;
        end
    endtask
    
    task update(input signed [3:0] diff);
        begin
            rsp <= rsp + diff;
            top <= top + diff;
            nex <= nex + diff;
            empty <= rsp == -diff;
        end
    endtask
    
    always @(posedge clk) begin
    valid <= 0;
    print <= 0;
    if (idle) begin
    case (state)
        IDLE: begin
            if (enter) begin
                state <= PRINT;
            end else if (start_alu) begin
                addr <= rsp;
                state <= RES;
            end else if (start_key_num) begin
                state <= KEY_N;
            end else if (start_key_op) begin
                case (key[3:0])
                0, 1, 2, 3, 10, 11: begin
                    addr <= prev == NUM ? rsp : key;
                    state <= KEY_B;
                end
                4, 5, 6, 7, 8, 9, 12, 13: begin
                    addr <= rsp;
                    state <= KEY_U;
                end
                endcase
            end
        end
        
        RES: begin
            if (!valid) begin
                if (empty) begin
                    stack[addr] <= res;
                    update(1);
                    prev <= NUM;
                    state <= IDLE;
                end else begin
                    cached_op <= stack[top][3:0];
                    state <= READ_CALC;
                end
            end
        end
        
        // NUMBER FROM KEYBOARD
        KEY_N: begin
            case (prev) 
            NUM: begin
                addr <= empty ? rsp : top;
                state <= PUSH_N;
            end
            B_OP: begin
                B <= key;
                state <= SEND_B;
            end
            U_OP: begin
                A <= key;
                state <= SEND_U;
            end
            endcase
            printf(key); // print input
        end
        
        // OPCODE FROM KEYBOARD      
        KEY_B: begin // Binary OP
            stack[addr] <= key;
            if (prev == NUM) update(1);
            prev <= B_OP;
            printf(key << 10); // print raw opcode
            state <= IDLE;
        end
        
        KEY_U: begin // Unary OP
            stack[addr] <= key;
            update(1);
            prev <= U_OP;
            printf(key << 10); // print raw opcode
            state <= IDLE;
        end
        
        PUSH_N: begin
            stack[addr] <= key;
            if (empty) update(1);
            // Prev is already num, no need to set
            state <= IDLE;
        end
        
        READ_CALC: begin
            case (cached_op)
            0, 1, 2, 3, 10, 11: begin       // Binary OP
                B <= res;
                state <= SEND_B;
            end
            4, 5, 6, 7, 8, 9, 12, 13: begin // Unary OP
                A <= res;
                state <= SEND_U;
            end
            endcase
        end
        
        SEND_B: begin
            op <= stack[top];
            A <= stack[nex];
            // B set by previous state
            update(-2);
            valid <= 1; // Tell ALU we have a calculation for it
            state <= IDLE;
        end  
        
        SEND_U: begin
            op <= stack[top];
            // A set by previous state
            B <= 0;
            update(-1);
            valid <= 1; // Tell ALU we have a calculation for it
            state <= IDLE;
        end
        
        PRINT: begin
            if (!empty) begin
                printf(stack[top]);
                update(-1);
            end else begin
                printf(0); // print 0 if nothing in stack?
            end
            state <= IDLE;
        end
        endcase
    end
    end
    
endmodule
