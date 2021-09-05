pub const sabaton = @import("../../sabaton.zig");

const std = @import("std");
const uefi = std.os.uefi;

const fs = @import("fs.zig");

var conout: ?*uefi.protocols.SimpleTextOutputProtocol = null;

pub const io = struct {
    pub fn putchar(ch: u8) void {
        if (conout) |co| {
            if (ch == '\n')
                putchar('\r');
            const chrarr = [2]u16{ ch, 0 };
            _ = co.outputString(@ptrCast(*const [1:0]u16, &chrarr));
        }
    }
};

pub fn locateProtocol(comptime T: type) callconv(.Inline) ?*T {
    var ptr: *T = undefined;
    const guid: std.os.uefi.Guid align(8) = T.guid;
    if (.Success != uefi.system_table.boot_services.?.locateProtocol(&guid, null, @ptrCast(*?*c_void, &ptr))) {
        return null;
    }
    return ptr;
}

pub fn handleProtocol(handle: uefi.Handle, comptime T: type) callconv(.Inline) ?*T {
    var ptr: *T = undefined;
    const guid: std.os.uefi.Guid align(8) = T.guid;
    if (.Success != uefi.system_table.boot_services.?.handleProtocol(handle, &guid, @ptrCast(*?*c_void, &ptr))) {
        return null;
    }
    return ptr;
}

pub fn locateConfiguration(guid: uefi.Guid) ?*c_void {
    const entries = uefi.system_table.configuration_table[0..uefi.system_table.number_of_table_entries];
    for (entries) |e| {
        if (e.vendor_guid.eql(guid))
            return e.vendor_table;
    }
    return null;
}

pub fn toUtf16(comptime ascii: []const u8) [ascii.len:0]u16 {
    const curr = [1:0]u16{ascii[0]};
    if (ascii.len == 1) return curr;
    return curr ++ toUtf16(ascii[1..]);
}

pub fn uefiVital(status: uefi.Status, context: [*:0]const u8) void {
    switch (status) {
        .Success => {},
        else => |t| {
            sabaton.puts("Fatal error: ");
            sabaton.print_str(@tagName(t));
            sabaton.puts(", while: ");
            sabaton.puts(context);
            @panic("");
        },
    }
}

pub fn uefiVitalFail(status: uefi.Status, context: [*:0]const u8) noreturn {
    uefiVital(status, context);
    unreachable;
}

pub const Alloc = struct {
    stdalloc: std.mem.Allocator = .{
        .allocFn = allocate,
        .resizeFn = resize,
    },

    fn allocate(self_alloc: *std.mem.Allocator, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) std.mem.Allocator.Error![]u8 {
        const self = @fieldParentPtr(@This(), "stdalloc", self_alloc);

        var ptr: [*]u8 = undefined;

        if (ptr_align > 8) {
            uefiVital(uefi.system_table.boot_services.?.allocatePages(.AllocateAnyPages, .LoaderData, (len + 0xFFF) / 0x1000, @ptrCast(*[*]align(0x1000) u8, &ptr)), "Allocating pages");
        } else {
            uefiVital(uefi.system_table.boot_services.?.allocatePool(.LoaderData, len, @ptrCast(*[*]align(8) u8, &ptr)), "Allocating memory");
        }

        return ptr[0..len];
    }

    fn resize(self_alloc: *std.mem.Allocator, old_mem: []u8, old_align: u29, new_size: usize, len_align: u29, ret_addr: usize) std.mem.Allocator.Error!usize {
        const self = @fieldParentPtr(@This(), "stdalloc", self_alloc);
        sabaton.puts("allocator resize!!\n");
        @panic("");
    }
};

var allocator_impl = Alloc{};
pub var allocator = &allocator_impl.stdalloc;

fn findFSRoot() *uefi.protocols.FileProtocol {
    // zig fmt: off
    const loaded_image = handleProtocol(uefi.handle, uefi.protocols.LoadedImageProtocol)
        orelse @panic("findFSRoot(): Could not get loaded image protocol");

    const device = loaded_image.device_handle orelse @panic("findFSRoot(): No loaded file device handle!");

    const simple_file_proto = handleProtocol(device, uefi.protocols.SimpleFileSystemProtocol)
        orelse @panic("findFSRoot(): Could not get simple file system");
    // zig fmt: on

    var file_proto: *uefi.protocols.FileProtocol = undefined;
    switch (simple_file_proto.openVolume(&file_proto)) {
        .Success => return file_proto,
        else => @panic("findFSRoot(): openVolume failed!"),
    }
}

var page_size: u64 = 0x1000;

pub fn get_page_size() u64 {
    return page_size;
}

var paging_root: sabaton.paging.Root = undefined;

pub fn main() noreturn {
    if (locateProtocol(uefi.protocols.SimpleTextOutputProtocol)) |proto| {
        conout = proto;
    }

    page_size = sabaton.paging.detect_page_size();

    // Find RSDP
    @import("acpi.zig").init();

    // Find the root FS we booted from
    const root = findFSRoot();

    const kernel_file_bytes = sabaton.vital(fs.loadFile(root, "kernel.elf"), "Loading kernel ELF (esp\\kernel.elf)", true);

    // Create the stivale2 tag for the kernel ELF file
    sabaton.kernel_file_tag.kernel_addr = @ptrToInt(kernel_file_bytes.ptr);
    sabaton.add_tag(&sabaton.kernel_file_tag.tag);

    var kernel_elf_file = sabaton.Elf{
        .data = kernel_file_bytes.ptr,
    };
    kernel_elf_file.init();

    var kernel_stivale2_header: sabaton.Stivale2hdr = undefined;
    _ = sabaton.vital(
        kernel_elf_file.load_section(".stivale2hdr", sabaton.util.to_byte_slice(&kernel_stivale2_header)),
        "loading .stivale2hdr",
        true,
    );

    const kernel_memory_bytes = sabaton.vital(allocator.alignedAlloc(u8, 0x1000, kernel_elf_file.paged_bytes()), "Allocating kernel memory", true);

    // Prepare a paging root for the kernel
    paging_root = sabaton.paging.init_paging();

    // Load the kernel into memory
    kernel_elf_file.load(kernel_memory_bytes, &paging_root);

    // Get a framebuffer if requested by the kernel
    @import("framebuffer.zig").init();

    while (true) {}
}
