// USB HID to PS/2 converter for Analogue Pocket dock keyboard (Player 3)
module usb_to_ps2 (
    input         clk,
    input  [31:0] cont3_key,
    input  [31:0] cont3_joy,
    input  [15:0] cont3_trig,
    output reg [10:0] ps2_key
);

wire is_kb = (cont3_key[31:28] == 4'h4);
wire [7:0] k0 = cont3_joy[31:24], k1 = cont3_joy[23:16];
wire [7:0] k2 = cont3_joy[15:8],  k3 = cont3_joy[7:0];
wire [7:0] k4 = cont3_trig[15:8], k5 = cont3_trig[7:0];

reg [7:0] p0=0, p1=0, p2=0, p3=0, p4=0, p5=0;
reg tog = 0;

function [8:0] h2p; input [7:0] h;
    case(h)
    8'h04:h2p=9'h01C; 8'h05:h2p=9'h032; 8'h06:h2p=9'h021; 8'h07:h2p=9'h023;
    8'h08:h2p=9'h024; 8'h09:h2p=9'h02B; 8'h0A:h2p=9'h034; 8'h0B:h2p=9'h033;
    8'h0C:h2p=9'h043; 8'h0D:h2p=9'h03B; 8'h0E:h2p=9'h042; 8'h0F:h2p=9'h04B;
    8'h10:h2p=9'h03A; 8'h11:h2p=9'h031; 8'h12:h2p=9'h044; 8'h13:h2p=9'h04D;
    8'h14:h2p=9'h015; 8'h15:h2p=9'h02D; 8'h16:h2p=9'h01B; 8'h17:h2p=9'h02C;
    8'h18:h2p=9'h03C; 8'h19:h2p=9'h02A; 8'h1A:h2p=9'h01D; 8'h1B:h2p=9'h022;
    8'h1C:h2p=9'h035; 8'h1D:h2p=9'h01A;
    8'h1E:h2p=9'h016; 8'h1F:h2p=9'h01E; 8'h20:h2p=9'h026; 8'h21:h2p=9'h025;
    8'h22:h2p=9'h02E; 8'h23:h2p=9'h036; 8'h24:h2p=9'h03D; 8'h25:h2p=9'h03E;
    8'h26:h2p=9'h046; 8'h27:h2p=9'h045;
    8'h28:h2p=9'h05A; 8'h29:h2p=9'h076; 8'h2A:h2p=9'h066; 8'h2B:h2p=9'h00D;
    8'h2C:h2p=9'h029; 8'h2D:h2p=9'h04E; 8'h2E:h2p=9'h055; 8'h2F:h2p=9'h054;
    8'h30:h2p=9'h05B; 8'h31:h2p=9'h05D; 8'h33:h2p=9'h04C; 8'h34:h2p=9'h052;
    8'h35:h2p=9'h00E; 8'h36:h2p=9'h041; 8'h37:h2p=9'h049; 8'h38:h2p=9'h04A;
    8'h39:h2p=9'h058;
    8'h3A:h2p=9'h005; 8'h3B:h2p=9'h006; 8'h3C:h2p=9'h004; 8'h3D:h2p=9'h00C;
    8'h3E:h2p=9'h003; 8'h3F:h2p=9'h00B; 8'h40:h2p=9'h083; 8'h41:h2p=9'h00A;
    8'h42:h2p=9'h001; 8'h43:h2p=9'h009; 8'h44:h2p=9'h078; 8'h45:h2p=9'h007;
    8'h4F:h2p=9'h174; 8'h50:h2p=9'h16B; 8'h51:h2p=9'h172; 8'h52:h2p=9'h175;
    8'hE0:h2p=9'h014; 8'hE1:h2p=9'h012; 8'hE2:h2p=9'h011;
    8'hE4:h2p=9'h114; 8'hE5:h2p=9'h059; 8'hE6:h2p=9'h111;
    default: h2p=9'h000;
    endcase
endfunction

wire in_prev0 = (k0==p0)||(k0==p1)||(k0==p2)||(k0==p3)||(k0==p4)||(k0==p5);
wire in_prev1 = (k1==p0)||(k1==p1)||(k1==p2)||(k1==p3)||(k1==p4)||(k1==p5);
wire in_curr0 = (p0==k0)||(p0==k1)||(p0==k2)||(p0==k3)||(p0==k4)||(p0==k5);
wire in_curr1 = (p1==k0)||(p1==k1)||(p1==k2)||(p1==k3)||(p1==k4)||(p1==k5);

always @(posedge clk) begin
    if (!is_kb) begin
        ps2_key <= 0;
        {p0,p1,p2,p3,p4,p5} <= 0;
    end else begin
        // New key press
        if (k0 != 0 && !in_prev0 && h2p(k0) != 0) begin
            ps2_key <= {~tog, 1'b1, h2p(k0)}; tog <= ~tog;
        end
        else if (k1 != 0 && !in_prev1 && h2p(k1) != 0) begin
            ps2_key <= {~tog, 1'b1, h2p(k1)}; tog <= ~tog;
        end
        // Key release
        else if (p0 != 0 && !in_curr0 && h2p(p0) != 0) begin
            ps2_key <= {~tog, 1'b0, h2p(p0)}; tog <= ~tog;
        end
        else if (p1 != 0 && !in_curr1 && h2p(p1) != 0) begin
            ps2_key <= {~tog, 1'b0, h2p(p1)}; tog <= ~tog;
        end
        p0<=k0; p1<=k1; p2<=k2; p3<=k3; p4<=k4; p5<=k5;
    end
end
endmodule
