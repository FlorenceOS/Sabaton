const std = @import("std");
const Builder = std.build.Builder;
const builtin = std.builtin;
const assert = std.debug.assert;

fn here() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

fn cpu_features(arch: std.Target.Cpu.Arch, ctarget: std.zig.CrossTarget) std.zig.CrossTarget {
    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    var enabled_feautres = std.Target.Cpu.Feature.Set.empty;

    if (arch == .aarch64) {
        const features = std.Target.aarch64.Feature;
        // This is equal to -mgeneral-regs-only
        disabled_features.addFeature(@enumToInt(features.fp_armv8));
        disabled_features.addFeature(@enumToInt(features.crypto));
        disabled_features.addFeature(@enumToInt(features.neon));
    }

    return std.zig.CrossTarget{
        .cpu_arch = arch,
        .os_tag = ctarget.os_tag,
        .abi = ctarget.abi,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_feautres,
    };
}

fn freestanding_target(elf: *std.build.LibExeObjStep, arch: std.Target.Cpu.Arch, do_code_model: bool) void {
    if (arch == .aarch64) {
        // We don't need the code model in asm blobs
        if (do_code_model)
            elf.code_model = .tiny;
    }

    elf.setTarget(cpu_features(arch, .{
        .os_tag = std.Target.Os.Tag.freestanding,
        .abi = std.Target.Abi.none,
    }));
}

fn executable_common(b: *Builder, exec: *std.build.LibExeObjStep, board_name: []const u8) void {
    var options = b.addOptions();
    options.addOption([]const u8, "board_name", board_name);
    exec.addOptions("build_options", options);

    exec.setBuildMode(.ReleaseSmall);
    if (@hasField(@TypeOf(exec.*), "want_lto"))
        exec.want_lto = false;

    exec.setMainPkgPath(here() ++ "/src/");
    exec.setOutputDir(b.cache_root);

    exec.install();

    exec.disable_stack_probing = true;
}

pub fn build_uefi(b: *Builder, arch: std.Target.Cpu.Arch) !*std.build.LibExeObjStep {
    const filename = "BOOTA64";
    const platform_path = b.fmt(here() ++ "/src/platform/uefi_{s}", .{@tagName(arch)});

    const exec = b.addExecutable(filename, b.fmt("{s}/main.zig", .{platform_path}));
    executable_common(b, exec, "UEFI");

    exec.code_model = .small;

    exec.setTarget(cpu_features(arch, .{
        .os_tag = std.Target.Os.Tag.uefi,
        .abi = std.Target.Abi.msvc,
    }));

    exec.setOutputDir(here() ++ "/uefidir/image/EFI/BOOT/");

    return exec;
}

fn build_elf(b: *Builder, arch: std.Target.Cpu.Arch, target_name: []const u8) !*std.build.LibExeObjStep {
    const elf_filename = b.fmt("Sabaton_{s}_{s}.elf", .{ target_name, @tagName(arch) });
    const platform_path = b.fmt(here() ++ "/src/platform/{s}_{s}", .{ target_name, @tagName(arch) });

    const elf = b.addExecutable(elf_filename, b.fmt("{s}/main.zig", .{platform_path}));
    elf.setLinkerScriptPath(.{ .path = b.fmt("{s}/linker.ld", .{platform_path}) });
    elf.addAssemblyFile(b.fmt("{s}/entry.S", .{platform_path}));
    executable_common(b, elf, target_name);

    freestanding_target(elf, arch, true);

    return elf;
}

fn assembly_blob(b: *Builder, arch: std.Target.Cpu.Arch, name: []const u8, asm_file: []const u8) !*std.build.InstallRawStep {
    const elf_filename = b.fmt("{s}_{s}.elf", .{ name, @tagName(arch) });

    const elf = b.addExecutable(elf_filename, null);
    elf.setLinkerScriptPath(.{ .path = "src/blob.ld" });
    elf.addAssemblyFile(asm_file);

    freestanding_target(elf, arch, false);
    elf.setBuildMode(.ReleaseSafe);

    elf.setMainPkgPath("src/");
    elf.setOutputDir(b.cache_root);

    elf.install();

    return elf.installRaw(b.fmt("{s}.bin", .{elf_filename}), .{
        .format = .bin,
        .only_section_name = ".blob",
        .pad_to_size = null,
    });
}

pub fn aarch64VirtBlob(b: *Builder) *std.build.InstallRawStep {
    const elf = try build_elf(b, .aarch64, "virt");
    return elf.installRaw(b.fmt("{s}.bin", .{elf.out_filename}), .{
        .format = .bin,
        .only_section_name = ".blob",
        .pad_to_size = 64 * 1024 * 1024, // 64M
    });
}

fn qemu_aarch64(b: *Builder, board_name: []const u8, desc: []const u8) !void {
    const command_step = b.step(board_name, desc);
    const blob = aarch64VirtBlob(b);
    const blob_path = b.getInstallPath(blob.dest_dir, blob.dest_filename);

    const run_step = b.addSystemCommand(&[_][]const u8{
        // zig fmt: off
        "qemu-system-aarch64",
        "-M", board_name,
        "-cpu", "cortex-a57",
        "-m", "4G",
        "-serial", "stdio",
        //"-S", "-s",
        "-d", "int",
        "-smp", "8",
        "-device", "ramfb",
        "-kernel", "test/Flork_stivale2_aarch64",
        "-drive", b.fmt("if=pflash,format=raw,file={s},readonly=on", .{blob_path}),
        // zig fmt: on
    });

    run_step.step.dependOn(&blob.step);
    command_step.dependOn(&run_step.step);
}

fn qemu_pi3_aarch64(b: *Builder, desc: []const u8, elf: *std.build.LibExeObjStep) !void {
    const command_step = b.step("pi3", desc);

    const blob = elf.installRaw(b.fmt("{s}.bin", .{elf.out_filename}), .{
        .format = .bin,
        .only_section_name = ".blob",
        .pad_to_size = null,
    });

    const blob_path = b.getInstallPath(blob.dest_dir, blob.dest_filename);

    const run_step = b.addSystemCommand(&[_][]const u8{
        // zig fmt: off
        "qemu-system-aarch64",
        "-M", "raspi3",
        "-device", "loader,file=test/Flork_stivale2_aarch64,addr=0x200000,force-raw=on",
        "-serial", "null",
        "-serial", "stdio",
        "-d", "int",
        "-kernel", blob_path,
        // zig fmt: off
    });

    run_step.step.dependOn(&blob.step);
    command_step.dependOn(&run_step.step);
}

fn qemu_uefi_aarch64(b: *Builder, desc: []const u8, dep: *std.build.LibExeObjStep) !void {
    const command_step = b.step("uefi", desc);

    const run_step = b.addSystemCommand(&[_][]const u8{
        // zig fmt: off
        "qemu-system-aarch64",
        "-M", "virt",
        "-m", "4G",
        "-cpu", "cortex-a57",
        "-serial", "stdio",
        "-device", "ramfb",
        "-drive", b.fmt("if=pflash,format=raw,file={s}/QEMU_EFI.fd,readonly=on", .{std.os.getenv("AARCH64_EDK_PATH").?}),
        "-drive", b.fmt("if=pflash,format=raw,file={s}/QEMU_VARS.fd", .{std.os.getenv("AARCH64_EDK_PATH").?}),
        "-hdd", "fat:rw:uefidir/image",
        "-usb",
        "-device", "usb-ehci",
        "-device", "usb-kbd",
        // zig fmt: off
    });

    run_step.step.dependOn(&dep.install_step.?.step);
    command_step.dependOn(&run_step.step);
}

const Device = struct {
    name: []const u8,
    arch: std.Target.Cpu.Arch,
};

const AssemblyBlobSpec = struct {
    name: []const u8,
    arch: std.Target.Cpu.Arch,
    path: []const u8,
};

pub fn build(b: *Builder) !void {
    //make_source_blob(b);

    try qemu_aarch64(
        b,
        "virt",
        "Run aarch64 sabaton for the qemu virt board",
    );
    
    try qemu_pi3_aarch64(
        b,
        "Run aarch64 sabaton for the qemu raspi3 board",
        try build_elf(b, .aarch64, "pi3"),
    );

    try qemu_uefi_aarch64(
        b,
        "Run aarch64 sabaton for UEFI",
        try build_uefi(b, .aarch64),
    );

    {
        const assembly_blobs = &[_]AssemblyBlobSpec{
            .{ .path = "src/platform/pine_aarch64/identity.S", .name = "identity_pine", .arch = .aarch64 },
            .{ .path = "src/platform/vision_five_v1_riscv64/s1.S", .name = "vision_five_v1_s1", .arch = .riscv64},
        };

        for (assembly_blobs) |spec| {
            const blob_file = try assembly_blob(b, spec.arch, spec.name, spec.path);
            b.default_step.dependOn(&blob_file.step);
        }
    }

    {
        const elf_devices = &[_]Device{};

        for (elf_devices) |dev| {
            const elf_file = try build_elf(b, .aarch64, dev.name);
            const s = b.step(dev.name, b.fmt("Build the blob for {s}", .{dev.name}));
            s.dependOn(&elf_file.step);
            b.default_step.dependOn(s);
        }
    }

    {
        const blob_devices = &[_]Device{
            .{ .name = "pine", .arch = .aarch64 },
            .{ .name = "vision_five_v1", .arch = .riscv64 },
        };

        for (blob_devices) |dev| {
            const elf = try build_elf(b, dev.arch, dev.name);
            const blob_file = elf.installRaw(b.fmt("{s}_{s}.bin", .{dev.name, @tagName(dev.arch)}), .{
                .format = .bin,
                .only_section_name = ".blob",
                .pad_to_size = null,
            });
            const s = b.step(dev.name, b.fmt("Build the blob for {s}", .{dev.name}));
            s.dependOn(&blob_file.step);
            b.default_step.dependOn(s);
        }
    }

    // qemu_riscv(b,
    //   "virt",
    //   "Run riscv64 sabaton on for the qemu virt board",
    //   build_elf(b, .riscv64, "virt"),
    // );
}
