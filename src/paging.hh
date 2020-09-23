#pragma once

#include "common.hh"

struct perms {
  u64 write: 1;
  u64 execute: 1;
};

void page_kernel_section(u64 vaddr_base, u64 paddr_base, u64 size, perms);
