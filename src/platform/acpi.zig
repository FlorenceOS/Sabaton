const sabaton = @import("root").sabaton;
const std = @import("std");

const RSDP = packed struct {
  signature: [8]u8,
  checksum: u8,
  oemid: [6]u8,
  revision: u8,
  rsdt_addr: u32,

  extended_length: u32,
  xsdt_addr: u64,
  extended_checksum: u8,
};

fn signature(name: []const u8) u32 {
  return std.mem.readInt(u32, name[0..4], sabaton.endian);
}

fn print_sig(table: []const u8) void {
  var offset: usize = 0;
  while(offset < 4) : (offset += 1) {
    sabaton.putchar(table[offset]);
  }
}

pub fn try_get_addr(tables: []u8, sig: []const u8) ?usize {
  const table = find_table(tables, signature(sig));
  return @ptrToInt((table orelse {
    if(sabaton.debug) {
      sabaton.puts("Couldn't find table with signature ");
      print_sig(sig);
      sabaton.putchar('\n');
    }
    return null;
  }).ptr);
}

fn parse_root_sdt(comptime T: type, addr: usize) !void {
  const sdt = try map_sdt(addr);

  var offset: u64 = 36;

  while(offset + @sizeOf(T) <= sdt.len): (offset += @sizeOf(T)) {
    try parse_sdt(std.mem.readInt(T, sdt.to_slice()[offset..][0..@sizeOf(T)], sabaton.endian));
  }
}

fn fixup_root(comptime T: type, root_table: []u8, acpi_tables_c: []u8) void {
  var acpi_tables = acpi_tables_c;
  var offset: u64 = 36;

  while(acpi_tables.len > 8) {
    const len = std.mem.readInt(u32, acpi_tables[4..8], sabaton.endian);
    if(len == 0) break;
    const sig = signature(acpi_tables);

    if(sabaton.debug) {
      sabaton.puts("Got table with signature ");
      print_sig(acpi_tables);
      sabaton.putchar('\n');
    }

    switch(sig) {
      // Ignore root tables
      signature("RSDT"), signature("XSDT") => { },

      // Nope, we don't point to this one either apparently.
      // https://github.com/qemu/qemu/blob/d0dddab40e472ba62b5f43f11cc7dba085dabe71/hw/arm/virt-acpi-build.c#L693
      signature("DSDT") => { },

      else => {
        // We add everything else
        // sabaton.log_hex("At offset ", offset);
        if(offset + @sizeOf(T) > root_table.len) {
          if(sabaton.debug) {
            sabaton.log_hex("Root table size is ", root_table.len);
            sabaton.puts("Can't fit this table pointer! :(\n");
            break;
          }
        } else {
          const ptr_bytes = root_table[offset..][0..@sizeOf(T)];
          const table_ptr = @intCast(u32, @ptrToInt(acpi_tables.ptr));
          std.mem.writeInt(T, ptr_bytes, table_ptr, sabaton.endian);
          offset += @sizeOf(T);
        }
      },
    }
    acpi_tables = acpi_tables[len..];
  }

  std.mem.writeInt(u32, root_table[4..][0..4], @intCast(u32, offset), sabaton.endian);
}

fn fixup_fadt(fadt: []u8, dsdt: []u8) void {
  // We have both a FADT and DSDT on ACPI >= 2, so
  // The FADT needs to point to the DSDT
  const dsdt_addr = @ptrToInt(dsdt.ptr);
  // Offsets: https://gcc.godbolt.org/z/KPWMaMqe5
  std.mem.writeIntNative(u64, fadt[140..][0..8], dsdt_addr);
  if(dsdt_addr < (1 << 32))
    std.mem.writeIntNative(u32, fadt[40..][0..4], @truncate(u32, dsdt_addr));
}

pub fn init(rsdp: []u8, tables_c: []u8) void {
  if(rsdp.len < @sizeOf(RSDP)) {
    if(sabaton.debug)
      sabaton.puts("RSDP too small, can't add.");
    return;
  }

  // Fixup RSDP
  const rsdp_val = @intToPtr(*RSDP, @ptrToInt(rsdp.ptr));

  var got_root = false;

  var fadt_opt: ?[]u8 = null;
  var dsdt_opt: ?[]u8 = null;

  var tables = tables_c;
  while(tables.len > 8) {
    const len = std.mem.readInt(u32, tables[4..8], sabaton.endian);
    if(len == 0) break;
    const table = tables[0..len];
    const sig = signature(table);

    switch(sig) {
      signature("RSDT") => {
        sabaton.puts("Found RSDT!\n");
        rsdp_val.rsdt_addr = @intCast(u32, @ptrToInt(table.ptr));
        got_root = true;
        fixup_root(u32, table, tables_c);
      },
      signature("XSDT") => {
        sabaton.puts("Found XSDT!\n");
        rsdp_val.xsdt_addr = @intCast(u64, @ptrToInt(table.ptr));
        got_root = true;
        fixup_root(u64, table, tables_c);
      },
      signature("FACP") => fadt_opt = table,
      signature("DSDT") => dsdt_opt = table,
      else => { },
    }

    tables = tables[len..];
  }

  if(got_root) {
    if(sabaton.debug) {
      sabaton.puts("Adding RSDP\n");
      sabaton.log("RSDP: {}\n", .{rsdp_val.*});
    }
    sabaton.add_rsdp(@ptrToInt(rsdp.ptr));

    if(rsdp_val.revision >= 2) {
      if(fadt_opt) |fadt| {
        if(dsdt_opt) |dsdt| {
          fixup_fadt(fadt, dsdt);
        }
      }
    }
  }
}
