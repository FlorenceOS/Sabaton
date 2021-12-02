const sabaton = @import("root").sabaton;

pub const Mode = enum {
    HVC,
    SMC,
};

/// Wake up cpu `cpunum`.
/// It will boot at `entry`, with X0 = `context`.
pub fn wake_cpu(entry: u64, cpunum: u64, context: u64, comptime mode: Mode) u64 {
    if (sabaton.debug) {
        sabaton.puts("Waking up CPU\n");
        sabaton.log_hex("cpunum:        ", cpunum);
        sabaton.log_hex("entry:         ", entry);
        sabaton.log_hex("context:       ", context);
    }
    // https://github.com/ziglang/zig/issues/10262
    _ = mode;
    // zig fmt: off
    const result = asm volatile (
        switch (mode) {
            .HVC => "HVC #0",
            .SMC => "SMC #0",
        }
        : [_] "={X0}" (-> u64)
        : [_] "{X0}" (@as(u64, 0xC4000003))
        , [_] "{X1}" (cpunum)
        , [_] "{X2}" (entry)
        , [_] "{X3}" (context)
    );
    // zig fmt: on
    if (sabaton.debug) {
        sabaton.log_hex("Wakeup result: ", result);
    }
    return result;
}
