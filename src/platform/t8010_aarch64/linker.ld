ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
  none   PT_NULL FLAGS(0);
}

__io_base         = 0x200000000;
__uart_base       = __io_base + 0xA0C0000;
__timer_base      = __io_base + 0xF140000;

__dram_base       = 0x800000000;

SECTIONS {
  . = 0x180018000;
  .blob : {
    __blob_base = .;
    *(.text.entry)
    *(.text*)
    *(.data*)
    *(.rodata*)
    *(.bss*)
    . = ALIGN(16);
    __blob_end = .;
  }

  . = ALIGN(16K);
  __pmm_base = .;

  .eh_frame : {
    *(.eh_frame*)
  }
}
