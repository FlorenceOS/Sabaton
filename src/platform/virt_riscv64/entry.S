.global _start

.section .text.entry
_start:
  // Disable interrupts
  //MSR DAIFSET, #0xF

  // Relocate ourselves
  AUIPC t0, %pcrel_hi(_start)
  LD t1, %lo(relocation_base)(t0)
  MV sp, t1
  LD t2, %lo(relocation_end)(t0)

reloc_loop:
  LD t3, (t0)
  SD t3, (t1)
  ADDI t0, t0, 8
  ADDI t1, t1, 8
  BLTU t1, t2, reloc_loop

  ADDI t0, sp, %lo(.cont)
  JR t0

.cont:
  J _main

.balign 8
relocation_base:
  .8byte __blob_base
relocation_end:
  .8byte __blob_end

.global devicetree_tag
.section .data.stivale_tags
.balign 8
platform_tags:
devicetree_tag:
  .8byte 0xabb29bd49a2833fa // DeviceTree
  .8byte 0
  .8byte __dram_base
  .8byte 0x100000

.balign 8
.global uart_tag
.global uart_reg
uart_tag:
  .8byte 0xb813f9b8dbc78797 // u32 MMIO UART
  .8byte 0
uart_reg:
  .8byte 0x10000000
