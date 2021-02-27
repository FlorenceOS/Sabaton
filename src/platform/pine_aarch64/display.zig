const sabaton = @import("../../sabaton.zig");

comptime {
    asm(
        \\   .section .data
        \\   .balign 8
        \\ framebuffer_tag:
        \\   .8byte 0x506461d2950408fa // framebuffer identifier
        \\   .8byte 0        // next
        \\   .8byte 0        // addr
        \\   .2byte 720      // width
        \\   .2byte 1440     // height
        \\   .2byte 720 * 4  // pitch
        \\   .2byte 32       // bpp
        \\   .byte  1        // memory model, 1 = RGB
        \\   .byte  8        // red mask size
        \\   .byte  16       // red_mask_shift
        \\   .byte  8        // green_mask_size
        \\   .byte  8        // green_mask_shift
        \\   .byte  8        // blue_mask_size
        \\   .byte  0        // blue_mask_shift
    );
}

const de_addr    = 0x01000000;
const tcon0_addr = 0x01C0C000;
const tcon1_addr = 0x01C0D000;

const rt_mixer0_addr = de_addr + 0x10_0000;
const bld_addr       = rt_mixer0_addr + 0x1000;
const ovl_v_addr     = rt_mixer0_addr + 0x2000;

comptime {
    if(tcon1_addr != tcon0_addr + 0x1000)
        @panic("Assuming the're right after eachother for mapping below");
}

fn bld(comptime T: type, offset: u16) *volatile T {
    return @intToPtr(*volatile T, @as(usize, bld_addr) + offset);
}

fn olv_v(comptime T: type, offset: u24) *volatile T {
    return @intToPtr(*volatile T, @as(usize, ovl_v_addr) + offset);
}

fn tcon0(offset: u16) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, tcon0_addr) + offset);
}

fn tcon1(offset: u16) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, tcon1_addr) + offset);
}


// struct Pixel {
//   u8 blue, green, red;
// };


// Allwinner A64 user manual:
//  6.2.5 TCOn0 Module register description

pub fn init() void {
    sabaton.platform.timer.init();
    const fb_tag = sabaton.near("framebuffer_tag");
    sabaton.add_tag(&fb_tag.addr(sabaton.Stivale2tag)[0]);

    // We have a 32 bit physical address space on this device, this has to work
    const fb_addr = @intCast(u32, @ptrToInt(sabaton.pmm.alloc_aligned(720 * 4 * 1440, .Hole).ptr));
    fb_tag.addr(u64)[2] = @as(u64, fb_addr);

    // TCON_En
    tcon0(0x0000).* |= (1 << 31);

    // TCON0_HV_IF_REG: HV_MODE = 8bit/4cycle Dummy RGB(DRGB)
    tcon0(0x0058).* |= (0b1010 << 28);

    // We'll only use the top field and layer 0

    // OVL_V_ATTCTL        LAY_FBFMT     VIDEO_UI_SEL
    olv_v(u32, 0x0000).* = (0x00 << 8) | (1 << 15);

    // OVL_V_MBSIZE        LAY_HEIGHT           LAY_WIDTH
    olv_v(u32, 0x0004).* = ((1440 - 1) << 16) | ((720 - 1) << 0);

    // // OVL_V_COOR          LAY_YCOOR   LAY_XCOOR
    // olv_v(u32, 0x0008).* = (0 << 16) | (0 << 0);

    // OVL_V_PITCH0        LAY_PITCH
    olv_v(u32, 0x000C).* = 720 * 4;

    // OVL_V_TOP_LADD0     LAYMB_LADD
    olv_v(u32, 0x0018).* = fb_addr;

    // Enable pipe0 from olv_v

    // BLD_FILL_COLOR_CTL P0_EN
    bld(u32, 0x0000).* =  (1 << 8);

    // BLD_CH_ISIZE      HEIGHT               WIDTH
    bld(u32, 0x0008).* = ((1440 - 1) << 16) | ((720 - 1) << 0);

    // // BLD_CH_OFFSET     YCOOR       XCOOR
    // bld(u32, 0x000C).* = (0 << 16) | (0 << 0);


    //tcon1(0x0).* |= 1 << 31;
}
