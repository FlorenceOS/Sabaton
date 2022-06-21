const sabaton = @import("root").sabaton;

// KEYADC is an ADC for the physical buttons on the phone
pub fn keyadc(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C2_1800) + offset);
}

const ctrl = keyadc(0x0000);
const intc = keyadc(0x0004);
const ints = keyadc(0x0008);
const data0 = keyadc(0x000C);
const data1 = keyadc(0x0010);

pub fn init() void {
    // zig fmt: off
    ints.* = 0x1F; // Clear all interrupts

    intc.* = 0; // Disable all interrupts

    ctrl.* = 0
        | (0 << 24) // First convert delay, number of samples
        | (0 << 16) // Continue time select, N/A
        | (0 << 12) // Key mode select = Normal
        | (0 << 8) // Level A to Level B time threshold select
        | (0 << 7) // Hold key enable
        | (0 << 6) // Sample hold enable
        | (0 << 4) // Level B = 1.9V
        | (0 << 2) // Sample rage = 250Hz
        | (1 << 0) // Enable KEYADC
    ;
    // zig fmt: on
}

pub fn disable() void {
    ctrl.* = 0;
}

pub fn getPressedKey() enum {
    Up,
    Down,
    // Is the power button separate??
    // Probably??
    //Power,
    None,
} {
    const val = data0.* & 0x3F;

    // if (val != 0x3F)
    //     sabaton.log_hex("KEYADC: ", val);

    return switch (val) {
        5 => .Up,

        11 => .Down,

        else => .None,
    };
}
