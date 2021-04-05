const sabaton = @import("root").sabaton;

comptime {
    asm(
        // We pack the CPU boot trampolines into the stack slots, because reasons.
        \\  .section .data
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
        \\  .8byte __boot_stack + 0x1000 // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\   // CPU 2
        \\  .4byte 2        // ACPI UID
        \\  .4byte 2        // CPU ID
        \\  .8byte __boot_stack + 0x2000 // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\   // CPU 3
        \\  .4byte 3        // ACPI UID
        \\  .4byte 3        // CPU ID
        \\  .8byte __boot_stack + 0x3000 // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\ .section .text.smp_stub
        \\ .global smp_stub
        \\smp_stub:
        \\  BL el2_to_el1
        \\  MSR SPSel, #0
        \\  LDR X1, [X0, #8] // Load stack
        \\  MOV SP, X1
        \\  // Fall through to smp_entry
    );
}

extern fn smp_stub(context: u64) callconv(.C) noreturn;

export fn smp_entry(context: u64) linksection(".text.smp_entry") noreturn {
  @call(.{.modifier = .always_inline}, sabaton.stivale2_smp_ready, .{context});
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

    var core: u64 = 1;
    while(core < 4) : (core += 1) {
        const ap_x0 = @ptrToInt(smp_tag) + 40 + core * 32;
        _ = sabaton.psci.wake_cpu(@ptrToInt(smp_stub), core, ap_x0, .SMC);
    }
}
