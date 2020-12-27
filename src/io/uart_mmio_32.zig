const sabaton = @import("root").sabaton;

pub fn putchar(char: u8) void {
  const uart_addr = sabaton.near("uart_reg").read(u64);
  @intToPtr(*volatile u32, uart_addr).* = @as(u32, char);
}
