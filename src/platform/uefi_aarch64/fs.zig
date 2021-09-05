const std = @import("std");
const uefi = std.os.uefi;

const root = @import("root");
const sabaton = root.sabaton;
const toUtf16 = root.toUtf16;

pub fn loadFile(filesystem: *uefi.protocols.FileProtocol, comptime path: []const u8) ![]u8 {
    const utf16_path = comptime toUtf16(path);

    var file: *const uefi.protocols.FileProtocol = undefined;
    root.uefiVital(filesystem.open(&file, &utf16_path, uefi.protocols.FileProtocol.efi_file_mode_read, 0), "loadFile: open");

    var position = uefi.protocols.FileProtocol.efi_file_position_end_of_file;
    root.uefiVital(file.setPosition(position), "loadFile: setPosition(EOF)");
    root.uefiVital(file.getPosition(&position), "loadFile: getPosition(file size)");
    root.uefiVital(file.setPosition(0), "loadFile: setPosition(0)");

    const file_space = sabaton.vital(root.allocator.alloc(u8, position), "loadFile: Allocating file memory", true);
    var bufsz = file_space.len;

    root.uefiVital(file.read(&bufsz, file_space.ptr), "loadFile: read");

    return file_space;
}
