pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.uart_mmio_32;
pub const ElfType = [*]u8;
pub const panic = sabaton.panic;

const std = @import("std");

var page_size: u64 = 0x1000;

pub fn get_page_size() u64 {
  return page_size;
}

export fn _main() noreturn {
  page_size = sabaton.paging.detect_page_size();
  @call(.{.modifier = .always_inline}, sabaton.main, .{});
}

pub fn get_kernel() [*]u8 {
  return sabaton.near("kernel_file_loc").read([*]u8);
}

pub fn get_dtb() []u8 {
  return sabaton.near("dram_base").read([*]u8)[0..0x100000];
}

pub fn get_dram() []u8 {
  return sabaton.near("dram_base").read([*]u8)[0..get_dram_size()];
}

pub fn map_platform(root: *sabaton.paging.Root) void {
  const uart_base = sabaton.near("uart_reg").read(u64);
  sabaton.paging.map(uart_base, uart_base, 0x1000, .rw, .mmio, root, .CannotOverlap);

  const kernel_elf_base = sabaton.near("kernel_file_loc").read(u64);
  sabaton.paging.map(kernel_elf_base, kernel_elf_base, kernel_elf_base, .r, .memory, root, .CannotOverlap);

  const blob_base = @ptrToInt(sabaton.near("__blob_base").addr(u8));
  const blob_end  = @ptrToInt(sabaton.near("__blob_end").addr(u8));
  sabaton.paging.map(blob_base, blob_base, blob_end - blob_base, .rwx, .memory, root, .CannotOverlap);
}

// Dram size varies as you can set different amounts of RAM for your VM
fn get_dram_size() u64 {
  const memory_blob = sabaton.vital(sabaton.dtb.find("memory", "reg"), "Cannot find memory in dtb", false);
  const base = std.mem.readIntBig(u64, memory_blob[0..8]);
  const size = std.mem.readIntBig(u64, memory_blob[8..16]);

  if(sabaton.safety and base != sabaton.near("dram_base").read(u64)) {
    sabaton.log_hex("dtb has wrong memory base: ", base);
    unreachable;
  }

  return size;
}

pub fn add_platform_tags(kernel_header: *sabaton.Stivale2hdr) void {
  sabaton.add_tag(&sabaton.near("uart_tag").addr(sabaton.Stivale2tag)[0]);
  sabaton.add_tag(&sabaton.near("devicetree_tag").addr(sabaton.Stivale2tag)[0]);
}
