pub const sabaton = @import("../../sabaton.zig");
pub const io = sabaton.io_impl.status_uart_mmio_32;
pub const panic = sabaton.panic;

pub const ccu = @import("ccu.zig");
pub const display = @import("display.zig");
pub const dram = @import("dram.zig");
pub const keyadc = @import("keyadc.zig");
pub const led = @import("led.zig");
pub const smp = @import("smp.zig");
pub const uart = @import("uart.zig");

const std = @import("std");

const enable_debugger = true;

pub const cacheline_size = 64;

const debugger_entry linksection(".debugger") = @embedFile("../host_aarch64_EL3.bin").*;

pub fn debugBreak() void {
    if (comptime (enable_debugger)) {
        asm volatile (
            \\SMC #5
        );
    }
}

// We know the page size is 0x1000
pub fn get_page_size() u64 {
    return 0x1000;
}

fn debuggerSendUart(ptr: [*c]const u8, sz: usize) callconv(.C) void {
    // No need to flush anything since we're only reading from dcache
    for (ptr[0..sz]) |c| {
        sabaton.io_impl.putchar_bin(c);
    }
}

fn debuggerRecvUart(ptr: [*c]u8, sz: usize) callconv(.C) void {
    // Flush icache after recv, no need to flush dcache since we're not doing dma
    for (ptr[0..sz]) |*c| {
        c.* = sabaton.io_impl.getchar_bin();
    }
    sabaton.cache.flush(true, false, @ptrToInt(ptr), sz);
}

export fn _main() linksection(".text.main") noreturn {
    ccu.init();
    ccu.upclock();

    uart.init();

    const SCTLR_EL3 = asm ("MRS %[out], SCTLR_EL3"
        : [out] "=r" (-> u64)
    );
    sabaton.log_hex("SCTLR_EL3: ", SCTLR_EL3);

    // sabaton.log_hex("PT base: ", sabaton.pmm.alloc_aligned(0x1000, .ReclaimableData).ptr);

    // // Enable MMU
    // asm volatile ("MSR SCTLR_EL3, %[sctlr]"
    //     :
    //     : [sctlr] "r" (SCTLR_EL3 | 1)
    // );

    // sabaton.puts("Paging enabled");

    if (comptime enable_debugger) {
        const debugger_stack = asm (
            \\ADR %[stk], __debugger_stack
            : [stk] "=r" (-> u64)
        );

        asm volatile (
            \\ MSR SPSel, #1
            \\ MOV SP, %[stk]
            \\ MSR SPSel, #0
            :
            : [stk] "r" (debugger_stack)
        );

        sabaton.log_hex("Set debugger stack to ", debugger_stack);

        const debugger_init = @ptrCast(
            fn (
                fn ([*c]const u8, usize) callconv(.C) void,
                fn ([*c]u8, usize) callconv(.C) void,
            ) callconv(.C) void,
            &debugger_entry[0],
        );

        sabaton.log_hex("Initializing debugger at ", @ptrToInt(debugger_init));

        debugger_init(
            debuggerSendUart,
            debuggerRecvUart,
        );
    }

    led.configureLed();
    led.output(.{ .green = true, .red = true, .blue = false });

    const dram_size = dram.init();
    _ = dram_size;

    led.output(.{ .green = true, .red = false, .blue = true });

    keyadc.init();
    while (true) {
        switch (keyadc.getPressedKey()) {
            .Up => sabaton.puts("Up button pressed\n"),
            .Down => sabaton.puts("Down button pressed\n"),
            else => {},
        }
    }

    //sabaton.timer.sleep_us(1_000_000);

    //@call(.{ .modifier = .always_inline }, sabaton.main, .{});
}

pub fn panic_hook() void {
    // Red
    led.output(.{ .green = false, .red = true, .blue = false });
}

pub fn launch_kernel_hook() void {
    // Blue
    led.output(.{ .green = false, .red = false, .blue = true });
}

pub fn get_kernel() [*]u8 {
    return sabaton.near("kernel_file_loc").read([*]u8);
}

// pub fn get_dtb() []u8 {
//   return sabaton.near("dram_base").read([*]u8)[0..0x100000];
// }

pub fn get_dram() []u8 {
    return sabaton.near("dram_base").read([*]u8)[0..get_dram_size()];
}

fn get_dram_size() u64 {
    return 0x80000000;
}

pub fn map_platform(root: *sabaton.paging.Root) void {
    // MMIO area
    sabaton.paging.map(0, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
    sabaton.paging.map(sabaton.upper_half_phys_base, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
}

pub fn add_platform_tags(kernel_header: *sabaton.Stivale2hdr) void {
    _ = kernel_header;
    sabaton.add_tag(&sabaton.near("uart_tag").addr(sabaton.Stivale2tag)[0]);
    sabaton.add_tag(&sabaton.near("devicetree_tag").addr(sabaton.Stivale2tag)[0]);
}

pub fn get_uart_info() io.Info {
    const base = 0x1C28000;
    return .{
        .uart = @intToPtr(*volatile u32, base),
        .status = @intToPtr(*volatile u32, base + 0x14),
        .mask = 0x20,
        .value = 0x20,
    };
}

pub fn get_uart_reader() io.Info {
    const base = 0x1C28000;
    return .{
        .uart = @intToPtr(*volatile u32, base),
        .status = @intToPtr(*volatile u32, base + 0x14),
        .mask = 0x1,
        .value = 0x1,
    };
}
