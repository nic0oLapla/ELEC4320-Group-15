`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.12.2025 12:33:20
// Design Name: 
// Module Name: num_2_ascii
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


module num_2_ascii(
    input clk,
    input [31:0] num,
    input start,
    input uart_ready,
    output reg [7:0] char,
    output reg uart_start,
    output wire  running
    );

    reg [31:0] div;             // "divisor"
    reg [21:0] int_rem;         // integer remainder
    reg [9:0] frac_rem;         // fractional remainder
    reg [3:0] curr_digit;       // value of current digit
    reg [3:0] digit_idx;        // current digit pos (0123456.8910)
    reg [3:0] digitised [0:9];  // full number split into digits
    reg leading_zeros;          // flag for leading zeros
    reg neg;                    // flag for negative
    reg dot;                    // have we printed the dot yet?

    // State Machine
    localparam IDLE = 0, SUB = 1, SEND_INT = 2, SEND_FRAC = 3, SEND_CR = 4, SEND_LF = 5;
    reg [2:0] state = IDLE;

    always @(posedge clk) begin
        uart_start <= 0;
        case (state)
        // WAITING FOR NEW NUMBER FROM CALCULATOR
        IDLE: begin
            if (start) begin 
                if (num[31]) begin
                    neg <= 1;
                    int_rem <= (~num + 1) >> 10; // scale by 1/1024
                    frac_rem <= ((~num + 1) & 10'h3FF) * 1000 >> 10; // mask lower 10 bits, scale by 1000/1024
                end else begin
                    neg <= 0;
                    int_rem <= num >> 10; // scale by 1/1024
                    frac_rem <= (num & 10'h3FF) * 1000 >> 10; // mask lower 10 bits, scale by 1000/1024
                end
                curr_digit <= 0;
                digit_idx <= 0;     // start at 1,000,000s place
                leading_zeros <= 1; // assume leading zeros
                dot <= 1;
                state <= SUB;       // start calculating
            end
        end

        // SUBTRACT UNTIL WE FIND THE CURRENT DIGIT'S VALUE
        SUB: begin
            case (digit_idx)                    // probably faster than using a power circuit
                0: div = 1000000;
                1: div = 100000;
                2: div = 10000;
                3: div = 1000;
                4: div = 100;
                5: div = 10;
                6: div = 1;
                7: div = 100;
                8: div = 10;
                9: div = 1;
            endcase
            
            if (digit_idx <= 6 && int_rem >= div) begin // INT: still going, subtract div and loop again
                int_rem <= int_rem - div;
                curr_digit <= curr_digit + 1;
            end else if (digit_idx >= 7 && frac_rem >= div) begin // FRAC: still going, subtract div and loop again
                frac_rem <= frac_rem - div;
                curr_digit <= curr_digit + 1;
            end else begin // digit value found, move on to next digit
                digitised[digit_idx] <= curr_digit;
                curr_digit <= 0;
                if (digit_idx == 9) begin
                    digit_idx <= 0;
                    state <= SEND_INT;
                end else begin
                    digit_idx <= digit_idx + 1;
                end
            end
        end

        // PRINTING SIGN AND INTEGER DIGITS
        SEND_INT: begin
        if (uart_ready) begin
            if (neg) begin // print negative sign if needed
                char <= 8'h2D;
                uart_start <= 1;
                neg <= 0;
            end else begin
                if (digit_idx == 6) begin // always print last integer digit, swap to printing fractional digits
                    char <= {4'h3, digitised[digit_idx]};
                    uart_start <= 1;                     
                    state <= SEND_FRAC; 
                end else if (!leading_zeros || digitised[digit_idx] != 0) begin // print valid digit, skip leading zeros             
                    char <= {4'h3, digitised[digit_idx]};
                    uart_start <= 1;   
                    leading_zeros <= 0;                   
                end
                digit_idx <= digit_idx + 1;  
            end              
        end
        end
        
        // PRINTING DOT AND FRACTIONAL DIGITS
        SEND_FRAC: begin
        if (uart_ready) begin
            if (dot) begin
                char <= 8'h2E;   // load full stop (.)  
                uart_start <= 1; // trigger the UART    
                dot <= 0;        // disable dot flag
            end else begin
                char <= {4'h3, digitised[digit_idx]};
                uart_start <= 1;            
                if (digit_idx == 9) state <= SEND_CR;
                else digit_idx <= digit_idx + 1;
            end
        end
        end
            
        // PRINTING NEWLINE CHARACTERS
        SEND_CR: begin
        if (uart_ready) begin
            char <= 8'h0D;
            uart_start <= 1;
            state <= SEND_LF;
        end
        end
        SEND_LF: begin
        if (uart_ready) begin
            char <= 8'h0A;
            uart_start <= 1;
            state <= IDLE;
        end
        end
        endcase
    end
    
    assign running = state != IDLE;
    
endmodule
