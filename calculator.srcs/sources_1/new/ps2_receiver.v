`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.12.2025 20:14:37
// Design Name: 
// Module Name: ps2_receiver
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


module ps2_receiver(
    input clk,
    input kb_clk,
    input kb_key,
    output reg [7:0] keycode = 0,
    output reg valid
    );
    
    wire db_clk, db_key;    // debounced keyboard clock and key
    reg [7:0] curr_key = 0; // current keycode
    reg [7:0] prev_key = 0; // previous keycode
    
    debouncer clk_debouncer(
        .clk(clk),
        .sig_in(kb_clk),
        .sig_out(db_clk)
    );
    debouncer key_debouncer(
        .clk(clk),
        .sig_in(kb_key),
        .sig_out(db_key)
    );
    
    reg [3:0] i = 0;    // ps/2 bit (0-10)
    reg char = 0;       // end-of-char flag
    
    always@(negedge db_clk) begin
        case(i)
            0:; // start bit
            1: curr_key[0] <= db_key;   // keycode byte LSB
            2: curr_key[1] <= db_key;
            3: curr_key[2] <= db_key;
            4: curr_key[3] <= db_key;
            5: curr_key[4] <= db_key;
            6: curr_key[5] <= db_key;
            7: curr_key[6] <= db_key;
            8: curr_key[7] <= db_key;   // keycode byte MSB
            9: char <= 1'b1;    // parity bit, raise end-of-char flag
            10: char <= 1'b0;   // stop bit, lower end-of-char flag
        endcase
        
        if (i <= 9) begin
            i <= i + 1;
        end else if (i == 10) begin
            i <= 0;
        end
    end
    
    reg p_char = 0; // char one clock cycle in the past, to catch positive edge of char

    always@(posedge clk) begin
        p_char <= char;
        if (char && !p_char) begin
            if (curr_key != 8'hF0 && prev_key != 8'hF0) begin    // ignore break sequences
                keycode <= curr_key;
                valid <= 1'b1;
            end           
            prev_key <= curr_key;
        end else
            valid <= 1'b0;
    end
endmodule
