// MacPlus PLL: 74.25 MHz → 65 MHz (SDRAM) + 32.5 MHz (sys) + 32.5 MHz 90° (DDR)
`timescale 1 ps / 1 ps
module pll (
    input  wire refclk, rst,
    output wire outclk_0, // 65 MHz (clk_mem / SDRAM)
    output wire outclk_1, // 32.5 MHz (clk_sys / video)
    output wire outclk_2, // 32.5 MHz 90° (video DDR)
    output wire locked
);
altera_pll #(
    .fractional_vco_multiplier("true"),
    .reference_clock_frequency("74.25 MHz"),
    .operation_mode("direct"),
    .number_of_clocks(3),
    .output_clock_frequency0("65.0 MHz"),    .phase_shift0("0 ps"),    .duty_cycle0(50),
    .output_clock_frequency1("32.5 MHz"),    .phase_shift1("0 ps"),    .duty_cycle1(50),
    .output_clock_frequency2("32.5 MHz"),    .phase_shift2("7692 ps"), .duty_cycle2(50),
    .pll_type("General"), .pll_subtype("General")
) pll_inst (
    .refclk({1'b0, refclk}), .rst(rst),
    .outclk({outclk_2, outclk_1, outclk_0}), .locked(locked),
    .fboutclk(), .fbclk(1'b0), .reconfig_to_pll(64'd0), .reconfig_from_pll()
);
endmodule
