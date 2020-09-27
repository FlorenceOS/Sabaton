#include "common.hh"
#include "paging.hh"

extern "C" u64 kernel_load_base;
extern "C" u8 *kernel_file_loc;

using addr = u64;
using off = u64;
using half = u16;
using word = u32;
using xword = u64;

struct Header {
  u8 ident[16];
  half type;
  half machine;
  word version;
  addr entry;
  off phoff;
  off shoff;
  word flags;
  half ehsize;
  half phentsize;
  half phnum;
  half shentsize;
  half shnum;
  half shstrndx;
} __attribute__((packed));

struct Section_Header {
  word name;
  word type;
  xword flags;
  addr vaddr;
  off offset;
  xword size;
  word link;
  word info;
  xword addralign;
  xword entsize;
} __attribute__((packed));

struct Program_Header {
  word type;
  word flags;
  off offset;
  addr vaddr;
  addr paddr;
  xword filesz;
  xword memsz;
  xword align;
} __attribute__((packed));

void validate_elf() {
  auto header = (Header*)kernel_file_loc;
  if(header->ident[0] != 0x7F ||
     header->ident[1] != 'E'  ||
     header->ident[2] != 'L'  ||
     header->ident[3] != 'F')
    panic("Invalid ELF magic!");

  if(header->type != 0x02) {
    panic("ELF not ET_EXEC!");
  }

  if(header->entry < (1ULL << 63))
    panic("Not higher half!");

  puts("ELF verification success.\n");
}

namespace {
  Section_Header *get_sh(u64 num) {
    auto header = (Header*)kernel_file_loc;
    return (Section_Header *)(kernel_file_loc + header->shoff + header->shentsize * num);
  }

  Program_Header *get_ph(u64 num) {
    auto header = (Header*)kernel_file_loc;
    return (Program_Header *)(kernel_file_loc + header->phoff + header->phentsize * num);
  }

  u64 load_elf_section(Section_Header const *sh, u8 *buf, u64 bufsize) {
    auto sz = bufsize;
    if(sh->size < sz)
      sz = sh->size;
    __builtin_memcpy(buf, kernel_file_loc + sh->offset, sz);
    return sz;
  }

  u64 load_elf_section(u64 num, u8 *buf, u64 bufsize, u64 load_offset) {
    auto sh = get_sh(num);
    auto sz = load_elf_section(sh, buf, bufsize);
    // TODO: Relocations
    return sz;
  }

  void load_elf_phdr(Program_Header const *ph, u64 load_offset) {
    __builtin_memcpy((void *)(load_offset + ph->vaddr), kernel_file_loc + ph->offset, ph->filesz);
    __builtin_memset((void *)(load_offset + ph->vaddr + ph->filesz), 0, ph->memsz - ph->filesz);

    page_section(ph->vaddr, load_offset + ph->vaddr, ph->memsz, {.write = (bool)(ph->flags&2), .execute = (bool)(ph->flags&1)});
    // TODO: Relocations
  }
}

u64 elf_entry() {
  return ((Header*)kernel_file_loc)->entry;
}

u64 load_elf_section(char const *section_name, u8 *buf, u64 bufsize, u64 load_offset) {
  auto header = (Header*)kernel_file_loc;
  auto string_table_size = get_sh(header->shstrndx)->size;

  u8 string_table[string_table_size];
  load_elf_section(get_sh(header->shstrndx), string_table, string_table_size);

  for(half sec = 0; sec < header->shnum; ++sec) {
    auto sh = get_sh(sec);
    if(__builtin_strcmp((char const *)&string_table[sh->name], section_name) == 0) {
      return load_elf_section(sec, buf, bufsize, load_offset);
    }
  }

  puts("Could not find section named '");
  puts(section_name);
  puts("'!\n");
  panic(nullptr);
}

void load_elf() {
  log_value("Kernel will be loaded at physical address ", kernel_load_base);

  auto header = (Header*)kernel_file_loc;

  u64 addr_low = ~0ULL;

  for(half phdr = 0; phdr < header->phnum; ++ phdr) {
    auto ph = get_ph(phdr);

    if(ph->type != 1)
      continue;

    if(ph->vaddr < addr_low)
      addr_low = ph->vaddr;
  }

  log_value("Lowest kernel address was ", addr_low);

  u64 const load_offset = kernel_load_base - addr_low;

  log_value("Loading kernel with physical offset ", load_offset);

  for(half phdr = 0; phdr < header->phnum; ++ phdr) {
    auto ph = get_ph(phdr);

    if(ph->type != 1)
      continue;

    load_elf_phdr(ph, load_offset);
  }
}
