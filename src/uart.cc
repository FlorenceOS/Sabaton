#include "common.hh"

extern "C" void putchar(char c);

extern "C" u32 uart_status_mask;
extern "C" u32 uart_status_value;
extern "C" u32 volatile *uart_reg;
extern "C" u32 volatile *uart_status;

extern "C" void putchar_raw(char c) {
  *uart_reg = c;
}

extern "C" void putchar_with_status(char c) {
  while((*uart_status & uart_status_mask) != uart_status_value);
  putchar_raw(c);
}

extern "C" void puts(char const *str) {
  while(*str)
    putchar(*str++);
}
