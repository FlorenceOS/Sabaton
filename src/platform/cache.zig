pub fn flushCacheline(comptime icache: bool, comptime dcache: bool, addr: u64) void {
    if (comptime (icache)) {
        asm volatile (
            \\ IC IVAU, %[ptr]
            :
            : [ptr] "r" (addr)
        );
    }

    if (comptime (dcache)) {
        asm volatile (
            \\ DC CIVAC, %[ptr]
            :
            : [ptr] "r" (addr)
        );
    }
}

const cacheline_size = @import("root").cacheline_size;

pub fn flush(comptime icache: bool, comptime dcache: bool, addr_c: u64, size_c: u64) void {
    var addr = addr_c & ~@as(u64, cacheline_size - 1);
    var size = size_c + cacheline_size - 1;

    while (size >= cacheline_size) : ({
        addr += cacheline_size;
        size -= cacheline_size;
    }) {
        flushCacheline(icache, dcache, addr);
    }
}
