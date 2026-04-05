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
wire [31:0] hdd_bridge_rd_data;
always @(*) begin
    casex(bridge_addr)
    32'h200xxxxx: bridge_rd_data <= hdd_bridge_rd_data;
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
wire target_dataslot_ack, target_dataslot_done;
wire [2:0] target_dataslot_err;
localparam [1:0] TARGET_REQ_READ = 2'd0;
localparam [1:0] TARGET_REQ_WRITE = 2'd1;
localparam [1:0] TARGET_REQ_GETFILE = 2'd2;
localparam [1:0] TARGET_REQ_OPENFILE = 2'd3;

reg        target_req_sys = 0;
reg  [1:0] target_req_type_sys = TARGET_REQ_READ;
reg [15:0] target_req_id_sys = 0;
reg [31:0] target_req_slotoffset_sys = 0;
reg [31:0] target_req_bridgeaddr_sys = 0;
reg [31:0] target_req_length_sys = 0;

wire        target_req_74a;
wire  [1:0] target_req_type_74a;
wire [15:0] target_req_id_74a;
wire [31:0] target_req_slotoffset_74a;
wire [31:0] target_req_bridgeaddr_74a;
wire [31:0] target_req_length_74a;

wire target_dataslot_read = target_req_74a && (target_req_type_74a == TARGET_REQ_READ);
wire target_dataslot_write = target_req_74a && (target_req_type_74a == TARGET_REQ_WRITE);
wire target_dataslot_getfile = target_req_74a && (target_req_type_74a == TARGET_REQ_GETFILE);
wire target_dataslot_openfile = target_req_74a && (target_req_type_74a == TARGET_REQ_OPENFILE);
wire [15:0] target_dataslot_id = target_req_id_74a;
wire [31:0] target_dataslot_slotoffset = target_req_slotoffset_74a;
wire [31:0] target_dataslot_bridgeaddr = target_req_bridgeaddr_74a;
wire [31:0] target_dataslot_length = target_req_length_74a;
wire [31:0] target_buffer_param_struct = target_req_bridgeaddr_74a;
wire [31:0] target_buffer_resp_struct = target_req_bridgeaddr_74a;

wire target_dataslot_ack_sys;
wire target_dataslot_done_sys;
wire [2:0] target_dataslot_err_sys;
localparam [9:0] HDD_SIZE_DATATABLE_ADDR = 10'd7;
reg  [9:0] datatable_addr = 0;
wire [31:0] datatable_q;
wire        datatable_wren = 1'b0;
wire [31:0] datatable_data = 32'd0;

synch_3 #(
    .WIDTH(115)
) target_req_sync (
    {
        target_req_sys,
        target_req_type_sys,
        target_req_id_sys,
        target_req_slotoffset_sys,
        target_req_bridgeaddr_sys,
        target_req_length_sys
    },
    {
        target_req_74a,
        target_req_type_74a,
        target_req_id_74a,
        target_req_slotoffset_74a,
        target_req_bridgeaddr_74a,
        target_req_length_74a
    },
    clk_74a
);

synch_3 #(
    .WIDTH(5)
) target_resp_sync (
    {target_dataslot_ack, target_dataslot_done, target_dataslot_err},
    {target_dataslot_ack_sys, target_dataslot_done_sys, target_dataslot_err_sys},
    clk_sys
);

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

// ======== Clocks ========
wire clk_sys; // 32.5 MHz
wire clk_mem; // 65 MHz

wire clk_sys_90; // 32.5 MHz 90° for video DDR

pll pll_inst(
    .refclk(clk_74a), .rst(1'b0),
    .outclk_0(clk_mem), .outclk_1(clk_sys), .outclk_2(clk_sys_90),
    .locked(pll_core_locked)
);

// ======== ROM Loading ========
// Slot 0: Mac ROM (128KB or 256KB) loaded at 0x10000000
// Pace the bridge output so the Mac DIO slot can keep up.
localparam [7:0] SLOT_ROM       = 8'd0;
localparam [7:0] SLOT_FLOPPY_INT = 8'd1;
localparam [7:0] SLOT_FLOPPY_EXT = 8'd2;
localparam [7:0] SLOT_HDD       = 8'd3;
localparam [31:0] HDD_BUFFER_BASE = 32'h20000000;

wire        dl_wr;
wire [27:0] dl_addr;
wire [7:0]  dl_data;

data_loader #(
    .ADDRESS_MASK_UPPER_4(4'h1),
    .ADDRESS_SIZE(28),
    // One byte every 8 clk_sys cycles => one 16-bit ROM word every 16 cycles,
    // which matches the Mac core's extra bus slot cadence.
    .WRITE_MEM_CLOCK_DELAY(7)
) rom_loader (
    .clk_74a(clk_74a), .clk_memory(clk_sys),
    .bridge_wr(bridge_wr), .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
    .write_en(dl_wr), .write_addr(dl_addr), .write_data(dl_data)
);

wire       hdd_dl_wr;
wire [8:0] hdd_dl_addr;
wire [7:0] hdd_dl_data;

data_loader #(
    .ADDRESS_MASK_UPPER_4(4'h2),
    .ADDRESS_SIZE(9)
) hdd_loader (
    .clk_74a(clk_74a), .clk_memory(clk_sys),
    .bridge_wr(bridge_wr), .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
    .write_en(hdd_dl_wr), .write_addr(hdd_dl_addr), .write_data(hdd_dl_data)
);

// Download tracking and ROM mode selection.
reg dl_downloading_74a = 0;
reg rom_is_se_74a = 0;
reg [7:0]  dl_slot_id_74a = SLOT_ROM;
reg [31:0] dl_slot_size_74a = 0;
reg [31:0] hdd_file_size_74a = 0;
always @(posedge clk_74a) begin
    datatable_addr <= HDD_SIZE_DATATABLE_ADDR;

    if (dataslot_requestwrite) begin
        dl_downloading_74a <= 1;
        dl_slot_id_74a <= dataslot_requestwrite_id[7:0];
        dl_slot_size_74a <= dataslot_requestwrite_size;
        if (dataslot_requestwrite_id[7:0] == SLOT_ROM)
            rom_is_se_74a <= (dataslot_requestwrite_size > 32'd131072);
    end
    else if (dataslot_allcomplete) dl_downloading_74a <= 0;

    hdd_file_size_74a <= datatable_q;
end

reg dl_s0 = 0, dl_s1 = 0;
reg rom_is_se_s0 = 0, rom_is_se_s1 = 0;
reg [7:0] dl_slot_id_s0 = SLOT_ROM, dl_slot_id_s1 = SLOT_ROM;
reg [31:0] dl_slot_size_s0 = 0, dl_slot_size_s1 = 0;
reg [31:0] hdd_file_size_s0 = 0, hdd_file_size_s1 = 0;
reg dl_active_prev = 0;
reg [7:0] dl_tail_hold = 0;
reg dio_write = 0;
reg ioctl_wait = 0;

always @(posedge clk_sys) begin
    dl_s0 <= dl_downloading_74a;
    dl_s1 <= dl_s0;
    rom_is_se_s0 <= rom_is_se_74a;
    rom_is_se_s1 <= rom_is_se_s0;
    dl_slot_id_s0 <= dl_slot_id_74a;
    dl_slot_id_s1 <= dl_slot_id_s0;
    dl_slot_size_s0 <= dl_slot_size_74a;
    dl_slot_size_s1 <= dl_slot_size_s0;
    hdd_file_size_s0 <= hdd_file_size_74a;
    hdd_file_size_s1 <= hdd_file_size_s0;

    dl_active_prev <= dl_s1;
    if (dl_s1) dl_tail_hold <= 8'd96;
    else if (dl_active_prev) dl_tail_hold <= 8'd96;
    else if (dl_tail_hold != 0) dl_tail_hold <= dl_tail_hold - 1'd1;
end

wire dl_active = dl_s1;
wire [20:0] dl_phys_addr =
    (dl_slot_id_s1 == SLOT_FLOPPY_INT) ? {2'b01, dl_addr[19:1]} :
    (dl_slot_id_s1 == SLOT_FLOPPY_EXT) ? {2'b10, dl_addr[19:1]} :
                                         {3'b000, dl_addr[17:1]};

// Convert data_loader 8-bit to 16-bit words and buffer in FIFO
// Mac bus can only write one word per bus cycle (~32 clk_sys)
reg [7:0]  dio_byte_hi;
reg        dio_byte_toggle = 0;

// FIFO: stores {addr[20:0], data[15:0]} = 37 bits
reg [36:0] dio_fifo [0:1023];
reg [9:0]  dio_fifo_wr = 0;
reg [9:0]  dio_fifo_rd = 0;

// Write side: pack bytes into words, push to FIFO
always @(posedge clk_sys) begin
    if (dl_wr) begin
        if (!dio_byte_toggle) begin
            dio_byte_hi <= dl_data;
            dio_byte_toggle <= 1;
        end else begin
            // Mac ROM is big-endian: the first byte at an even address is the word's high byte.
            dio_fifo[dio_fifo_wr] <= {dl_phys_addr, dio_byte_hi, dl_data};
            dio_fifo_wr <= dio_fifo_wr + 1'd1;
            dio_byte_toggle <= 0;
        end
    end
    if (!dio_download) dio_byte_toggle <= 0;
end

// Read side: drain one word per bus cycle
reg [15:0] dio_data;
reg [20:0] dio_a;
wire dio_download = dl_active || (dl_tail_hold != 0) || dio_byte_toggle || (dio_fifo_rd != dio_fifo_wr) || ioctl_wait;

// ======== Reset ========
reg       n_reset = 0;
reg [1:0] status_cpu = 0;
reg       status_mem = 0; // 0=1MB, 1=4MB
reg       status_mod = 0; // 0=Plus, 1=SE

always @(posedge clk_sys) begin
    reg [15:0] rst_cnt;
    if (clk8_en_p) begin
        status_mod <= rom_is_se_s1;
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

// Floppy insertion state. Images live right after the ROM in SDRAM, matching MiSTer.
reg dsk_int_ds = 0, dsk_ext_ds = 0;
reg dsk_int_ss = 0, dsk_ext_ss = 0;
wire dsk_int_ins = dsk_int_ds || dsk_int_ss;
wire dsk_ext_ins = dsk_ext_ds || dsk_ext_ss;

always @(posedge clk_sys) begin
    reg old_down = 0;

    old_down <= dio_download;
    if (old_down && ~dio_download) begin
        if (dl_slot_id_s1 == SLOT_FLOPPY_INT) begin
            dsk_int_ds <= (dl_slot_size_s1 == 32'd819200);
            dsk_int_ss <= (dl_slot_size_s1 == 32'd409600);
        end
        else if (dl_slot_id_s1 == SLOT_FLOPPY_EXT) begin
            dsk_ext_ds <= (dl_slot_size_s1 == 32'd819200);
            dsk_ext_ss <= (dl_slot_size_s1 == 32'd409600);
        end
    end

    if (diskEject[0]) begin
        dsk_int_ds <= 0;
        dsk_int_ss <= 0;
    end

    if (diskEject[1]) begin
        dsk_ext_ds <= 0;
        dsk_ext_ss <= 0;
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
addrController_top #(
    .VIDEO_VERTICAL_DOUBLE(1'b0),
    .VIDEO_PIXEL_LATENCY(0)
) ac0 (
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

// Mouse input: controller 1 d-pad emulation, overridden by dock mouse on Player 4.
wire [24:0] pad_ps2_mouse;
pad_to_ps2_mouse pad_mouse (
    .clk(clk_sys), .cont1_key(cont1_key), .ps2_mouse(pad_ps2_mouse)
);

wire dock_mouse_present = (cont4_key[31:28] == 4'h5);
wire [24:0] dock_ps2_mouse;
usb_to_ps2_mouse usb_mouse (
    .clk(clk_sys), .cont4_key(cont4_key), .cont4_joy(cont4_joy),
    .cont4_trig(cont4_trig), .ps2_mouse(dock_ps2_mouse)
);
wire [24:0] active_ps2_mouse = dock_mouse_present ? dock_ps2_mouse : pad_ps2_mouse;

// Data Controller (I/O hub: VIA, SCC, IWM, SCSI, keyboard, mouse, video, audio)
wire [1:0] diskEject;
wire [1:0] diskMotor, diskAct;

localparam SCSI_DEVS = 2;
wire [31:0] sd_lba_s [SCSI_DEVS];
wire [SCSI_DEVS-1:0] sd_rd_s, sd_wr_s;
reg  [SCSI_DEVS-1:0] sd_ack_s = 0;
reg  [7:0] sd_buff_addr_s = 0;
reg [15:0] sd_buff_dout_s = 0;
wire [15:0] sd_buff_din_s [SCSI_DEVS];
reg sd_buff_wr_s = 0;
wire [SCSI_DEVS-1:0] img_mounted_s = {1'b0, |hdd_file_size_s1};
wire [31:0] img_size_s = hdd_file_size_s1[31:9];

localparam HDS_IDLE       = 3'd0;
localparam HDS_WAIT_ACK   = 3'd1;
localparam HDS_FILL       = 3'd2;
localparam HDS_DONE       = 3'd3;
localparam HDS_ERROR      = 3'd4;
localparam HDS_WRITE_PREP = 3'd5;
localparam HDS_WRITE_COPY = 3'd6;
localparam HDS_WRITE_WAIT = 3'd7;

reg [2:0] hdd_state = HDS_IDLE;
reg [9:0] hdd_rx_count = 0;
reg [7:0] hdd_byte_lo = 0;
reg       hdd_byte_toggle = 0;
reg [7:0] hdd_copy_idx = 0;
reg       hdd_copy_primed = 0;
reg [15:0] hdd_copy_lo = 0;
(* ramstyle = "M10K, no_rw_check" *) reg [31:0] hdd_tx_buf [0:127];

wire [6:0] hdd_bridge_word = bridge_addr[8:2];
wire       hdd_bridge_sel = (bridge_addr[31:9] == HDD_BUFFER_BASE[31:9]);
assign hdd_bridge_rd_data = hdd_bridge_sel ? hdd_tx_buf[hdd_bridge_word] : 32'd0;

always @(posedge clk_sys) begin
    sd_ack_s <= 0;
    sd_buff_wr_s <= 0;

    if (target_dataslot_ack_sys)
        target_req_sys <= 0;

    if (hdd_state == HDS_FILL && hdd_dl_wr) begin
        if (!hdd_byte_toggle) begin
            hdd_byte_lo <= hdd_dl_data;
            hdd_byte_toggle <= 1;
        end else begin
            sd_buff_addr_s <= hdd_rx_count[8:1];
            sd_buff_dout_s <= {hdd_dl_data, hdd_byte_lo};
            sd_buff_wr_s <= 1;
            hdd_byte_toggle <= 0;
        end

        hdd_rx_count <= hdd_rx_count + 1'd1;
    end

    case (hdd_state)
        HDS_IDLE: begin
            hdd_rx_count <= 0;
            hdd_byte_toggle <= 0;

            if (sd_rd_s[0] && img_mounted_s[0] && !target_req_sys) begin
                target_req_type_sys <= TARGET_REQ_READ;
                target_req_id_sys <= SLOT_HDD;
                target_req_slotoffset_sys <= sd_lba_s[0] << 9;
                target_req_bridgeaddr_sys <= HDD_BUFFER_BASE;
                target_req_length_sys <= 32'd512;
                target_req_sys <= 1;
                hdd_state <= HDS_WAIT_ACK;
            end else if (sd_wr_s[0] && img_mounted_s[0]) begin
                hdd_state <= HDS_WRITE_PREP;
            end
        end

        HDS_WAIT_ACK: begin
            if (target_dataslot_ack_sys)
                hdd_state <= HDS_FILL;
            else if (target_dataslot_done_sys && target_dataslot_err_sys != 0)
                hdd_state <= HDS_ERROR;
        end

        HDS_FILL: begin
            if (hdd_rx_count == 10'd512 && !hdd_byte_toggle) begin
                hdd_state <= HDS_DONE;
            end else if (target_dataslot_done_sys && target_dataslot_err_sys != 0) begin
                hdd_state <= HDS_ERROR;
            end
        end

        HDS_DONE: begin
            sd_ack_s[0] <= 1'b1;
            if (!sd_rd_s[0] && !sd_wr_s[0])
                hdd_state <= HDS_IDLE;
        end

        HDS_ERROR: begin
            if (!sd_rd_s[0] && !sd_wr_s[0])
                hdd_state <= HDS_IDLE;
        end

        HDS_WRITE_PREP: begin
            hdd_copy_idx <= 0;
            hdd_copy_primed <= 0;
            sd_buff_addr_s <= 0;
            hdd_state <= HDS_WRITE_COPY;
        end

        HDS_WRITE_COPY: begin
            if (!hdd_copy_primed) begin
                hdd_copy_primed <= 1;
                sd_buff_addr_s <= 0;
            end else begin
                if (!hdd_copy_idx[0]) begin
                    hdd_copy_lo <= sd_buff_din_s[0];
                end else begin
                    hdd_tx_buf[hdd_copy_idx[7:1]] <= {sd_buff_din_s[0], hdd_copy_lo};
                end

                if (hdd_copy_idx == 8'hFF) begin
                    target_req_type_sys <= TARGET_REQ_WRITE;
                    target_req_id_sys <= SLOT_HDD;
                    target_req_slotoffset_sys <= sd_lba_s[0] << 9;
                    target_req_bridgeaddr_sys <= HDD_BUFFER_BASE;
                    target_req_length_sys <= 32'd512;
                    target_req_sys <= 1;
                    hdd_state <= HDS_WRITE_WAIT;
                end else begin
                    hdd_copy_idx <= hdd_copy_idx + 1'd1;
                    sd_buff_addr_s <= hdd_copy_idx + 1'd1;
                end
            end
        end

        HDS_WRITE_WAIT: begin
            if (target_dataslot_done_sys && target_dataslot_err_sys == 0) begin
                hdd_state <= HDS_DONE;
            end else if (target_dataslot_done_sys && target_dataslot_err_sys != 0) begin
                hdd_state <= HDS_ERROR;
            end
        end
    endcase
end

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
    .ps2_mouse(active_ps2_mouse),
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
// Mac Plus: 512x342 monochrome, every clk_sys cycle is one pixel
assign video_rgb_clock    = clk_sys;
assign video_rgb_clock_90 = clk_sys_90;
assign video_skip = 1'b0;

wire [7:0] pix = {8{pixelOut}};
assign video_rgb = (_vblank & _hblank) ? {pix, pix, pix} : 24'd0;
assign video_de  = _vblank & _hblank;
assign video_vs  = vsync;
assign video_hs  = hsync;

// ======== Audio ========
wire [15:0] mac_audio_i2s = {mac_audio[10], mac_audio, 4'b0};

sound_i2s #(
    .CHANNEL_WIDTH(16),
    .SIGNED_INPUT(1)
) sound_i2s_inst (
    .clk_74a   (clk_74a),
    .clk_audio (clk_sys),
    .audio_l   (mac_audio_i2s),
    .audio_r   (mac_audio_i2s),
    .audio_mclk(audio_mclk),
    .audio_lrck(audio_lrck),
    .audio_dac (audio_dac)
);

// ======== SDRAM ========
assign dram_cke = 1;

// DIO write path (ROM/floppy loading)
wire download_cycle = dio_download && dioBusControl;

wire [24:0] sdram_addr = download_cycle ? {4'b0001, dio_a} :
                          ~_romOE       ? {4'b0001, 2'b00, status_mod, memoryAddr[18:1]} :
                                          {3'b000, (dskReadAckInt || dskReadAckExt), memoryAddr[21:1]};

wire [15:0] sdram_din  = download_cycle ? dio_data              : memoryDataOut;
wire  [1:0] sdram_ds   = download_cycle ? 2'b11                 : {!_memoryUDS, !_memoryLDS};
wire        sdram_we   = download_cycle ? dio_write             : !_ramWE;
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

// DIO write: match MiSTer's ioctl_wait pattern exactly
// ioctl_wait goes high when word is ready, cleared after bus cycle writes it
always @(posedge clk_sys) begin
    reg old_cyc;

    // Load next word from FIFO when not waiting
    if (!ioctl_wait && dio_fifo_rd != dio_fifo_wr) begin
        {dio_a, dio_data} <= dio_fifo[dio_fifo_rd];
        dio_fifo_rd <= dio_fifo_rd + 1'd1;
        ioctl_wait <= 1;
    end

    // MiSTer pattern: dio_write asserts when dioBusControl falls while waiting
    old_cyc <= dioBusControl;
    if (~dioBusControl) dio_write <= ioctl_wait;
    if (old_cyc & ~dioBusControl & dio_write) ioctl_wait <= 0;
end


endmodule
