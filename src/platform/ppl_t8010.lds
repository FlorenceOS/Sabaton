__sram_base       = 0x180000000;
__dram_base       = 0x800000000;
__uart_base       = 0xA0C0000;

__dram_size       = 0x80000000;

__load_location   = __sram_base + 0x80000;

INCLUDE src/platform/ppl_common.lds