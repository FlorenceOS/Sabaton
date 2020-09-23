link ?= ld.lld
link := $(link) --gc-sections --no-dynamic-linker --build-id=none -static -nostdlib

objcopy ?= llvm-objcopy

assemble ?= clang
assemble := $(assemble) -c -target aarch64-none-eabi

cxx ?= clang
cxx := $(cxx) -c -target aarch64-none-eabi -mcmodel=tiny -ffunction-sections -fdata-sections -mgeneral-regs-only -mstrict-align -Oz

CommonSources := $(shell find src -maxdepth 1 -name '*.asm' -o -name '*.cc')
CommonHeaders := $(shell find src -maxdepth 1 -name '*.hh')
CommonObjects := $(patsubst src/%, build/%.o, $(CommonSources))

PlatformSources := $(shell find src/platform -maxdepth 1 -name '*.asm')

all: | $(patsubst src/platform/%.asm, out/%.bin, $(PlatformSources))

clean:
	rm -rfv build/
	rm -rfv out/

.PHONY: clean all

.SECONDARY:;

build/%.elf: src/platform/%.lds build/%.asm.o $(CommonObjects)
	@mkdir -p $(@D)
	$(link) -T $^ -o $@

out/%.bin: build/%.elf
	@mkdir -p $(@D)
	$(objcopy) -O binary -j .blob $< $@
	truncate -s 64M $@

build/%.asm.o: src/platform/%.asm
	@mkdir -p $(@D)
	$(assemble) $< -o $@

build/%.cc.o: src/%.cc $(CommonHeaders)
	@mkdir -p $(@D)
	$(cxx) $< -o $@ -Isrc

build/%.asm.o: src/%.asm
	@mkdir -p $(@D)
	$(assemble) $< -o $@
