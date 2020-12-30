const sabaton = @import("root").sabaton;
const std = @import("std");

var data: []u8 = undefined;

const BE = sabaton.util.BigEndian;

const Header = packed struct {
  magic: BE(u32),
  totalsize: BE(u32),
  off_dt_struct: BE(u32),
  off_dt_strings: BE(u32),
  off_mem_rsvmap: BE(u32),
  version: BE(u32),
  last_comp_version: BE(u32),
  boot_cpuid_phys: BE(u32),
  size_dt_strings: BE(u32),
  size_dt_struct: BE(u32),
};

pub fn find(comptime node_prefix: []const u8, comptime prop_name: []const u8) ![]u8 {
  const dtb = sabaton.platform.get_dtb();

  const header = @ptrCast(*Header, dtb.ptr);

  std.debug.assert(header.magic.read() == 0xD00DFEED);
  std.debug.assert(header.totalsize.read() == dtb.len);

  var curr = @ptrCast([*]BE(u32), dtb.ptr + header.off_dt_struct.read());

  var current_depth: usize = 0;
  var found_at_depth: ?usize = null;

  while(true) {
    const opcode = curr[0].read();
    curr += 1;
    switch(opcode) {
      0x00000001 => { // FDT_BEGIN_NODE
        const name = @ptrCast([*:0]u8, curr);
        const namelen = sabaton.util.strlen(name);

        if(sabaton.debug)
          sabaton.log("FDT_BEGIN_NODE(\"{}\", {})\n", .{name[0..namelen], namelen});

        current_depth += 1;
        if(found_at_depth == null and namelen >= node_prefix.len) {
          if(std.mem.eql(u8, name[0..node_prefix.len], node_prefix)) {
            found_at_depth = current_depth;
          }
        }

        curr += (namelen + 4) / 4;
      },
      0x00000002 => { // FDT_END_NODE
        if(sabaton.debug)
          sabaton.log("FDT_END_NODE\n", .{});
        if(found_at_depth) |d| {
          if(d == current_depth) {
            found_at_depth = null;
          }
        }
        current_depth -= 1;
      },
      0x00000003 => { // FDT_PROP
        const nameoff = curr[1].read();
        var len = curr[0].read();

        const name = @ptrCast([*:0]u8, dtb.ptr + header.off_dt_strings.read() + nameoff);
        if(sabaton.debug)
          sabaton.log("FDT_PROP(\"{}\"), len 0x{X}\n", .{name, len});

        if(found_at_depth) |d| {
          if(d == current_depth) {
            // DID WE FIND IT??
            if(std.mem.eql(u8, name[0..prop_name.len], prop_name) and name[prop_name.len] == 0)
              return @ptrCast([*]u8, curr + 2)[0..len];
          }
        }

        len += 3;
        curr += len / 4 + 2;
      },
      0x00000004 => { }, // FDT_NOP
      0x00000009 => break, // FDT_END
      else => {
        if(sabaton.safety) {
          sabaton.log_hex("Unknown DTB opcode: ", opcode);
        }
        unreachable;
      }
    }
  }

  return error.NotFound;
}
