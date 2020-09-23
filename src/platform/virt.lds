ENTRY(_start)
OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)

PHDRS {
  none   PT_NULL FLAGS(0);
}

SECTIONS {
  . = 0;

  .blob : {
    *(.text.entry)
    *(.text*)
    *(.data*)
    *(.rodata*)
  }

  .strtab : {
    *(.strtab*) 
  }

  .symtab : {
    *(.symtab) 
  }

  .comment : {
    *(.comment*) 
  }

  .shstrtab : {
    *(.shstrtab*) 
  }

  /DISCARD/ : {
    *(*)
  }
}
