const sabaton = @import("root").sabaton;

const pte = u64;
const table_ptr = [*]pte;

pub const Perms = enum {
    none = 0,
    x = 1,
    w = 2,
    r = 4,

    rw = 6,
    rwx = 7,
    rx = 5,
};

pub const MemoryType = enum {
    memory,
    mmio,
};

pub const Root = struct {
    ttbr0: table_ptr,
    ttbr1: table_ptr,
};

fn make_table_at(e: *pte) table_ptr {
    switch (decode(e.*, false)) {
        .Mapping => unreachable,
        .Table => {
            return @intToPtr(table_ptr, e.* & 0x0000FFFFFFFFF000);
        },
        .Empty => {
            const page_size = sabaton.platform.get_page_size();
            const ret = sabaton.pmm.alloc_aligned(page_size, .PageTable);
            //sabaton.log_hex("Allocated new table at ", ret.ptr);
            e.* = @ptrToInt(ret.ptr) | 1 << 63 | 3;
            return @ptrCast(table_ptr, ret.ptr);
        },
    }
}

fn get_index(vaddr: u64, base_bits: u6, level: u64) usize {
    const shift_bits = @intCast(u6, base_bits + (base_bits - 3) * level);
    return (vaddr >> shift_bits) & ((@as(u64, 1) << (base_bits - 3)) - 1);
}

fn extra_bits(perm: Perms, mt: MemoryType, page_size: usize, botlevel: bool) u64 {
    var bits: u64 = 0x1 | (1 << 5) | (1 << 10);

    // Set the walk bit
    if (page_size < 0x10000 and botlevel) bits |= 2;

    if (@enumToInt(perm) & @enumToInt(Perms.w) == 0) bits |= 1 << 7;
    if (@enumToInt(perm) & @enumToInt(Perms.x) == 0) bits |= 1 << 54;
    bits |= switch (mt) {
        .memory => @as(u64, 0 << 2 | 2 << 8 | 1 << 11),
        .mmio => @as(u64, 1 << 2 | 2 << 8),
    };
    return bits;
}

fn make_mapping_at(ent: *pte, paddr: u64, bits: u64) void {
    ent.* = paddr | bits;
}

pub fn detect_page_size() u64 {
    var aa64mmfr0 = asm volatile ("MRS %[reg], ID_AA64MMFR0_EL1\n\t"
        : [reg] "=r" (-> u64)
    );

    var psz: u64 = undefined;

    if (((aa64mmfr0 >> 28) & 0x0F) == 0b0000) {
        psz = 0x1000;
    } else if (((aa64mmfr0 >> 20) & 0x0F) == 0b0001) {
        psz = 0x4000;
    } else if (((aa64mmfr0 >> 24) & 0x0F) == 0b0000) {
        psz = 0x10000;
    } else if (sabaton.safety) {
        @panic("Unknown page size!");
    } else {
        unreachable;
    }
    return psz;
}

pub fn init_paging() Root {
    const page_size = sabaton.platform.get_page_size();
    return .{
        .ttbr0 = @ptrCast(table_ptr, sabaton.pmm.alloc_aligned(page_size, .PageTable)),
        .ttbr1 = @ptrCast(table_ptr, sabaton.pmm.alloc_aligned(page_size, .PageTable)),
    };
}

fn can_map(size: u64, vaddr: u64, paddr: u64, large_step: u64) bool {
    if (large_step > 0x40000000)
        return false;
    if (size < large_step)
        return false;
    const mask = large_step - 1;
    if (vaddr & mask != 0)
        return false;
    if (paddr & mask != 0)
        return false;
    return true;
}

fn choose_root(r: *const Root, vaddr: u64) table_ptr {
    if (sabaton.util.upper_half(vaddr)) {
        return r.ttbr1;
    } else {
        return r.ttbr0;
    }
}

pub fn current_root() Root {
    return .{
        .ttbr0 = asm ("MRS %[br0], TTBR0_EL1"
            : [br0] "=r" (-> table_ptr)
        ),
        .ttbr1 = asm ("MRS %[br1], TTBR1_EL1"
            : [br1] "=r" (-> table_ptr)
        ),
    };
}

const Decoded = enum {
    Mapping,
    Table,
    Empty,
};

pub fn decode(e: pte, bottomlevel: bool) Decoded {
    if (e & 1 == 0)
        return .Empty;
    if (bottomlevel or e & 2 == 0)
        return .Mapping;
    return .Table;
}

pub fn map(vaddr_c: u64, paddr_c: u64, size_c: u64, perm: Perms, mt: MemoryType, in_root: *Root) void {
    const page_size = sabaton.platform.get_page_size();
    var vaddr = vaddr_c;
    var paddr = paddr_c;
    var size = size_c;
    size += page_size - 1;
    size &= ~(page_size - 1);

    const root = choose_root(in_root, vaddr);

    const levels: usize =
        switch (page_size) {
        0x1000, 0x4000 => 4,
        0x10000 => 3,
        else => unreachable,
    };

    const base_bits = @intCast(u6, @ctz(u64, page_size));

    const small_bits = extra_bits(perm, mt, page_size, true);
    const large_bits = extra_bits(perm, mt, page_size, false);

    while (size != 0) {
        var current_step_size = page_size << @intCast(u6, (base_bits - 3) * (levels - 1));
        var level = levels - 1;
        var current_table = root;

        while (true) {
            const ind = get_index(vaddr, base_bits, level);
            // We can only map at this level if it's not a table
            switch (decode(current_table[ind], level == 0)) {
                .Mapping => {
                    sabaton.log_hex("Overlapping mapping at ", vaddr);
                    sabaton.log_hex("PTE is ", current_table[ind]);
                    unreachable;
                },
                .Table => {}, // Just iterate to the next level
                .Empty => {
                    // If we can map at this level, do so
                    if (can_map(size, vaddr, paddr, current_step_size)) {
                        const bits = if (level == 0) small_bits else large_bits;
                        make_mapping_at(&current_table[ind], paddr, bits);
                        break;
                    }
                    // Otherwise, just iterate to the next level
                },
            }

            if (level == 0)
                unreachable;

            current_table = make_table_at(&current_table[ind]);
            current_step_size >>= (base_bits - 3);
            level -= 1;
        }

        vaddr += current_step_size;
        paddr += current_step_size;
        size -= current_step_size;
    }
}

pub fn apply_paging(r: *Root) void {
    var sctlr = asm (
        \\MRS %[sctlr], SCTLR_EL1
        : [sctlr] "=r" (-> u64)
    );
    var aa64mmfr0 = asm (
        \\MRS %[id], ID_AA64MMFR0_EL1
        : [id] "=r" (-> u64)
    );

    // Documentation? Nah, be a professional guesser.
    sctlr |= 1;

    aa64mmfr0 &= 0x0F;
    if (aa64mmfr0 > 5)
        aa64mmfr0 = 5;

    var paging_granule_br0: u64 = undefined;
    var paging_granule_br1: u64 = undefined;
    var region_size_offset: u64 = undefined;

    switch (sabaton.platform.get_page_size()) {
        0x1000 => {
            paging_granule_br0 = 0b00;
            paging_granule_br1 = 0b10;
            region_size_offset = 16;
        },
        0x4000 => {
            paging_granule_br0 = 0b10;
            paging_granule_br1 = 0b01;
            region_size_offset = 8;
        },
        0x10000 => {
            paging_granule_br0 = 0b01;
            paging_granule_br1 = 0b11;
            region_size_offset = 0;
        },
        else => unreachable,
    }

    const tcr: u64 = 0 | (region_size_offset << 0) // T0SZ
    | (region_size_offset << 16) // T1SZ
    | (1 << 8) // TTBR0 Inner WB RW-Allocate
    | (1 << 10) // TTBR0 Outer WB RW-Allocate
    | (1 << 24) // TTBR1 Inner WB RW-Allocate
    | (1 << 26) // TTBR1 Outer WB RW-Allocate
    | (2 << 12) // TTBR0 Inner shareable
    | (2 << 28) // TTBR1 Inner shareable
    | (aa64mmfr0 << 32) // intermediate address size
    | (paging_granule_br0 << 14) // TTBR0 granule
    | (paging_granule_br1 << 30) // TTBR1 granule
    | (1 << 56) // Fault on TTBR1 access from EL0
    | (0 << 55) // Don't fault on TTBR0 access from EL0
    ;

    const mair: u64 = 0 | (0b11111111 << 0) // Normal, Write-back RW-Allocate non-transient
    | (0b00000000 << 8) // Device, nGnRnE
    ;

    if (sabaton.debug) {
        sabaton.log("Enabling paging... ", .{});
    }

    asm volatile (
        \\MSR TTBR0_EL1, %[ttbr0]
        \\MSR TTBR1_EL1, %[ttbr1]
        \\MSR MAIR_EL1, %[mair]
        \\MSR TCR_EL1, %[tcr]
        \\MSR SCTLR_EL1, %[sctlr]
        \\DSB SY
        \\ISB SY
        :
        : [ttbr0] "r" (r.ttbr0),
          [ttbr1] "r" (r.ttbr1),
          [sctlr] "r" (sctlr),
          [tcr] "r" (tcr),
          [mair] "r" (mair)
        : "memory"
    );

    if (sabaton.debug) {
        sabaton.log("Paging enabled!\n", .{});
    }
}
