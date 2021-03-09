pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.status_uart_mmio_32;
pub const ElfType = [*]u8;
pub const panic = sabaton.panic;

pub const display = @import("display.zig");
pub const smp = @import("smp.zig");
pub const timer = @import("timer.zig");

// We know the page size is 0x1000
pub fn get_page_size() u64 {
  return 0x1000;
}

export fn _main() linksection(".text.main") noreturn {
  @call(.{.modifier = .always_inline}, sabaton.main, .{});
}

pub fn get_kernel() ElfType {
  return sabaton.near("kernel_file_loc").read([*]u8);
}

// pub fn get_dtb() []u8 {
//   return sabaton.near("dram_base").read([*]u8)[0..0x100000];
// }

pub fn get_dram() []u8 {
  return sabaton.near("dram_base").read([*]u8)[0..get_dram_size()];
}

fn get_dram_size() u64 {
  return 0x80000000;
}

pub fn map_platform(root: *sabaton.paging.Root) void {
  // MMIO area
  sabaton.paging.map(0, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
  sabaton.paging.map(sabaton.upper_half_phys_base, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
}

pub fn add_platform_tags(kernel_header: *sabaton.Stivale2hdr) void {
  sabaton.add_tag(&sabaton.near("uart_tag").addr(sabaton.Stivale2tag)[0]);
  sabaton.add_tag(&sabaton.near("devicetree_tag").addr(sabaton.Stivale2tag)[0]);
}

pub fn get_uart_info() io.Info {
  const base = 0x1C28000;
  return .{
    .uart = @intToPtr(*volatile u32, base),
    .status = @intToPtr(*volatile u32, base + 0x14),
    .mask = 0x20,
    .value = 0x20,
  };
}
