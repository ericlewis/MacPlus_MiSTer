// USB HID scancode to PS/2 scancode converter
// The Pocket dock sends USB HID keycodes on cont3_joy/cont3_key
// MiSTer cores expect PS/2 scancodes on ps2_key[10:0]
//
// ps2_key format: [7:0]=scancode, [8]=extended, [9]=pressed, [10]=toggle
//
// USB HID format (from Pocket):
//   cont3_joy[31:24] = scan code 1
//   cont3_joy[23:16] = scan code 2
//   cont3_joy[15:8]  = scan code 3
//   cont3_joy[7:0]   = scan code 4
//   cont3_trig[15:8] = scan code 5
//   cont3_trig[7:0]  = scan code 6
//   cont3_key[15:0]  = modifier bits
//   cont3_key[31:28] = type (0x4 = keyboard)

module usb_to_ps2 (
    input         clk,
    input  [31:0] cont3_key,
    input  [31:0] cont3_joy,
    input  [15:0] cont3_trig,
    output reg [10:0] ps2_key // [7:0]=code, [8]=extended, [9]=pressed, [10]=toggle
);

wire is_keyboard = (cont3_key[31:28] == 4'h4);

// Track previous state to detect changes
reg [31:0] prev_joy;
reg [15:0] prev_trig;
reg [15:0] prev_mods;

// USB HID to PS/2 Set 2 lookup (common keys only)
// Full table would be 256 entries; this covers the essentials
function [8:0] hid_to_ps2; // [8]=extended, [7:0]=ps2 code
    input [7:0] hid;
    case (hid)
        8'h04: hid_to_ps2 = 9'h01C; // A
        8'h05: hid_to_ps2 = 9'h032; // B
        8'h06: hid_to_ps2 = 9'h021; // C
        8'h07: hid_to_ps2 = 9'h023; // D
        8'h08: hid_to_ps2 = 9'h024; // E
        8'h09: hid_to_ps2 = 9'h02B; // F
        8'h0A: hid_to_ps2 = 9'h034; // G
        8'h0B: hid_to_ps2 = 9'h033; // H
        8'h0C: hid_to_ps2 = 9'h043; // I
        8'h0D: hid_to_ps2 = 9'h03B; // J
        8'h0E: hid_to_ps2 = 9'h042; // K
        8'h0F: hid_to_ps2 = 9'h04B; // L
        8'h10: hid_to_ps2 = 9'h03A; // M
        8'h11: hid_to_ps2 = 9'h031; // N
        8'h12: hid_to_ps2 = 9'h044; // O
        8'h13: hid_to_ps2 = 9'h04D; // P
        8'h14: hid_to_ps2 = 9'h015; // Q
        8'h15: hid_to_ps2 = 9'h02D; // R
        8'h16: hid_to_ps2 = 9'h01B; // S
        8'h17: hid_to_ps2 = 9'h02C; // T
        8'h18: hid_to_ps2 = 9'h03C; // U
        8'h19: hid_to_ps2 = 9'h02A; // V
        8'h1A: hid_to_ps2 = 9'h01D; // W
        8'h1B: hid_to_ps2 = 9'h022; // X
        8'h1C: hid_to_ps2 = 9'h035; // Y
        8'h1D: hid_to_ps2 = 9'h01A; // Z
        8'h1E: hid_to_ps2 = 9'h016; // 1
        8'h1F: hid_to_ps2 = 9'h01E; // 2
        8'h20: hid_to_ps2 = 9'h026; // 3
        8'h21: hid_to_ps2 = 9'h025; // 4
        8'h22: hid_to_ps2 = 9'h02E; // 5
        8'h23: hid_to_ps2 = 9'h036; // 6
        8'h24: hid_to_ps2 = 9'h03D; // 7
        8'h25: hid_to_ps2 = 9'h03E; // 8
        8'h26: hid_to_ps2 = 9'h046; // 9
        8'h27: hid_to_ps2 = 9'h045; // 0
        8'h28: hid_to_ps2 = 9'h05A; // Enter
        8'h29: hid_to_ps2 = 9'h076; // Escape
        8'h2A: hid_to_ps2 = 9'h066; // Backspace
        8'h2B: hid_to_ps2 = 9'h00D; // Tab
        8'h2C: hid_to_ps2 = 9'h029; // Space
        8'h2D: hid_to_ps2 = 9'h04E; // -
        8'h2E: hid_to_ps2 = 9'h055; // =
        8'h2F: hid_to_ps2 = 9'h054; // [
        8'h30: hid_to_ps2 = 9'h05B; // ]
        8'h31: hid_to_ps2 = 9'h05D; // backslash
        8'h33: hid_to_ps2 = 9'h04C; // ;
        8'h34: hid_to_ps2 = 9'h052; // '
        8'h35: hid_to_ps2 = 9'h00E; // `
        8'h36: hid_to_ps2 = 9'h041; // ,
        8'h37: hid_to_ps2 = 9'h049; // .
        8'h38: hid_to_ps2 = 9'h04A; // /
        8'h39: hid_to_ps2 = 9'h058; // Caps Lock
        8'h3A: hid_to_ps2 = 9'h005; // F1
        8'h3B: hid_to_ps2 = 9'h006; // F2
        8'h3C: hid_to_ps2 = 9'h004; // F3
        8'h3D: hid_to_ps2 = 9'h00C; // F4
        8'h3E: hid_to_ps2 = 9'h003; // F5
        8'h3F: hid_to_ps2 = 9'h00B; // F6
        8'h40: hid_to_ps2 = 9'h083; // F7
        8'h41: hid_to_ps2 = 9'h00A; // F8
        8'h42: hid_to_ps2 = 9'h001; // F9
        8'h43: hid_to_ps2 = 9'h009; // F10
        8'h44: hid_to_ps2 = 9'h078; // F11
        8'h45: hid_to_ps2 = 9'h007; // F12
        8'h4F: hid_to_ps2 = 9'h174; // Right arrow (extended)
        8'h50: hid_to_ps2 = 9'h16B; // Left arrow (extended)
        8'h51: hid_to_ps2 = 9'h172; // Down arrow (extended)
        8'h52: hid_to_ps2 = 9'h175; // Up arrow (extended)
        default: hid_to_ps2 = 9'h000;
    endcase
endfunction

// Scan the 6 key slots + modifiers for changes
reg [7:0] prev_keys [0:5];
reg [7:0] curr_keys [0:5];
reg       toggle = 0;

integer i;
always @(posedge clk) begin
    if (!is_keyboard) begin
        ps2_key <= 0;
    end else begin
        // Latch current keys
        curr_keys[0] <= cont3_joy[31:24];
        curr_keys[1] <= cont3_joy[23:16];
        curr_keys[2] <= cont3_joy[15:8];
        curr_keys[3] <= cont3_joy[7:0];
        curr_keys[4] <= cont3_trig[15:8];
        curr_keys[5] <= cont3_trig[7:0];

        // Check for newly pressed keys (in current but not in previous)
        for (i = 0; i < 6; i = i + 1) begin
            if (curr_keys[i] != 0 && curr_keys[i] != prev_keys[i]) begin
                // New key pressed
                ps2_key <= {~toggle, 1'b1, hid_to_ps2(curr_keys[i])};
                toggle <= ~toggle;
            end
        end

        // Check for released keys (in previous but not in current)
        for (i = 0; i < 6; i = i + 1) begin
            if (prev_keys[i] != 0) begin
                // Check if this key is still in current set
                reg found;
                found = 0;
                if (prev_keys[i] == curr_keys[0]) found = 1;
                if (prev_keys[i] == curr_keys[1]) found = 1;
                if (prev_keys[i] == curr_keys[2]) found = 1;
                if (prev_keys[i] == curr_keys[3]) found = 1;
                if (prev_keys[i] == curr_keys[4]) found = 1;
                if (prev_keys[i] == curr_keys[5]) found = 1;
                if (!found) begin
                    // Key released
                    ps2_key <= {~toggle, 1'b0, hid_to_ps2(prev_keys[i])};
                    toggle <= ~toggle;
                end
            end
        end

        // Update previous state
        for (i = 0; i < 6; i = i + 1)
            prev_keys[i] <= curr_keys[i];
    end
end

endmodule
