const sabaton = @import("root").sabaton;
const std = @import("std");

pub fn upper_half(vaddr: u64) bool {
  return vaddr >= 0x8000000000000000;
}

pub fn BigEndian(comptime T: type) type {
  return packed struct {
    val: T,

    pub fn read(self: *@This()) T {
      return std.mem.readIntBig(T, @ptrCast([*]u8, &self.val)[0..4]);
    }
  };
}

pub fn vital(val: anytype, comptime context: []const u8, comptime reachable: bool) @TypeOf(val catch unreachable) {
  return val catch |err| {
    if(reachable) {
      @call(.{.modifier = .never_inline}, sabaton.puts, .{"Fatal error: "});
      @call(.{.modifier = .never_inline}, sabaton.print_str, .{@errorName(err)});
      @call(.{.modifier = .never_inline}, sabaton.puts, .{" while " ++ context});
      @panic("");
    }
    unreachable;
  };
}

pub fn strlen(str: [*:0]u8) usize {
  var len: usize = 0;
  while(str[len] != 0)
    len += 1;
  return len;
}

pub fn near(comptime name: []const u8) type {
  return struct {
    pub fn read(comptime t: type) t {
      return asm(
        "LDR %[out], " ++ name ++ "\n\t"
        : [out] "=r" (-> t)
      );
    }

    pub fn addr(comptime t: type) [*]t {
      return asm(
        "ADR %[out], " ++ name ++ "\n\t"
        : [out] "=r" (-> [*]t)
      );
    }

    pub fn write(val: anytype) void {
      addr(@TypeOf(val))[0] = val;
    }

    pub fn read_volatile(comptime t: type) t {
      return asm volatile(
        "LDR %[out], " ++ name ++ "\n\t"
        : [out] "=r" (-> t)
        :
        : "memory"
      );
    }

    pub fn volatile_addr(comptime t: type) [*]volatile t {
      return asm(
        "ADR %[out], " ++ name ++ "\n\t"
        : [out] "=r" (-> [*]volatile t)
      );
    }

    pub fn write_volatile(val: anytype) void {
      volatile_addr(@TypeOf(val))[0] = val;
    }
  };
}

pub fn to_byte_slice(val: anytype) []u8 {
  return @ptrCast([*]u8, val)[0..@sizeOf(@TypeOf(val.*))];
}
