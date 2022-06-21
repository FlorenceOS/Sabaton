.global _start

.section .text.entry
_start:
// We enter this fucking beast of a platform in arm mode, not aarch64.
// Let's do something about that.
    .byte 0x17, 0x16, 0xA0, 0xE3 // mov.w r1, #0x1700000
    .byte 0x1C, 0x00, 0x8F, 0xE2 // addw  r0, pc, #0x1c  // ADR R0, go64
    .byte 0xA0, 0x00, 0x81, 0xE5 // str.w r0, [r1, #0xa0]
    .byte 0x4E, 0xF0, 0x7F, 0xF5 // dsb   st
    .byte 0x50, 0x0F, 0x1C, 0xEE // mrc   p15, #0, r0, c12, c0, #2
    .byte 0x03, 0x00, 0x80, 0xE3 // orr   r0, r0, #3
    .byte 0x50, 0x0F, 0x0C, 0xEE // mcr   p15, #0, r0, c12, c0, #2
    .byte 0x6F, 0xF0, 0x7F, 0xF5 // isb   sy
//1:
    .byte 0x03, 0xF0, 0x20, 0xE3 // wfi   
    .byte 0xFD, 0xFF, 0xFF, 0xEA // b 1b
go64:
    MOVZ X0, #0x3600
    MOVK X0, #0x016E, LSL #16
    MSR CNTFRQ_EL0, X0

    //         NS    IRQ    FIQ     EA    RES1   SMD    HCE    SIF     RW      ST      TWI     TWE
    MOV X0, #(0<<1)|(1<<1)|(1<<2)|(1<<3)|(3<<4)|(0<<7)|(1<<8)|(0<<9)|(1<<10)|(0<<11)|(0<<12)|(0<<13)
    MSR SCR_EL3, X0

    MRS X0, SCTLR_EL3
    ORR X0, X0, #(1 << 12) // icache
    ORR X0, X0, #(1 << 2) // dcache
    MSR SCTLR_EL3, X0

    MSR CPTR_EL3, XZR // Enable FP/SIMD

    // Stacc ptr
    MSR SPSel, #0
    ADR X0, __boot_stack
    MOV SP, X0

// .global devicetree_tag
// devicetree_tag:
//   .8byte 0xabb29bd49a2833fa // DeviceTree
//   .8byte 0
// dtb_loc:
//   .8byte 0
//   .8byte 0
// .global kernel_file_loc
// kernel_file_loc:
//   .8byte 0
// memhead:
//   .8byte 0

//   // Next usable physmem
//   LDR X0, memhead
//   ADR X5, pmm_head
//   STR X0, [X5]

//   // Copy page settings to EL1
//   MRS X1, SCTLR_EL2
//   MSR SCTLR_EL1, X1
//   MRS X1, TCR_EL2
//   MSR TCR_EL1, X1
//   MRS X1, MAIR_EL2
//   MSR MAIR_EL1, X1
//   MRS X1, TTBR0_EL2
//   MSR TTBR0_EL1, X1
//   MSR TTBR1_EL1, XZR

//   TLBI VMALLE1

//   BL el2_to_el1

//   // Stacc
//   MSR SPSel, #0
//   ADR X1, __boot_stack
//   MOV SP, X1

//   // Fall through to main

// .section .text
// .global el2_to_el1
// el2_to_el1:
//   // aarch64 in EL1
//   ORR X1, XZR, #(1 << 31)
//   ORR X1, X1,  #(1 << 1)
//   MSR HCR_EL2, X1

//   // Counters in EL1
//   MRS X1, CNTHCTL_EL2
//   ORR X1, X1, #3
//   MSR CNTHCTL_EL2, X1
//   MSR CNTVOFF_EL2, XZR

//   // FP/SIMD in EL1
//   MOV X1, #0x33FF
//   MSR CPTR_EL2, X1
//   MSR HSTR_EL2, XZR
//   MOV X1, #0x300000
//   MSR CPACR_EL1, X1

//   // Get the fuck out of EL2 into EL1
//   MSR ELR_EL2, LR
//   MOV X1, #0x3C5
//   MSR SPSR_EL2, X1
//   ERET
  
// .section .data
// // Allwinner A64 user manual:
// //  7.3.4: UART Controller Register List
// //  7.3.5: UART Register Description

// .global uart_tag
// .global uart_reg
// .global uart_status
// .global uart_status_mask
// .global uart_status_value
// .balign 8
// uart_tag:
//   .8byte 0xf77485dbfeb260f9 // u32 MMIO UART with status
//   .8byte 0
// uart_reg:
//   .8byte __uart_base + 0x00 // TX Holding Register
// uart_status:
//   .8byte __uart_base + 0x14 // Line Status Register
// uart_status_mask:
//   .4byte 0x00000040 // TX Holding Register Empty
// uart_status_value:
//   .4byte 0x00000040 // TX Holding Register Empty is set
