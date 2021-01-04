pub const platform = @import("root");
pub const io_impl = @import("io/io.zig");
pub const util = @import("lib/util.zig");
pub const dtb = @import("lib/dtb.zig");
pub const pmm = @import("lib/pmm.zig");
pub const paging = @import("platform/paging.zig");

pub const puts = io_impl.puts;
pub const log_hex = io_impl.log_hex;
pub const print_hex = io_impl.print_hex;
pub const print_str = io_impl.print_str;
pub const log = io_impl.log;
pub const putchar = io_impl.putchar;
pub const near = util.near;
pub const vital = util.vital;
pub const io = platform.io;

pub const debug = @import("builtin").mode == .Debug;
pub const safety = std.debug.runtime_safety;

const std = @import("std");

pub fn panic(reason: []const u8, stacktrace: ?*std.builtin.StackTrace) noreturn {
  @call(.{.modifier = .never_inline}, puts, .{"PANIC!"});
  if(reason.len != 0) {
    @call(.{.modifier = .never_inline}, puts, .{" Reason:"});
    @call(.{.modifier = .never_inline}, print_str, .{reason});
  }

  if(sabaton.debug) {
    if(stacktrace) |t| {
      log("\nTrace:\n", .{});
      for(t.instruction_addresses) |addr| {
        log("  0x{X}\n", .{addr});
      }
    } else {
      log("\nNo trace.\n", .{});
    }
  }

  asm volatile(
    \\  // Disable interrupts
    \\  MSR DAIFSET, 0xF
    \\
    \\  // Hang
    \\1:WFI
    \\  B 1b
  );
  unreachable;
}

const Elf = @import("lib/elf.zig").Elf;
const sabaton = @This();

pub const Stivale2tag = struct {
  ident: u64,
  next: ?*@This(),
};

const InfoStruct = struct {
  brand: [64]u8 = pad_str("Sabaton", 64),
  version: [64]u8 = pad_str("Forged in Valhalla by the hammer of Thor", 64),
  tags: ?*Stivale2tag = null,
};

pub const Stivale2hdr = struct {
  entry_point: u64,
  stack: u64,
  flags: u64,
  tags: ?*Stivale2tag,
};

fn pad_str(str: []const u8, comptime len: usize) [len]u8 {
  var ret = [1]u8{0} ** len;
  @memcpy(@ptrCast([*]u8, &ret[0]), str.ptr, str.len);
  return ret;
}

var stivale2_info: InfoStruct = .{ };

pub fn add_tag(tag: *Stivale2tag) void {
  tag.next = stivale2_info.tags;
  stivale2_info.tags = tag;
}

pub fn main() noreturn {
  const dram = @call(.{.modifier = .always_inline}, platform.get_dram, .{});

  var kernel_elf = Elf {
    .data = @call(.{.modifier = .always_inline}, platform.get_kernel, .{}),
  };

  @call(.{.modifier = .always_inline}, kernel_elf.init, .{});

  var kernel_header: Stivale2hdr = undefined;
  _ = vital(
    kernel_elf.load_section(".stivale2hdr", util.to_byte_slice(&kernel_header)),
    "loading .stivale2hdr", true,
  );

  @call(.{.modifier = .always_inline}, platform.add_platform_tags, .{&kernel_header});

  // Allocate space for backing pages of the kernel
  pmm.switch_state(.KernelPages);
  const kernel_memory_pool = pmm.alloc_aligned(kernel_elf.paged_bytes(), .KernelPage);

  // TODO: Allocate and put modules here

  pmm.switch_state(.PageTables);
  var root = @call(.{.modifier = .always_inline}, paging.init_paging, .{});
  @call(.{.modifier = .always_inline}, platform.map_platform, .{&root});
  {
    const dram_base = @ptrToInt(dram.ptr);
    sabaton.paging.map(dram_base, dram_base, dram.len, .rw, .memory, &root, .CanOverlap);
  }
  @call(.{.modifier = .always_inline}, paging.apply_paging, .{&root});
  // Check the flags in the stivale2 header
  @call(.{.modifier = .always_inline}, kernel_elf.load, .{kernel_memory_pool});

  if(sabaton.debug)
    sabaton.log("Sealing PMM\n", .{});

  pmm.switch_state(.Sealed);

  if(sabaton.debug)
    sabaton.log("Writing DRAM size: 0x{X}\n", .{dram.len});

  pmm.write_dram_size(dram.len);

  add_tag(&near("memmap_tag").addr(Stivale2tag)[0]);

  if(sabaton.debug)
    sabaton.log("Entering kernel...\n", .{});

  asm volatile(
    \\  CBZ %[stack], 1f
    \\  MOV SP, %[stack]
    \\1:BR %[entry]
    :
    : [entry] "r" (kernel_elf.entry())
    , [stack] "r" (kernel_header.stack)
    , [info] "{X0}" (&stivale2_info)
  );
  unreachable;
}
