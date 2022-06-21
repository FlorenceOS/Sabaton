const sabaton = @import("root").sabaton;

fn ccu(offset: u16) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C2_0000) + offset);
}

const pll_ddr0 = ccu(0x0020);
const pll_ddr1 = ccu(0x004C);
const cpux_axi_cfg = ccu(0x0050);
const ahb1_apb1_cfg = ccu(0x0054);
const apb2_cfg = ccu(0x0058);
const ahb2_cfg = ccu(0x005C);
const bus_clk_gate0 = ccu(0x0060);
const bus_clk_gate1 = ccu(0x0064);
const bus_clk_gate2 = ccu(0x0068);
const bus_clk_gate3 = ccu(0x006C);
const bus_clk_gate4 = ccu(0x0070);
const ce_clk = ccu(0x009C);
const dram_cfg = ccu(0x00F4);
const mbus_reset = ccu(0x00FC);
const mbus_clk_gating = ccu(0x015C);
const mbus2_clk = ccu(0x0160);
const bus_soft_rst0 = ccu(0x02C0);
const bus_soft_rst1 = ccu(0x02C4);
const bus_soft_rst2 = ccu(0x02C8);
const bus_soft_rst3 = ccu(0x02D0);
const bus_soft_rst4 = ccu(0x02D8);
const pll_lock_ctrl = ccu(0x0320);
const mipi_dsi_clk = ccu(0x0168);

fn waitPllStable(pll_addr: *volatile u32) void {
    while ((pll_addr.* & (1 << 28)) == 0) {}
}

fn initPll(offset: u16, pll_value: u32) void {
    const reg = ccu(offset);
    reg.* = pll_value;
    waitPllStable(reg);
}

fn setPllCpux(clk: u32) void {
    const k: u32 = 1 + @boolToInt(clk >= 768000000);
    const n = clk / (24000000 * k);

    // zig fmt: off

    // Temporarily toggle CPUX clock to OSC24M while we reconfigure PLL_CPUX
    cpux_axi_cfg.* = 0
        | (1 << 16) // CPUX_CLK_SRC_SEL = OSC24M
        | (1 << 8) // CPU_APB_CLK_DIV = /2
        | (2 << 0) // AXI_CLK_DIV_RATIO = /3
    ;

    sabaton.timer.sleep_us(2);

    initPll(0x0000, 0 // PLL_CPUX
        | (1 << 31) // PLL_ENABLE
        | (0 << 16) // PLL_OUT_EXT_DIVP
        | ((n-1) << 8) // PLL_FACTOR_N
        | ((k-1) << 4) // PLL_FACTOR_K
        | (0 << 0) // PLL_FACTOR_M
    );

    // Switch CPUX back to PLL_CPUX
    cpux_axi_cfg.* = 0
        | (2 << 16) // CPUX_CLK_SRC_SEL = PLL_CPUX
        | (1 << 8) // CPU_APB_CLK_DIV = /2
        | (2 << 0) // AXI_CLK_DIV_RATIO = /3
    ;
    // zig fmt: on

    sabaton.timer.sleep_us(2);
}

pub fn upclock() void {
    setPllCpux(816000000);

    // zig fmt: off
    ahb1_apb1_cfg.* = 0
        | (0 << 12) // AHB_1_CLK_SRC_SEL = LOSC
        | (1 << 8) // APB1_CLK_RATIO = /2
        | (2 << 6) // AHB1_PRE_DIV = /3
        | (0 << 4) // AHB1_CLK_DIV_RATIO = /1
    ;
    // zig fmt: on

    ahb2_cfg.* = 1; // AHB2_CLK_CFG = PLL_PERIPH0(1X)/2
}

pub fn init() void {
    pll_lock_ctrl.* = 0x1FFF;

    setPllCpux(408000000);

    // zig fmt: off

    initPll(0x0028, 0 // PLL_PERIPH0
        | (1 << 31) // PLL_ENABLE
        | (1 << 24) // PLL_CLK_OUT_EN
        | (1 << 18) // Reserved 1
        | (24 << 8) // PLL_FACTOR_N, Factor=24, N=25
        | (1 << 4) // PLL_FACTOR_K
        | (1 << 0) // PLL_FACTOR_M
    ); 

    ahb1_apb1_cfg.* = 0
        | (0 << 12) // AHB_1_CLK_SRC_SEL = LOSC
        | (1 << 8) // APB1_CLK_RATIO = /2
        | (2 << 6) // AHB1_PRE_DIV = /3
        | (1 << 4) // AHB1_CLK_DIV_RATIO = /2
    ;

    mbus_clk_gating.* = 0
        | (1 << 31) // MBUS_SCLK_GATING = ON
        | (1 << 24) // MBUS_SCLK_SRC = PLL_PERIPH0(2X)
        | (2 << 0) // MBUS_SCLK_RATIO_M = /3
    ;

    apb2_cfg.* = 0
        | (1 << 24) // APB2_CLK_SRC_SEL = OSC24M
        | (0 << 16) // CLK_RAT_N = /2
        | (0 << 0) // CLK_RAT_M = /1
    ;
    // zig fmt: on
}

pub fn clockUarts() void {
    bus_clk_gate3.* |= (1 << 16);
    bus_soft_rst4.* |= (1 << 16);
}

pub fn clockDram() void {
    mbus_clk_gating.* &= ~@as(u32, 1 << 31); // Clear MBUS_SCLK_GATING

    mbus_reset.* &= ~@as(u32, 1 << 31); // Clear MBUS_RESET

    bus_clk_gate0.* &= ~@as(u32, 1 << 14); // Clear DRAM_GATING

    bus_soft_rst0.* &= ~@as(u32, 1 << 14); // Clear SDRAM_RST

    pll_ddr0.* &= ~@as(u32, 1 << 31); // Clear PLL_ENABLE
    pll_ddr1.* &= ~@as(u32, 1 << 31); // Clear PLL_ENABLE

    sabaton.timer.sleep_us(10);

    dram_cfg.* &= ~@as(u32, 1 << 31); // Clear DRAM_CTR_RST

    // zig fmt: off
    initPll(0x004C, 0 // pll_ddr1
        | (1 << 31) // PLL_ENABLE
        | (1 << 30) // SDRPLL_UPD
        | ((46-1) << 8) // 552 * 2 * 1000000 / 24000000 = 46
    );

    dram_cfg.* &= ~@as(u32, 0
        | (0x3 << 0) // Clear DRAM_DIV_M
        | (0x3 << 20) // Clear DDR_SRC_SELECT
    );
    dram_cfg.* |= @as(u32, 0
        | (1 << 0) // Set DRAM_DIV_M, M = 2
        | (1 << 20) // Set DDR_SRC_SELECT = PLL_DDR1
        | (1 << 16) // Set SDRCLK_UPD, validate config
    );
    // zig fmt: on

    while (dram_cfg.* & (1 << 16) != 0) {} // Wait for config validation

    bus_soft_rst0.* |= 1 << 14; // Set SDRAM_RST
    bus_clk_gate0.* |= 1 << 14; // Set DRAM_GATING
    mbus_reset.* |= 1 << 31; // Set MBUS_RESET
    mbus_clk_gating.* |= 1 << 31; // Set MBUS_SCLK_GATING

    dram_cfg.* |= 1 << 31; // Set DRAM_CTR_RST

    sabaton.timer.sleep_us(10);
}

// // Cock and ball torture?
// // Clock and PLL torture.
// init_pll(0x0010, 0x83001801); // PLL_VIDEO0
// init_pll(0x0028, 0x80041811); // PLL_PERIPH0
// init_pll(0x0040, 0x80C0041A); // PLL_MIPI
// init_pll(0x0048, 0x83006207); // PLL_DE

// // Cock gating registers?
// // Clock gating registers.
// ccu(0x0060).* = 0x33800040; // BUS_CLK_GATING_REG0
// ccu(0x0064).* = 0x00201818; // BUS_CLK_GATING_REG1
// ccu(0x0068).* = 0x00000020; // BUS_CLK_GATING_REG2
// ccu(0x006C).* = 0x00010000; // BUS_CLK_GATING_REG3
// //ccu(0x0070).* = 0x00000000; // BUS_CLK_GATING_REG4

// ccu(0x0088).* = 0x0100000B; // SMHC0_CLK_REG
// ccu(0x008C).* = 0x0001000E; // SMHC0_CLK_REG
// ccu(0x0090).* = 0x01000005; // SMHC0_CLK_REG

// ccu(0x00CC).* = 0x00030303; // USBPHY_CFG_REG

// ccu(0x0104).* = 0x81000000; // DE_CLK_REG
// ccu(0x0118).* = 0x80000000; // TCON0_CLK_REG
// ccu(0x0150).* = 0x80000000; // HDMI_CLK_REG
// ccu(0x0154).* = 0x80000000; // HDMI_SLOW_CLK_REG
// ccu(0x0168).* = 0x00008001; // MIPI_DSI_CLK_REG

// ccu(0x0224).* = 0x10040000; // PLL_AUDIO_BIAS_REG

// ----------------------

// // zig fmt: off
// const reg0_devs: u32 = 0
//     | (1 << 29) // USB-OHCI0
//     | (1 << 28) // USB-OTG-OHCI
//     | (1 << 25) // USB-EHCI0
//     | (1 << 24) // USB-OTG-EHCI0
//     | (1 << 23) // USB-OTG-Device
//     | (1 << 13) // NAND
//     | (1 << 1) // MIPI_DSI
// ;

// const reg1_devs: u32 = 0
//     | (1 << 22) // SPINLOCK
//     | (1 << 21) // MSGBOX
//     | (1 << 20) // GPU
//     | (1 << 12) // DE
//     | (1 << 11) // HDMI1
//     | (1 << 10) // HDMI0
//     | (1 << 5) // DEINTERLACE
//     | (1 << 4) // TCON1
//     | (1 << 3) // TCON0
// ;
// // zig fmt: on

// ccu(0x02C0).* &= ~reg0_devs;
// ccu(0x02C4).* &= ~reg1_devs;

// ccu(0x02C0).* |= reg0_devs;
// ccu(0x02C4).* |= reg1_devs;
