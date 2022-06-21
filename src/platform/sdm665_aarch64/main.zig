pub const sabaton = @import("../../sabaton.zig");

fn uartReg(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, 0x4A90000 + offset);
}

pub const io = struct {
    pub fn putchar(ch: u8) void {
        uartReg(0x600).* = 0x08000000;
        uartReg(0x270).* = 1;
        uartReg(0x700).* = ch;
        uartReg(0x61C).* = 0x40000000;
        uartReg(0x620).* = 0x40000000;
    }
};

pub export fn _main() callconv(.C) noreturn {
    sabaton.main();
}

fn get_sram() []u8 {
    return @intToPtr([*]u8, 0xC100000)[0..0x200000];
}

pub fn get_dram() []u8 {
    return @intToPtr([*]u8, 0x45E10000)[0..0x20000000];
}

pub fn get_kernel() [*]u8 {
    return @intToPtr([*]u8, 0x42424242);
}

pub fn add_platform_tags(kernel_header: *sabaton.Stivale2hdr) void {
    _ = kernel_header;
}

pub fn map_platform(root: *sabaton.paging.Root) void {
    _ = root;
}

pub fn get_page_size() usize {
    return 0x1000;
}
