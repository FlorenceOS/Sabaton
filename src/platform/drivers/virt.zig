const sabaton = @import("root").sabaton;
const std = @import("std");

pub const io = sabaton.io_impl.uart_mmio_32;

pub const acpi = struct {
    pub fn init() void {
        if (sabaton.fw_cfg.find_file("etc/acpi/tables")) |tables| {
            if (sabaton.fw_cfg.find_file("etc/acpi/rsdp")) |rsdp| {
                const rsdp_bytes = sabaton.pmm.alloc_aligned(rsdp.size, .Hole);
                const table_bytes = sabaton.pmm.alloc_aligned(tables.size, .Hole);

                rsdp.read(rsdp_bytes);
                tables.read(table_bytes);

                sabaton.acpi.init(rsdp_bytes, table_bytes);
            }
        }
    }
};

pub const display = struct {
    fn try_find(comptime f: anytype, comptime name: []const u8) bool {
        const retval = f();
        if (retval) {
            sabaton.puts("Found " ++ name ++ "!\n");
        } else {
            sabaton.puts("Couldn't find " ++ name ++ "\n");
        }
        return retval;
    }

    pub fn init() void {
        // First, try to find a ramfb
        if (try_find(sabaton.ramfb.init, "ramfb"))
            return;

        sabaton.puts("Kernel requested framebuffer but we could not provide one!\n");
    }
};

pub const smp = struct {
    pub fn init() void {
        sabaton.dtb.psci_smp(.HVC);
    }
};

const FW_CFG_KERNEL_SIZE = 0x08;
const FW_CFG_KERNEL_DATA = 0x11;

pub fn get_kernel() [*]u8 {
    if (sabaton.fw_cfg.find_file("opt/Sabaton/kernel")) |kernel| {
        sabaton.log_hex("fw_cfg reported opt/sabaton/kernel size of ", kernel.size);
        const kernel_bytes = sabaton.pmm.alloc_aligned(kernel.size, .ReclaimableData);
        sabaton.puts("Reading kernel file into allocated buffer!\n");
        kernel.read(kernel_bytes);
        sabaton.puts("Kernel get!\n");
        return kernel_bytes.ptr;
    }

    {
        const ksize = sabaton.fw_cfg.get_variable(u32, FW_CFG_KERNEL_SIZE);
        sabaton.log_hex("fw_cfg reported -kernel file size ", ksize);
        const kernel_bytes = sabaton.pmm.alloc_aligned(ksize, .ReclaimableData);
        sabaton.puts("Reading kernel file into allocated buffer!\n");
        sabaton.fw_cfg.get_bytes(kernel_bytes, FW_CFG_KERNEL_DATA);
        sabaton.puts("Kernel get!\n");
        return kernel_bytes.ptr;
    }
    @panic("Kernel not found using fw_cfg!");
}

pub fn get_dram() []u8 {
    return sabaton.near("dram_base").read([*]u8)[0..get_dram_size()];
}

pub fn map_platform(root: *sabaton.paging.Root) void {
    sabaton.paging.map(0, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
    sabaton.paging.map(sabaton.upper_half_phys_base, 0, 1024 * 1024 * 1024, .rw, .mmio, root);
    sabaton.puts("Initing pci!\n");
    sabaton.pci.init_from_dtb(root);
}

// Dram size varies as you can set different amounts of RAM for your VM
fn get_dram_size() u64 {
    const memory_blob = sabaton.vital(sabaton.dtb.find("memory@", "reg"), "Cannot find memory in dtb", false);
    const base = std.mem.readIntBig(u64, memory_blob[0..8]);
    const size = std.mem.readIntBig(u64, memory_blob[8..16]);

    if (sabaton.safety and base != sabaton.near("dram_base").read(u64)) {
        sabaton.log_hex("dtb has wrong memory base: ", base);
        unreachable;
    }

    return size;
}

pub fn add_platform_tags(kernel_header: *sabaton.Stivale2hdr) void {
    _ = kernel_header;
    sabaton.add_tag(&sabaton.near("uart_tag").addr(sabaton.Stivale2tag)[0]);
    sabaton.add_tag(&sabaton.near("devicetree_tag").addr(sabaton.Stivale2tag)[0]);
}
