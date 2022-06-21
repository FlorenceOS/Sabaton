const sabaton = @import("root").sabaton;

const num_lanes = 4;
const lines_per_lane = 11;

const read_delays = [num_lanes][lines_per_lane]u8{
    [_]u8{ 16, 16, 16, 16, 17, 16, 16, 17, 16, 1, 0 },
    [_]u8{ 17, 17, 17, 17, 17, 17, 17, 17, 17, 1, 0 },
    [_]u8{ 16, 17, 17, 16, 16, 16, 16, 16, 16, 0, 0 },
    [_]u8{ 17, 17, 17, 17, 17, 17, 17, 17, 17, 1, 0 },
};

const write_delays = [num_lanes][lines_per_lane]u8{
    [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 15, 15 },
    [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 0, 10, 10 },
    [_]u8{ 1, 0, 1, 1, 1, 1, 1, 1, 0, 11, 11 },
    [_]u8{ 1, 0, 0, 1, 1, 1, 1, 1, 0, 12, 12 },
};

const ac_delays = [31]u8{ 5, 5, 13, 10, 2, 5, 3, 3, 0, 3, 3, 3, 1, 0, 0, 0, 3, 4, 0, 3, 4, 1, 4, 0, 1, 1, 0, 1, 13, 5, 4 };

pub fn ccm(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C2_0000) + offset);
}

pub fn com(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C6_2000) + offset);
}

pub fn ctl0(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C6_3000) + offset);
}

pub fn ctl1(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C6_4000) + offset);
}

pub fn phy0(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C6_5000) + offset);
}

pub fn phy1(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C6_6000) + offset);
}

fn init_cr() void {
    // zig fmt: off
    const common_value = 0
        | (1 << 12) // Full width
        | ((12 - 5) << 8) // PAGE_SHFT - 5, 4096 page size
        | ((15 - 1) << 4) // Row bits = 15
        | (1 << 2) // 8 Banks
        | (1 << 0) // Dual ranks
    ;
    com(0x0000).* = 0
        | common_value
        | (0 << 15) // Interleaved
        | (7 << 16) // LPDDR3
        | (1 << 19) // 1T
        | ((8-1) << 20) // BL = 8
    ;
    com(0x0004).* = common_value;
    // zig fmt: on
}

fn init_timings() void {}

pub fn init() usize {
    sabaton.platform.ccu.clockDram();

    ctl0(0x000C).* = 0xC00E;

    sabaton.timer.sleep_us(500);

    init_cr();
    init_timings();

    @import("root").debugBreak();

    // zig fmt: off
    ctl0(0x0120).* = 0 // ODTMap
        | (3 << 8)
        | (3 << 0)
    ;
    // zig fmt: on

    sabaton.timer.sleep_us(1);

    // VTF enable
    ctl0(0x00B8).* |= (3 << 8);

    // DQ hold disable
    ctl0(0x0108).* &= ~@as(u32, 1 << 13);

    com(0x00D0).* |= (1 << 31);

    sabaton.timer.sleep_us(10);

    // // Detect dram size
    // // set_cr

    return 0;
}
