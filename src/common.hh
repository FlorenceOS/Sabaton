#pragma once

using u8 = unsigned char;
using u16 = unsigned short;
using u32 = unsigned int;
using u64 = unsigned long long;

extern "C" void putchar(char chr);
extern "C" void puts(char const *str);

inline void print_hex_impl(unsigned long long num, int nibbles) { for(int i = nibbles - 1; i >= 0; -- i) putchar("0123456789ABCDEF"[(num >> (i * 4))&0xF]); }
#define print_hex(v) print_hex_impl((unsigned long long)(v), sizeof(v) * 2);
#define log_value(s, v) \
  do { \
    puts(s);\
    print_hex(v);\
    putchar('\n');\
  }while(0)

void panic(char const *reason) __attribute__((noreturn));

struct File;

File *file_open(char const *path);
void file_read(u8 *buf, File *f, u64 size);
u64 file_size(File *f);
