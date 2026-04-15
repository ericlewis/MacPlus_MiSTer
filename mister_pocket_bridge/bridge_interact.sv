//
// bridge_interact.sv
//
// Analogue Pocket APF Bridge Registers -> MiSTer status[] Bits
//
// Maps APF bridge register writes from the Pocket menu into the subset of
// MiSTer-compatible status bits used by the Mac Plus core.
//
// Bridge registers are written from the Pocket OS (interact.json menu) on the
// clk_74a domain. Values are synchronized to clk_sys for use by the core.
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
// Register layout used by the Pocket UI:
//   0x00: [0]   Memory size  -> status[4]
//   0x04: [0]   CPU speed    -> status[5]
//   0x14: [1:0] CPU type     -> status[14:13]
//
// Action registers such as Reset & Apply are handled as write toggles in the
// top-level core rather than level-sensitive status bits.
//
always @(posedge clk_sys) begin
    status <= 128'd0;

    status[4]      <= regs_sys[0][0];       // Memory: 0 = 1MB, 1 = 4MB
    status[5]      <= regs_sys[1][0];       // Speed: 0 = 8MHz, 1 = 16MHz
    status[14:13]  <= regs_sys[5][1:0];     // CPU: 00 = 68000, 01 = 68010, 10 = 68020
end

endmodule
