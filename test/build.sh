clang test/test.cc -target aarch64-none-eabi -c -mcmodel=tiny -ffunction-sections -fdata-sections -mgeneral-regs-only -mstrict-align -Oz -o test/test.o -fno-pic
ld.lld --no-dynamic-linker --build-id=none -static -nostdlib test/test.o -o test/test.elf -T test/test.lds --no-pie --apply-dynamic-relocs --Bstatic -z max-page-size=1
truncate -s 64M test/test.elf #do this for booting on virt
