module cordic_circular (
    input clk,
    input start,
    input mode, // 0 for rotation, 1 for vectoring
    input [31:0] x_in, y_in, z_in,
    output reg [31:0] x_out, y_out, z_out,
    output reg done
);

    // Number of iterations
    localparam N = 16;

    // Arctan table for 16 bits (in fixed-point with 16 fractional bits)
    wire [31:0] atan_table [0:15];
    assign atan_table[0] = 32'h20000000; // 45.0 degrees in radians * 2^16
    assign atan_table[1] = 32'h12E4051E; // 26.565 degrees
    assign atan_table[2] = 32'h09FB385B; // 14.036 degrees
    assign atan_table[3] = 32'h051111D4; // 7.125 degrees
    assign atan_table[4] = 32'h028B0D43; // 3.576 degrees
    assign atan_table[5] = 32'h0145D7E1; // 1.790 degrees
    assign atan_table[6] = 32'h00A2F61E; // 0.895 degrees
    assign atan_table[7] = 32'h00517C55; // 0.448 degrees
    assign atan_table[8] = 32'h0028BE53; // 0.224 degrees
    assign atan_table[9] = 32'h00145F2F; // 0.112 degrees
    assign atan_table[10] = 32'h000A2F98; // 0.056 degrees
    assign atan_table[11] = 32'h000517CC; // 0.028 degrees
    assign atan_table[12] = 32'h00028BE6; // 0.014 degrees
    assign atan_table[13] = 32'h000145F3; // 0.007 degrees
    assign atan_table[14] = 32'h0000A2FA; // 0.0035 degrees
    assign atan_table[15] = 32'h0000517D; // 0.00175 degrees

    // Pipeline registers
    reg [31:0] x [0:N];
    reg [31:0] y [0:N];
    reg [31:0] z [0:N];
    reg [0:N] valid;

    integer i;

    always @(posedge clk) begin
        if (start) begin
            x[0] <= x_in;
            y[0] <= y_in;
            z[0] <= z_in;
            valid[0] <= 1;
        end else begin
            valid[0] <= 0;
        end

        for (i=0; i<N; i=i+1) begin
            if (valid[i]) begin
                if (mode == 0) begin // rotation
                    if (z[i][31]) begin // negative
                        x[i+1] <= x[i] + (y[i] >>> i);
                        y[i+1] <= y[i] - (x[i] >>> i);
                        z[i+1] <= z[i] + atan_table[i];
                    end else begin
                        x[i+1] <= x[i] - (y[i] >>> i);
                        y[i+1] <= y[i] + (x[i] >>> i);
                        z[i+1] <= z[i] - atan_table[i];
                    end
                end else begin // vectoring
                    if (y[i][31]) begin // negative
                        x[i+1] <= x[i] - (y[i] >>> i);
                        y[i+1] <= y[i] + (x[i] >>> i);
                        z[i+1] <= z[i] + atan_table[i];
                    end else begin
                        x[i+1] <= x[i] + (y[i] >>> i);
                        y[i+1] <= y[i] - (x[i] >>> i);
                        z[i+1] <= z[i] - atan_table[i];
                    end
                end
                valid[i+1] <= 1;
            end else begin
                valid[i+1] <= 0;
            end
        end

        if (valid[N]) begin
            x_out <= x[N];
            y_out <= y[N];
            z_out <= z[N];
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule

