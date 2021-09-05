const std = @import("std");
const uefi = std.os.uefi;

const sabaton = @import("root").sabaton;

const locateConfiguration = @import("root").locateConfiguration;

pub fn init() callconv(.Inline) void {
    if (locateConfiguration(uefi.tables.ConfigurationTable.acpi_20_table_guid)) |tbl| {
        sabaton.add_rsdp(@ptrToInt(tbl));
        return;
    }

    if (locateConfiguration(uefi.tables.ConfigurationTable.acpi_10_table_guid)) |tbl| {
        sabaton.add_rsdp(@ptrToInt(tbl));
        return;
    }

    sabaton.puts("No ACPI table found!\n");
}
