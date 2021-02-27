const sabaton = @import("root").sabaton;

comptime {
    asm(
        // We pack the CPU boot trampolines into the stack slots, because reasons.
        \\  .section .text
        \\  .balign 8
        \\  .global smp_tag
        \\smp_tag:
        \\  .8byte 0x34d1d96339647025 // smp identifier
        \\  .8byte 0        // next
        \\  .8byte 0        // flags
        \\  .4byte 0        // boot cpu id
        \\  .4byte 0        // pad
        \\  .8byte 4        // cpu_count
        \\
        \\   // CPU 0
        \\  .4byte 0        // ACPI UID
        \\  .4byte 0        // CPU ID
        \\  .8byte 0        // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\   // CPU 1
        \\  .4byte 1        // ACPI UID
        \\  .4byte 1        // CPU ID
        \\cpu1_entry:
        \\  MOV X0, #1
        \\  B smp_entry
        \\  //.8byte 0      // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\   // CPU 2
        \\  .4byte 2        // ACPI UID
        \\  .4byte 2        // CPU ID
        \\cpu2_entry:
        \\  MOV X0, #2
        \\  B smp_entry
        \\  //.8byte 0      // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\   // CPU 3
        \\  .4byte 3        // ACPI UID
        \\  .4byte 3        // CPU ID
        \\cpu3_entry:
        \\  MOV X0, #3
        \\  B smp_entry
        \\  //.8byte 0      // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
    );
}

pub var waiting_for_boot: u32 = 0;

export fn smp_entry(cpuid: u64) noreturn {
  _ = @atomicRmw(u32, &waiting_for_boot, .Sub, 1, .AcqRel);
  @call(.{.modifier = .always_inline}, sabaton.stivale2_smp_ready, .{cpuid});
}

fn cpucfg(offset: u16) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x0170_0C00) + offset);
}

fn ccu(offset: u64) *volatile u32 {
    return @intToPtr(*volatile u32, @as(usize, 0x01C2_0000) + offset);
}

pub fn init() void {
    const smp_tag = sabaton.near("smp_tag").addr(sabaton.Stivale2tag);
    sabaton.add_tag(&smp_tag[0]);

    sabaton.platform.timer.init();

    // // PLL_CPUX: 90001031
    // //sabaton.log_hex("PLL_CPUX: ", ccu(0x00).*);
    // ccu(0x00).* = 0x80001031 | (1 << 24);
    // //sabaton.log_hex("PLL_CPUX: ", ccu(0x00).*);
    // // PLL_CPUX: 81001031
    // while(ccu(0x00).* & (1 << 28) == 0)
    //     asm volatile("YIELD");
    // //sabaton.log_hex("PLL_CPUX: ", ccu(0x00).*);
    // // PLL_CPUX: 91001031

    // C_RST_CTRL
    cpucfg(0x80).* = ~@as(u32, 1 << 12);
    sabaton.log_hex("C_RST_CTRL: ", cpucfg(0x80).*);
    cpucfg(0x80).* = ~@as(u32, 0);
    sabaton.log_hex("C_RST_CTRL: ", cpucfg(0x80).*);

    sabaton.log_hex("C_CPU_STATUS: ", cpucfg(0x30).*);

    // C_CTRL_REG0: AA64nAA32
    cpucfg(0x00).* = cpucfg(0x00).* | 1 << 24;

    sabaton.log_hex("C_CTRL_REG0: ", cpucfg(0x00).*);

    @atomicStore(u32, &waiting_for_boot, 3, .Release);

    inline for([_]u16{1, 2, 3}) |core| {
        const entry = @ptrToInt(smp_tag) + 48 + core * 32;
        // RVBARADDRX_L
        cpucfg(0xA0 + core * 8).* = @truncate(u32, entry);
        // RVBARADDRX_H
        cpucfg(0xA4 + core * 8).* = @truncate(u32, entry >> 32);
    }

    // GENER_CTRL_REG0
    cpucfg(0x28).* = (0 << 4) | (1 << 8) | (0 << 12) | (0 << 16) | (1 << 24);

    // Start the cores
    // C_RST_CTRL
    cpucfg(0x80).* = ~@as(u32, 0b1110);

    sabaton.puts("Waiting for CPUs...\n");

    sabaton.log_hex("C_CPU_STATUS: ", cpucfg(0x30).*);

    var last_remaining: u32 = 0;
    while(true) {
        const remaining = @atomicLoad(u32, &waiting_for_boot, .Acquire);
        if(remaining != last_remaining) {
            last_remaining = remaining;
            sabaton.log_hex("CPUs not alive yet: ", remaining);
        }
        if(remaining == 0)
            break;
    }
}
