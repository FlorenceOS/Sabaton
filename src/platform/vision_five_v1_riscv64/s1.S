.global _start
_start:
  li t0, 0x12440000 # UART3 
  li t2, 0x18001000 # Target addr

readb: # Clobbers t1, return in a0
  lw t1, 20(t0)
  andi t1, t1, 1
  beqz t1, readb
  lw a0, 0(t0)
  ret

binary_size:
