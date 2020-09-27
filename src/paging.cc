#include "paging.hh"
#include "pmm.hh"
#include "align.hh"

paging_roots setup_paging() {
  auto tr0 = calloc_phys(page_size, true);
  auto tr1 = calloc_phys(page_size, true);

  return {
    .tr0 = tr0,
    .tr1 = tr1,
  };
}

namespace {
  u64 *make_table_at(u64 *pte) {
    if(*pte & 1) {
      auto next_table = *pte;
      next_table &= 0x0000FFFFFFFFF000ULL;
      return (u64 *)next_table;
    } else {
      auto next_table = calloc_phys(page_size, true);
      *pte  = next_table;
      *pte |= 1ULL << 63 | 0x3ULL;
      return (u64 *)next_table;
    }
  }

  void make_mapping_at(u64 *pte, u64 paddr) {
    *pte  = paddr;
    *pte |= 0x627ULL;
  }

  u64 get_index(u64 vaddr_base, u64 base_bits, u64 level) {
    auto const shift_bits = base_bits + level * (base_bits - 3);
    return (vaddr_base >> shift_bits) & ((1ULL << (base_bits - 3)) - 1);
  }

  u64 *make_empty_pte(u64 vaddr_base, u64 base_bits, u64 levels, u64 *table) {
    for(u64 i = levels - 1; i > 0; -- i) {
      auto ind = get_index(vaddr_base, base_bits, i);
      table = make_table_at(&table[ind]);
    }

    auto ind = get_index(vaddr_base, base_bits, 0);

    if(table[ind]) {
      log_value("PTE nonzero: ", table[ind]);
      panic("Overlapping mappings!");
    }

    return &table[ind];
  }
}

void page_section(u64 vaddr_base, u64 paddr_base, u64 size, perms p) {
  paging_roots r;
  asm(
    "MRS %[TR0], TTBR0_EL1\n\t"
    : [TR0] "=r" (r.tr0)
  );
  asm(
    "MRS %[TR1], TTBR1_EL1\n\t"
    : [TR1] "=r" (r.tr1)
  );
  page_section(vaddr_base, paddr_base, size, p, &r);
}

void page_section(u64 vaddr_base, u64 paddr_base, u64 size, perms p, paging_roots const *roots) {
  size = align_page_size_up(size);

  if(!is_aligned(vaddr_base, page_size))
    panic("Misaligned virt!");

  if(!is_aligned(paddr_base, page_size))
    panic("Misaligned phys!");

  u64 *root;
  if(vaddr_base & (1ULL << 63)) {
    root = (u64 *)roots->tr1;
  } else {
    root = (u64 *)roots->tr0;
  }

  u64 base_bits;
  u64 levels;

  switch(page_size) {
  case 0x1000:
    base_bits = 12;
    levels = 4;
    break;

  case 0x4000:
    base_bits = 14;
    levels = 4;
    break;

  case 0x10000:
    base_bits = 16;
    levels = 3;
    break;

  default:
    panic("Unknown page size!!");
  }

  while(size) {
    auto pte = make_empty_pte(vaddr_base, base_bits, levels, root);
    make_mapping_at(pte, paddr_base);
    size -= page_size;
    vaddr_base += page_size;
    paddr_base += page_size;
  }
}


void apply_paging(paging_roots const *roots) {
  u64 sctlr;
  u64 aa64mmfr0;

  asm volatile(
    "MRS %[sctlr], SCTLR_EL1\n\t"
    "MRS %[mmfasjf], ID_AA64MMFR0_EL1\n\t"
    : [sctlr] "=r" (sctlr)
    , [mmfasjf] "=r" (aa64mmfr0)
  );

  // Documentation? Nah, be a professional guesser.
  sctlr |= 1;

  aa64mmfr0 &= 0x0F;
  if(aa64mmfr0 > 5)
    aa64mmfr0 = 5;

  u64 paging_granule_br0;
  u64 paging_granule_br1;

  switch(page_size) {
  case 0x1000:
    paging_granule_br0 = 0b00;
    paging_granule_br1 = 0b10;
    break;

  case 0x4000:
    paging_granule_br0 = 0b10;
    paging_granule_br1 = 0b01;
    break;

  case 0x10000:
    paging_granule_br0 = 0b01;
    paging_granule_br1 = 0b11;
    break;
  }

  u64 tcr = 0
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

  u64 mair = 0
    | (0b11111111 << 0) // Normal, Write-back RW-Allocate non-transient
    | (0b00001100 << 8) // Device, GRE
    | (0b01000100 << 16) // Device, nGnRnE
  ;

  asm(
    "MSR TTBR0_EL1, %[TR0]\n\t"
    "MSR TTBR1_EL1, %[TR1]\n\t"
    "MSR MAIR_EL1, %[mair]\n\t"
    "MSR TCR_EL1, %[tcr]\n\t"
    "MSR SCTLR_EL1, %[sctlr]\n\t"
    "ISB SY\n\t"
    :
    : [TR0]   "r" (roots->tr0)
    , [TR1]   "r" (roots->tr1)
    , [sctlr] "r" (sctlr)
    , [tcr]   "r" (tcr)
    , [mair]  "r" (mair)
    : "memory"
  );

  puts("Paging enabled!\n");
}
