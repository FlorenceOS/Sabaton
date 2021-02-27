const sabaton = @import("root").sabaton;
const std = @import("std");

var base: ?u64 = null;

const File = packed struct {
  size: u32,
  select: u16,
  reserved: u16,
  name: [56]u8,

  pub fn write(self: *const @This(), buffer: []const u8) void {
    const dma_addr = @intToPtr(*volatile u64, base.? + 16);
    do_dma(@intToPtr([*]u8, @ptrToInt(buffer.ptr))[0..buffer.len], (1 << 4) | (1 << 3) | (@as(u32, self.select) << 16), dma_addr);
  }

  pub fn read(self: *const @This(), buffer: []u8) void {
    const dma_addr = @intToPtr(*volatile u64, base.? + 16);
    do_dma(buffer, (1 << 1) | (1 << 3) | (@as(u32, self.select) << 16), dma_addr);
  }
};

pub fn init_from_dtb() void {
  const fw_cfg = sabaton.dtb.find("fw-cfg@", "reg") catch return;

  base = std.mem.readIntBig(u64, fw_cfg[0..][0..8]);

  if(sabaton.debug)
    sabaton.log_hex("fw_cfg base: ", base.?);

  const data = @intToPtr(*volatile u64, base.?);
  const selector = @intToPtr(*volatile u16, base.? + 8);
  const dma_addr = @intToPtr(*volatile u64, base.? + 16);

  if(sabaton.safety) {
    selector.* = std.mem.nativeToBig(u16, 0);
    std.debug.assert(@truncate(u32, data.*) == 0x554D4551); // 'QEMU'

    selector.* = std.mem.nativeToBig(u16, 1);
    std.debug.assert(@truncate(u32, data.*) & 2 != 0); // DMA bit
    std.debug.assert(std.mem.bigToNative(u64, dma_addr.*) == 0x51454d5520434647);
  }
}

const DMAAccess = packed struct {
  control: u32,
  length: u32,
  addr: u64,
};

pub fn do_dma(buffer: []u8, control: u32, dma_addr: *volatile u64) void {
  var access_bytes: [@sizeOf(DMAAccess)]u8 = undefined;
  var access = @ptrCast(*volatile DMAAccess, &access_bytes[0]);
  access.* = .{
    .control = std.mem.nativeToBig(u32, control),
    .length = std.mem.nativeToBig(u32, @intCast(u32, buffer.len)),
    .addr = std.mem.nativeToBig(u64, @ptrToInt(buffer.ptr)),
  };
  dma_addr.* = std.mem.nativeToBig(u64, @ptrToInt(access));
  asm volatile("":::"memory");
  if(sabaton.safety) {
    while(true) {
      const ctrl = std.mem.bigToNative(u32, access.control);
      if(ctrl & 1 != 0)
        @panic("fw_cfg dma error!");
      if(ctrl == 0)
        return;

      sabaton.puts("Still waiting...\n");
    }
  }
}

pub fn find_file(filename: []const u8) ?File {
  if(base) |b| {
    const dma_addr = @intToPtr(*volatile u64, b + 16);

    // Get number of files
    var num_files: u32 = undefined;
    do_dma(@ptrCast([*]u8, &num_files)[0..4], (1 << 1) | (1 << 3) | (0x0019 << 16), dma_addr);
    num_files = std.mem.bigToNative(u32, num_files);

    var current_file: u32 = 0;
    while(current_file < num_files) : (current_file += 1) {
      // Get a file at a time
      var f: File = undefined;
      do_dma(@ptrCast([*]u8, &f)[0..@sizeOf(File)], (1 << 1), dma_addr);
      f.size = std.mem.bigToNative(u32, f.size);
      f.select = std.mem.bigToNative(u16, f.select);

      if(std.mem.eql(u8, filename, f.name[0..filename.len]) and f.name[filename.len] == 0) {
        return f;
      }
    }
  }

  return null;
}
