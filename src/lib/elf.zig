const std = @import("std");
const sabaton = @import("root").sabaton;

const LoadType = enum {
  MakePageTables,
  LoadDataPages,
};

const addr = u64;
const off = u64;
const half = u16;
const word = u32;
const xword = u64;

pub const elf64hdr = packed struct {
  ident: [16]u8,
  elf_type: half,
  machine: half,
  version: word,
  entry: addr,
  phoff: off,
  shoff: off,
  flags: word,
  ehsize: half,
  phentsize: half,
  phnum: half,
  shentsize: half,
  shnum: half,
  shstrndx: half,
};

pub const elf64shdr = packed struct {
  name: word,
  stype: word,
  flags: xword,
  vaddr: addr,
  offset: off,
  size: xword,
  link: word,
  info: word,
  addralign: xword,
  entsize: xword,
};

pub const elf64phdr = packed struct {
  phtype: word,
  flags: word,
  offset: off,
  vaddr: addr,
  paddr: addr,
  filesz: xword,
  memsz: xword,
  alignment: xword,
};

pub const Elf = struct {
  data: sabaton.platform.ElfType,
  shstrtab: ?[]u8 = null,

  pub fn init(self: *@This()) void {
    if(!std.mem.eql(u8, self.data[0..4], "\x7FELF")) {
      @panic("Invalid ELF magic!");
    }

    const shshstrtab = self.shdr(self.header().shstrndx);
    self.shstrtab = (self.data + shshstrtab.offset)[0..shshstrtab.size];
  }

  pub fn section_name(self: *@This(), offset: usize) [*:0]u8 {
    return @ptrCast([*:0]u8, &self.shstrtab.?[offset]);
  }

  pub fn header(self: *@This()) *elf64hdr {
    return @ptrCast(*elf64hdr, self.data);
  }

  pub fn shdr(self: *@This(), num: usize) *elf64shdr {
    const h = self.header();
    return @ptrCast(*elf64shdr, self.data + h.shoff + h.shentsize * num);
  }

  pub fn phdr(self: *@This(), num: usize) *elf64phdr {
    const h = self.header();
    return @ptrCast(*elf64phdr, self.data + h.phoff + h.phentsize * num);
  }

  pub fn load_section(self: *@This(), name: []const u8, buf: []u8) !void {
    var snum: usize = 0;
    const h = self.header();
    while(snum < h.shnum): (snum += 1) {
      const s = self.shdr(snum);
      const sname = self.section_name(s.name);

      if(std.mem.eql(u8, sname[0..name.len], name) and sname[name.len] == 0) {
        var load_size = s.size;
        if(load_size > buf.len)
          load_size = buf.len;

        @memcpy(buf.ptr, self.data + s.offset, load_size);

        return;
        // TODO: Relocations
      }
    }
    return error.HeaderNotFound;
  }

  pub fn load(self: *@This(), mempool_c: []align(4096) u8) void {
    const page_size = sabaton.platform.get_page_size();
    var mempool = mempool_c;

    var phnum: usize = 0;
    const h = self.header();
    while(phnum < h.phnum): (phnum += 1) {
      const ph = self.phdr(phnum);

      if(ph.phtype != 1)
        continue;

      if(sabaton.debug) {
        sabaton.log("Loading 0x{X} bytes at ELF offset 0x{X}\n", .{ph.filesz, ph.offset});
        sabaton.log("Memory size is 0x{X} and is backed by physical memory at 0x{X}\n", .{ph.memsz, @ptrToInt(mempool.ptr)});
      }

      @memcpy(mempool.ptr, self.data + ph.offset, ph.filesz);
      @memset(mempool.ptr + ph.filesz, 0, ph.memsz - ph.filesz);

      const perms = @intToEnum(sabaton.paging.Perms, @intCast(u3, ph.flags & 0x7));
      sabaton.paging.map(ph.vaddr, @ptrToInt(mempool.ptr), ph.memsz, perms, .memory, null, .CannotOverlap);

      // TODO: Relocations

      var used_bytes = ph.memsz;
      used_bytes += page_size - 1;
      used_bytes &= ~(page_size - 1);

      mempool.ptr = @alignCast(4096, mempool.ptr + used_bytes);
      mempool.len -= used_bytes;
    }

    if(sabaton.debug and mempool.len != 0) {
      sabaton.puts("Kernel overallocated??\n");
    }
  }

  pub fn paged_bytes(self: *@This()) usize {
    const page_size = sabaton.platform.get_page_size();
    var result: usize = 0;

    var phnum: usize = 0;
    const h = self.header();
    while(phnum < h.phnum): (phnum += 1) {
      const ph = self.phdr(phnum);

      if(ph.phtype != 1)
        continue;

      result += ph.memsz;
      result += page_size - 1;
      result &= ~(page_size - 1);
    }

    return result;
  }

  pub fn entry(self: *@This()) usize {
    const h = self.header();
    return h.entry;
  }
};
