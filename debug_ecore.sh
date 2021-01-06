#!/usr/bin/expect
set timeout 2
spawn telnet 127.0.0.1 4444
expect "> "
send "targets iphone.ecore0\r"
expect "> "
send "halt\r"
expect "> "
send "targets\r"
expect "> "
send "gdb_breakpoint_override hard\r"
expect "> "
send "exit\r"
spawn gdb-multiarch -ex "target remote :3333" -ex "file zig-cache/Sabaton_t8010_aarch64.elf" -ex "restore zig-cache/Sabaton_t8010_aarch64.elf.bin binary _start" -ex "set \$pc = _start"
interact
