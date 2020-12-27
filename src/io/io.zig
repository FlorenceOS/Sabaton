pub const uart_mmio_32 = @import("uart_mmio_32.zig");

const sabaton = @import("root").sabaton;

const fmt = @import("std").fmt;

const putchar = sabaton.platform.io.putchar;

const Printer = struct {
  pub fn writeAll(self: *const Printer, str: []const u8) !void {
    print_str(str);
  }

  pub fn print(self: *const Printer, comptime format: []const u8, args: anytype) !void {
    log(format, args);
  }

  pub fn writeByteNTimes(self: *const Printer, val: u8, num: usize) !void {
    var i: usize = 0;
    while(i < num): (i += 1) {
      putchar(val);
    }
  }

  pub const Error = anyerror;
};

pub fn log(comptime format: []const u8, args: anytype) void {
  var printer = Printer{};
  fmt.format(printer, format, args) catch unreachable;
}

pub fn print_chars(ptr: [*]const u8, num: usize) void {
  var i: usize = 0;
  while(i < num): (i += 1) {
    putchar(ptr[i]);
  }
}

fn print_str(str: []const u8) void {
  @call(.{.modifier = .never_inline}, print_chars, .{str.ptr, str.len});
}
