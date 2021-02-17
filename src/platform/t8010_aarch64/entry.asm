.global _start

// SCTLR_EL1 is 0x3050198d on entry

.section .text.entry
_start:
  // Disable interrupts
  MSR DAIFSET, #0xF

  ADR X0, _start
  ADD X0, X0, #0x80000
  MOV SP, X0

//   // Disable cache
//   MRS X0, SCTLR_EL1
//   AND X0, X0, #~4
//   MSR SCTLR_EL1, X0

//   LDR X0, =__timer_base
//   BL map_device_memory
//   MOV W1, 0xA
//   STR W1, [X0, 0x88]

//   MOV W1, 0xFFFFFFFF
//   STP W1, W1, [X0, 0x8C]
//   STP W1, W1, [X0, 0x94]

  MOV  X0, #0x100F
  MSR  SCTLR_EL1, X0

//   LDR X0, =__timer_base
//   BL map_device_memory

//   // Enable UART
//   LDR X0, =__uart_base
//   BL map_device_memory

//   // rULCON0
//   MOV W1, 0x00000003 // 8 data bits, no parity, no stop bit
//   STR W1, [X0, #0x00]

//   // rUCON0
//   MOV W1, 0x00000005 | (1 << 10) // int/poll mode, no interrupts enabled, NCLK
//   STR W1, [X0, #0x04]

//   // rUFCON0
//   MOV W1, 0x00000000 // Disable fifos
//   STR W1, [X0, #0x08]

//   // rUMCON0
//   MOV W1, 0x00000000 // No flow control
//   STR W1, [X0, #0x0C]

//   // rUBRDIV0
//   MOV W1, 0x0000000C
//   STR W1, [X0, #0x28]

// 1:
//   DSB ST
//   MOV W1, 0x21
//   STR W1, [X0, #0x20]
//   B 1b

  B _main

// map_device_memory:
//   LSR X1, X0, #22
//   ADD X2, X1, #0xA0000
//   LSL X1, X1, #22
//   ADD X1, X1, #0x621
//   MOV X3, #0x180000000
//   STR X1, [X3, X2]
//   DSB SY
//   ISB
//   RET
