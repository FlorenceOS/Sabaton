pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.status_uart_mmio_32;
pub const ElfType = [*]u8;
pub const panic = sabaton.panic;

const std = @import("std");

export fn _main() noreturn {
  // const root_tbl = @ptrCast([*]u64, sabaton.pmm.alloc_aligned(sabaton.get_page_size(), .ReclaimableData).ptr);
  // @memset(@ptrCast([*]u8, root_tbl), 0, 0x4000);
  // var root: sabaton.paging.Root = .{
  //   .ttbr0 = root_tbl,
  //   .ttbr1 = root_tbl,
  // };

  // const sram = @import("root").get_sram();
  // const sram_base = @ptrToInt(sram.ptr);

  // const dram = @import("root").get_dram();
  // const dram_base = @ptrToInt(dram.ptr);

  // // Map SRAM region
  // sabaton.paging.map(sram_base, sram_base, sram.len, .rwx, .memory, &root);
  // // Map MMIO region
  // sabaton.paging.map(0, 0, sram_base, .rw, .mmio, &root);
  // // Map DRAM region
  // sabaton.paging.map(dram_base, dram_base, dram.len, .rwx, .memory, &root);

  // sabaton.paging.apply_paging(&root);
  const uart_base = sabaton.near("uart_reg").read(u64) & ~(sabaton.get_page_size() - 1);

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
    \\
    \\  1:
    \\    DSB ST
    \\    MOV W1, 0x21
    \\    STR W1, [%[uart_base], #0x20]
    \\    B 1b
    :
    : [uart_base] "r" (uart_base)
    : "X1", "memory"
  );

  while(true)
    sabaton.puts("Hello world!\n");
  //sabaton.paging.detect_page_size();
  //@call(.{.modifier = .always_inline}, sabaton.main, .{});
}
