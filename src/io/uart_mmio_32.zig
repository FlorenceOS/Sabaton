const sabaton = @import("root").sabaton;

pub fn write_reg(char: u8, reg: *volatile u32) void {
    reg.* = @as(u32, char);
}

extern const uart_reg: *volatile u32;

pub fn putchar(char: u8) void {
    if (char == '\n')
        write_reg('\r', uart_reg);
    write_reg(char, uart_reg);
}
