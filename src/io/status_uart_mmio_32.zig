const sabaton = @import("root").sabaton;

fn await_write() void {
  const status_reg = sabaton.near("uart_status").read(*volatile u32);
  const mask = sabaton.near("uart_status_mask").read(u32);
  const value = sabaton.near("uart_status_value").read(u32);

  while((status_reg.* & mask) != value) { }
}

pub fn putchar(char: u8) void {
  if(char == '\n')
    putchar('\r');
    
  await_write();
  sabaton.io_impl.uart_mmio_32.write_uart_reg(char);
}
