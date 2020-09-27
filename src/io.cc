#include "common.hh"

void print_hex_impl(unsigned long long num, int nibbles) {
  for(int i = nibbles - 1; i >= 0; -- i)
    putchar("0123456789ABCDEF"[(num >> (i * 4))&0xF]);
}
