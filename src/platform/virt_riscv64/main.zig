pub const sabaton = @import("../../sabaton.zig");
pub const panic = sabaton.panic;

pub usingnamespace @import("../drivers/virt.zig");

pub fn get_uart_info() @This().io.Info {
    const base = 0x10000000;
    return .{
        .uart = @intToPtr(*volatile u32, base),
    };
}

var dtb_base: u64 = undefined;

pub fn get_dtb() []u8 {
    return @intToPtr([*]u8, dtb_base)[0..0x100000];
}

pub fn get_page_size() u64 {
    return 0x1000;
}

export fn _main(hart_id: u64, dtb_base_arg: u64) linksection(".text.main") noreturn {
    _ = hart_id;
    dtb_base = dtb_base_arg;
    sabaton.fw_cfg.init_from_dtb();
    @call(.{ .modifier = .always_inline }, sabaton.main, .{});
}

pub fn map_platform(root: *sabaton.paging.Root) void {
    sabaton.paging.map(0, 0, 0x3000_0000, .rw, .mmio, root);
    sabaton.paging.map(sabaton.upper_half_phys_base, 0, 0x3000_0000, .rw, .mmio, root);
    sabaton.pci.init_from_dtb(root);
}