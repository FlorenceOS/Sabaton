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

usingnamespace if(sabaton.debug) struct {
  pub fn log(comptime format: []const u8, args: anytype) void {
    var printer = Printer{};
    fmt.format(printer, format, args) catch unreachable;
  }
  } else struct { };

pub fn print_chars(ptr: [*]const u8, num: usize) void {
  var i: usize = 0;
  while(i < num): (i += 1) {
    putchar(ptr[i]);
  }
}

fn print_hex_impl(num: u64, nibbles: isize) void {
  var i: isize = nibbles - 1;
  while(i >= 0) : (i -= 1){
    putchar("0123456789ABCDEF"[(num >> (i * 4))&0xF]);
  }
}

pub fn print_hex(num: anytype) void {
  @call(.{.modifier = .never_inline}, (@bitSizeOf(@TypeOf(num)) + 3)/4);
}

pub fn log_hex(str: [*:0]const u8, val: anytype) void {
  print_str(str);
  print_hex(val);
}

pub fn puts(str_c: [*:0]const u8) void {
  var str = str_c;
  while(str[0] != 0): (str += 1)
    putchar(str[0]);
}

pub fn print_str(str: []const u8) void {
  for(str) |c|
    putchar(c);
}
