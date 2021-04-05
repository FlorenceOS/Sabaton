const sabaton = @import("../../sabaton.zig");

const regs = @import("regs.zig");

const width = 720;
const height = 1440;

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
        \\   .2byte %[width] * %[bpp]/8 // pitch
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
        , [bpp] "i" (@as(usize, 32))
    );
}

pub fn init() void {
    const fb_tag = sabaton.near("framebuffer_tag");
    sabaton.add_tag(&fb_tag.addr(sabaton.Stivale2tag)[0]);

    // We have a 32 bit physical address space on this device, this has to work
    const fb_addr = @intCast(u32, @ptrToInt(sabaton.pmm.alloc_aligned(width * 4 * height, .Hole).ptr));
    fb_tag.addr(u64)[2] = @as(u64, fb_addr);

    // Backlight brightness PWM, we just do a digital high lol
    regs.output_port('L', 10, true);

    // Enable backlight
    regs.output_port('H', 10, true);
}
