setenv loads_echo 1;
setenv autostart no;

mw.l 40000000 0 20;
load mmc "1:2" 40000000 /identity;
md.l 40000000 20;
go 40000000;

load mmc "1:2" 40000000 /Sabaton.bin;

setexpr load_addr 40010000;
mw.l 40000010 ${load_addr};
load mmc "1:4" ${load_addr} /dtb;
mw.l 40000018 ${filesize};

setexpr load_addr ${load_addr} '+' ${filesize};
setexpr load_addr ${load_addr} '+' 00000fff;
setexpr load_addr ${load_addr} '&' fffff000;

mw.l 40000020 ${load_addr};
load mmc "1:9" ${load_addr} /Kernel.elf;
load mmc "1:9" ${load_addr} /Kernel.elf;
load mmc "1:9" ${load_addr} /Kernel.elf;
load mmc "1:9" ${load_addr} /Kernel.elf;
load mmc "1:9" ${load_addr} /Kernel.elf;

setexpr load_addr ${load_addr} '+' ${filesize};
setexpr load_addr ${load_addr} '+' 00000fff;
setexpr load_addr ${load_addr} '&' fffff000;

mw.l 40000028 ${load_addr};

md.l 40000000 c;
go 40000030;
