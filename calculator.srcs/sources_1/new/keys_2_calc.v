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
    input [7:0] keycode,
    input start,            // EoC signal from sp/2
    input ready,            // ready-to-receive from calc
    output reg [15:0] A,    // two's C 16-bit int
    output reg [15:0] B,
    output reg [3:0] op,    // 4-bit opcode
    output reg valid        // 1-tick valid pulse for calc
    );
    
    reg [3:0] digit = 0;
    reg [1:0] count = 0;
    
    localparam IDLE = 0, NUM1 = 1, OP = 2, NUM2 = 3;
    reg [1:0] state = IDLE;
    
    reg p_start = 0;
    
    always@(posedge clk) begin
    if (ready && start && !p_start) begin
        case (state)
        IDLE: begin
            valid <= 0;
            if (start) begin
                A <= 0;
                B <= 0;
                count <= 0;
                state <= NUM1;
            end
        end
        
        NUM1: begin
        if (count <= 2) begin
            case (keycode)
            8'h16: A <= (8'd10 * A) + 8'd1; // 1 - 9
            8'h1E: A <= (8'd10 * A) + 8'd2;
            8'h26: A <= (8'd10 * A) + 8'd3;
            8'h25: A <= (8'd10 * A) + 8'd4;
            8'h2E: A <= (8'd10 * A) + 8'd5;
            8'h36: A <= (8'd10 * A) + 8'd6;
            8'h3D: A <= (8'd10 * A) + 8'd7;
            8'h3E: A <= (8'd10 * A) + 8'd8;
            8'h46: A <= (8'd10 * A) + 8'd9; 
            8'h45: A <= (8'd10 * A);        // 0
            8'h4E: begin                    // negative
                A <= -A;
                count <= count - 1;
            end
            endcase
            count <= count + 1;
        end else begin
            op <= 8'hFF;
            state <= OP;
        end
        end
    
        OP: begin
            case (keycode)
            8'h15: op <= 0;
            8'h1D: op <= 1;
            8'h24: op <= 2;
            8'h2D: op <= 3;
            8'h2C: op <= 4;
            8'h35: op <= 5;
            8'h3C: op <= 6;
            8'h43: op <= 7;
            8'h44: op <= 8;
            8'h4D: op <= 9;
            8'h1C: op <= 10;
            8'h1B: op <= 11;
            8'h23: op <= 12;
            8'h2B: op <= 13;
            endcase
            if (op != 8'hFF) begin
                count <= 0;
                state <= NUM2;
            end
        end
        
        NUM2: begin
        if (count <= 2) begin
            case (keycode)
            8'h16: B <= (8'd10 * B) + 8'd1; // 1 - 9
            8'h1E: B <= (8'd10 * B) + 8'd2;
            8'h26: B <= (8'd10 * B) + 8'd3;
            8'h25: B <= (8'd10 * B) + 8'd4;
            8'h2E: B <= (8'd10 * B) + 8'd5;
            8'h36: B <= (8'd10 * B) + 8'd6;
            8'h3D: B <= (8'd10 * B) + 8'd7;
            8'h3E: B <= (8'd10 * B) + 8'd8;
            8'h46: B <= (8'd10 * B) + 8'd9; 
            8'h45: B <= (8'd10 * B);        // 0
            8'h4E: begin                    // negative
                B <= -B;
                count <= count - 1;
            end
            endcase
            count <= count + 1;
        end else begin
            valid <= 1;     // pulse valid
            state <= IDLE;
        end
        end
        endcase
    end else valid <= 0;    // set valid back to zero for 1-tick pulse
    end
    
endmodule
