//============================================================================
//  Macintosh Plus for Analogue Pocket
//  Copyright (C) 2026 Eric Lewis — GPL-3.0-or-later
//  Based on MacPlus MiSTer by Sorgelig, Plus Too by Till Harbaum
//============================================================================
`default_nettype wire

module core_top (
input   wire            clk_74a, clk_74b,
inout   wire    [7:0]   cart_tran_bank2,  output wire cart_tran_bank2_dir,
inout   wire    [7:0]   cart_tran_bank3,  output wire cart_tran_bank3_dir,
inout   wire    [7:0]   cart_tran_bank1,  output wire cart_tran_bank1_dir,
inout   wire    [7:4]   cart_tran_bank0,  output wire cart_tran_bank0_dir,
inout   wire            cart_tran_pin30,  output wire cart_tran_pin30_dir,
output  wire            cart_pin30_pwroff_reset,
inout   wire            cart_tran_pin31,  output wire cart_tran_pin31_dir,
input   wire            port_ir_rx,       output wire port_ir_tx, port_ir_rx_disable,
inout   wire            port_tran_si,     output wire port_tran_si_dir,
inout   wire            port_tran_so,     output wire port_tran_so_dir,
inout   wire            port_tran_sck,    output wire port_tran_sck_dir,
inout   wire            port_tran_sd,     output wire port_tran_sd_dir,
output  wire [21:16] cram0_a, output wire cram0_clk, cram0_adv_n, cram0_cre, cram0_ce0_n, cram0_ce1_n, cram0_oe_n, cram0_we_n, cram0_ub_n, cram0_lb_n,
inout   wire [15:0]  cram0_dq, input wire cram0_wait,
output  wire [21:16] cram1_a, output wire cram1_clk, cram1_adv_n, cram1_cre, cram1_ce0_n, cram1_ce1_n, cram1_oe_n, cram1_we_n, cram1_ub_n, cram1_lb_n,
inout   wire [15:0]  cram1_dq, input wire cram1_wait,
output  wire [12:0] dram_a, output wire [1:0] dram_ba, dram_dqm,
inout   wire [15:0] dram_dq,
output  wire dram_clk, dram_cke, dram_ras_n, dram_cas_n, dram_we_n,
output  wire [16:0] sram_a, output wire sram_oe_n, sram_we_n, sram_ub_n, sram_lb_n,
inout   wire [15:0] sram_dq,
input   wire vblank,
output  wire dbg_tx, input wire dbg_rx, output wire user1, input wire user2,
inout   wire aux_sda, output wire aux_scl, output wire vpll_feed,
output  wire [23:0] video_rgb,
output  wire video_rgb_clock, video_rgb_clock_90, video_de, video_skip, video_vs, video_hs,
output  wire audio_mclk, audio_dac, audio_lrck, input wire audio_adc,
output  wire bridge_endian_little,
input   wire [31:0] bridge_addr, bridge_wr_data,
input   wire bridge_rd, bridge_wr,
output  reg  [31:0] bridge_rd_data,
input   wire [31:0] cont1_key, cont2_key, cont3_key, cont4_key,
input   wire [31:0] cont1_joy, cont2_joy, cont3_joy, cont4_joy,
input   wire [15:0] cont1_trig, cont2_trig, cont3_trig, cont4_trig
);

// ======== Tie-offs ========
assign port_ir_tx=0; assign port_ir_rx_disable=1; assign bridge_endian_little=0;
assign cart_tran_bank3=8'hzz; assign cart_tran_bank3_dir=0;
assign cart_tran_bank2=8'hzz; assign cart_tran_bank2_dir=0;
assign cart_tran_bank1=8'hzz; assign cart_tran_bank1_dir=0;
assign cart_tran_bank0=4'hf;  assign cart_tran_bank0_dir=1;
assign cart_tran_pin30=0;     assign cart_tran_pin30_dir=1'bz;
assign cart_pin30_pwroff_reset=0;
assign cart_tran_pin31=1'bz;  assign cart_tran_pin31_dir=0;
assign port_tran_so=1'bz; assign port_tran_so_dir=0;
assign port_tran_si=1'bz; assign port_tran_si_dir=0;
assign port_tran_sck=1'bz; assign port_tran_sck_dir=0;
assign port_tran_sd=1'bz; assign port_tran_sd_dir=0;
assign cram0_a=0; assign cram0_dq={16{1'bZ}}; assign cram0_clk=0;
assign cram0_adv_n=1; assign cram0_cre=0; assign cram0_ce0_n=1; assign cram0_ce1_n=1;
assign cram0_oe_n=1; assign cram0_we_n=1; assign cram0_ub_n=1; assign cram0_lb_n=1;
assign cram1_a=0; assign cram1_dq={16{1'bZ}}; assign cram1_clk=0;
assign cram1_adv_n=1; assign cram1_cre=0; assign cram1_ce0_n=1; assign cram1_ce1_n=1;
assign cram1_oe_n=1; assign cram1_we_n=1; assign cram1_ub_n=1; assign cram1_lb_n=1;
assign sram_a=0; assign sram_dq={16{1'bZ}};
assign sram_oe_n=1; assign sram_we_n=1; assign sram_ub_n=1; assign sram_lb_n=1;
assign dbg_tx=1'bZ; assign user1=1'bZ; assign aux_scl=1'bZ; assign vpll_feed=1'bZ;

// ======== Bridge ========
wire [31:0] cmd_bridge_rd_data;
always @(*) begin
    casex(bridge_addr)
    32'hF8xxxxxx: bridge_rd_data <= cmd_bridge_rd_data;
    default:      bridge_rd_data <= 0;
    endcase
end

wire reset_n, pll_core_locked, pll_core_locked_s;
synch_3 s01(pll_core_locked, pll_core_locked_s, clk_74a);

wire dataslot_requestread, dataslot_requestwrite, dataslot_update, dataslot_allcomplete;
wire [15:0] dataslot_requestread_id, dataslot_requestwrite_id, dataslot_update_id;
wire [31:0] dataslot_requestwrite_size, dataslot_update_size;
wire [31:0] rtc_epoch_seconds, rtc_date_bcd, rtc_time_bcd;
wire rtc_valid, osnotify_inmenu;
wire savestate_start, savestate_load;
reg target_dataslot_read=0, target_dataslot_write=0, target_dataslot_getfile=0, target_dataslot_openfile=0;
wire target_dataslot_ack, target_dataslot_done;
wire [2:0] target_dataslot_err;
reg [15:0] target_dataslot_id;
reg [31:0] target_dataslot_slotoffset, target_dataslot_bridgeaddr, target_dataslot_length;
wire [31:0] target_buffer_param_struct, target_buffer_resp_struct;
wire [9:0] datatable_addr; wire datatable_wren; wire [31:0] datatable_data, datatable_q;

core_bridge_cmd icb(
    .clk(clk_74a), .reset_n(reset_n),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr), .bridge_rd(bridge_rd), .bridge_rd_data(cmd_bridge_rd_data),
    .bridge_wr(bridge_wr), .bridge_wr_data(bridge_wr_data),
    .status_boot_done(pll_core_locked_s), .status_setup_done(pll_core_locked_s), .status_running(reset_n),
    .dataslot_requestread(dataslot_requestread), .dataslot_requestread_id(dataslot_requestread_id),
    .dataslot_requestread_ack(1'b1), .dataslot_requestread_ok(1'b1),
    .dataslot_requestwrite(dataslot_requestwrite), .dataslot_requestwrite_id(dataslot_requestwrite_id),
    .dataslot_requestwrite_size(dataslot_requestwrite_size),
    .dataslot_requestwrite_ack(1'b1), .dataslot_requestwrite_ok(1'b1),
    .dataslot_update(dataslot_update), .dataslot_update_id(dataslot_update_id), .dataslot_update_size(dataslot_update_size),
    .dataslot_allcomplete(dataslot_allcomplete),
    .rtc_epoch_seconds(rtc_epoch_seconds), .rtc_date_bcd(rtc_date_bcd), .rtc_time_bcd(rtc_time_bcd), .rtc_valid(rtc_valid),
    .savestate_supported(1'b0), .savestate_addr(0), .savestate_size(0), .savestate_maxloadsize(0),
    .savestate_start(savestate_start), .savestate_start_ack(0), .savestate_start_busy(0), .savestate_start_ok(0), .savestate_start_err(0),
    .savestate_load(savestate_load), .savestate_load_ack(0), .savestate_load_busy(0), .savestate_load_ok(0), .savestate_load_err(0),
    .osnotify_inmenu(osnotify_inmenu),
    .target_dataslot_read(target_dataslot_read), .target_dataslot_write(target_dataslot_write),
    .target_dataslot_getfile(target_dataslot_getfile), .target_dataslot_openfile(target_dataslot_openfile),
    .target_dataslot_ack(target_dataslot_ack), .target_dataslot_done(target_dataslot_done), .target_dataslot_err(target_dataslot_err),
    .target_dataslot_id(target_dataslot_id), .target_dataslot_slotoffset(target_dataslot_slotoffset),
    .target_dataslot_bridgeaddr(target_dataslot_bridgeaddr), .target_dataslot_length(target_dataslot_length),
    .target_buffer_param_struct(target_buffer_param_struct), .target_buffer_resp_struct(target_buffer_resp_struct),
    .datatable_addr(datatable_addr), .datatable_wren(datatable_wren), .datatable_data(datatable_data), .datatable_q(datatable_q)
);

always @(posedge clk_74a) begin
    target_dataslot_read <= 0; target_dataslot_write <= 0;
    target_dataslot_getfile <= 0; target_dataslot_openfile <= 0;
end

// ======== Clocks ========
wire clk_sys; // 32.5 MHz
wire clk_mem; // 65 MHz

pll pll_inst(
    .refclk(clk_74a), .rst(1'b0),
    .outclk_0(clk_mem), .outclk_1(clk_sys),
    .locked(pll_core_locked)
);

// Video PLL: 12.288 MHz (template, proven working)
wire clk_vid, clk_vid_90;
mf_pllbase pll_vid(
    .refclk(clk_74a), .rst(1'b0),
    .outclk_0(clk_vid), .outclk_1(clk_vid_90), .locked()
);

// ======== ROM Loading ========
// Slot 0: Mac ROM (128KB or 256KB) loaded at 0x10000000
// The ROM + optional floppy image concatenated
wire        dl_wr;
wire [27:0] dl_addr;
wire [7:0]  dl_data;

data_loader #(.ADDRESS_MASK_UPPER_4(4'h1), .ADDRESS_SIZE(28)) rom_loader (
    .clk_74a(clk_74a), .clk_memory(clk_sys),
    .bridge_wr(bridge_wr), .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
    .write_en(dl_wr), .write_addr(dl_addr), .write_data(dl_data)
);

// Download tracking
reg is_downloading = 0;
always @(posedge clk_74a) begin
    if (dataslot_requestwrite) is_downloading <= 1;
    else if (dataslot_allcomplete) is_downloading <= 0;
end

reg dl_s0, dl_s1;
always @(posedge clk_sys) begin dl_s0 <= is_downloading; dl_s1 <= dl_s0; end
wire dio_download = dl_s1;

// Convert data_loader 8-bit output to 16-bit (Mac uses word-wide data)
// Accumulate two bytes into one 16-bit word
reg [7:0] dio_byte_hi;
reg       dio_byte_toggle = 0;
reg       dio_write_word = 0;
reg [15:0] dio_data;
reg [20:0] dio_a;
wire [7:0] dio_index = 0; // ROM

always @(posedge clk_sys) begin
    dio_write_word <= 0;
    if (dl_wr) begin
        if (!dio_byte_toggle) begin
            dio_byte_hi <= dl_data;
            dio_byte_toggle <= 1;
        end else begin
            // Mac ROM byte swap (matching MiSTer's {ioctl_data[7:0], ioctl_data[15:8]})
            dio_data <= {dl_data, dio_byte_hi};
            dio_a <= dl_addr[21:1]; // word address
            dio_write_word <= 1;
            dio_byte_toggle <= 0;
        end
    end
    if (!dio_download) dio_byte_toggle <= 0;
end

// ======== Reset ========
reg       n_reset = 0;
reg [1:0] status_cpu = 0;
reg       status_mem = 0; // 0=1MB, 1=4MB
reg       status_mod = 0; // 0=Plus, 1=SE

always @(posedge clk_sys) begin
    reg [15:0] rst_cnt;
    if (clk8_en_p) begin
        if (~pll_core_locked || dio_download || ~_cpuReset_o) begin
            rst_cnt <= '1;
            n_reset <= 0;
        end
        else if (rst_cnt) begin
            rst_cnt <= rst_cnt - 1'd1;
        end
        else begin
            n_reset <= 1;
        end
    end
end

// ======== Mac Plus Core ========
localparam configROMSize = 1'b1; // 128K ROM
wire [1:0] configRAMSize = status_mem ? 2'b11 : 2'b10; // 1MB or 4MB
wire       status_turbo = 0; // no turbo for now

// CPU signals
wire clk8, _cpuReset, _cpuReset_o, _cpuUDS, _cpuLDS, _cpuRW, _cpuAS;
wire clk8_en_p, clk8_en_n;
wire clk16_en_p, clk16_en_n;
wire _cpuVMA, _cpuVPA, _cpuDTACK;
wire E_rising, E_falling;
wire [2:0] _cpuIPL;
wire [2:0] cpuFC;
wire [23:0] cpuAddr;
wire [15:0] cpuDataOut;

// RAM/ROM
wire _romOE, _ramOE, _ramWE;
wire _memoryUDS, _memoryLDS;
wire videoBusControl, dioBusControl, cpuBusControl;
wire [21:0] memoryAddr;
wire [15:0] memoryDataOut;
wire memoryLatch;

// Video & peripherals
wire vid_alt, loadPixels, pixelOut, _hblank, _vblank, hsync, vsync;
wire memoryOverlayOn, selectSCSI, selectSCC, selectIWM, selectVIA, selectRAM, selectROM, selectSEOverlay;
wire [15:0] dataControllerDataOut;
wire snd_alt, loadSound;
wire [10:0] mac_audio;

// Floppy
wire dskReadAckInt, dskReadAckExt;
wire [21:0] dskReadAddrInt, dskReadAddrExt;

// CPU selection: FX68K only
wire cpu_en_p = clk8_en_p;
wire cpu_en_n = clk8_en_n;

assign _cpuVPA   = (cpuFC == 3'b111) ? 1'b0 : ~(!_cpuAS && cpuAddr[23:21] == 3'b111);
assign _cpuDTACK = ~(!_cpuAS && cpuAddr[23:21] != 3'b111);

wire [15:0] fx68_dout;
wire [23:1] fx68_a;
wire        fx68_rw, fx68_as_n, fx68_uds_n, fx68_lds_n;
wire        fx68_E_falling, fx68_E_rising, fx68_vma_n;
wire        fx68_fc0, fx68_fc1, fx68_fc2;
wire        fx68_reset_n;

assign _cpuReset_o = fx68_reset_n;
assign _cpuRW      = fx68_rw;
assign _cpuAS      = fx68_as_n;
assign _cpuUDS     = fx68_uds_n;
assign _cpuLDS     = fx68_lds_n;
assign E_falling   = fx68_E_falling;
assign E_rising    = fx68_E_rising;
assign _cpuVMA     = fx68_vma_n;
assign cpuFC       = {fx68_fc2, fx68_fc1, fx68_fc0};
assign cpuAddr[23:1] = fx68_a;
assign cpuAddr[0]  = 0;
assign cpuDataOut  = fx68_dout;

fx68k fx68k_inst (
    .clk       (clk_sys),
    .extReset  (!_cpuReset),
    .pwrUp     (!_cpuReset),
    .enPhi1    (cpu_en_p),
    .enPhi2    (cpu_en_n),
    .eRWn      (fx68_rw),
    .ASn       (fx68_as_n),
    .LDSn      (fx68_lds_n),
    .UDSn      (fx68_uds_n),
    .E         (),
    .E_div     (status_turbo),
    .E_PosClkEn(fx68_E_falling),
    .E_NegClkEn(fx68_E_rising),
    .VMAn      (fx68_vma_n),
    .FC0       (fx68_fc0),
    .FC1       (fx68_fc1),
    .FC2       (fx68_fc2),
    .BGn       (),
    .oRESETn   (fx68_reset_n),
    .oHALTEDn  (),
    .DTACKn    (_cpuDTACK),
    .VPAn      (_cpuVPA),
    .HALTn     (1'b1),
    .BERRn     (1'b1),
    .BRn       (1'b1),
    .BGACKn    (1'b1),
    .IPL0n     (_cpuIPL[0]),
    .IPL1n     (_cpuIPL[1]),
    .IPL2n     (_cpuIPL[2]),
    .iEdb      (dataControllerDataOut),
    .oEdb      (fx68_dout),
    .eab       (fx68_a)
);

// Address Controller
addrController_top ac0 (
    .clk(clk_sys), .clk8(clk8),
    .clk8_en_p(clk8_en_p), .clk8_en_n(clk8_en_n),
    .clk16_en_p(clk16_en_p), .clk16_en_n(clk16_en_n),
    .cpuAddr(cpuAddr),
    ._cpuUDS(_cpuUDS), ._cpuLDS(_cpuLDS), ._cpuRW(_cpuRW), ._cpuAS(_cpuAS),
    .turbo(status_turbo),
    .configROMSize({status_mod, ~status_mod}),
    .configRAMSize(configRAMSize),
    .memoryAddr(memoryAddr), .memoryLatch(memoryLatch),
    ._memoryUDS(_memoryUDS), ._memoryLDS(_memoryLDS),
    ._romOE(_romOE), ._ramOE(_ramOE), ._ramWE(_ramWE),
    .videoBusControl(videoBusControl),
    .dioBusControl(dioBusControl),
    .cpuBusControl(cpuBusControl),
    .selectSCSI(selectSCSI), .selectSCC(selectSCC),
    .selectIWM(selectIWM), .selectVIA(selectVIA),
    .selectRAM(selectRAM), .selectROM(selectROM),
    .selectSEOverlay(selectSEOverlay),
    .hsync(hsync), .vsync(vsync),
    ._hblank(_hblank), ._vblank(_vblank),
    .loadPixels(loadPixels), .vid_alt(vid_alt),
    .memoryOverlayOn(memoryOverlayOn),
    .snd_alt(snd_alt), .loadSound(loadSound),
    .dskReadAddrInt(dskReadAddrInt), .dskReadAckInt(dskReadAckInt),
    .dskReadAddrExt(dskReadAddrExt), .dskReadAckExt(dskReadAckExt)
);

// Dock keyboard → PS/2 (Player 3)
wire [10:0] dock_ps2_key;
usb_to_ps2 usb_kbd (
    .clk(clk_sys), .cont3_key(cont3_key), .cont3_joy(cont3_joy),
    .cont3_trig(cont3_trig), .ps2_key(dock_ps2_key)
);

// Dock mouse → PS/2 (Player 4)
wire [24:0] dock_ps2_mouse;
usb_to_ps2_mouse usb_mouse (
    .clk(clk_sys), .cont4_key(cont4_key), .cont4_joy(cont4_joy),
    .cont4_trig(cont4_trig), .ps2_mouse(dock_ps2_mouse)
);

// Data Controller (I/O hub: VIA, SCC, IWM, SCSI, keyboard, mouse, video, audio)
wire [1:0] diskEject;
wire [1:0] diskMotor, diskAct;

// Stub floppy/SCSI for initial port
wire dsk_int_ins = 0;
wire dsk_ext_ins = 0;
wire dsk_int_ds = 0;
wire dsk_ext_ds = 0;

// Stub SCSI
wire [1:0] img_mounted_s = 0;
wire [31:0] img_size_s = 0;

localparam SCSI_DEVS = 2;
wire [31:0] sd_lba_s [SCSI_DEVS];
wire [SCSI_DEVS-1:0] sd_rd_s, sd_wr_s, sd_ack_s;
wire [7:0] sd_buff_addr_s;
wire [15:0] sd_buff_dout_s;
wire [15:0] sd_buff_din_s [SCSI_DEVS];
wire sd_buff_wr_s;

assign sd_ack_s = 0;
assign sd_buff_dout_s = 0;
assign sd_buff_wr_s = 0;

dataController_top #(SCSI_DEVS) dc0 (
    .clk32(clk_sys),
    .clk8_en_p(clk8_en_p), .clk8_en_n(clk8_en_n),
    .E_rising(E_rising), .E_falling(E_falling),
    .machineType(status_mod),
    ._systemReset(n_reset),
    ._cpuReset(_cpuReset),
    ._cpuIPL(_cpuIPL),
    ._cpuUDS(_cpuUDS), ._cpuLDS(_cpuLDS), ._cpuRW(_cpuRW),
    ._cpuVMA(_cpuVMA),
    .cpuDataIn(cpuDataOut),
    .cpuDataOut(dataControllerDataOut),
    .cpuAddrRegHi(cpuAddr[12:9]),
    .cpuAddrRegMid(cpuAddr[6:4]),
    .cpuAddrRegLo(cpuAddr[2:1]),
    .selectSCSI(selectSCSI), .selectSCC(selectSCC),
    .selectIWM(selectIWM), .selectVIA(selectVIA),
    .selectSEOverlay(selectSEOverlay),
    .cpuBusControl(cpuBusControl),
    .videoBusControl(videoBusControl),
    .memoryDataOut(memoryDataOut),
    .memoryDataIn(sdram_do),
    .memoryLatch(memoryLatch),
    // Dock keyboard (Player 3) and mouse (Player 4)
    .ps2_key(dock_ps2_key),
    .capslock(),
    .ps2_mouse(dock_ps2_mouse),
    // Serial disabled
    .serialIn(1'b0), .serialOut(), .serialCTS(1'b0), .serialRTS(),
    // RTC
    .timestamp({1'b0, rtc_epoch_seconds}),
    // Video
    ._hblank(_hblank), ._vblank(_vblank),
    .pixelOut(pixelOut), .loadPixels(loadPixels), .vid_alt(vid_alt),
    .memoryOverlayOn(memoryOverlayOn),
    // Audio
    .audioOut(mac_audio), .snd_alt(snd_alt), .loadSound(loadSound),
    // Floppy (stubbed)
    .insertDisk({dsk_ext_ins, dsk_int_ins}),
    .diskSides({dsk_ext_ds, dsk_int_ds}),
    .diskEject(diskEject),
    .dskReadAddrInt(dskReadAddrInt), .dskReadAckInt(dskReadAckInt),
    .dskReadAddrExt(dskReadAddrExt), .dskReadAckExt(dskReadAckExt),
    .diskMotor(diskMotor), .diskAct(diskAct),
    // SCSI (stubbed)
    .img_mounted(img_mounted_s),
    .img_size(img_size_s),
    .io_lba(sd_lba_s),
    .io_rd(sd_rd_s), .io_wr(sd_wr_s), .io_ack(sd_ack_s),
    .sd_buff_addr(sd_buff_addr_s),
    .sd_buff_dout(sd_buff_dout_s),
    .sd_buff_din(sd_buff_din_s),
    .sd_buff_wr(sd_buff_wr_s)
);

// ======== Video Output ========
// Mac Plus: 512x342 monochrome (1-bit)
assign video_rgb_clock    = clk_vid;
assign video_rgb_clock_90 = clk_vid_90;
assign video_skip = 1'b0;

reg [7:0] vid_r, vid_g, vid_b;
reg       vid_hs, vid_vs, vid_de;

always @(posedge clk_vid) begin
    vid_r  <= {8{pixelOut}};
    vid_g  <= {8{pixelOut}};
    vid_b  <= {8{pixelOut}};
    vid_de <= _vblank & _hblank;
    vid_vs <= vsync;
    vid_hs <= hsync;
end

assign video_rgb = vid_de ? {vid_r, vid_g, vid_b} : 24'd0;
assign video_de  = vid_de;
assign video_vs  = vid_vs;
assign video_hs  = vid_hs;

// ======== Audio ========
assign audio_mclk = audgen_mclk;
assign audio_dac  = audgen_dac;
assign audio_lrck = audgen_lrck;

reg [21:0] audgen_accum;
reg audgen_mclk;
parameter [20:0] CYCLE_48KHZ = 21'd122880 * 2;
always @(posedge clk_74a) begin
    audgen_accum <= audgen_accum + CYCLE_48KHZ;
    if (audgen_accum >= 21'd742500) begin
        audgen_mclk <= ~audgen_mclk;
        audgen_accum <= audgen_accum - 21'd742500 + CYCLE_48KHZ;
    end
end

reg [1:0] aud_mclk_div;
wire audgen_sclk = aud_mclk_div[1];
always @(posedge audgen_mclk) aud_mclk_div <= aud_mclk_div + 1'b1;

reg [4:0] audgen_lrck_cnt;
reg audgen_lrck, audgen_dac;
reg [15:0] audgen_shift;
reg [15:0] aud_sample;
always @(posedge clk_74a) aud_sample <= {mac_audio[10:0], 5'b00000};

always @(negedge audgen_sclk) begin
    audgen_lrck_cnt <= audgen_lrck_cnt + 1'b1;
    if (audgen_lrck_cnt == 5'd31) audgen_lrck <= ~audgen_lrck;
    if (audgen_lrck_cnt == 5'd0) audgen_shift <= aud_sample;
    audgen_dac <= audgen_shift[15];
    audgen_shift <= {audgen_shift[14:0], 1'b0};
end

// ======== SDRAM ========
assign dram_cke = 1;

// DIO write path (ROM/floppy loading)
wire download_cycle = dio_download && dioBusControl;

wire [24:0] sdram_addr = download_cycle ? {4'b0001, dio_a} :
                          ~_romOE       ? {4'b0001, 2'b00, status_mod, memoryAddr[18:1]} :
                                          {3'b000, (dskReadAckInt || dskReadAckExt), memoryAddr[21:1]};

wire [15:0] sdram_din  = download_cycle ? dio_data              : memoryDataOut;
wire  [1:0] sdram_ds   = download_cycle ? 2'b11                 : {!_memoryUDS, !_memoryLDS};
wire        sdram_we   = download_cycle ? dio_write_word        : !_ramWE;
wire        sdram_oe   = download_cycle ? 1'b0                  : (!_ramOE || !_romOE || dskReadAckInt || dskReadAckExt);

wire [15:0] extra_rom_data_demux = memoryAddr[0] ? {sdram_out[7:0], sdram_out[7:0]} : {sdram_out[15:8], sdram_out[15:8]};
wire [15:0] sdram_do   = download_cycle ? 16'hFFFF : (dskReadAckInt || dskReadAckExt) ? extra_rom_data_demux : sdram_out;
wire [15:0] sdram_out;

sdram sdram_inst (
    .init    (!pll_core_locked),
    .clk_64  (clk_mem),
    .clk_8   (clk8),
    .sd_clk  (dram_clk),
    .sd_data (dram_dq),
    .sd_addr (dram_a),
    .sd_dqm  (dram_dqm),
    .sd_ba   (dram_ba),
    .sd_cs   (),
    .sd_we   (dram_we_n),
    .sd_ras  (dram_ras_n),
    .sd_cas  (dram_cas_n),
    .din     (sdram_din),
    .addr    (sdram_addr),
    .ds      (sdram_ds),
    .we      (sdram_we),
    .oe      (sdram_oe),
    .dout    (sdram_out)
);

// DIO write synchronization with bus cycle
reg dio_write;
always @(posedge clk_sys) begin
    reg old_cyc;
    if (dio_write_word) begin
        ioctl_wait <= 1;
    end
    old_cyc <= dioBusControl;
    if (~dioBusControl) dio_write <= ioctl_wait;
    if (old_cyc & ~dioBusControl & dio_write) ioctl_wait <= 0;
end
reg ioctl_wait = 0;

endmodule
