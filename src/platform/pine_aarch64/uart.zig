const ccu = @import("ccu.zig");
const regs = @import("regs.zig");

pub fn uart(offset: usize) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C2_8000) + offset);
}

const dll = uart(0x0000);
const dlh = uart(0x0004);
const fcr = uart(0x0008);
const lcr = uart(0x000C);

pub fn init() void {
    ccu.clockUarts();

    regs.configure_port('B', 8, .Uart);
    regs.configure_port('B', 9, .Uart);
    regs.pull_port('B', 9, .Up);

    // zig fmt: off
    lcr.* = 0
        | (1 << 7) // DLAB
        // Leave the rest undefined for now
    ;

    fcr.* = 0
        | (1 << 0) // Enable FIFOs, required for getchar()
    ;

    // Baud rate: 24 * 1000 * 1000 / 16 / 115200 => Divisor should be 13
    dlh.* = 0
        | (0 << 0) // Divisor Latch High
    ;
    dll.* = 0
        | (13 << 0) // Divisor Latch Low
    ;

    lcr.* = 0
        | (0 << 8) // DLAB
        | (0 << 6) // Break Control
        | (0 << 4) // Even parity = N/A
        | (0 << 3) // Parity enable = No
        | (0 << 2) // Number of stop bits = 1
        | (3 << 0) // Data length = 8 bits
    ;
    // zig fmt: on
}
