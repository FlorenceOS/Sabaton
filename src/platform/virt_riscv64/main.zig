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

export fn _main(hart_id: u64, dtb_base_arg: u64) linksection(".text.main") noreturn {
    _ = hart_id;
    dtb_base = dtb_base_arg;
    sabaton.fw_cfg.init_from_dtb();
    @call(.{ .modifier = .always_inline }, sabaton.main, .{});
}
