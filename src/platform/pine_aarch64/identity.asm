  // Disable paging
  MRS X5, SCTLR_EL2
  AND X0, X5, #~1
  MSR SCTLR_EL2, X0
  DSB SY
  ISB SY

  MRS X0, TTBR0_EL2

  LDR X0, [X0]
  AND X0, X0, #0x0000FFFFFFFFF000
  LDR X0, [X0]
  AND X0, X0, #0x0000FFFFFFFFF000

  // MAIR should be FF440C0400 at this point (don't ask)
  // Identity map first 1G of dram
  // 1G PTE, memory, AttrIdx = 4
  MOVZ X2, (1024 * 1024 * 1024) >> 16, LSL #16
  MOVK X2, (1 << 0) | (4 << 2) | (1 << 5) | (1 << 10) | (2 << 8), LSL #0
  // 1G PTE, device, AttrIdx = 0
  MOVZ X1, (1 << 0) | (0 << 2) | (1 << 5) | (1 << 10) | (2 << 8)
  STP X1, X2, [X0]

  // Reenable paging
  MSR SCTLR_EL2, X5
  RET
