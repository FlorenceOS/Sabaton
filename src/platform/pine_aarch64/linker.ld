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
  __blob_base = .;
  .blob : {
    *(.text.entry)
    KEEP(*(.text.main))
    *(.text.smp_stub)
    KEEP(*(.text.smp_entry))
    *(.text*)
    *(.data*)
    *(.rodata*)
    *(.bss*)
    *(.COMMON)
  }: blob
  __blob_end = .;
  . = ALIGN(4K);
  . += 4K;
  __boot_stack = .;

  /DISCARD/ : {
    *(.eh_frame*)
  }
}
