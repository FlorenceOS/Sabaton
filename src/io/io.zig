pub const uart_mmio_32 = @import("uart_mmio_32.zig");
pub const status_uart_mmio_32 = @import("status_uart_mmio_32.zig");

const sabaton = @import("root").sabaton;

const fmt = @import("std").fmt;

pub const putchar = sabaton.platform.io.putchar;

const Printer = struct {
    pub fn writeAll(_: *const Printer, str: []const u8) !void {
        print_str(str);
    }

    pub fn print(_: *const Printer, comptime format: []const u8, args: anytype) !void {
        log(format, args);
    }

    pub fn writeByteNTimes(_: *const Printer, val: u8, num: usize) !void {
        var i: usize = 0;
        while (i < num) : (i += 1) {
            putchar(val);
        }
    }
    pub const Error = anyerror;
};

usingnamespace if (sabaton.debug) struct {
    pub fn log(comptime format: []const u8, args: anytype) void {
        var printer = Printer{};
        fmt.format(printer, format, args) catch unreachable;
    }
} else struct {
    pub fn log(comptime _: []const u8, _: anytype) void {
        @compileError("Log called!");
    }
};

pub fn print_chars(ptr: [*]const u8, num: usize) void {
    var i: usize = 0;
    while (i < num) : (i += 1) {
        putchar(ptr[i]);
    }
}

fn wrapped_print_hex(num: u64, nibbles: isize) void {
    var i: isize = nibbles - 1;
    while (i >= 0) : (i -= 1) {
        putchar("0123456789ABCDEF"[(num >> @intCast(u6, i * 4)) & 0xF]);
    }
}

pub fn print_hex(num: anytype) void {
    switch (@typeInfo(@TypeOf(num))) {
        else => @compileError("Unknown print_hex type!"),

        .Int => @call(.{ .modifier = .never_inline }, wrapped_print_hex, .{ num, (@bitSizeOf(@TypeOf(num)) + 3) / 4 }),
        .Pointer => @call(.{ .modifier = .always_inline }, print_hex, .{@ptrToInt(num)}),
        .ComptimeInt => @call(.{ .modifier = .always_inline }, print_hex, .{@as(usize, num)}),
    }
}

pub fn log_hex(str: [*:0]const u8, val: anytype) void {
    puts(str);
    print_hex(val);
    putchar('\n');
}

fn wrapped_puts(str_c: [*:0]const u8) void {
    var str = str_c;
    while (str[0] != 0) : (str += 1)
        @call(.{ .modifier = .never_inline }, putchar, .{str[0]});
}

pub fn puts(str_c: [*:0]const u8) void {
    @call(.{ .modifier = .never_inline }, wrapped_puts, .{str_c});
}

fn wrapped_print_str(str: []const u8) void {
    for (str) |c|
        putchar(c);
}

pub fn print_str(str: []const u8) void {
    @call(.{ .modifier = .never_inline }, wrapped_print_str, .{str});
}
