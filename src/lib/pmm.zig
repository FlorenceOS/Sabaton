comptime {
  asm(
    \\.extern __pmm_base
    \\.extern __dram_base
    \\
    \\.global dram_base
    \\.global memmap_tag
    \\
    \\ memmap_tag:
    \\   .8byte 0x2187F79E8612DE07
    \\   .8byte 0 // Next ptr
    \\   .8byte 4 // Entries
    \\
    \\ // Prekernel reclaimable
    \\ dram_base:
    \\   .8byte __dram_base
    \\ prekernel_size:
    \\   .8byte 0
    \\   .8byte 0x1000 // Reclaimable
    \\
    \\ // Kernel and module pages
    \\ stivalehdr_pages_base:
    \\   .8byte 0
    \\ stivalehdr_pages_size:
    \\   .8byte 0
    \\   .8byte 0x1001 // Kernel and modules
    \\
    \\ // Page tables
    \\ pt_base:
    \\   .8byte 0
    \\ pt_size:
    \\   .8byte 0
    \\   .8byte 0x1000 // Reclaimable, will be 0x070c8a122cc97b24 if Sabaton tag is present in kernel
    \\
    \\ // Usable region
    \\ pmm_head:
    \\   .8byte __pmm_base
    \\ usable_size:
    \\   .8byte 0
    \\   .8byte 1 // Usable
  );
}

const sabaton = @import("root").sabaton;
const std = @import("std");

const pmm_state = enum {
  Prekernel = 0,
  KernelPages,
  PageTables,
  Sealed,
};

var current_state: pmm_state = .Prekernel;

pub fn verify_transition(s: pmm_state) void {
  if(current_state == .Sealed or (@enumToInt(current_state) + 1 != @enumToInt(s))) {
    sabaton.log("Unexpected pmm sate: .{} while in state .{}\n", .{@tagName(s), @tagName(current_state)});
    unreachable;
  }
}

pub fn switch_state(new_state: pmm_state) void {
  verify_transition(new_state);

  // Transition out of current state and apply changes
  const page_size = sabaton.near("page_size").read(u64);

  // Page align the addresses and sizes
  var current_base = sabaton.near("pmm_head").read(u64);
  current_base += page_size - 1;
  current_base &= ~(page_size - 1);

  const eff_idx = @as(usize, @enumToInt(current_state)) * 3;
  const current_entry = sabaton.near("dram_base").addr(u64);

  // Size = head - base
  current_entry[eff_idx + 1] = current_base - current_entry[eff_idx + 0];
  // next_base = head
  current_entry[eff_idx + 3] = current_base;

  current_state = new_state;
}

const purpose = enum {
  ReclaimableData,
  KernelPage,
  PageTable,
};

fn verify_purpose(p: purpose) void {
  if(switch(current_state) {
    // When we're doing page tables, only allow that
    .PageTables => p != .PageTable,

    // When loading the kernel, only allow it
    .KernelPages => p != .KernelPage,

    // Before and after kernel loading we can do normal allocations
    .Prekernel => p != .ReclaimableData,

    // When we're sealed we don't want to allocate anything anymore
    .Sealed => true,
  }) {
    sabaton.log("Allocation purpose .{} not valid in state .{}!", .{@tagName(p), @tagName(current_state)});
    unreachable;
  }
}

fn alloc_impl(num_bytes: u64, aligned: bool, p: purpose) []u8 {
  var current_base = sabaton.near("pmm_head").read(u64);

  verify_purpose(p);

  if(aligned) {
    const page_size = sabaton.near("page_size").read(u64);

    current_base += page_size - 1;
    current_base &= ~(page_size - 1);
  }

  sabaton.near("pmm_head").write(current_base + num_bytes);
  const ptr = @intToPtr([*]u8, current_base);
  @memset(ptr, 0, num_bytes);
  return ptr[0..num_bytes];
}

pub fn alloc(num_bytes: u64, p: purpose) []u8 {
  return alloc_impl(num_bytes, false, p);
}

pub fn alloc_aligned(num_bytes: u64, p: purpose) []align(0x1000) u8 {
  return @alignCast(0x1000, alloc_impl(num_bytes, true, p));
}

pub fn write_dram_size(dram_len: u64) void {
  if(current_state != .Sealed) {
    sabaton.log("Unexpected pmm sate: .{} while writing dram size\n", .{@tagName(current_state)});
    unreachable;
  }

  const dram_base = sabaton.near("dram_base").read(u64);
  const current_head = sabaton.near("pmm_head").read(u64);
  sabaton.near("usable_size").write(dram_base + dram_len - current_head);
}