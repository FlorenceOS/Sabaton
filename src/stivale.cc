#include "common.hh"
#include "elf.hh"
#include "pmm.hh"
#include "paging.hh"
#include "dtb.hh"

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

struct stivale_info {
  char bootloader_brand[64]{"Sabaton"};
  char bootloader_version[64]{"Let's just say it's not production ready"};

  stivale_tag *tags;
};

extern "C" u8 *kernel_file_loc;
extern "C" u64 dram_base;
extern "C" stivale_tag stivale_tags_head;

extern "C" void enter_kernel(stivale_info *, u64 stack, u64 entry) __attribute__((noreturn));
extern "C" void platform_add_tags();

extern "C" stivale_tag firmware_tag;

namespace {
  stivale_tag **tags_head;
  stivale_tag *last_tag = nullptr;

  auto parse_kernel_tags(stivale2hdr const &hdr) {
    struct {
      bool fb = false;
      bool smp = false;
    } r;
    for(auto tag = hdr.tags; tag; tag = tag->next) {
      switch(tag->ident) {
      case 0x3ECC1BC43D0F7971: { // Framebuffer
        if(((u16*)tag)[8])  panic("Nonzero width");
        if(((u16*)tag)[9])  panic("Nonzero height");
        if(((u16*)tag)[10]) panic("Nonzero bpp");
        r.fb = true;
        puts("Kernel requested framebuffer\n");
        break;
      }
      case 0x1AB015085F3273DF: {
        r.smp = true;
        puts("Kernel requested SMP\n");
        break;
      }
      default: log_value("Unknown tag identifier: 0x", tag->ident); break;
      }
    }
    return r;
  }
}

extern "C" void append_tag(stivale_tag *tag) {
  puts("Appending tag with identifier 0x");
  print_hex(tag->ident);
  puts(" (");
  char const *name;
  switch(tag->ident) {
    case 0xABB29BD49A2833FA:
      name = "DeviceTree";
      break;

    case 0xB813F9B8DBC78797:
      name = "UART";
      break;

    case 0x2187F79E8612DE07:
      name = "Memory map";
      break;

    case 0x359D837855E3858C:
      name = "Firmware";
      break;

    default:
      name = "UNKNOWN";
      break;
  }
  puts(name);
  puts(")\n");

  if(last_tag) {
    last_tag->next = tag;
  }
  else {
    *tags_head = tag;
  }
  last_tag = tag;
}

extern "C" void load_stivale_kernel() {
  puts("SABATON: Loading stivale from ELF at ");
  print_hex(kernel_file_loc);
  putchar('\n');

  stivale_info info{};
  tags_head = &info.tags;

  auto paging_roots = setup_paging();

  auto phys_high = devicetree_get_phys_high();

  page_section(0, 0, phys_high, {.write = 1, .execute = 1}, &paging_roots);

  apply_paging(&paging_roots);

  validate_elf();

  stivale2hdr hdr;

  load_elf_section(".stivale2hdr", (u8 *)&hdr, sizeof(hdr), 0);

  // @TODO: KASLR
  if(hdr.flags & 1) {
    panic("KASLR not implemented yet.");
  }

  load_elf();

  auto [fb, smp] = parse_kernel_tags(hdr);

  platform_add_tags();

  // This call seals the pmm, no pmm allocations after this are allowed.
  devicetree_parse(db, smp);

  append_tag(&firmware_tag);

  return enter_kernel(&info, hdr.stack, hdr.entry_point ?: elf_entry());
}
