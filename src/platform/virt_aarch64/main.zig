pub const sabaton = @import("../../sabaton.zig");
pub const panic = sabaton.panic;

pub usingnamespace @import("../drivers/virt.zig");

pub fn get_uart_info() @This().io.Info {
    const base = 0x9000000;
    return .{
        .uart = @intToPtr(*volatile u32, base),
    };
}

pub fn get_dtb() []u8 {
    return sabaton.near("dram_base").read([*]u8)[0..0x100000];
}

var page_size: u64 = 0x1000;

pub fn get_page_size() u64 {
    return page_size;
}

export fn _main() linksection(".text.main") noreturn {
    page_size = sabaton.paging.detect_page_size();
    sabaton.fw_cfg.init_from_dtb();
    @call(.{ .modifier = .always_inline }, sabaton.main, .{});
}

pub fn map_platform(root: *sabaton.paging.Root) void {
    sabaton.paging.map(0, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
    sabaton.paging.map(sabaton.upper_half_phys_base, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
    sabaton.puts("Initing pci!\n");
    sabaton.pci.init_from_dtb(root);
}