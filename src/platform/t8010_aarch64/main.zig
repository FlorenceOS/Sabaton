usingnamespace @import("../fruity/fruity.zig");

comptime {
  asm(
    \\.section .data
    \\uart_tag:
    \\  .8byte 0xf77485dbfeb260f9 // u32 MMIO UART with status
    \\  .8byte 0
    \\uart_reg:
    \\  .8byte __uart_base + 0x20
    \\uart_status:
    \\  .8byte __uart_base + 0x10
    \\uart_status_mask:
    \\  .4byte 0x00000004
    \\uart_status_value:
    \\  .4byte 0x00000004
  );
}

// We know the page size is 0x4000
pub fn get_page_size() u64 {
  return 0x4000;
}

pub fn get_sram() []u8 {
  // 0x200000 bytes of sram at 0x180000000
  return @intToPtr([*]u8, 0x180000000)[0..0x200000];
}

pub fn get_dram() []u8 {
  // 2G of dram at 0x800000000
  return @intToPtr([*]u8, 0x800000000)[0..(2 * 1024 * 1024 * 1024)];
}

pub fn get_uart_info() io.Info {
  const base = 0x20A0C0000;
  return .{
    .uart = @intToPtr(*volatile u32, base + 0x20),
    .status = @intToPtr(*volatile u32, base + 0x10),
    .mask = 0x00000004,
    .value = 0x00000004,
  };
}
