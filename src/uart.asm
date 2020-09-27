.section .text.putchar

.extern uart_loc

.global putchar
putchar:
  LDR X1, uart_loc
  STR W0, [X1]
  DSB ST
  RET

.section .text.puts
.global puts
puts:
  LDR X1, uart_loc
1:
  LDRB W2, [X0, #0]
  ADD X0, X0, #1
  CBZ W2, 2f
  STR W2, [X1]
  DSB ST
  B 1b
2:
  RET
