const sabaton = @import("../../sabaton.zig");

const regs = @import("regs.zig");
const timer = @import("root").timer;
const pmic = @import("pmic.zig");

const width = 720;
const height = 1440;
const bpp = 24;

const pitch = width * bpp/8;

comptime {
    if(bpp != 32 and bpp != 24) {
        @compileError("Invalid bpp!");
    }
}

const panel_bpp = 24;

// VIDEO0 = 24000000 * n / m
// (24 * 58 / 5) / 4 = 69.6
const panel_clock = 69000;

// DCLK = MIPI clock /4
const dclk_divisor = 4;

const hsync_start = width + 40;
const hsync_end   = hsync_start + 40;
const hperiod     = hsync_end + 40;

const vsync_start = height + 12;
const vsync_end   = vsync_start + 10;
const vperiod     = vsync_end + 17;

const panel_lanes = 4;

// From manual:
//   Block Space should be set >20*pixel_cycle'
const block_space = hperiod * panel_bpp / (dclk_divisor * panel_lanes) - hsync_start;

const start_delay = ((vperiod - height - 10 - 1) * hperiod * (150 - 1)) / (panel_clock / 1000) / 8;

// Cant't do input/output constraints on global asm, so this is what we have to do.
export fn tag() callconv(.Naked) void {
    asm volatile(
        \\   .section .data
        \\   .balign 8
        \\ framebuffer_tag:
        \\   .8byte 0x506461d2950408fa // framebuffer identifier
        \\   .8byte 0        // next
        \\   .8byte 0        // addr
        \\   .2byte %[width] // width
        \\   .2byte %[height]// height
        \\   .2byte %[pitch] // pitch
        \\   .2byte %[bpp]   // bpp
        \\   .byte  1        // memory model, 1 = RGB
        \\   .byte  8        // red mask size
        \\   .byte  16       // red_mask_shift
        \\   .byte  8        // green_mask_size
        \\   .byte  8        // green_mask_shift
        \\   .byte  8        // blue_mask_size
        \\   .byte  0        // blue_mask_shift
        :
        : [width] "i" (@as(usize, width))
        , [height] "i" (@as(usize, height))
        , [bpp] "i" (@as(usize, bpp))
        , [pitch] "i" (@as(usize, pitch))
    );
}

fn init_tcon0() void {
    // PLL_MIPI is a bit different, check A64 manual 3.3.6.1, list item 4:
    //   When configured PLL_MIPI,LDO1 and LDO2 must be enable at first,and delay 100us ,configure the
    //   division factor, then enable and delay 500us, PLL_MIPI can be output to use.

    // PLL_VIDEO0
    regs.ccu(0x0010).* = (1 << 31) | (1 << 24) | ((99 - 1) << 8) | ((8 - 1) << 0);

    // PLL_MIPI          LDO{1,2}_EN
    regs.ccu(0x0040).* = (3 << 22);

    timer.sleep_us(100);

    // PLL_MIPI          ENABLE      LDO{1,2}_EN   PLL_PRE_DIV_M     PLL_FACTOR_K     PLL_FACTOR_N
    regs.ccu(0x0040).* = (1 << 31) | (3 << 22)   | ((13 - 1) << 0) | ((2 - 1) << 4) | ((6 - 1) << 8);

    timer.sleep_us(500);

    // TCON0_CLK_REG     CLOCK ON    CLK_SRC_SEL
    regs.ccu(0x0118).* = (1 << 31) | (0 << 24);

    // Gate clock
    // BUS_CLK_GATING_REG1 TCON0_GATING
    regs.ccu(0x0064).* =   (1 << 4);

    // Reset off
    // BUS_SOFT_RST_REG1 TCON0_RST
    regs.ccu(0x02C4).* = (1 << 3);

    // Allwinner A64 user manual:
    //  6.2.5 TCON0 Module register description

    // Set all pins to tristate
    // TCON_TRISTATE
    regs.tcon0(0x00F4).* = 0xFFFFFFFF;

    // TCON0_DCLK_REG                  TCON0_Dclk_Div
    regs.tcon0(0x0044).* = (1 << 31) | (dclk_divisor << 0);

    // TCON0_CTL_REG       TCON0_EN    8080 I/F
    regs.tcon0(0x0040).* = (1 << 31) | (1 << 24);

    // TCON0_BASIC0_REG    HEIGHT                WIDTH
    regs.tcon0(0x0048).* = ((height - 1) << 0) | ((width - 1) << 16);

    // TCON0_ECC_FIFO
    regs.tcon0(0x00F8).* = (1 << 3);

    // TCON0_CPU_IF_REG
    regs.tcon0(0x0060).* = (1 << 16) | (1 << 2) | (1 << 0);

    // TCON0_CPU_TRI0_REG  Block_Space                 Block_Size
    regs.tcon0(0x0160).* = ((block_space - 1) << 16) | ((width - 1) << 0);

    // TCON0_CPU_TRI1_REG  Block_Num
    regs.tcon0(0x0164).* = ((height - 1) << 0);

    // TCON0_CPU_TRI2_REG  Trans_Start_Set  Start_Delay
    regs.tcon0(0x0168).* = (10 << 0)      | (start_delay << 16);

    // TCON_SAFE_PERIOD_REG
    regs.tcon0(0x01F0).* = (3000 << 16) | (3 << 0);

    // Enable all outputs
    // TCON0_IO_TRI_REG
    //regs.tcon0(0x008C).* = 0xE0000000;
    regs.tcon0(0x008C).* = 0;

    // Enable TCON
    // TCON_GCTL_REG       TCON_En
    regs.tcon0(0x0000).* = (1 << 31);
}

fn init_dsi_instrs() void {

}

fn init_dsi() void {
    // Display reset, active low
    regs.output_port('D', 23, false);

    sabaton.log_hex("pmic 0x15: ", pmic.read(0x15));

    pmic.write(0x15, 0x1A);
    pmic.set_bits(0x12, (1 << 3));

    pmic.write(0x91, 0x1A);
    pmic.write(0x90, 0x03);

    pmic.write(0x16, 0x0B);
    pmic.set_bits(0x12, (1 << 4));

    timer.sleep_us(15000);

    regs.ccu(0x0060).* |= (1 << 1);
    regs.ccu(0x02C0).* |= (1 << 1);

    regs.mipi_dsi(0x0000).* = (1 << 0);
    regs.mipi_dsi(0x0010).* = (1 << 16) | (1 << 17);

    regs.mipi_dsi(0x0060).* = 10;
    regs.mipi_dsi(0x0078).* = 0;

    @call(.{.modifier = .always_inline}, init_dsi_instrs, .{});

    regs.mipi_dsi(0x02F8).* = 0xFF;

    // Deassert reset
    regs.write_port('D', 23, true);
}

pub fn init() void {
    const fb_tag = sabaton.near("framebuffer_tag");
    sabaton.add_tag(&fb_tag.addr(sabaton.Stivale2tag)[0]);

    const fb_bytes = width * bpp/8 * height;
    const fb_addr = @ptrToInt(sabaton.pmm.alloc_aligned(fb_bytes, .Hole).ptr);
    fb_tag.addr(u64)[2] = fb_addr;

    @memset(@intToPtr([*]u8, fb_addr), 0xFF, fb_bytes);

    @call(.{.modifier = .always_inline}, init_tcon0, .{});
    @call(.{.modifier = .always_inline}, init_dsi, .{});

    // Display reset
    regs.output_port('D', 23, true);

    // Allwinner DE2.0 Specification:
    //  5.10.8 OVL_UI Register Description

    // Enable layer 0 with simple framebuffer
    // We use pipe1 (OLV_UI0) in core0
    regs.de(0x0000).* = 0x3; // Pass through sclk to core0 and core1
    regs.de(0x0004).* = 0x3; // Pass through hclk to core0 and core1

    // Reset mixer cores (we can do both without additional cost, so why not?)
    regs.de(0x0008).* = 0;   // Stop  core0 and core1
    regs.de(0x0008).* = 0x3; // Start core0 and core1

    // OVL_UI_MDSIZE
    regs.de_olv_ui(0x0004).* = ((height - 1) << 16) | ((width - 1) << 0);

    // OVL_UI_COOR
    // Should already be 0
    // regs.de_olv_ui(0x0008).* = (0 << 16) | (0 << 0);

    // OVL_UI_PITCH            LAY_PITCH
    regs.de_olv_ui(0x000C).* = pitch;

    // No, I don't know why the bottom half is called "top" and vice versa. Tread carefully.
    regs.de_olv_ui(0x0010).* = @truncate(u32, fb_addr);       // OVL_UI_TOP_LADD: LAYMB_LADD
    regs.de_olv_ui(0x0014).* = @truncate(u32, fb_addr >> 32); // OVL_UI_BOT_LADD: LAYMB_LADD

    // OVL_UI_FILL_COLOR
    // regs.de_olv_ui(0x0018).* = 0;

    // Allwinner DE2.0 Specification:
    //  5.10.9 BLD Register Description

    // BLD_FILL_COLOR_CTL   P0_EN      P0_FCEN
    regs.de_bld(0x0000).* = (1 << 8) | (1 << 0); // Enable pipe and fill color

    // BLD_FILL_COLOR
    regs.de_bld(0x0004).* = (0xFF << 24); // Fill with alpha = 0xFF

    // BLD_CH_ISIZE         HEIGHT                 WIDTH
    regs.de_bld(0x0008).* = ((height - 1) << 16) | ((width - 1) << 0);

    // BLD_CH_OFFSET        YCOOR       XCOOR
    regs.de_bld(0x000C).* = (0 << 16) | (0 << 0);

    // BLD Routing

    // Here we route pipe1 through each blender, only sending it through
    // Pipe1 is OVL_UI layer 0, which is the one we're using.

    // BLD_CH_RTCTL         P3_RTCTL    P2_RTCTL   P1_RTCTL   P0_RTCTL
    regs.de_bld(0x0080).* = (0 << 12) | (0 << 8) | (0 << 4) | (1 << 0);

    // BLD_SIZE             BLD_HEIGHT             BLD_WIDTH
    regs.de_bld(0x008C).* = ((height - 1) << 16) | ((width - 1) << 0);

    {
        var reg: usize = 0x0090;
        while(reg <= 0x009C): (reg += 4) {
            // BLD_CTL
            regs.de_bld(reg).* = 0x03010301; // Normal blending coefficients
        }
    }

    // Set the enable bit
    // OVL_UI_ATTR_CTL         LAY_FBFMT=XRGB_8888 | LAY_EN
    regs.de_olv_ui(0x0000).* = (0x04 << 8)         | (1 << 0);

    // Now we should be sending our framebuffer data to TCON0

    // Backlight brightness PWM, we just do a digital high lol
    regs.output_port('L', 10, true);

    // Enable backlight
    regs.output_port('H', 10, true);

    regs.write_port('D', 23, false);
}
