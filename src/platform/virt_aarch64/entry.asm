.global _start

.section .text.entry
_start:
  // Disable interrupts
  MSR DAIFSET, #0xF

  // Enable UART
  LDR X0, uart_reg

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

  ADD X0, X0, #0x10
  ADD X1, X1, #0x10

  B .relocate_loop
.relocate_done:

  // Jump to relocated code
  LDR X1, relocation_base
  ADD X1, X1, .cont - _start
  BR X1

.cont:
  // Set up an early stack
  ADR X18, _start
  MOV SP, X18

  B _main

.global devicetree_tag
.global uart_tag
.global uart_reg
.section .data.stivale_tags
.balign 8
platform_tags:
devicetree_tag:
  .8byte 0xabb29bd49a2833fa // DeviceTree
  .8byte 0
  .8byte __dram_base
  .8byte 0x100000

.balign 8
uart_tag:
  .8byte 0xb813f9b8dbc78797 // u32 MMIO UART
  .8byte 0
uart_reg:
  .8byte 0x9000000

.global kernel_file_loc
.section .rodata
.balign 8
kernel_file_loc:
  .8byte __kernel_file_loc
relocation_base:
  .8byte __blob_base
relocation_end:
  .8byte __blob_end
