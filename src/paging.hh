#pragma once

#include "common.hh"

struct perms {
  u64 write: 1;
  u64 execute: 1;
};

struct paging_roots {
  u64 tr0;
  u64 tr1;
};

paging_roots setup_paging();
void apply_paging(paging_roots const *roots);
void page_section(u64 vaddr_base, u64 paddr_base, u64 size, perms);
void page_section(u64 vaddr_base, u64 paddr_base, u64 size, perms, paging_roots const *roots);
