pub const sabaton = @import("../../sabaton.zig");

const std = @import("std");
const uefi = std.os.uefi;

const fs = @import("fs.zig");

var conout: ?*uefi.protocols.SimpleTextOutputProtocol = null;

pub const panic = sabaton.panic;

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
    if (uefi.system_table.boot_services.?.locateProtocol(&guid, null, @ptrCast(*?*c_void, &ptr)) != .Success) {
        return null;
    }
    return ptr;
}

pub fn handleProtocol(handle: uefi.Handle, comptime T: type) callconv(.Inline) ?*T {
    var ptr: *T = undefined;
    const guid: std.os.uefi.Guid align(8) = T.guid;
    if (uefi.system_table.boot_services.?.handleProtocol(handle, &guid, @ptrCast(*?*c_void, &ptr)) != .Success) {
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

// O(n^2) but who cares, it's really small code
fn sortStivale2Memmap(data_c: []align(8) u8) void {
    var data = data_c;

    while (true) {
        const num_entries = data.len / 0x18;
        if (num_entries < 2)
            return;

        var curr_min_i: usize = 0;
        var curr_min_addr = std.mem.readIntNative(u64, data[0..8]);

        // First let's find the smallest addr among the rest
        var i: usize = 1;

        while (i < num_entries) : (i += 1) {
            const curr_addr = std.mem.readIntNative(u64, data[i * 0x18 ..][0..8]);
            if (curr_addr < curr_min_addr) {
                curr_min_addr = curr_addr;
                curr_min_i = i;
            }
        }

        // Swap the current entry with the smallest one
        std.mem.swap([0x18]u8, data[0..0x18], data[curr_min_i * 0x18 ..][0..0x18]);

        data = data[0x18..];
    }
}

const MemoryMap = struct {
    memory_map: []align(8) u8,
    key: usize,
    desc_size: usize,
    desc_version: u32,

    const memory_map_size = 64 * 1024;

    const Iterator = struct {
        map: *const MemoryMap,
        curr_offset: usize = 0,

        fn next(self: *@This()) ?*uefi.tables.MemoryDescriptor {
            if (self.curr_offset + @offsetOf(uefi.tables.MemoryDescriptor, "attribute") >= self.map.memory_map.len)
                return null;

            const result = @ptrCast(*uefi.tables.MemoryDescriptor, @alignCast(8, self.map.memory_map.ptr + self.curr_offset));
            self.curr_offset += self.map.desc_size;
            return result;
        }
    };

    fn fetch(self: *@This()) void {
        self.memory_map.len = memory_map_size;
        uefiVital(uefi.system_table.boot_services.?.getMemoryMap(
            &self.memory_map.len,
            @ptrCast([*]uefi.tables.MemoryDescriptor, @alignCast(8, self.memory_map.ptr)), // Cast is workaround for the wrong zig type annotation
            &self.key,
            &self.desc_size,
            &self.desc_version,
        ), "Getting UEFI memory map");
    }

    fn parse_to_stivale2(self: *const @This(), stivale2buf: []align(8) u8) void {
        var iter = Iterator{ .map = self };

        std.mem.writeIntNative(u64, stivale2buf[0x00..0x08], 0x2187F79E8612DE07);
        //std.mem.writeIntNative(u64, stivale2buf[0x08..0x10], 0); // Next ptr
        const num_entries = @ptrCast(*u64, &stivale2buf[0x10]);
        num_entries.* = 0;

        var stivale2ents = stivale2buf[0x18..];

        while (iter.next()) |e| : ({
            num_entries.* += 1;
            stivale2ents = stivale2ents[0x18..];
        }) {
            std.mem.writeIntNative(u64, stivale2ents[0x00..0x08], e.physical_start);
            std.mem.writeIntNative(u64, stivale2ents[0x08..0x10], e.number_of_pages * page_size);
            //std.mem.writeIntNative(u32, stivale2ents[0x14..0x18], stiavle2_reserved);
            std.mem.writeIntNative(u32, stivale2ents[0x10..0x14], @as(u32, switch (e.type) {
                .ReservedMemoryType,
                .UnusableMemory,
                .MemoryMappedIO,
                .MemoryMappedIOPortSpace,
                .PalCode,
                .PersistentMemory,
                .RuntimeServicesCode,
                .RuntimeServicesData,
                => 2, // RESERVED

                // We load all kernel code segments as LoaderData, should probably be changed to reclaim more memory here
                .LoaderData => 0x1001, // KERNEL_AND_MODULES
                .LoaderCode => 0x1000, // BOOTLOADER_RECLAIMABLE

                // Boot services entries are marked as usable since we've
                // already exited boot services when we enter the kernel
                .BootServicesCode,
                .BootServicesData,
                => 1, // USABLE

                .ConventionalMemory => 1, // USABLE

                .ACPIReclaimMemory => 3, // ACPI_RECLAIMABLE

                .ACPIMemoryNVS => 4, // ACPI_NVS

                else => @panic("Bad memory map type"),
            }));
        }

        sortStivale2Memmap(stivale2buf[0x18..]);
    }

    fn map_everything(self: *const @This(), root: *sabaton.paging.Root) void {
        var iter = Iterator{ .map = self };

        while (iter.next()) |e| {
            const memory_type: sabaton.paging.MemoryType = switch (e.type) {
                .ReservedMemoryType,
                .LoaderCode,
                .LoaderData,
                .BootServicesCode,
                .BootServicesData,
                .RuntimeServicesCode,
                .RuntimeServicesData,
                .ConventionalMemory,
                .UnusableMemory,
                .ACPIReclaimMemory,
                .PersistentMemory,
                => .memory,
                .ACPIMemoryNVS,
                .MemoryMappedIO,
                .MemoryMappedIOPortSpace,
                => .mmio,
                else => continue,
            };
            const perms: sabaton.paging.Perms = switch (e.type) {
                .ReservedMemoryType,
                .LoaderData,
                .BootServicesCode,
                .BootServicesData,
                .RuntimeServicesData,
                .ConventionalMemory,
                .UnusableMemory,
                .ACPIReclaimMemory,
                .PersistentMemory,
                .ACPIMemoryNVS,
                .MemoryMappedIO,
                .MemoryMappedIOPortSpace,
                => .rw,
                .LoaderCode,
                .RuntimeServicesCode,
                => .rwx,
                else => continue,
            };

            sabaton.paging.map(e.physical_start, e.physical_start, e.number_of_pages * page_size, perms, memory_type, root);
            sabaton.paging.map(sabaton.upper_half_phys_base + e.physical_start, e.physical_start, e.number_of_pages * page_size, perms, memory_type, root);
        }
    }

    fn init() @This() {
        var result: @This() = undefined;
        result.memory_map.ptr = @alignCast(8, sabaton.vital(allocator.alloc(u8, memory_map_size), "Allocating for UEFI memory map", true).ptr);
        result.fetch();
        return result;
    }
};

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

    // Ought to be enough for any firmwares crappy memory layout, right?
    const stivale2_memmap_bytes = @alignCast(8, sabaton.vital(allocator.alloc(u8, 64 * 1024), "Allocating for stivale2 memory map", true));

    // Get a framebuffer
    @import("framebuffer.zig").init();

    // Get the memory map to calculate a max address used by UEFI
    var memmap = MemoryMap.init();

    memmap.map_everything(&paging_root);

    // Now we need a memory map to exit boot services
    memmap.fetch();

    memmap.parse_to_stivale2(stivale2_memmap_bytes);
    sabaton.add_tag(@ptrCast(*sabaton.Stivale2tag, stivale2_memmap_bytes.ptr));

    uefiVital(uefi.system_table.boot_services.?.exitBootServices(uefi.handle, memmap.key), "Exiting boot services");

    conout = null; // We can't call UEFI after exiting boot services

    sabaton.paging.apply_paging(&paging_root);

    sabaton.enterKernel(&kernel_elf_file, kernel_stivale2_header.stack);
}
