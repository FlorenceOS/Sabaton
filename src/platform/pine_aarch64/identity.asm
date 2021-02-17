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
  MOV X1, #0x40000000
  MOVK X1, (1 << 0) | (4 << 2) | (1 << 5) | (1 << 10) | (2 << 8)
  STR X1, [X0, #8]

  // Reenable paging
  MSR SCTLR_EL2, X5
  RET
