void validate_elf();
void load_elf();
u64 elf_entry();
u64 load_elf_section(char const *section_name, u8 *buf, u64 bufsize, u64 load_offset);
