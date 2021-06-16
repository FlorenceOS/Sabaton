ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
  none   PT_NULL FLAGS(0);
}

__kernel_file_loc = 0x4000000;
__dram_base       = 1024M;

SECTIONS {
  . = 0x40100000;
  .blob : {
    __blob_base = .;
    *(.text.entry)
    KEEP(*(.text.main))
    *(.text.smp_stub)
    KEEP(*(.text.smp_entry))
    *(.text*)

    . = ALIGN(8);
    PROVIDE(memmap_tag = .);
    QUAD(0x2187F79E8612DE07); /* Stivale2 memmap identifier */
    QUAD(0); /* Next */
    QUAD(6); /* Memory map entries */

    QUAD(0); /* MMIO base region */
    QUAD(__dram_base);
    LONG(2);
    LONG(0);

    *(.data.memmap);

    QUAD(0x8000000000); /* PCI-E high mmio (64 bit bar space) */
    QUAD(0x8000000000);
    LONG(2);
    LONG(0);

    *(.data*)
    *(.rodata*)
    *(.bss*)
    . = ALIGN(16);
    __blob_end = .;
  }

  . = ALIGN(4K);
  __pmm_base = .;

  .eh_frame : {
    *(.eh_frame*)
  }
}
