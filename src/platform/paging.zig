comptime {
  asm(
    \\page_size:
    \\  .8byte 0x1000
  );
}

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
  if(e.* & 1 != 0) {
    return @intToPtr(table_ptr, e.* & 0x0000FFFFFFFFF000);
  } else {
    const page_size = sabaton.near("page_size").read(u64);
    const ret = sabaton.pmm.alloc_aligned(page_size, .PageTable);
    e.* = @ptrToInt(ret.ptr);
    e.* |= 1 << 63 | 0x3;
    return @ptrCast(table_ptr, ret.ptr);
  }
}

fn get_index(vaddr: u64, base_bits: u6, level: u64) usize {
  const shift_bits = @intCast(u6, base_bits + (base_bits - 3) * level);
  return (vaddr >> shift_bits) & ((@as(u64, 1) << (base_bits - 3)) - 1);
}

fn make_pte(vaddr: u64, base_bits: u6, levels: u64, tbl_in: table_ptr) *pte {
  var level = levels - 1;
  var tbl = tbl_in;
  while(level > 0): (level -= 1) {
    const ind = get_index(vaddr, base_bits, level);
    tbl = make_table_at(&tbl[ind]);
  }

  const ind = get_index(vaddr, base_bits, 0);
  // I decided that overlapping mappings are fine and we should just
  // not overwrite anything
  // if(tbl[ind] != 0) {
  //   sabaton.log("Nonzero page table entry!\n", .{});
  //   unreachable;
  // }
  return &tbl[ind];
}

fn extra_bits(perm: Perms, mt: MemoryType) u64 {
  var bits: u64 = 0x3 | (2 << 2) | (1 << 5) | (1 << 10);
  const bit_nx = 1 << 54;
  const bit_nw = 1 << 7;

  if(@enumToInt(perm) & @enumToInt(Perms.w) == 0) bits |= bit_nw;
  if(@enumToInt(perm) & @enumToInt(Perms.x) == 0) bits |= bit_nx;
  bits |= switch(mt) {
    .memory => @as(u64, 0 << 2 | 2 << 8 | 1 << 11),
    .mmio   => @as(u64, 1 << 2 | 0 << 8),
  };
  return bits;
}

fn make_mapping_at(ent: *pte, paddr: u64, bits: u64) void {
  ent.* = paddr | bits;
}

pub fn detect_page_size() void {
  var aa64mmfr0: u64 = undefined;

  asm volatile(
    "MRS %[reg], ID_AA64MMFR0_EL1\n\t"
    : [reg] "=r" (aa64mmfr0)
  );

  var psz: u64 = undefined;

  if(((aa64mmfr0 >> 28) & 0x0F) == 0b0000) {
    psz = 0x1000;
  }
  else if(((aa64mmfr0 >> 20) & 0x0F) == 0b0001) {
    psz = 0x4000;
  }
  else if(((aa64mmfr0 >> 24) & 0x0F) == 0b0000) {
    psz = 0x10000;
  }
  else {
    @panic("Unknown page size!");
  }
  sabaton.near("page_size").write(psz);
}

pub fn init_paging() Root {
  const page_size = sabaton.near("page_size").read(u64);
  return .{
    .ttbr0 = @ptrCast(table_ptr, sabaton.pmm.alloc_aligned(page_size, .PageTable)),
    .ttbr1 = @ptrCast(table_ptr, sabaton.pmm.alloc_aligned(page_size, .PageTable)),
  };
}

fn choose_root(r: *const Root, vaddr: u64) table_ptr {
  return
    if(sabaton.util.upper_half(vaddr)) r.ttbr1 else r.ttbr0;
}

pub fn current_root() Root {
  return .{
    .ttbr0 = asm("MRS %[br0], TTBR0_EL1": [br0] "=r" (-> table_ptr)),
    .ttbr1 = asm("MRS %[br1], TTBR1_EL1": [br1] "=r" (-> table_ptr)),
  };
}

pub fn map(vaddr_c: u64, paddr_c: u64, size_c: u64, perm: Perms, mt: MemoryType, in_root: ?*Root, mode: enum{CanOverlap, CannotOverlap}) void {
  const page_size = sabaton.near("page_size").read(u64);
  var vaddr = vaddr_c;
  var paddr = paddr_c;
  var size = size_c;
  size += page_size - 1;
  size &= ~(page_size - 1);

  var root: table_ptr = undefined;
  if(in_root) |r| {
    root = choose_root(r, vaddr);
  }
  else {
    const roots = current_root();
    root = choose_root(&roots, vaddr);
  }

  const levels = 4;
  const base_bits = @intCast(u6, @ctz(u64, page_size));
  const bits = extra_bits(perm, mt);

  while(size != 0) {
    const ent = make_pte(vaddr, base_bits, levels, root);
    if(ent.* == 0) {
      make_mapping_at(ent, paddr, bits);
    } else if (mode == .CannotOverlap) {
      @panic("Overlapping mapping");
    }
    size -= page_size;
    vaddr += page_size;
    paddr += page_size;
  }
}

pub fn apply_paging(r: *Root) void {
  var sctlr = asm(
    \\MRS %[sctlr], SCTLR_EL1
    : [sctlr] "=r" (-> u64)
  );
  var aa64mmfr0 = asm(
    \\MRS %[id], ID_AA64MMFR0_EL1
    : [id] "=r" (-> u64)
  );

  // Documentation? Nah, be a professional guesser.
  sctlr |= 1;

  aa64mmfr0 &= 0x0F;
  if(aa64mmfr0 > 5)
    aa64mmfr0 = 5;

  var paging_granule_br0: u64 = undefined;
  var paging_granule_br1: u64 = undefined;

  const page_size = sabaton.near("page_size").read(u64);

  switch(page_size) {
    0x1000 => {
      paging_granule_br0 = 0b00;
      paging_granule_br1 = 0b10;
    },
    0x4000 => {
      paging_granule_br0 = 0b10;
      paging_granule_br1 = 0b01;
    },
    0x10000 => {
      paging_granule_br0 = 0b01;
      paging_granule_br1 = 0b11;
    },
    else => unreachable,
  }

  const tcr: u64 = 0
    | (16 << 0)  // T0SZ=16
    | (16 << 16) // T1SZ=16
    | (1 << 8)   // TTBR0 Inner WB RW-Allocate
    | (1 << 10)  // TTBR0 Outer WB RW-Allocate
    | (1 << 24)  // TTBR1 Inner WB RW-Allocate
    | (1 << 26)  // TTBR1 Outer WB RW-Allocate
    | (2 << 12)  // TTBR0 Inner shareable
    | (2 << 28)  // TTBR1 Inner shareable
    | (aa64mmfr0 << 32) // intermediate address size
    | (paging_granule_br0 << 14) // TTBR0 granule
    | (paging_granule_br1 << 30) // TTBR1 granule
  ;

  const mair: u64 = 0
    | (0b11111111 << 0) // Normal, Write-back RW-Allocate non-transient
    | (0b00001100 << 8) // Device, GRE
  ;

  if(sabaton.debug) {
    sabaton.log("Enabling paging... ", .{});
  }

  asm volatile(
    \\MSR TTBR0_EL1, %[ttbr0]
    \\MSR TTBR1_EL1, %[ttbr1]
    \\MSR MAIR_EL1, %[mair]
    \\MSR TCR_EL1, %[tcr]
    \\MSR SCTLR_EL1, %[sctlr]
    \\DSB SY
    \\ISB SY
    :
    : [ttbr0] "r" (r.ttbr0)
    , [ttbr1] "r" (r.ttbr1)
    , [sctlr] "r" (sctlr)
    , [tcr]   "r" (tcr)
    , [mair]  "r" (mair)
    : "memory"
  );

  if(sabaton.debug) {
    sabaton.log("Paging enabled!\n", .{});
  }
}
