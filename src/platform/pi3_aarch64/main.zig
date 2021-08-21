const std = @import("std");
pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.status_uart_mmio_32;
pub const panic = sabaton.panic;
pub const display = @import("display.zig");
pub const ElfType = [*]u8;
const regs = @import("regs.zig");

var page_size: u64 = 0x1000;
pub fn get_page_size() u64 {
    return page_size;
}

export fn _main() linksection(".text.main") noreturn {
    regs.miniuart_init();
    @call(.{ .modifier = .always_inline }, sabaton.main, .{});
}

pub fn get_dram() []allowzero u8 {
    var slice: [8]u32 align(16) = undefined;
    var mbox = @intToPtr([*]volatile u32, @ptrToInt(&slice));
    mbox[0] = 8 * 4; // size
    mbox[1] = 0; // req

    mbox[2] = 0x10005; // tag
    mbox[3] = 8; // buffer size
    mbox[4] = 0; // req/resp code
    mbox[5] = 0; // base
    mbox[6] = 0; // size
    mbox[7] = 0; // terminator

    regs.mbox_call(8, @ptrToInt(mbox));
    const size = mbox[6];
    const addr = mbox[5];
    return @intToPtr([*]allowzero u8, addr)[0..size];
}

pub fn get_uart_info() io.Info {
    return .{
        .uart = regs.AUX_MU_IO,
        .status = regs.AUX_MU_LSR,
        .mask = 0x20,
        .value = 0x20,
    };
}

pub fn get_kernel() [*]u8 {
    // TODO: this relies on the config.txt/qemu setup, replace it with a real SD driver
    return @intToPtr([*]u8, 0x200000);
}

pub fn add_platform_tags(kernel_header: *sabaton.Stivale2hdr) void {
    sabaton.add_tag(&sabaton.near("uart_tag").addr(sabaton.Stivale2tag)[0]);
}

pub fn map_platform(root: *sabaton.paging.Root) void {
    sabaton.paging.map(regs.MMIO_BASE, regs.MMIO_BASE, 0xFFFFFFF, .rw, .mmio, root);
    sabaton.paging.map(sabaton.upper_half_phys_base + regs.MMIO_BASE, regs.MMIO_BASE, 0xFFFFFFF, .rw, .mmio, root);
}
