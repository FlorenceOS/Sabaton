ENTRY(_start)

PHDRS {
    none   PT_NULL FLAGS(0);
}

SECTIONS {
    . = 0x18000000;
    .blob : {
        __blob_base = .;
        *(.text.entry)
        KEEP(*(.text.main))
        *(.text.smp_stub)
        KEEP(*(.text.smp_entry))
        *(.text*)

        #. = ALIGN(8);
        #PROVIDE(memmap_tag = .);
        #QUAD(0x2187F79E8612DE07); /* Stivale2 memmap identifier */
        #QUAD(0); /* Next */
        #QUAD(4); /* Memory map entries */

        #*(.data.memmap);

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
