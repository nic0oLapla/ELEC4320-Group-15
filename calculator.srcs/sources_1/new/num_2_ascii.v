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

    
    reg [19:0] div;             // "divisor"
    reg [21:0] int_rem;         // integer remainder
    reg [9:0] frac_rem;         // fractional remainder
    reg [3:0] curr_digit;       // value of current digit
    reg [3:0] digit_idx;        // current digit pos (0123456.8910)
    reg [3:0] digitised [0:9];  // full number split into digits
    reg leading_zeros;          // flag for leading zeros
    reg neg;                    // flag for negative
    reg dot;                    // have we printed the dot yet?

    // State Machine
    localparam IDLE = 0, 
               SETUP = 1, 
               SUB_INT_CALC = 2,   
               SUB_INT_UPDATE = 3, 
               SUB_FRAC_CALC = 4,
               SUB_FRAC_UPDATE = 5,
               WRITE = 6, 
               SEND_INT = 7, 
               SEND_FRAC = 8, 
               SEND_CR = 9, 
               SEND_LF = 10;
    reg [3:0] state = IDLE;
    
    reg [9:0] frac_bits;
    reg [9:0] frac_1000;
    
    reg [21:0] diff;     
    reg        less;  

    always @(posedge clk) begin
        uart_start <= 0;
        case (state)
        // WAITING FOR NEW NUMBER FROM CALCULATOR
        IDLE: begin
            if (start) begin 
                if (num[31]) begin
                    neg <= 1;
                    int_rem <= ~num >> 10; // scale by 1/1024       
                    frac_bits <= -num[9:0];
                    frac_1000 <= (-num[9:0] << 4) + (-num[9:0] << 3);
                end else begin
                    neg <= 0;
                    int_rem <= num >> 10; // scale by 1/1024
                    frac_bits <= num[9:0];
                    frac_1000 <= (num[9:0] << 4) + (num[9:0] << 3);
                end
                curr_digit <= 0;
                digit_idx <= 0;     // start at 1,000,000s place
                div <= 1000000;     // pre-load divisor
                leading_zeros <= 1; // assume leading zeros
                dot <= 1;           // there is a dot
                state <= SETUP;       // start calculating
            end
        end
        
        SETUP: begin
            frac_rem <= frac_bits - (frac_1000 >> 10);
            state <= SUB_INT_CALC;
        end

        // SUBTRACT UNTIL WE FIND THE CURRENT DIGIT'S VALUE - INT
        SUB_INT_CALC: begin
            {less, diff} <= {1'b0, int_rem} - {1'b0, div};
            state <= SUB_INT_UPDATE;
        end
        SUB_INT_UPDATE: begin
            if (!less) begin // !less means diff >= div
                int_rem <= diff;
                curr_digit <= curr_digit + 1;
                state <= SUB_INT_CALC;
            end else begin // digit value found, update digit
                state <= WRITE;
            end
        end
        
        // SUBTRACT UNTIL WE FIND THE CURRENT DIGIT'S VALUE - FRAC
        SUB_FRAC_CALC: begin
            {less, diff} <= {1'b0, frac_rem} - {1'b0, div};
            state <= SUB_FRAC_UPDATE;
        end
        SUB_FRAC_UPDATE: begin
            if (!less) begin // !less means diff >= div
                frac_rem <= diff;
                curr_digit <= curr_digit + 1;
                state <= SUB_FRAC_CALC;
            end else begin // digit value found, update digit
                state <= WRITE;
            end
        end
        
        // UPDATE THE VALUE OF THE CURRENT DIGIT AND PREP THE NEXT ONE
        WRITE: begin
            digitised[digit_idx] <= curr_digit;
            curr_digit <= 0;
            case (digit_idx) // next div
                0: div <= 100000;
                1: div <= 10000;
                2: div <= 1000;
                3: div <= 100;
                4: div <= 10;
                5: div <= 1;
                6: div <= 100;
                7: div <= 10;
                8: div <= 1;
            endcase
            case (digit_idx)
            0, 1, 2, 3, 4, 5: begin
                digit_idx <= digit_idx + 1;
                state <= SUB_INT_CALC;
            end
            6, 7, 8: begin
                digit_idx <= digit_idx + 1;
                state <= SUB_FRAC_CALC;
            end
            9: begin
                digit_idx <= 0;
                state <= SEND_INT;
            end
            endcase
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
