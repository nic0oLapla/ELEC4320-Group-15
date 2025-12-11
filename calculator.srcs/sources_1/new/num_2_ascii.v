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
    input [15:0] num,
    input valid,
    input uart_ready,
    output reg [7:0] char,
    output reg running,
    output reg uart_start
    );

    reg [13:0] div;         // "divisor"
    reg [15:0] rem;         // remainder
    reg [3:0] curr_digit;   // value of current digit
    reg [2:0] digit_idx;    // current digit pos (4 to 0)
    reg leading_zeros;      // flag for leading zeros

    // State Machine
    localparam IDLE = 0, SUB = 1, SEND = 2, WAIT_UART = 3;
    reg [1:0] state = IDLE;

    always @(posedge clk) begin
        case (state)
        // WAITING FOR NEW NUMBER FROM CALCULATOR
        IDLE: begin
            uart_start <= 0;
            if (valid) begin
                running <= 1;       // block calculator
                rem <= num;         // load result 
                digit_idx <= 0;     // start at 10,000s place
                curr_digit <= 0;
                leading_zeros <= 1; // assume leading zeros
                state <= SUB;       // start calculating
            end else begin
                running <= 0;
            end
        end

        // SUBTRACT UNTIL WE FIND THE CURRENT DIGIT'S VALUE
        SUB: begin
            case (digit_idx)                    // probably faster than using a power circuit
                0: div = 10000;
                1: div = 1000;
                2: div = 100;
                3: div = 10;
                4: div = 1;
            endcase

            if (rem >= div) begin               // still going, subtract 10^idx and loop again
                rem <= rem - div;
                curr_digit <= curr_digit + 1;
            end else begin                      // digit value found, move on to sending char
                state <= SEND;
            end
        end

        // DIGIT FOUND, SEND CHARACTER TO UART
        SEND: begin
            if (digit_idx == 5) begin                                                   // send CR
                char <= 8'h0D;                                                          // load CR
                uart_start <= 1;                                                        // trigger the UART
                state <= WAIT_UART;                                                     // wait for UART sender
            end else if (digit_idx == 6) begin                                          // send LF
                char <= 8'h0A;                                                          // load LF
                uart_start <= 1;                                                        // trigger the UART
                state <= WAIT_UART;                                                     // wait for UART sender
            end else if (leading_zeros && (curr_digit == 0) && (digit_idx != 4)) begin  // skip leading zeros but not if last digit
                 digit_idx <= digit_idx + 1;
                 curr_digit <= 0;
                 state <= SUB;
            end else begin
                leading_zeros <= 0;                                                     // found a valid digit
                char <= {4'h3, curr_digit};                                             // convert digit to ascii
                uart_start <= 1;                                                        // trigger the UART
                state <= WAIT_UART;                                                     // wait for UART sender
            end
        end

        // WAITING FOR UART TO SEND PREVIOUS CHARACTER
        WAIT_UART: begin
            uart_start <= 0;                        // drop start signal
            
            if (uart_ready && !uart_start) begin
                if (digit_idx == 6) begin           // return to idle
                    state <= IDLE;
                    running <= 0;
                end else begin                      // next character
                    digit_idx <= digit_idx + 1;
                    curr_digit <= 0;
                    if (digit_idx <= 4)             // still going, find next digit
                        state <= SUB;
                    else                            // final digit done, send CR
                        state <= SEND;
                end
            end
        end
        endcase
    end
    
endmodule
