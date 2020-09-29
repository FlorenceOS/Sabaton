#include "common.hh"

#include "stivale.hh"
#include "align.hh"
#include "pmm.hh"

template<typename T>
u64 read_be(u8 *ptr);

template<> u64 read_be<u8>(u8 *ptr) { return *ptr; }
template<> u64 read_be<u16>(u8 *ptr) { return (read_be<u8>(ptr) << 8) | read_be<u8>(ptr + 1); }
template<> u64 read_be<u32>(u8 *ptr) { return (read_be<u16>(ptr) << 16) | read_be<u16>(ptr + 2); }
template<> u64 read_be<u64>(u8 *ptr) { return (read_be<u32>(ptr) << 32) | read_be<u32>(ptr + 4); }

template<typename T>
struct BigEndian {
  T dummy;
  operator T() const { return read_be<T>((u8 *)this); };
};

extern "C" u8 *dtb_loc;
extern "C" u64 dram_base;

struct Header {
  BigEndian<u32> magic;
  BigEndian<u32> totalsize;
  BigEndian<u32> off_dt_struct;
  BigEndian<u32> off_dt_strings;
  BigEndian<u32> off_mem_rsvmap;
  BigEndian<u32> version;
  BigEndian<u32> last_comp_version;
  BigEndian<u32> boot_cpuid_phys;
  BigEndian<u32> size_dt_strings;
  BigEndian<u32> size_dt_struct;
};

struct rsvmap_entry {
  BigEndian<u64> base;
  BigEndian<u64> size;
};

//#define DT_VERBOSE

namespace {
  void parse_dt(u64 *phys_high, bool init_fb, bool boot_aps, bool make_memmap) {
    auto header = (Header *)dtb_loc;

    if(header->magic != 0xD00DFEED)
      panic("DTB magic");

    auto name = [&](u32 nameoff) -> char const * {
      return (char const *)(dtb_loc + header->off_dt_strings + nameoff);
    };

    {
      auto rsvmap = (rsvmap_entry *)(dtb_loc + header->off_mem_rsvmap);
      for(; rsvmap->base && rsvmap->size; ++rsvmap) {
        log_value("rsvbase", rsvmap->base);
        log_value("rsvsize", rsvmap->size);
      }
    }

    {
      auto       ptr = (BigEndian<u32> *)(dtb_loc + header->off_dt_struct);
      auto const end = (BigEndian<u32> *)(dtb_loc + header->off_dt_struct + header->size_dt_struct - 1);

#ifdef DT_VERBOSE
      int depth = 0;

      auto drawdepth = [&]() {
        for(int i = 0; i < depth; ++ i)
          putchar(' ');
      };
#endif

      bool found_dram = false;
      bool inited_fb = false;
      bool aps_booted = false;

      auto looking_for_dram = [&]() {
        if(found_dram)
          return false;
        return phys_high || make_memmap;
      };

      auto looking_for_framebuffer = [&]() {
        return init_fb && !inited_fb;
      };

      auto looking_for_cpus = [&]() {
        return boot_aps && !aps_booted;
      };

      auto needs_to_parse = [&]() {
        return looking_for_dram() || looking_for_framebuffer() || looking_for_cpus();
      };

      bool is_in_memory = false;

      for(; needs_to_parse() && ptr < end;) {
        switch(*ptr++) {
        case 0x00000001: { // FDT_BEGIN_NODE
          auto const str = (char const *)ptr;
          u32 const slen = align_up(__builtin_strlen(str) + 1, 4ul);

          ptr += slen/4;

          if(looking_for_dram()) {
            if(__builtin_strncmp(str, "memory", 6) == 0) {
              is_in_memory = true;
            }
          }

#ifdef DT_VERBOSE
          drawdepth();
          puts("Node: ");
          puts(str);
          putchar('\n');
          depth += 1;
#endif

          break;
        }

        case 0x00000002: { // FDT_END_NODE
          is_in_memory = false;
#ifdef DT_VERBOSE
          depth -= 1;
#endif
          break;
        }

        case 0x00000003: { // FDT_PROP
          u32 const len = align_up((u32)*ptr++, 4u);
          u32 const nameoff = *ptr++;
          auto prop_name = name(nameoff);

#ifdef DT_VERBOSE
          drawdepth();
          puts("Property: ");
          puts(prop_name);
          putchar('\n');
#endif

          if(looking_for_dram() && is_in_memory && __builtin_strcmp(prop_name, "reg") == 0) {
            found_dram = true;
            auto vals = (BigEndian<u64> *)ptr;
            u64 base = vals[0];
            u64 size = vals[1];

            if(phys_high && dram_base == base)
              *phys_high = base + size;
            if(make_memmap) {
              auto const tag = (u64 *)calloc_phys(8 * 9, false);
              auto output = tag;
              *output++ = 0x2187f79e8612de07;
              // Next ptr
              output += 1;
              // Entries in memmap
              *output++ = 2;

              u64 usable_base = seal_phys();
              u64 reclaimable_size = base - usable_base;
              
              // Bootloader reclaimable
              *output++ = base;
              *output++ = reclaimable_size;
              *output++ = 0x1000;

              // Usable memory
              *output++ = usable_base;
              *output++ = size - reclaimable_size;
              *output++ = 1;

              append_tag((stivale_tag *)tag);
            }
          }

          ptr += len/4;
          break;
        }

        case 0x00000004: // FDT_NOP
          break;

        case 0x00000009: // FDT_END
          return;

        default:
#ifdef DT_VERBOSE
          drawdepth();
#endif
          log_value("Unknown opcode: ", *ptr);
          break;
        }
      }

      if(looking_for_dram()) {
        panic("Could not find dram in devicetree!");
      }

      if(looking_for_cpus()) {
        puts("Warning: Could not find CPUs in devicetree.\n");
      }

      if(looking_for_framebuffer()) {
        puts("Warning: Could not find framebuffer in devicetree.\n");
      }
     }

    if(init_fb) {

    }

    if(boot_aps) {

    }

    return;
  }
}

extern "C" stivale_tag framebuffer_tag;
extern "C" stivale_tag rsdp_tag;
extern "C" stivale_tag epoch_tag;

extern "C" u64 devicetree_get_phys_high() {
  u64 phys_high;
  parse_dt(&phys_high, false, false, 0);
  log_value("Physical high is ", phys_high);
  return phys_high;
}

extern "C" void devicetree_enable_fb_smp(bool init_fb, bool boot_aps) {
  parse_dt(nullptr, init_fb, boot_aps, false);
}

extern "C" void devicetree_make_memmap() {
  parse_dt(nullptr, false, false, true);
}
