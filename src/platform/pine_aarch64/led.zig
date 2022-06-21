const regs = @import("regs.zig");

// One-shot the LED port operations instead of using the ports api
// which does a volatile read and write for each color
const single_led_write = true;

// Assume that there are no current outputs on the same
// register on the D port pins
const assume_no_outputs = true;

pub fn output(
    // The color of the front-facing LED
    // You can combine colors like all three making white.
    col: struct { red: bool, green: bool, blue: bool },
) void {
    if (comptime single_led_write) {
        const op = @intToPtr(*volatile u32, 0x1C2087C);

        var op_val: u32 = if (comptime assume_no_outputs)
            0
        else
            op.* & ~@as(u32, 0x1C0000);

        if (col.red) op_val |= 0x080000;
        if (col.blue) op_val |= 0x100000;
        if (col.green) op_val |= 0x040000;

        op.* = op_val;
    } else {
        regs.write_port('D', 18, col.green);
        regs.write_port('D', 19, col.red);
        regs.write_port('D', 20, col.blue);
    }
}

// Configure all three led pins in a single operation
// instead of 2 per (like above)
const single_config_write = true;

// Assume no other pins on the D port in the same configuration
// regsister are active
const assume_ports_unconfigured = true;

pub fn configureLed() void {
    if (comptime single_config_write) {
        const config = @intToPtr(*volatile u32, 0x1C20874);

        const config_val: u32 = if (comptime assume_ports_unconfigured)
            0x77700077
        else
            config.* & 0xFFF000FF;

        config.* = config_val | 0x00011100;
    } else {
        regs.configure_port('D', 18, .Output);
        regs.configure_port('D', 19, .Output);
        regs.configure_port('D', 20, .Output);
    }
}
