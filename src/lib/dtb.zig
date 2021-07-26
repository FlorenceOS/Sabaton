const sabaton = @import("root").sabaton;
const std = @import("std");

var data: []u8 = undefined;

const BE = sabaton.util.BigEndian;

const Header = packed struct {
    magic: BE(u32),
    totalsize: BE(u32),
    off_dt_struct: BE(u32),
    off_dt_strings: BE(u32),
    off_mem_rsvmap: BE(u32),
    version: BE(u32),
    last_comp_version: BE(u32),
    boot_cpuid_phys: BE(u32),
    size_dt_strings: BE(u32),
    size_dt_struct: BE(u32),
};

pub fn find_cpu_id(dtb_id: usize) ?u32 {
    var cpu_name_buf = [_]u8{undefined} ** 32;
    cpu_name_buf[0] = 'c';
    cpu_name_buf[1] = 'p';
    cpu_name_buf[2] = 'u';
    cpu_name_buf[3] = '@';

    const buf_len = sabaton.util.write_int_decimal(cpu_name_buf[4..], dtb_id) + 4;
    const id_bytes = (find(cpu_name_buf[0..buf_len], "reg") catch return null)[0..4];
    return std.mem.readIntBig(u32, id_bytes[0..4]);
}

comptime {
    asm (
        \\.section .text.smp_stub
        \\.global smp_stub
        \\smp_stub:
        \\  DSB SY
        \\  LDR X1, [X0, #8]
        \\  MOV SP, X1
    );
}

export fn smp_entry(context: u64) linksection(".text.smp_entry") noreturn {
    @call(.{ .modifier = .always_inline }, sabaton.stivale2_smp_ready, .{context});
}

pub fn psci_smp(comptime methods: ?sabaton.psci.Mode) void {
    const psci_method = blk: {
        if (comptime (methods == null)) {
            const method_str = (sabaton.dtb.find("psci", "method") catch return)[0..3];
            sabaton.puts("PSCI method: ");
            sabaton.print_str(method_str);
            sabaton.putchar('\n');
            break :blk method_str;
        }
        break :blk undefined;
    };

    const num_cpus = blk: {
        var count: u32 = 1;

        while (true) : (count += 1) {
            _ = find_cpu_id(count) orelse break :blk count;
        }
    };

    sabaton.log_hex("Number of CPUs found: ", num_cpus);

    if (num_cpus == 1)
        return;

    const smp_tag = sabaton.pmm.alloc_aligned(40 + num_cpus * @sizeOf(sabaton.stivale.SMPTagEntry), .Hole);
    const entry = @ptrToInt(sabaton.near("smp_stub").addr(u32));
    const smp_header = @intToPtr(*sabaton.stivale.SMPTagHeader, @ptrToInt(smp_tag.ptr));
    smp_header.tag.ident = 0x34d1d96339647025;
    smp_header.cpu_count = num_cpus;

    var cpu_num: u32 = 1;
    while (cpu_num < num_cpus) : (cpu_num += 1) {
        const id = find_cpu_id(cpu_num) orelse unreachable;
        const tag_addr = @ptrToInt(smp_tag.ptr) + 40 + cpu_num * @sizeOf(sabaton.stivale.SMPTagEntry);
        const tag_entry = @intToPtr(*sabaton.stivale.SMPTagEntry, tag_addr);
        tag_entry.acpi_id = cpu_num;
        tag_entry.cpu_id = id;
        const stack = sabaton.pmm.alloc_aligned(0x1000, .Hole);
        tag_entry.stack = @ptrToInt(stack.ptr) + 0x1000;

        // Make sure we've written everything we need to memory before waking this CPU up
        asm volatile ("DSB ST\n" ::: "memory");

        if (comptime (methods == null)) {
            if (std.mem.eql(u8, psci_method, "smc")) {
                _ = sabaton.psci.wake_cpu(entry, id, tag_addr, .SMC);
                continue;
            }

            if (std.mem.eql(u8, psci_method, "hvc")) {
                _ = sabaton.psci.wake_cpu(entry, id, tag_addr, .HVC);
                continue;
            }
        } else {
            _ = sabaton.psci.wake_cpu(entry, id, tag_addr, comptime (methods.?));
            continue;
        }

        if (comptime !sabaton.safety)
            unreachable;

        @panic("Unknown PSCI method!");
    }

    sabaton.add_tag(&smp_header.tag);
}

pub fn find(node_prefix: []const u8, prop_name: []const u8) ![]u8 {
    const dtb = sabaton.platform.get_dtb();

    const header = @ptrCast(*Header, dtb.ptr);

    std.debug.assert(header.magic.read() == 0xD00DFEED);
    std.debug.assert(header.totalsize.read() == dtb.len);

    var curr = @ptrCast([*]BE(u32), dtb.ptr + header.off_dt_struct.read());

    var current_depth: usize = 0;
    var found_at_depth: ?usize = null;

    while (true) {
        const opcode = curr[0].read();
        curr += 1;
        switch (opcode) {
            0x00000001 => { // FDT_BEGIN_NODE
                const name = @ptrCast([*:0]u8, curr);
                const namelen = sabaton.util.strlen(name);

                if (sabaton.debug)
                    sabaton.log("FDT_BEGIN_NODE(\"{s}\", {})\n", .{ name[0..namelen], namelen });

                current_depth += 1;
                if (found_at_depth == null and namelen >= node_prefix.len) {
                    if (std.mem.eql(u8, name[0..node_prefix.len], node_prefix)) {
                        found_at_depth = current_depth;
                    }
                }

                curr += (namelen + 4) / 4;
            },
            0x00000002 => { // FDT_END_NODE
                if (sabaton.debug)
                    sabaton.log("FDT_END_NODE\n", .{});
                if (found_at_depth) |d| {
                    if (d == current_depth) {
                        found_at_depth = null;
                    }
                }
                current_depth -= 1;
            },
            0x00000003 => { // FDT_PROP
                const nameoff = curr[1].read();
                var len = curr[0].read();

                const name = @ptrCast([*:0]u8, dtb.ptr + header.off_dt_strings.read() + nameoff);
                if (sabaton.debug)
                    sabaton.log("FDT_PROP(\"{s}\"), len 0x{X}\n", .{ name, len });

                if (found_at_depth) |d| {
                    if (d == current_depth) {
                        // DID WE FIND IT??
                        if (std.mem.eql(u8, name[0..prop_name.len], prop_name) and name[prop_name.len] == 0)
                            return @ptrCast([*]u8, curr + 2)[0..len];
                    }
                }

                len += 3;
                curr += len / 4 + 2;
            },
            0x00000004 => {}, // FDT_NOP
            0x00000009 => break, // FDT_END
            else => {
                if (sabaton.safety) {
                    sabaton.log_hex("Unknown DTB opcode: ", opcode);
                }
                unreachable;
            },
        }
    }

    return error.NotFound;
}
