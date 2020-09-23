.global stivale_tags_head

.extern device_tags

.section .data.stivale_tags
.balign 16
stivale_tags_head:
command_line_tag:
  .8byte 0xe5e76a1b4597a781 // Command line
  .8byte memory_map_tag
  .8byte 0

.balign 16
memory_map_tag:
  .8byte 0x2187f79e8612de07 // Memory map
  .8byte framebuffer_tag
  .8byte 0
  .8byte 0

.balign 16
framebuffer_tag:
  .8byte 0x506461d2950408fa // Framebuffer
  .8byte modules_tag
  .8byte 0
  .2byte 0
  .2byte 0
  .2byte 0
  .2byte 0

.balign 16
modules_tag:
  .8byte 0x4b6fe466aade04ce // Modules
  .8byte rsdp_tag
  .8byte 0
  .8byte 0

.balign 16
rsdp_tag:
  .8byte 0x9e1786930a375e78 // RSDP
  .8byte epoch_tag
  .8byte 0

.balign 16
epoch_tag:
  .8byte 0x566a7bed888e1407 // Epoch
  .8byte firmware_tag
  .8byte 0
  .8byte 0

.balign 16
firmware_tag:
  .8byte 0x359d837855e3858c // Firmware
  .8byte smp_tag
  .8byte 0 // UEFI is probably the closest (no VGA text mode etc)

.balign 16
smp_tag:
  .8byte 0x34d1d96339647025
  .8byte device_tags
  .8byte 0
  .8byte 0
