.global _start
.global uart_loc
.global platform_tags
.global kernel_load_base
.global kernel_file_loc
.global page_size

.extern puts
.extern uart_location

.section .text.entry
_start:
  // Disable interrupts
  MSR DAIFSET, #0xF

  // Enable UART
  LDR X0, uart_loc

  // IBRD
  MOV W1, 0x10
  STR W1, [X0, #0x24]

  // CR
  MOV W1, 0xC301
  STR W1, [X0, #0x30]

  LDR X18, kernel_load_base
  MOV SP, X18

  B load_stivale_kernel

.section .rodata.hello_str
hello_str:
  .asciz "Hello, world!\x0a"

.section .data.stivale_tags
.balign 16
platform_tags:
devicetree_tag:
  .8byte 0xabb29bd49a2833fa // DeviceTree
  .8byte uart_tag
  .8byte 0x40000000
  .8byte 0x100000

.balign 16
uart_tag:
  .8byte 0xb813f9b8dbc78797 // u32 MMIO UART
  .8byte 0
uart_loc:
  .8byte 0x9000000

.section .rodata.kernel_load_base
.balign 8
kernel_load_base:
  .8byte 0x40000000 + 0x100000
kernel_file_loc:
  .8byte 0x4000000

.section .rodata.page_size
.balign 8
page_size:
  .8byte 0x1000
