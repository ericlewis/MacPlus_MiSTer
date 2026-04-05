// Gamepad d-pad to PS/2 mouse converter for Analogue Pocket controller 1.
module pad_to_ps2_mouse (
    input         clk,
    input  [31:0] cont1_key,
    output reg [24:0] ps2_mouse
);

localparam [17:0] MOVE_PERIOD = 18'd200000;
localparam signed [7:0] STEP = 8'sd3;

reg [17:0] move_div = 0;
reg [1:0]  prev_buttons = 0;

wire move_tick = (move_div == 0);
wire move_up = cont1_key[0];
wire move_down = cont1_key[1];
wire move_left = cont1_key[2];
wire move_right = cont1_key[3];
wire left_btn = cont1_key[4];
wire right_btn = cont1_key[5];
wire [1:0] cur_buttons = {right_btn, left_btn};

wire moving = move_up | move_down | move_left | move_right;
wire buttons_changed = (cur_buttons != prev_buttons);

wire signed [8:0] dx_calc = move_left ? -STEP : (move_right ? STEP : 9'sd0);
wire signed [8:0] dy_calc = move_up ? -STEP : (move_down ? STEP : 9'sd0);

wire [7:0] dx8 = dx_calc[7:0];
wire [7:0] dy8 = dy_calc[7:0];

always @(posedge clk) begin
    if (moving) begin
        if (move_tick) move_div <= MOVE_PERIOD;
        else move_div <= move_div - 1'd1;
    end else begin
        move_div <= 0;
    end

    if (buttons_changed || (moving && move_tick)) begin
        prev_buttons <= cur_buttons;
        ps2_mouse <= {
            ~ps2_mouse[24],
            dy8,
            dx8,
            1'b0,
            1'b0,
            dy8[7],
            dx8[7],
            1'b1,
            1'b0,
            right_btn,
            left_btn
        };
    end
end

endmodule
