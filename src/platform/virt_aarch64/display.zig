const sabaton = @import("root").sabaton;

fn try_find(comptime f: anytype, comptime name: []const u8) bool {
    const retval = f();
    if (retval) {
        sabaton.puts("Found " ++ name ++ "!\n");
    } else {
        sabaton.puts("Couldn't find " ++ name ++ "\n");
    }
    return retval;
}

pub fn init() void {
    // First, try to find a ramfb
    if (try_find(sabaton.ramfb.init, "ramfb"))
        return;

    sabaton.puts("Kernel requested framebuffer but we could not provide one!\n");
}
