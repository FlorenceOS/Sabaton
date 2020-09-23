#include "paging.hh"

extern "C" u64 page_size;

void page_kernel_section(u64 vaddr_base, u64 paddr_base, u64 size, perms p) {
  if(size & (page_size - 1)) {
    size &= ~(page_size - 1);
    size += page_size;
  }
  puts("lol prentending to page v");
  print_hex(vaddr_base);
  puts(" to phys ");
  print_hex(paddr_base);
  puts(" with size ");
  print_hex(size);
  putchar('\n');
}
