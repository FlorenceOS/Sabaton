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
        if (reachable) {
            sabaton.puts("Fatal error: ");
            sabaton.print_str(@errorName(err));
            sabaton.puts(" while " ++ context);
            @panic("");
        }
        unreachable;
    };
}

pub fn strlen(str: [*:0]u8) usize {
    var len: usize = 0;
    while (str[len] != 0)
        len += 1;
    return len;
}

pub fn near(comptime name: []const u8) type {
    return struct {
        pub fn read(comptime t: type) t {
            return asm ("LDR %[out], " ++ name ++ "\n\t"
                : [out] "=r" (-> t)
            );
        }

        pub fn addr(comptime t: type) [*]t {
            return asm ("ADR %[out], " ++ name ++ "\n\t"
                : [out] "=r" (-> [*]t)
            );
        }

        pub fn write(val: anytype) void {
            addr(@TypeOf(val))[0] = val;
        }
    };
}

pub fn to_byte_slice(val: anytype) []u8 {
    return @ptrCast([*]u8, val)[0..@sizeOf(@TypeOf(val.*))];
}

/// Writes the int i into the buffer, returns the number
/// of characters written.
pub fn write_int_decimal(buf: []u8, i: usize) usize {
    const current = '0' + @intCast(u8, i % 10);
    const next = i / 10;
    if (next != 0) {
        const written = write_int_decimal(buf, next);
        buf[written] = current;
        return written + 1;
    } else {
        buf[0] = current;
        return 1;
    }
}
