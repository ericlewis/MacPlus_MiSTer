//
// bridge_interact.sv
//
// Analogue Pocket APF Bridge Registers → MiSTer status[] Bits
//
// Maps APF bridge register writes at configurable addresses to
// specific bit ranges within a 128-bit MiSTer-compatible status register.
//
// Bridge registers are written from the Pocket OS (interact.json menu)
// on the clk_74a domain. Values are synchronized to clk_sys for use
// by the core.
//
// Copyright (c) 2026 Eric Lewis
// SPDX-License-Identifier: GPL-3.0-or-later
//

module bridge_interact #(
    parameter NUM_REGS = 16
) (
    input         clk_74a,
    input         clk_sys,

    // APF bridge bus (active on clk_74a)
    input  [31:0] bridge_addr,
    input         bridge_wr,
    input  [31:0] bridge_wr_data,
    input         bridge_rd,
    output reg [31:0] bridge_rd_data,

    // MiSTer-compatible status output (active on clk_sys)
    output reg [127:0] status
);

// Register file in clk_74a domain
// Each register is a 32-bit value at address offset [5:2] (word-aligned)
reg [31:0] regs_74a [NUM_REGS];

integer k;
initial begin
    for (k = 0; k < NUM_REGS; k = k + 1)
        regs_74a[k] = 32'd0;
end

// Handle bridge reads and writes
always @(posedge clk_74a) begin
    if (bridge_wr && bridge_addr[31:16] == 16'h0000) begin
        if (bridge_addr[7:2] < NUM_REGS[5:0])
            regs_74a[bridge_addr[7:2]] <= bridge_wr_data;
    end

    if (bridge_rd && bridge_addr[31:16] == 16'h0000) begin
        if (bridge_addr[7:2] < NUM_REGS[5:0])
            bridge_rd_data <= regs_74a[bridge_addr[7:2]];
        else
            bridge_rd_data <= 32'd0;
    end
end

// Synchronize register values to clk_sys domain
// Double-flop each register value (safe since these are quasi-static config values)
reg [31:0] regs_sys [NUM_REGS];
reg [31:0] regs_meta [NUM_REGS];

integer j;
always @(posedge clk_sys) begin
    for (j = 0; j < NUM_REGS; j = j + 1) begin
        regs_meta[j] <= regs_74a[j];
        regs_sys[j]  <= regs_meta[j];
    end
end

//
// Map registers to status bits.
// This mapping is C64-specific but demonstrates the pattern.
// For other cores, override this mapping.
//
// Register layout (each is a 32-bit bridge register at word offset):
//   0x00: [0] = Video standard (PAL/NTSC)        → status[2]
//   0x04: [0] = Swap joysticks                    → status[3]
//   0x08: [1:0] = Aspect ratio                    → status[5:4]
//   0x0C: [0] = Left SID model                    → status[13]
//   0x10: [0] = Right SID model                   → status[16]
//   0x14: [1:0] = System ROM selection             → status[15:14]
//   0x18: [2:0] = Right SID port                  → status[22:20]
//   0x1C: [1:0] = Stereo mix                      → status[19:18]
//   0x20: [1:0] = VIC-II variant                  → status[35:34]
//   0x24: [0] = 8580 digifix                      → status[37]
//   0x28: [0] = CIA mode                          → status[45]
//   0x2C: [1:0] = Turbo mode                      → status[47:46]
//   0x30: [0] = OPL2 enable                       → status[12]
//   0x34: [2:0] = Palette                         → status[84:82]
//   0x38: [0] = Clear RAM on reset                → status[24]
//   0x3C: [0] = Reset (directly usable)           → status[0]
//
always @(posedge clk_sys) begin
    status <= 128'd0;

    status[2]      <= regs_sys[0][0];       // Video standard
    status[3]      <= regs_sys[1][0];       // Swap joysticks
    status[5:4]    <= regs_sys[2][1:0];     // Aspect ratio
    status[13]     <= regs_sys[3][0];       // Left SID model
    status[16]     <= regs_sys[4][0];       // Right SID model
    status[15:14]  <= regs_sys[5][1:0];     // System ROM selection
    status[22:20]  <= regs_sys[6][2:0];     // Right SID port
    status[19:18]  <= regs_sys[7][1:0];     // Stereo mix
    status[35:34]  <= regs_sys[8][1:0];     // VIC-II variant
    status[37]     <= regs_sys[9][0];       // 8580 digifix
    status[45]     <= regs_sys[10][0];      // CIA mode
    status[47:46]  <= regs_sys[11][1:0];    // Turbo mode
    status[12]     <= regs_sys[12][0];      // OPL2 enable
    status[84:82]  <= regs_sys[13][2:0];    // Palette
    status[24]     <= regs_sys[14][0];      // Clear RAM on reset
    status[0]      <= regs_sys[15][0];      // Reset trigger
end

endmodule
