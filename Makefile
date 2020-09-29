link ?= ld.lld
link := $(link) --gc-sections --no-dynamic-linker --build-id=none -static -nostdlib

objcopy ?= llvm-objcopy

assemble ?= clang -target aarch64-none-eabi
assemble := $(assemble) -c

cxx ?= clang -target aarch64-none-eabi
cxx := $(cxx) -c -ffunction-sections -fdata-sections -mgeneral-regs-only -mstrict-align -Oz -Wall -std=c++17

CommonSources := $(shell find src -maxdepth 1 -name '*.asm' -o -name '*.cc')
CommonHeaders := $(shell find src -maxdepth 1 -name '*.hh')
CommonObjects := $(patsubst src/%, build/%.o, $(CommonSources))

PlatformSources := $(shell find src/platform -maxdepth 1 -name '*.asm')
LinkerCommon    := $(shell find src/platform -maxdepth 1 -name '*_common.lds')

all: | $(patsubst src/platform/%.asm, out/%.bin, $(PlatformSources))

clean:
	rm -rfv build/
	rm -rfv out/

.PHONY: clean all

.SECONDARY:;

build/%.elf: src/platform/%.lds build/%.asm.o $(LinkerCommon) $(CommonObjects)
	@mkdir -p $(@D)
	$(link) -T $< $(filter %.o,$^) -o $@

build/%.bin: build/%.elf
	@mkdir -p $(@D)
	$(objcopy) -O binary --only-section .blob $< $@

build/%.asm.o: src/platform/%.asm
	@mkdir -p $(@D)
	$(assemble) $< -o $@

build/%.cc.o: src/%.cc $(CommonHeaders)
	@mkdir -p $(@D)
	$(cxx) $< -o $@ -Isrc

build/%.asm.o: src/%.asm
	@mkdir -p $(@D)
	$(assemble) $< -o $@

out/virt.bin: build/virt.bin
	@mkdir -p $(@D)
	cp $< $@ && truncate -s 64M $@
