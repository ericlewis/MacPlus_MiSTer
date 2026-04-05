// USB dock mouse to PS/2 mouse converter for Analogue Pocket (Player 4)
module usb_to_ps2_mouse (
    input         clk,
    input  [31:0] cont4_key,
    input  [31:0] cont4_joy,
    input  [15:0] cont4_trig,
    output reg [24:0] ps2_mouse
);

wire is_mouse = (cont4_key[31:28] == 4'h5);
reg [31:0] prev_report = 0;

wire signed [15:0] mouse_dx = cont4_joy[15:0];
wire signed [15:0] mouse_dy = cont4_trig[15:0];

function automatic [7:0] clamp_delta;
    input signed [15:0] delta;
    begin
        if (delta > 16'sd127) clamp_delta = 8'h7F;
        else if (delta < -16'sd128) clamp_delta = 8'h80;
        else clamp_delta = delta[7:0];
    end
endfunction

wire [7:0] dx8 = clamp_delta(mouse_dx);
wire [7:0] dy8 = clamp_delta(mouse_dy);
wire dx_overflow = (mouse_dx > 16'sd127) || (mouse_dx < -16'sd128);
wire dy_overflow = (mouse_dy > 16'sd127) || (mouse_dy < -16'sd128);

always @(posedge clk) begin
    if (!is_mouse) begin
        ps2_mouse <= 0;
        prev_report <= 0;
    end else if (cont4_key != prev_report) begin
        prev_report <= cont4_key;
        ps2_mouse <= {
            ~ps2_mouse[24],
            dy8,
            dx8,
            dy_overflow,
            dx_overflow,
            dy8[7],
            dx8[7],
            1'b1,
            cont4_joy[18],
            cont4_joy[17],
            cont4_joy[16]
        };
    end
end
endmodule
