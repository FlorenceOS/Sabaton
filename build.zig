const std = @import("std");
const Builder = std.build.Builder;
const builtin = std.builtin;
const assert = std.debug.assert;

const Arch = if (@hasField(builtin, "Arch")) builtin.Arch else std.Target.Cpu.Arch;

// var source_blob: *std.build.RunStep = undefined;
// var source_blob_path: []u8 = undefined;

// fn make_source_blob(b: *Builder) void {
//   source_blob_path =
//     std.mem.concat(b.allocator, u8,
//       &[_][]const u8{ b.cache_root, "/sources.tar" }
//     ) catch unreachable;

//   source_blob = b.addSystemCommand(
//     &[_][]const u8 {
//       "tar", "--no-xattrs", "-cf", source_blob_path, "src", "build.zig",
//     },
//   );
// }

const TransformFileCommandStep = struct {
    step: std.build.Step,
    output_path: []const u8,
    fn run_command(s: *std.build.Step) !void {}
};

const custom_build_id: std.build.Step.Id =
    if (@hasField(std.build.Step.Id, "Custom"))
    .Custom
else
    .custom;

fn make_transform(b: *Builder, dep: *std.build.Step, command: [][]const u8, output_path: []const u8) !*TransformFileCommandStep {
    const transform = try b.allocator.create(TransformFileCommandStep);

    transform.output_path = output_path;
    transform.step = std.build.Step.init(custom_build_id, "", b.allocator, TransformFileCommandStep.run_command);

    const command_step = b.addSystemCommand(command);

    command_step.step.dependOn(dep);
    transform.step.dependOn(&command_step.step);

    return transform;
}

fn cpu_features(arch: Arch, ctarget: std.zig.CrossTarget) std.zig.CrossTarget {
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
        .cpu_arch = ctarget.cpu_arch,
        .os_tag = ctarget.os_tag,
        .abi = ctarget.abi,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_feautres,
    };
}

fn freestanding_target(elf: *std.build.LibExeObjStep, arch: Arch, do_code_model: bool) void {
    if (arch == .aarch64) {
        // We don't need the code model in asm blobs
        if (do_code_model)
            elf.code_model = .tiny;
    }

    elf.setTarget(cpu_features(arch, .{
        .cpu_arch = arch,
        .os_tag = std.Target.Os.Tag.freestanding,
        .abi = std.Target.Abi.none,
    }));
}

fn takes_new_file_ref() bool {
    return @typeInfo(@TypeOf(std.build.LibExeObjStep.setLinkerScriptPath)).Fn.args[1].arg_type.? != []const u8;
}

fn file_ref(filename: []const u8) if (takes_new_file_ref()) std.build.FileSource else []const u8 {
    if (comptime takes_new_file_ref()) {
        return .{ .path = filename };
    } else {
        return filename;
    }
}

pub fn board_supported(arch: Arch, target_name: []const u8) bool {
    switch (arch) {
        .aarch64 => {
            if (std.mem.eql(u8, target_name, "virt"))
                return true;
            if (std.mem.eql(u8, target_name, "pi3"))
                return true;
            if (std.mem.eql(u8, target_name, "pine"))
                return true;
            return false;
        },
        else => return false,
    }
}

pub fn build_elf(b: *Builder, arch: Arch, target_name: []const u8, path_prefix: []const u8) !*std.build.LibExeObjStep {
    if (!board_supported(arch, target_name)) return error.UnsupportedBoard;

    const elf_filename = b.fmt("Sabaton_{s}_{s}.elf", .{ target_name, @tagName(arch) });
    const platform_path = b.fmt("{s}src/platform/{s}_{s}", .{ path_prefix, target_name, @tagName(arch) });

    const elf = b.addExecutable(elf_filename, b.fmt("{s}/main.zig", .{platform_path}));
    elf.setLinkerScriptPath(file_ref(b.fmt("{s}/linker.ld", .{platform_path})));
    elf.addAssemblyFile(b.fmt("{s}/entry.S", .{platform_path}));

    elf.addBuildOption([]const u8, "board_name", target_name);
    freestanding_target(elf, arch, true);
    elf.setBuildMode(.ReleaseSmall);
    if (@hasField(@TypeOf(elf.*), "want_lto"))
        elf.want_lto = false;

    elf.setMainPkgPath(b.fmt("{s}src/", .{path_prefix}));
    elf.setOutputDir(b.cache_root);

    elf.disable_stack_probing = true;

    elf.install();

    //elf.step.dependOn(&source_blob.step);

    return elf;
}

pub fn pad_file(b: *Builder, dep: *std.build.Step, path: []const u8) !*TransformFileCommandStep {
    const padded_path = b.fmt("{s}.pad", .{path});

    const pad_step = try make_transform(
        b,
        dep,
        &[_][]const u8{ "/bin/sh", "-c", b.fmt("cp {s} {s} && truncate -s 64M {s}", .{ path, padded_path, padded_path }) },
        padded_path,
    );

    return pad_step;
}

const pad_mode = enum { Padded, NotPadded };

fn section_blob(b: *Builder, elf: *std.build.LibExeObjStep, mode: pad_mode, section_name: []const u8) !*TransformFileCommandStep {
    const elf_path = b.getInstallPath(elf.install_step.?.dest_dir, elf.out_filename);

    const dumped_path = b.fmt("{s}.bin", .{elf_path});

    const dump_step = try make_transform(
        b,
        &elf.install_step.?.step,
        &[_][]const u8{
            // zig fmt: off
            "llvm-objcopy",
                "-O", "binary",
                "--only-section", section_name,
                elf_path, dumped_path,
            // zig fmt: on
        },
        dumped_path,
    );

    if (mode == .Padded)
        return pad_file(b, &dump_step.step, dump_step.output_path);

    return dump_step;
}

fn blob(b: *Builder, elf: *std.build.LibExeObjStep, mode: pad_mode) !*TransformFileCommandStep {
    return section_blob(b, elf, mode, ".blob");
}

fn assembly_blob(b: *Builder, arch: Arch, name: []const u8, asm_file: []const u8) !*TransformFileCommandStep {
    const elf_filename = b.fmt("{s}_{s}.elf", .{ name, @tagName(arch) });

    const elf = b.addExecutable(elf_filename, null);
    elf.setLinkerScriptPath(file_ref("src/blob.ld"));
    elf.addAssemblyFile(asm_file);

    freestanding_target(elf, arch, false);
    elf.setBuildMode(.ReleaseSafe);

    elf.setMainPkgPath("src/");
    elf.setOutputDir(b.cache_root);

    elf.install();

    return blob(b, elf, .NotPadded);
}

pub fn build_blob(b: *Builder, arch: Arch, target_name: []const u8, path_prefix: []const u8) !*TransformFileCommandStep {
    const elf = try build_elf(b, arch, target_name, path_prefix);
    return blob(b, elf, .Padded);
}

fn qemu_aarch64(b: *Builder, board_name: []const u8, desc: []const u8, dep_elf: *std.build.LibExeObjStep) !void {
    const command_step = b.step(board_name, desc);

    const dep = try blob(b, dep_elf, .Padded);

    const params = &[_][]const u8{
        // zig fmt: off
        "qemu-system-aarch64",
        "-M", board_name,
        "-cpu", "cortex-a57",
        "-drive", b.fmt("if=pflash,format=raw,file={s},readonly=on", .{dep.output_path}),
        "-m", "4G",
        "-serial", "stdio",
        //"-S", "-s",
        "-d", "int",
        "-smp", "8",
        "-device", "ramfb",
        "-fw_cfg", "opt/Sabaton/kernel,file=test/Flork_stivale2_aarch64",
        // zig fmt: on
    };

    const run_step = b.addSystemCommand(params);
    run_step.step.dependOn(&dep.step);
    command_step.dependOn(&run_step.step);
}

fn qemu_pi3_aarch64(b: *Builder, desc: []const u8, dep_elf: *std.build.LibExeObjStep) !void {
    const command_step = b.step("pi3", desc);

    const dep = try blob(b, dep_elf, .NotPadded);

    const params = &[_][]const u8{
        // zig fmt: off
        "qemu-system-aarch64",
        "-M", "raspi3",
        "-device", "loader,file=test/Flork_stivale2_aarch64,addr=0x200000,force-raw=on",
        "-serial", "null",
        "-serial", "stdio",
        "-d", "int",
        "-kernel", dep.output_path,
        // zig fmt: off
    };

    const run_step = b.addSystemCommand(params);
    run_step.step.dependOn(&dep.step);
    command_step.dependOn(&run_step.step);
}

const Device = struct {
    name: []const u8,
    arch: Arch,
};

const AssemblyBlobSpec = struct {
    name: []const u8,
    arch: Arch,
    path: []const u8,
};

pub fn build(b: *Builder) !void {
    //make_source_blob(b);

    try qemu_aarch64(
        b,
        "virt",
        "Run aarch64 sabaton on for the qemu virt board",
        try build_elf(b, .aarch64, "virt", "./"),
    );
    
    try qemu_pi3_aarch64(
        b,
        "Run aarch64 sabaton on for the qemu raspi3 board",
        try build_elf(b, .aarch64, "pi3", "./"),
    );

    {
        const assembly_blobs = &[_]AssemblyBlobSpec{
            .{ .path = "src/platform/pine_aarch64/identity.S", .name = "identity_pine", .arch = .aarch64 },
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
        };

        for (blob_devices) |dev| {
            const elf_file = try build_elf(b, .aarch64, dev.name, "./");
            const blob_file = try blob(b, elf_file, .NotPadded);
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
