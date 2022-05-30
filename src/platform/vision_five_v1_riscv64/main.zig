pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.status_uart_mmio_32;
//pub const panic = sabaton.panic;

const uart_regs = @intToPtr([*]volatile u32, 0x12440000);

const uart_clock = 100000000;

pub fn get_uart_info() io.Info {
    return .{
        .uart = &uart_regs[0],
        .status = &uart_regs[5],
        .mask = 0x20,
        .value = 0x20,
    };
}

export fn _start() linksection(".text.entry") void {
    sabaton.print_str("Hello, world!\n");
}
