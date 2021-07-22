const sabaton = @import("root").sabaton;
const std = @import("std");

pub const SMPTagHeader = struct {
  tag: sabaton.Stivale2tag,
  flags: u64,
  boot_cpu: u32,
  pad: u32,
  cpu_count: u64,
};

pub const SMPTagEntry = struct {
  acpi_id: u32,
  cpu_id: u32,
  stack: u64,
  goto: u64,
  arg: u64,
};

comptime {
  std.debug.assert(@sizeOf(sabaton.stivale.SMPTagEntry) == 32);
}
