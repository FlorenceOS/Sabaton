const sabaton = @import("../../sabaton.zig");

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
        \\  B stivale2_smp_ready
        \\  //.8byte 0        // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\   // CPU 2
        \\  .4byte 2        // ACPI UID
        \\  .4byte 2        // CPU ID
        \\cpu2_entry:
        \\  MOV X0, #2
        \\  B stivale2_smp_ready
        \\  //.8byte 0        // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
        \\
        \\   // CPU 3
        \\  .4byte 3        // ACPI UID
        \\  .4byte 3        // CPU ID
        \\cpu3_entry:
        \\  MOV X0, #3
        \\  B stivale2_smp_ready
        \\  //.8byte 0        // target stack
        \\  .8byte 0        // goto address
        \\  .8byte 0        // extra argument
    );
}

const cpucfg_addr = 0x170_0C00;
var current_cpuid: usize = 0;

pub fn init() void {
    sabaton.add_tag(&sabaton.near("smp_tag").addr(sabaton.Stivale2tag)[0]);

    sabaton.platform.timer.init();
}
