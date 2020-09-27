.global _start
.global uart_loc
.global platform_tags
.global kernel_load_base
.global kernel_file_loc
.global page_size
.global phys_head
.global dtb_loc
.global dram_base
.global platform_add_tags

.extern puts
.extern uart_location
.extern platform_init
.extern __blob_base
.extern __blob_end

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

  // Relocate ourselves
  ADR X0, _start
  LDR X1, relocation_base
  LDR X2, relocation_end

.relocate_loop:
  CMP X1, X2
  B.EQ .relocate_done

  // I also know how to write bzero like this :)
  LDP X3, X4, [X0, #0x00]
  STP X3, X4, [X1, #0x00]
  LDP X3, X4, [X0, #0x10]
  STP X3, X4, [X1, #0x10]
  LDP X3, X4, [X0, #0x20]
  STP X3, X4, [X1, #0x20]
  LDP X3, X4, [X0, #0x30]
  STP X3, X4, [X1, #0x30]

  ADD X0, X0, #0x40
  ADD X1, X1, #0x40

  B .relocate_loop
.relocate_done:

  // Jump to relocated code
  LDR X1, relocation_base
  ADD X1, X1, .cont - _start
  BR X1

.cont:

  // Set up a stack
  LDR X18, kernel_load_base
  MOV SP, X18

  BL platform_init
  B load_stivale_kernel

.section .data.stivale_tags
.balign 16
platform_tags:
devicetree_tag:
  .8byte 0xabb29bd49a2833fa // DeviceTree
  .8byte 0
  .8byte __dram_base
  .8byte 0x100000

.balign 16
uart_tag:
  .8byte 0xb813f9b8dbc78797 // u32 MMIO UART
  .8byte 0
uart_loc:
  .8byte 0x9000000

.section .text.platform_add_tags
platform_add_tags:
  STP X29, X30, [SP, #-0x10]!
  MOV X29, SP

  ADR X0, devicetree_tag
  BL append_tag

  LDP X29, X30, [SP], 0x10

  ADR X0, uart_tag
  B append_tag

.section .rodata
.balign 8
kernel_file_loc:
  .8byte __kernel_file_loc
relocation_base:
  .8byte __blob_base
relocation_end:
  .8byte __blob_end
dtb_loc:
dram_base:
  .8byte __dram_base
phys_head:
  .8byte __pmm_base
kernel_load_base:
  .8byte __kernel_load_base
page_size:
  .8byte 0x1000
