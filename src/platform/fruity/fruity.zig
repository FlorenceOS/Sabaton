pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.status_uart_mmio_32;
pub const ElfType = [*]u8;
pub const panic = sabaton.panic;

const std = @import("std");

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

export fn _main() void {
  const root_tbl = @ptrCast([*]u64, sabaton.pmm.alloc_aligned(get_page_size(), .ReclaimableData).ptr);
  @memset(@ptrCast([*]u8, root_tbl), 0, 0x4000);
  var root: sabaton.paging.Root = .{
    .ttbr0 = root_tbl,
    .ttbr1 = root_tbl,
  };
  sabaton.paging.map(0x180000000, 0x180000000, 0x180100000 - 0x180000000, .rwx, .memory, &root, .CanOverlap);
  sabaton.paging.apply_paging(&root);
  const uart_base = sabaton.near("uart_reg").read(u64) & ~(get_page_size() - 1);
  sabaton.paging.map(uart_base, uart_base, get_page_size(), .rw, .mmio, &root, .CannotOverlap);

  // Init uart
  asm volatile(
    \\uart_init:
    \\  // rULCON0
    \\  MOV W1, 0x00000003 // 8 data bits, no parity, no stop bit
    \\  STR W1, [%[uart_base], #0x00]
    \\
    \\  // rUCON0
    \\  MOV W1, 0x00000005 | (1 << 10) // int/poll mode, no interrupts enabled, NCLK
    \\  STR W1, [%[uart_base], #0x04]
    \\
    \\  // rUFCON0
    \\  MOV W1, 0x00000000 // Disable fifos
    \\  STR W1, [%[uart_base], #0x08]
    \\
    \\  // rUMCON0
    \\  MOV W1, 0x00000000 // No flow control
    \\  STR W1, [%[uart_base], #0x0C]
    \\
    \\  // rUBRDIV0
    \\  MOV W1, 0x0000000C
    \\  STR W1, [%[uart_base], #0x28]
    :
    : [uart_base] "r" (uart_base)
    : "X1", "memory"
  );

  sabaton.puts("Hello world!\n");
  //sabaton.paging.detect_page_size();
  //@call(.{.modifier = .always_inline}, sabaton.main, .{});
}
