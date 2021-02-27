const sabaton = @import("root").sabaton;
const std = @import("std");

fn combine(a: u8, b: u8, c: u8, d: u8) u32 {
  return 0
    | (@as(u32, a) << 0)
    | (@as(u32, b) << 8)
    | (@as(u32, c) << 16)
    | (@as(u32, d) << 24)
  ;
}

pub fn init() bool {
  if(sabaton.fw_cfg.find_file("etc/ramfb")) |ramfb| {
    const framebuffer = @ptrToInt(sabaton.pmm.alloc_aligned(sabaton.fb_bytes, .Hole).ptr);

    sabaton.log_hex("File has selector ", ramfb.select);

    var cfg: packed struct {
      addr: u64 = undefined,
      fourcc: u32 = std.mem.nativeToBig(u32, combine('X', 'R', '2', '4')),
      flags: u32 = std.mem.nativeToBig(u32, 0),
      width: u32 = std.mem.nativeToBig(u32, sabaton.fb_width),
      height: u32 = std.mem.nativeToBig(u32, sabaton.fb_height),
      stride: u32 = std.mem.nativeToBig(u32, sabaton.fb_pitch),
    } = .{};

    if(sabaton.safety) {
      if(ramfb.size != @sizeOf(@TypeOf(cfg))) {
        sabaton.log_hex("Bad ramfb file size: ", ramfb.size);
        unreachable;
      }
    }

    cfg.addr = std.mem.nativeToBig(u64, framebuffer);

    var cfg_bytes = @intToPtr([*]u8, @ptrToInt(&cfg))[0..@sizeOf(@TypeOf(cfg))];
    ramfb.write(cfg_bytes);
    cfg.addr = 0;
    ramfb.read(cfg_bytes);

    const resaddr = std.mem.bigToNative(u64, cfg.addr);

    if(sabaton.safety) {
      if(resaddr != framebuffer) {
        sabaton.log_hex("ramfb: Unable to set framebuffer: ", resaddr);
        return false;
      }
    }

    sabaton.add_framebuffer(framebuffer);

    return true;
  }

  return false;
}
