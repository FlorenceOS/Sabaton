.global enter_kernel

.section .text.enter_kernel
enter_kernel: // stivale_info *, u64 stack, u64 entry
  MOV SP, X1
  BR X2

.global framebuffer_tag
.global rsdp_tag
.global epoch_tag
.global firmware_tag

.global framebuffer_addr
.global framebuffer_width
.global framebuffer_height
.global framebuffer_pitch
.global framebuffer_bpp

.global rsdp_ptr

.global epoch_value

.section .data.framebuffer_tag
.balign 16
framebuffer_tag:
  .8byte 0x506461d2950408fa // Framebuffer
  .8byte 0
framebuffer_addr:
  .8byte 0
framebuffer_width:
  .2byte 0
framebuffer_height:
  .2byte 0
framebuffer_pitch:
  .2byte 0
framebuffer_bpp:
  .2byte 0

.section .data.rsdp_tag
.balign 16
rsdp_tag:
  .8byte 0x9e1786930a375e78 // RSDP
  .8byte 0
rsdp_ptr:
  .8byte 0

.section .data.epoch_tag
.balign 16
epoch_tag:
  .8byte 0x566a7bed888e1407 // Epoch
  .8byte 0
epoch_value:
  .8byte 0

.section .data.firmware_tag
.balign 16
firmware_tag:
  .8byte 0x359d837855e3858c // Firmware
  .8byte 0
  .8byte 0 // UEFI is probably the closest (no VGA text mode etc)
