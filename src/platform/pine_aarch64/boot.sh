setenv load_addr 41000000;
load mmc 1:2 ${load_addr} /Sabaton.elf;
setexpr sabaton_addr ${load_addr};
echo "[SABATON]" Loaded Sabaton.elf with size 0x${filesize} at 0x${load_addr};

setexpr load_addr ${load_addr} + ${filesize};
setexpr load_addr ${load_addr} + 00000fff;
setexpr load_addr ${load_addr} '&' fffff000;

load mmc 1:4 ${load_addr} /dtb;
setexpr dtb_addr ${load_addr};
setexpr dtb_size ${filesize};
echo "[SABATON]" Loaded dtb with size 0x${dtb_size} at 0x${dtb_addr};

setexpr load_addr ${load_addr} + ${filesize};
setexpr load_addr ${load_addr} + 00000fff;
setexpr load_addr ${load_addr} '&' fffff000;

load mmc 1:9 ${load_addr} /Zigger.elf;
setexpr krn_addr ${load_addr};
setexpr krn_size ${filesize};
echo "[SABATON]" Loaded user kernel with size 0x${krn_size} at 0x${krn_addr};

setexpr load_addr ${load_addr} + ${filesize};
setexpr load_addr ${load_addr} + 00000fff;
setexpr load_addr ${load_addr} '&' fffff000;

mw.b 40800000 0 20;

mw.l 40800000 ${dtb_addr};
mw.l 40800008 ${dtb_size};

mw.l 40800010 ${krn_addr};
mw.l 40800018 ${load_addr};

bootelf -p ${sabaton_addr};
