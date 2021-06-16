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

    . = ALIGN(8);
    PROVIDE(memmap_tag = .);
    QUAD(0x2187F79E8612DE07); /* Stivale2 memmap identifier */
    QUAD(0); /* Next */
    QUAD(5); /* Memory map entries */

    QUAD(0); /* MMIO base region */
    QUAD(1024M);
    LONG(2);
    LONG(0);

    *(.data.memmap);

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
