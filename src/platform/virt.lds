ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
  none   PT_NULL FLAGS(0);
}

__kernel_file_loc = 0x4000000;
__dram_base       = 0x40000000;

putchar = putchar_raw;

platform_get_phys_high = devicetree_get_phys_high;
platform_enable_fb_smp = devicetree_enable_fb_smp;
platform_make_memmap   = devicetree_make_memmap;
stack_top = __blob_base;

SECTIONS {
  . = 0x40100000;
  .blob : {
    __blob_base = .;
    *(.text.entry)
    . = ALIGN(16);
    *(.text*)
    . = ALIGN(16);
    *(.data*)
    . = ALIGN(16);
    *(.rodata*)
    . = ALIGN(16);
    *(.bss*)
    . = ALIGN(0x40);
    __blob_end = .;
  }

  . = ALIGN(4K);
  __pmm_base = .;

  .eh_frame : {
    *(.eh_frame*)
  }
}
