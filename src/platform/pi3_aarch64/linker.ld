ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
    none   PT_NULL FLAGS(0);
}
__dram_base = 0;

SECTIONS {
    /*
      This is actually loaded at 0x80000, but the first thing we do is relocating.
      It's at 0x1000 instead of 0 because the stack is allocated before _start
    */
    . = 0x1000;
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
        QUAD(5); /* Memory map entries */

        *(.data.memmap);

        QUAD(0x3C000000); /* MMIO base region */
        QUAD(0x04000000);
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
