setenv autostart no

echo "[SABATON] Setting up identity map"
load mmc "1:4" 80000000 /identity
go 80000000

setexpr load_addr 40000000
echo "[SABATON] Loading Sabaton"
load mmc "1:4" ${load_addr} /Sabaton.bin

setexpr load_addr ${load_addr} '+' ${filesize}
setexpr load_addr ${load_addr} '+' 00004fff # 0x4000 bytes for stacks, 0x1000 per core
setexpr load_addr ${load_addr} '&' fffff000

echo "[SABATON] Loading DTB"
mw.l 40000010 ${load_addr}
load mmc "1:4" ${load_addr} /dtb
mw.l 40000018 ${filesize}

setexpr load_addr ${load_addr} '+' ${filesize}
setexpr load_addr ${load_addr} '+' 00000fff
setexpr load_addr ${load_addr} '&' fffff000

echo "[SABATON] Loading your kernel"
mw.l 40000020 ${load_addr}
load mmc "1:4" ${load_addr} /Kernel.elf

setexpr load_addr ${load_addr} '+' ${filesize}
setexpr load_addr ${load_addr} '+' 00000fff
setexpr load_addr ${load_addr} '&' fffff000

echo "[SABATON] Starting Sabaton..."
mw.l 40000028 ${load_addr}
go 40000030
