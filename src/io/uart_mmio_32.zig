const sabaton = @import("root").sabaton;

pub fn write_uart_reg(char: u8) void {
  sabaton.near("uart_reg").read(*volatile u32).* = @as(u32, char);
}

pub fn putchar(char: u8) void {
  if(char == '\n')
    putchar('\r');
  write_uart_reg(char);
}
