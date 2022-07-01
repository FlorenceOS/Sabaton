ENTRY(_start)

PHDRS {
    none   PT_NULL FLAGS(0);
}

__kernel_file_loc = 0x4000000;
__dram_base       = 0x80000000;

SECTIONS {
    . = 0x80100000;
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
        QUAD(7); /* Memory map entries */

        QUAD(0); /* MMIO base region */
        QUAD(__dram_base);
        LONG(2);
        LONG(0);

        *(.data.memmap);

        QUAD(0x30000000); /* PCI ECAM */
        QUAD(0x10000000);
        LONG(2);
        LONG(0);

        QUAD(0x40000000); /* PCI-E high mmio (64 bit bar space) */
        QUAD(0x40000000);
        LONG(2);
        LONG(0);

        *(.data*)
        *(.sdata*)
        *(.rodata*)
        *(.bss*)
        *(.sbss*)
        . = ALIGN(16);
        __blob_end = .;
    }

    . = ALIGN(4K);
    __pmm_base = .;

    .eh_frame : {
        *(.eh_frame*)
    }
}
