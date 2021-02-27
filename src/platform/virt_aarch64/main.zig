pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.uart_mmio_32;
pub const ElfType = [*]u8;
pub const panic = sabaton.panic;

pub const display = struct {
  fn try_find(comptime f: anytype, comptime name: []const u8) bool {
    const retval = f();
    if(retval) {
      sabaton.puts("Found " ++ name ++ "!\n");
    } else {
      sabaton.puts("Couldn't find " ++ name ++ "\n");
    }
    return retval;
  }

  pub fn init() void {
    // First, try to find a ramfb
    if(try_find(sabaton.ramfb.init, "ramfb"))
      return;

    sabaton.puts("Kernel requested framebuffer but we could not provide one!\n");
  }
};

const std = @import("std");

var page_size: u64 = 0x1000;

pub fn get_page_size() u64 {
  return page_size;
}

export fn _main() linksection(".text.main") noreturn {
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
  sabaton.paging.map(0, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
  sabaton.paging.map(sabaton.upper_half_phys_base, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
  sabaton.pci.init_from_dtb(root);
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
