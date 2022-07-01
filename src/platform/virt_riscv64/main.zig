pub const sabaton = @import("../../sabaton.zig");
pub const panic = sabaton.panic;

pub usingnamespace @import("../drivers/virt.zig");

pub fn get_uart_info() @This().io.Info {
    const base = 0x10000000;
    return .{
        .uart = @intToPtr(*volatile u32, base),
    };
}

var dtb_base: u64 = undefined;

pub fn get_dtb() []u8 {
    return @intToPtr([*]u8, dtb_base)[0..0x100000];
}

pub fn get_page_size() u64 {
    return 0x1000;
}

var had_exception = false;

fn handle_hiccup_supervisor() noreturn {
    asm volatile(
        \\ NOP
    );
    sabaton.puts("Sabaton caught an exception!\n");
    sabaton.log_hex("mstatus: ", asm volatile(
        \\ CSRR %[mstatus], mstatus
        : [mstatus] "=r" (->u64)
    ));
    sabaton.log_hex("scause: ", asm volatile(
        \\ CSRR %[scause], scause
        : [scause] "=r" (->u64)
    ));
    sabaton.log_hex("sepc: ", asm volatile(
        \\ CSRR %[sepc], sepc
        : [sepc] "=r" (->u64)
    ));
    sabaton.log_hex("stval: ", asm volatile(
        \\ CSRR %[stval], stval
        : [stval] "=r" (->u64)
    ));
    while(true) {}
}

fn handle_hiccup_machine() noreturn {
    asm volatile(
        \\ NOP
    );
    sabaton.puts("Sabaton caught an exception!\n");
    sabaton.log_hex("mcause: ", asm volatile(
        \\ CSRR %[mcause], mcause
        : [mcause] "=r" (->u64)
    ));
    sabaton.log_hex("mepc: ", asm volatile(
        \\ CSRR %[mepc], mepc
        : [mepc] "=r" (->u64)
    ));
    sabaton.log_hex("mtval: ", asm volatile(
        \\ CSRR %[mtval], mtval
        : [mtval] "=r" (->u64)
    ));
    while(true) {}
}

export fn _main(hart_id: u64, dtb_base_arg: u64) linksection(".text.main") noreturn {
    asm volatile(
        \\ CSRW pmpcfg0, %[pmp_config]
        :
        : [pmp_config] "r" (@as(u64, 0b00011111))
    );

    asm volatile(
        \\ CSRW pmpaddr0, %[pmp_addr]
        :
        : [pmp_addr] "r" (~@as(u64, 0))
    );

    asm volatile(
        \\ CSRW mtvec, %[vec]
        :
        : [vec] "r" (((@ptrToInt(handle_hiccup_machine) + 2) / 4) * 4)
    );

    asm volatile(
        \\ CSRW stvec, %[vec]
        :
        : [vec] "r" (((@ptrToInt(handle_hiccup_supervisor) + 2) / 4) * 4)
    );

    asm volatile(
        \\ CSRW mideleg, %[lmao]
        \\ CSRW medeleg, %[lmao]
        :
        : [lmao] "r" (~@as(u64, 0))
    );

    _ = hart_id;
    dtb_base = dtb_base_arg;
    sabaton.fw_cfg.init_from_dtb();
    @call(.{ .modifier = .always_inline }, sabaton.main, .{});
}

pub fn map_platform(root: *sabaton.paging.Root) void {
    sabaton.paging.map(0, 0, 0x3000_0000, .rw, .mmio, root);
    sabaton.paging.map(sabaton.upper_half_phys_base, 0, 0x3000_0000, .rw, .mmio, root);
    sabaton.pci.init_from_dtb(root);
}