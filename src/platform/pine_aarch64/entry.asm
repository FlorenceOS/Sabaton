.global _start

.section .text.entry
_start:
.global devicetree_tag
devicetree_tag:
  .8byte 0xabb29bd49a2833fa // DeviceTree
  .8byte 0
dtb_loc:
  .8byte 0
  .8byte 0
.global kernel_file_loc
kernel_file_loc:
  .8byte 0
memhead:
  .8byte 0

  // Next usable physmem
  LDR X0, memhead
  ADR X5, pmm_head
  STR X0, [X5]

  // aarch64 in EL1
  MOV X1, XZR
  ORR X1, X1, #(1 << 31)
  ORR X1, X1, #(1 << 1)
  MSR HCR_EL2, X1

  // Counters in EL1
  MRS X1, CNTHCTL_EL2
  ORR X1, X1, #3
  MSR CNTHCTL_EL2, X1
  MSR CNTVOFF_EL2, XZR

  // FP/SIMD in EL1
  MOV X1, #0x33FF
  MSR CPTR_EL2, X1
  MSR HSTR_EL2, XZR
  MOV X1, #0x300000
  MSR CPACR_EL1, X1

  // Copy page settings to EL1
  MRS X1, SCTLR_EL2
  MSR SCTLR_EL1, X1
  MRS X1, TCR_EL2
  MSR TCR_EL1, X1
  MRS X1, MAIR_EL2
  MSR MAIR_EL1, X1
  MRS X1, TTBR0_EL2
  MSR TTBR0_EL1, X1
  MSR TTBR1_EL1, XZR

  TLBI VMALLE1

  // Get the fuck out of EL2 into EL1
  ADR X1, el1
  MSR ELR_EL2, X1
  MOV X1, #0x3C5
  MSR SPSR_EL2, X1
  ERET
el1:
  // Stacc just before the dtb
  LDR X1, dtb_loc
  MOV SP, X1

  // Fall through to main
  
.section .data
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
