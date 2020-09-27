ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
  none   PT_NULL FLAGS(0);
  text   PT_LOAD FLAGS((1 << 2) | (1 << 0) /* Readable | Executable */);
  data   PT_LOAD FLAGS((1 << 2) | (1 << 1) /* Readable | Writeable  */);
  rodata PT_LOAD FLAGS((1 << 2)            /* Readable */);
}

SECTIONS {
  .stivale2hdr : {
    KEEP(*(.stivale2hdr))
  }:none

  .shstrtab : {
    *(.shstrtab)
  }:none

  . = 0xffffffff80000000;
  .text : ALIGN(64K) {
    *(.text*)
  }:text

  .data : ALIGN(64K) {
    *(.data*)
    *(.bss*)
  }:data

  .rodata : ALIGN(64K) {
    *(.rodata*)
  }:rodata

  /DISCARD/ : {
    *(*)
  }
}
