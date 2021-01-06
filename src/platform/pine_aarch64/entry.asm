.global _start

.section .text.entry
_start:
  // Disable interrupts
  MSR DAIFSET, 0xF

  // Disable paging and cache
  MRS X0, SCTLR_EL1
  AND X0, X0, ~3
  MSR SCTLR_EL1, X0

  MOV X0, 0x41000000
  MOV SP, X0

  // Get memory layout from u-boot script
  MOV X0, 0x40800000
  LDP X1, X2, [X0, #0x00]
  ADR X5, dtb_loc
  STP X1, X2, [X5, #0x00]

  LDP X1, X2, [X0, #0x10]
  STR X1, [X5, kernel_file_loc - dtb_loc]

  // Next usable physmem
  ADD X2, X2, X1
  ADR X5, pmm_head
  STR X2, [X5]

  B _main

.section .data

.global devicetree_tag
.balign 16
devicetree_tag:
  .8byte 0xabb29bd49a2833fa // DeviceTree
  .8byte 0
dtb_loc:
  .8byte 0
  .8byte 0

// Allwinner A64 user manual:
//  7.3.4: UART Controller Register List
//  7.3.5: UART Register Description

.global uart_tag
.global uart_reg
.global uart_status
.global uart_status_mask
.global uart_status_value
.balign 8
uart_tag:
  .8byte 0xf77485dbfeb260f9 // u32 MMIO UART with status
  .8byte 0
uart_reg:
  .8byte __uart_base + 0x00 // TX Holding Register
uart_status:
  .8byte __uart_base + 0x14 // Line Status Register
uart_status_mask:
  .4byte 0x00000040 // TX Holding Register Empty
uart_status_value:
  .4byte 0x00000040 // TX Holding Register Empty is set

.global kernel_file_loc
.balign 8
kernel_file_loc:
  .8byte 0
