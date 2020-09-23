#include "common.hh"
#include "elf.hh"

extern "C" u8 *kernel_file_loc;

struct stivale_tag {
  u64 ident;
  stivale_tag *next;
};

struct stivale2hdr {
  u64 entry_point;
  u64 stack;
  u64 flags;
  stivale_tag *tags;
};

extern "C" void load_stivale_kernel() {
  puts("SABATON: Loading stivale from ELF at ");
  print_hex(kernel_file_loc);
  putchar('\n');

  validate_elf();

  stivale2hdr hdr;

  load_elf_section(".stivale2hdr", (u8 *)&hdr, sizeof(hdr), 0);

  // @TODO: KASLR

  load_elf();

  auto entry = hdr.entry_point ?: elf_entry();

  puts("Done!\n");
  while(1) { }
}
