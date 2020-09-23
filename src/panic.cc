#include "common.hh"

void panic(char const *reason) {
  puts("PaNiC!!");
  if(reason) {
    puts(": ");
    puts(reason);
  }
  putchar('\n');
  while(1)
    asm("YIELD");
}
