const sabaton = @import("root").sabaton;

pub fn write_reg(char: u8, reg: *volatile u32) void {
  reg.* = @as(u32, char);
}

pub fn putchar(char: u8) void {
  const addr = sabaton.near("uart_reg").read(*volatile u32);
  if(char == '\n')
    write_reg('\r', addr);
  write_reg(char, addr);
}
