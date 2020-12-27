pub const platform = @import("root");
pub const io_impl = @import("io/io.zig");
pub const util = @import("lib/util.zig");
pub const dtb = @import("lib/dtb.zig");
pub const pmm = @import("lib/pmm.zig");
pub const paging = @import("platform/paging.zig");

pub const log = io_impl.log;
pub const near = util.near;
pub const vital = util.vital;
pub const io = platform.io;

pub const debug = @import("builtin").mode == .Debug;

const std = @import("std");

pub fn panic(reason: []const u8, stacktrace: ?*std.builtin.StackTrace) noreturn {
  log("PANIC!\n", .{});
  if(reason.len != 0) {
    log("Reason: {}!\n", .{reason});
  }

  if(stacktrace) |t| {
    log("Trace:\n", .{});
    for(t.instruction_addresses[t.index..]) |addr| {
      log("  0x{X}\n", .{addr});
    }
  } else {
    log("No trace.\n", .{});
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

extern fn enter_kernel(info: *const InfoStruct, entry: u64, stack: u64) noreturn;

comptime {
  asm(
    \\.section .text.enter_kernel
    \\enter_kernel:
    \\  CBZ X2, 1f
    \\  MOV SP, X2
    \\1:BR X1
  );
}

pub fn main() noreturn {
  const dram = platform.get_dram();

  var kernel_elf = Elf {
    .data = platform.get_kernel(),
  };

  kernel_elf.init();

  var kernel_header: Stivale2hdr = undefined;
  _ = vital(
    kernel_elf.load_section(".stivale2hdr", util.to_byte_slice(&kernel_header)),
    "loading .stivale2hdr", true,
  );

  platform.add_platform_tags(&kernel_header);

  // Allocate space for backing pages of the kernel
  pmm.switch_state(.KernelPages);
  const kernel_memory_pool = pmm.alloc_aligned(kernel_elf.paged_bytes(), .KernelPage);

  // TODO: Allocate and put modules here

  pmm.switch_state(.PageTables);
  var root = paging.init_paging();
  platform.map_platform(&root);
  {
    const dram_base = @ptrToInt(dram.ptr);
    sabaton.paging.map(dram_base, dram_base, dram.len, .rw, .memory, &root, .CanOverlap);
  }
  paging.apply_paging(&root);
  // Check the flags in the stivale2 header
  kernel_elf.load(kernel_memory_pool);

  if(sabaton.debug)
    sabaton.log("Sealing PMM\n", .{});

  pmm.switch_state(.Sealed);

  if(sabaton.debug)
    sabaton.log("Writing DRAM size: 0x{X}\n", .{dram.len});

  pmm.write_dram_size(dram.len);

  add_tag(&near("memmap_tag").addr(Stivale2tag)[0]);

  var kernel_entry: u64 = kernel_elf.entry();
  var kernel_stack: u64 = kernel_header.stack;

  if(sabaton.debug)
    sabaton.log("Entering kernel...\n", .{});

  enter_kernel(&stivale2_info, kernel_entry, kernel_stack);
}
