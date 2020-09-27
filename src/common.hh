#pragma once

using u8 = unsigned char;
using u16 = unsigned short;
using u32 = unsigned int;
using u64 = unsigned long long;

extern "C" void putchar(char chr);
extern "C" void puts(char const *str);

void print_hex_impl(unsigned long long num, int nibbles);
#define print_hex(v) print_hex_impl((unsigned long long)(v), sizeof(v) * 2);
#define log_value(s, v) \
  do { \
    puts(s);\
    print_hex(v);\
    putchar('\n');\
  }while(0)

extern "C" u64 page_size;

void panic(char const *reason) __attribute__((noreturn));
