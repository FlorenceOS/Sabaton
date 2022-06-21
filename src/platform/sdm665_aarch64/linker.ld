ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
    none   PT_NULL FLAGS(0);
    blob   PT_LOAD FLAGS(7);
}

__sram_base = 0xC100000;
__sram_size = 0x0200000;

__dram_base = 0x45E10000;
__dram_size = 0x20000000;

__pmm_base = __dram_base;

SECTIONS {
    . = __sram_base;
    __blob_base = .;
    .blob : {
        *(.text.entry)

        . = ALIGN(8);
        PROVIDE(memmap_tag = .);
        QUAD(0x2187F79E8612DE07); /* Stivale2 memmap identifier */
        QUAD(0); /* Next */
        QUAD(5); /* Memory map entries */

        QUAD(0); /* MMIO base region */
        QUAD(0xC000000);
        LONG(2);
        LONG(0);

        QUAD(__sram_base); /* SRAM region */
        QUAD(__sram_base + __sram_size);
        LONG(0x1000); /* Reclaimable (Should it be?) */
        LONG(0);

        *(.data.memmap);

        *(.data*)
        *(.rodata*)
        *(.bss*)
        *(.COMMON)
        . = ALIGN(0x800);
        vbar = .;
        *(.text.vbar)
        *(.text*)
        #. = ALIGN(0x800);
        #*(.debugger*)
    }: blob
    __blob_end = .;
    . = ALIGN(4K);
    . += 4K;
    __boot_stack = .;
    . += 4K;
    __debugger_stack = .;

    /DISCARD/ : {
        *(.eh_frame*)
    }
}
