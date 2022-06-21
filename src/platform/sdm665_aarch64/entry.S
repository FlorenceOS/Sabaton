.global _start

.section .text.entry
_start:
	//ADR X0, evt
	//MSR VBAR_EL3, X0
	B _main
