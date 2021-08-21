const sabaton = @import("root").sabaton;

fn putchar_impl(
    char: u8,
    uart_reg: *volatile u32,
    status_reg: *volatile u32,
    mask: u32,
    value: u32,
) void {
    if (char == '\n')
        putchar_impl('\r', uart_reg, status_reg, mask, value);

    // Wait until output is ready
    while ((status_reg.* & mask) != value) {}

    sabaton.io_impl.uart_mmio_32.write_reg(char, uart_reg);
}

pub fn putchar(char: u8) void {
    const uart_info: Info = sabaton.platform.get_uart_info();

    putchar_impl(char, uart_info.uart, uart_info.status, uart_info.mask, uart_info.value);
}

pub const Info = struct {
    uart: *volatile u32,
    status: *volatile u32,
    mask: u32,
    value: u32,
};
