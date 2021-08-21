const sabaton = @import("root").sabaton;
const std = @import("std");

var bus0base: usize = undefined;
var bus0size: usize = undefined;
var bar32base: usize = undefined;
var bar64base: usize = undefined;

fn pci_bars_callback(dev: Addr) bool {
    const header_type = dev.get_header_type();
    const num_bars: u8 = switch (header_type & 0x7F) {
        0x00 => 6,
        0x01 => 2,
        else => 0,
    };

    var bar_idx: u8 = 0;
    while (bar_idx < num_bars) : (bar_idx += 1) {
        const bar_bits = dev.read(u32, 0x10 + bar_idx * 4);
        dev.write(u32, 0x10 + bar_idx * 4, 0xFFFFFFFF);
        const bar_value = dev.read(u32, 0x10 + bar_idx * 4);

        if (bar_bits & 1 != 0)
            continue; // Not a memory BAR

        const is64 = ((bar_value & 0b110) >> 1) == 2;

        var bar_size = @as(u64, bar_value & 0xFFFFFFF0);
        if (is64) {
            dev.write(u32, 0x10 + (bar_idx + 1) * 4, 0xFFFFFFFF);
            bar_size |= @as(u64, dev.read(u32, 0x10 + (bar_idx + 1) * 4)) << 32;
        }

        // Negate BAR size
        bar_size = ~bar_size +% 1;

        if (!is64) {
            bar_size &= (1 << 32) - 1;
        }

        if (bar_size == 0)
            continue;

        var base = if (is64) &bar64base else &bar32base;

        // Align to BAR size
        base.* += bar_size - 1;
        base.* &= ~(bar_size - 1);

        if (sabaton.debug) {
            if (is64) {
                sabaton.puts("64 bit BAR: \n");
            } else {
                sabaton.puts("32 bit BAR: \n");
            }
            sabaton.log_hex("  BAR index: ", bar_idx);
            sabaton.log_hex("  BAR bits:  ", bar_bits);
            sabaton.log_hex("  BAR size:  ", bar_size);
            sabaton.log_hex("  BAR addr:  ", base.*);
        }

        // Write BAR
        dev.write(u32, 0x10 + bar_idx * 4, @truncate(u32, base.*) | bar_bits);
        if (is64) {
            dev.write(u32, 0x10 + (bar_idx + 1) * 4, @truncate(u32, base.* >> 32));
        }
        dev.write(u16, 4, 1 << 1);

        // Increment BAR pointer
        base.* += bar_size;

        bar_idx += @boolToInt(is64);
    }

    // We never want to stop iterating
    return false;
}

pub fn init_from_dtb(root: *sabaton.paging.Root) void {
    const pci_blob = sabaton.vital(sabaton.dtb.find("pcie@", "reg"), "Cannot find pci base dtb", true);
    bus0base = std.mem.readIntBig(u64, pci_blob[0..][0..8]);
    bus0size = std.mem.readIntBig(u64, pci_blob[8..][0..8]);

    if (sabaton.debug) {
        sabaton.log_hex("PCI config space base: ", bus0base);
        sabaton.log_hex("PCI config space size: ", bus0size);
    }

    sabaton.paging.map(bus0base, bus0base, bus0size, .rw, .mmio, root);
    sabaton.paging.map(bus0base + sabaton.upper_half_phys_base, bus0base, bus0size, .rw, .mmio, root);

    const bar_blob = sabaton.vital(sabaton.dtb.find("pcie@", "ranges"), "Cannot find pci ranges dtb", true);
    bar32base = std.mem.readIntBig(u64, bar_blob[0x28..][0..8]);
    bar64base = std.mem.readIntBig(u64, bar_blob[0x3C..][0..8]);

    const bar32size = std.mem.readIntBig(u64, bar_blob[0x30..][0..8]);
    const bar64size = std.mem.readIntBig(u64, bar_blob[0x44..][0..8]);

    if (sabaton.debug) {
        sabaton.log_hex("PCI BAR32 base: ", bar32base);
        sabaton.log_hex("PCI BAR32 size: ", bar32size);
        sabaton.log_hex("PCI BAR64 base: ", bar64base);
        sabaton.log_hex("PCI BAR64 size: ", bar64size);
    }

    // This should already be present in mmio region, if it's not, open an issue.
    // sabaton.paging.map(bar32base, bar32base, bar32size, .rw, .mmio, root);
    // sabaton.paging.map(bar32base + sabaton.upper_half_phys_base, bar32base, bar32size, .rw, .mmio, root);

    sabaton.paging.map(bar64base, bar64size, bus0size, .rw, .mmio, root);
    sabaton.paging.map(bar64base + sabaton.upper_half_phys_base, bar64size, bar64size, .rw, .mmio, root);

    _ = scan(pci_bars_callback);
}

pub const Addr = struct {
    bus: u8,
    device: u5,
    function: u3,

    fn mmio(self: @This(), offset: u8) u64 {
        return bus0base + (@as(u64, self.device) << 15 | @as(u64, self.function) << 12 | @as(u64, offset));
    }

    pub fn read(self: @This(), comptime T: type, offset: u8) T {
        return @intToPtr(*volatile T, self.mmio(offset)).*;
    }

    pub fn write(self: @This(), comptime T: type, offset: u8, value: T) void {
        @intToPtr(*volatile T, self.mmio(offset)).* = value;
    }

    pub fn get_vendor_id(self: @This()) u16 {
        return self.read(u16, 0x00);
    }
    pub fn get_product_id(self: @This()) u16 {
        return self.read(u16, 0x02);
    }
    pub fn get_class(self: @This()) u8 {
        return self.read(u8, 0x0B);
    }
    pub fn get_subclass(self: @This()) u8 {
        return self.read(u8, 0x0A);
    }
    pub fn get_progif(self: @This()) u8 {
        return self.read(u8, 0x09);
    }
    pub fn get_header_type(self: @This()) u8 {
        return self.read(u8, 0x0E);
    }
};

fn device_scan(callback: fn (Addr) bool, bus: u8, device: u5) bool {
    var addr: Addr = .{
        .bus = bus,
        .device = device,
        .function = 0,
    };

    if (addr.get_vendor_id() == 0xFFFF)
        return false; // Device not present, ignore

    if (callback(addr))
        return true;

    if (addr.get_header_type() & 0x80 == 0)
        return false; // Not multifunction device, ignore

    addr.function += 1;

    while (addr.function < (1 << 3)) : (addr.function += 1) {
        if (callback(addr))
            return true;
    }

    return false;
}

fn bus_scan(callback: fn (Addr) bool, bus: u8) bool {
    var device: usize = 0;
    while (device < (1 << 5)) : (device += 1) {
        if (device_scan(callback, bus, @truncate(u5, device)))
            return true;
    }
    return false;
}

pub fn scan(callback: fn (Addr) bool) bool {
    return bus_scan(callback, 0);
}
