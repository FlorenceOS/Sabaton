#include "pmm.hh"
#include "align.hh"

extern "C" u64 pmm_base;
extern "C" u64 phys_head;
extern "C" u64 kernel_load_base;

namespace {
  bool sealed = false;
}

u64 calloc_phys(u64 size, bool aligned) {
  if(sealed)
    panic("Sealed!");

  auto ret = phys_head;
  if(aligned)
    ret = align_page_size_up(ret);
  phys_head = ret + size;
  __builtin_memset((void *)ret, 0, size);
  return ret;
}

u64 seal_phys() {
  sealed = true;
  return align_page_size_up(phys_head);
}
