const sabaton = @import("root").sabaton;

fn putchar_impl(
  char: u8,
  uart_reg: *volatile u32,
  status_reg: *volatile u32,
  mask: u32,
  value: u32
) void {
  if(char == '\n')
    putchar_impl('\r', uart_reg, status_reg, mask, value);

  // Wait until output is ready
  while((status_reg.* & mask) != value) { }

  sabaton.io_impl.uart_mmio_32.write_reg(char, uart_reg);
}

pub fn putchar(char: u8) void {
  const uart_tag = @ptrToInt(sabaton.near("uart_tag").addr(u8));
  
  const uart_reg = @intToPtr(**volatile u32, uart_tag + 0x10).*;
  const status_reg = @intToPtr(**volatile u32, uart_tag + 0x18).*;

  const mask = @intToPtr(*u32, uart_tag + 0x20).*;
  const value = @intToPtr(*u32, uart_tag + 0x24).*;

  putchar_impl(char, uart_reg, status_reg, mask, value);
}
