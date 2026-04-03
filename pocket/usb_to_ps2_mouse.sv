// USB dock mouse to PS/2 mouse converter
// Pocket dock mouse is on Player 4:
//   cont4_joy[31:16] = buttons (bit 0=left, 1=right, 2=middle)
//   cont4_joy[15:0]  = relative X movement (signed 16-bit LE)
//   cont4_key[15:0]  = report counter
//   cont4_trig[15:0] = relative Y movement (signed 16-bit LE)
//   cont4_key[31:28] = type (0x5 = mouse)
//
// MiSTer ps2_mouse format: [24:0]
//   [0]    = button left
//   [1]    = button right
//   [2]    = button middle
//   [3]    = always 1
//   [4]    = X sign
//   [5]    = Y sign
//   [15:8] = X movement (signed 8-bit)
//   [23:16]= Y movement (signed 8-bit)
//   [24]   = strobe (active on new data)

module usb_to_ps2_mouse (
    input         clk,
    input  [31:0] cont4_key,
    input  [31:0] cont4_joy,
    input  [15:0] cont4_trig,
    output reg [24:0] ps2_mouse
);

wire is_mouse = (cont4_key[31:28] == 4'h5);

reg [15:0] prev_counter;

always @(posedge clk) begin
    if (!is_mouse) begin
        ps2_mouse <= 0;
    end else begin
        // Detect new report via counter change
        if (cont4_key[15:0] != prev_counter) begin
            prev_counter <= cont4_key[15:0];

            // Clamp X/Y deltas to signed 8-bit range
            reg signed [15:0] dx, dy;
            dx = $signed(cont4_joy[15:0]);
            dy = $signed(cont4_trig[15:0]);

            reg [7:0] mx, my;
            mx = (dx > 127) ? 8'd127 : (dx < -128) ? -8'd128 : dx[7:0];
            my = (dy > 127) ? 8'd127 : (dy < -128) ? -8'd128 : dy[7:0];

            ps2_mouse <= {
                ~ps2_mouse[24],  // toggle strobe
                my,              // [23:16] Y movement
                mx,              // [15:8]  X movement
                2'b00,           // [7:6] unused
                my[7],           // [5] Y sign
                mx[7],           // [4] X sign
                1'b1,            // [3] always 1
                cont4_joy[18],   // [2] middle button
                cont4_joy[17],   // [1] right button
                cont4_joy[16]    // [0] left button
            };
        end
    end
end

endmodule
