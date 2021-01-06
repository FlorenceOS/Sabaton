ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
  none   PT_NULL FLAGS(0);
  blob   PT_LOAD FLAGS(7);
}

__uart_base = 0x1C28000;
__dram_base = 0x40000000;
__pmm_base = 0;

SECTIONS {
  . = 0x40000000;
  .blob : {
    __blob_base = .;
    *(.text.entry)
    *(.text*)
    *(.data*)
    *(.rodata*)
    *(.bss*)
    __blob_end = .;
  }: blob

  /DISCARD/ : {
    *(.eh_frame*)
  }
}
