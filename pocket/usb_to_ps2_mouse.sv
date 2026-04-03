// USB dock mouse to PS/2 mouse converter for Analogue Pocket (Player 4)
module usb_to_ps2_mouse (
    input         clk,
    input  [31:0] cont4_key,
    input  [31:0] cont4_joy,
    input  [15:0] cont4_trig,
    output reg [24:0] ps2_mouse
);

wire is_mouse = (cont4_key[31:28] == 4'h5);
reg [15:0] prev_counter = 0;

always @(posedge clk) begin
    if (!is_mouse) begin
        ps2_mouse <= 0;
    end else if (cont4_key[15:0] != prev_counter) begin
        prev_counter <= cont4_key[15:0];
        ps2_mouse <= {
            ~ps2_mouse[24],
            cont4_trig[7:0],      // Y delta (low 8 bits)
            cont4_joy[7:0],       // X delta (low 8 bits)
            2'b00,
            cont4_trig[7],        // Y sign
            cont4_joy[7],         // X sign
            1'b1,
            cont4_joy[18],        // middle
            cont4_joy[17],        // right
            cont4_joy[16]         // left
        };
    end
end
endmodule
