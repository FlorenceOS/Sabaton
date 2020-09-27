#include "common.hh"

namespace {
  void detect_page_size() {
    u64 aa64mmfr0;

    asm(
      "MRS %[mmfasjf], ID_AA64MMFR0_EL1\n\t"
      : [mmfasjf] "=r" (aa64mmfr0)
    );

    if(((aa64mmfr0 >> 28) & 0x0F) == 0b0000) {
      page_size = 0x1000;
      return;
    }
    if(((aa64mmfr0 >> 20) & 0x0F) == 0b0001) {
      page_size = 0x4000;
      return;
    }
    if(((aa64mmfr0 >> 24) & 0x0F) == 0b0000) {
      page_size = 0x10000;
      return;
    }

    panic("Wtf page size");
  }
}

extern "C" void platform_init() {
  detect_page_size();
  log_value("Page size is ", page_size);
}