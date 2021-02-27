setenv autostart no

load mmc "1:2" 80000000 /identity
go 80000000

load mmc "1:2" 40000000 /Sabaton.bin

setexpr load_addr 40020000
mw.l 40000010 ${load_addr}
load mmc "1:4" ${load_addr} /dtb
mw.l 40000018 ${filesize}

setexpr load_addr ${load_addr} '+' ${filesize}
setexpr load_addr ${load_addr} '+' 00000fff
setexpr load_addr ${load_addr} '&' fffff000

mw.l 40000020 ${load_addr}
load mmc "1:9" ${load_addr} /Kernel.elf

setexpr load_addr ${load_addr} '+' ${filesize}
setexpr load_addr ${load_addr} '+' 00000fff
setexpr load_addr ${load_addr} '&' fffff000

mw.l 40000028 ${load_addr}
go 40000030
