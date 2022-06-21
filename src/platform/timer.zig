// aarch64 generic timer

const sabaton = @import("root").sabaton;
const platform = sabaton.platform;

pub fn init() void {}

pub fn get_ticks() usize {
    return asm volatile ("MRS %[out], CNTPCT_EL0"
        : [out] "=r" (-> usize)
    );
}

pub fn get_freq() usize {
    return asm ("MRS %[out], CNTFRQ_EL0"
        : [out] "=r" (-> usize)
    );
}

pub fn get_us() usize {
    return (get_ticks() * 1000000) / get_freq();
}

pub fn sleep_us(us: usize) void {
    const start_us = get_us();
    while (start_us + us > get_us()) {}
}
