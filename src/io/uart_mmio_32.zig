const sabaton = @import("root").sabaton;

pub fn write_reg(char: u8, reg: *volatile u32) void {
    reg.* = @as(u32, char);
}

pub fn putchar(char: u8) void {
    const uart_info: Info = sabaton.platform.get_uart_info();

    if (char == '\n')
        write_reg('\r', uart_info.uart);
    write_reg(char, uart_info.uart);
}

pub const Info = struct {
    uart: *volatile u32,
};
