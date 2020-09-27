using u8 = unsigned char;
using u16 = unsigned short;
using u32 = unsigned int;
using u64 = unsigned long long;

void my_putchar(u64 uart_addr, char c) {
  *(u32 volatile *)uart_addr = c;
}

void my_puts(u64 uart_addr, char const *str) {
  while(*str)
    my_putchar(uart_addr, *str++);
}

void my_hello_world(u64 uart_addr) {
  my_puts(uart_addr, "Hello, world!\n");
}

struct stivale_tag {
  u64 ident;
  stivale_tag *next;
} __attribute__((packed));

struct stivale_info {
  char bootloader_brand[64];    // Bootloader null-terminated brand string
  char bootloader_version[64];  // Bootloader null-terminated version string
  stivale_tag *tags;
} __attribute__((packed));

u64 stivale_header[4] __attribute__((section(".stivale2hdr"))) {
  0,
  0,
  0,
  0,
};

extern "C" void _start(stivale_info *info) {
  for(auto tag = info->tags; tag; tag = tag->next) {
    if(tag->ident == 0xb813f9b8dbc78797) {
      my_hello_world(((u64*)tag)[2]);
    }
  }
  while(1) { }
}
