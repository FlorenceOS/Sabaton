const std = @import("std");
const Builder = std.build.Builder;
const builtin = std.builtin;
const assert = std.debug.assert;

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
  fn run_command(s: *std.build.Step) !void { }
};

fn make_transform(b: *Builder, dep: *std.build.Step, command: [][]const u8, output_path: []const u8) !*TransformFileCommandStep {
  const transform = try b.allocator.create(TransformFileCommandStep);

  transform.output_path = output_path;
  transform.step = std.build.Step.init(.Custom, "", b.allocator, TransformFileCommandStep.run_command);

  const command_step = b.addSystemCommand(command);

  command_step.step.dependOn(dep);
  transform.step.dependOn(&command_step.step);

  return transform;
}

fn target(elf: *std.build.LibExeObjStep, arch: builtin.Arch, do_code_model: bool) void {
  var disabled_features = std.Target.Cpu.Feature.Set.empty;
  var enabled_feautres  = std.Target.Cpu.Feature.Set.empty;

  if(arch == .aarch64) {
    const features = std.Target.aarch64.Feature;
    // This is equal to -mgeneral-regs-only
    disabled_features.addFeature(@enumToInt(features.fp_armv8));
    disabled_features.addFeature(@enumToInt(features.crypto));
    disabled_features.addFeature(@enumToInt(features.neon));

    // We don't need the code model in asm blobs
    if(do_code_model)
      elf.code_model = .tiny;
  }

  elf.setTarget(std.zig.CrossTarget {
    .cpu_arch = arch,
    .os_tag = std.Target.Os.Tag.freestanding,
    .abi = std.Target.Abi.none,
    .cpu_features_sub = disabled_features,
    .cpu_features_add = enabled_feautres,
  });
}

pub fn board_supported(arch: builtin.Arch, target_name: []const u8) bool {
  switch(arch) {
    .aarch64 => {
      if(std.mem.eql(u8, target_name, "virt"))
        return true;
      if(std.mem.eql(u8, target_name, "pine"))
        return true;
      return false;
    },
    else => return false,
  }
}

pub fn build_elf(b: *Builder, arch: builtin.Arch, target_name: []const u8, path_prefix: []const u8) !*std.build.LibExeObjStep {
  if(!board_supported(arch, target_name)) return error.UnsupportedBoard;

  const elf_filename = b.fmt("Sabaton_{}_{}.elf", .{target_name, @tagName(arch)});

  const platform_path = b.fmt("{}src/platform/{}_{}", .{path_prefix, target_name, @tagName(arch)});

  const elf = b.addExecutable(elf_filename, b.fmt("{}/main.zig", .{platform_path}));
  elf.setLinkerScriptPath(b.fmt("{}/linker.ld", .{platform_path}));
  elf.addAssemblyFile(b.fmt("{}/entry.asm", .{platform_path}));

  elf.addBuildOption([] const u8, "board_name", target_name);
  target(elf, arch, true);
  elf.setBuildMode(.ReleaseSmall);

  elf.setMainPkgPath(b.fmt("{}src/", .{path_prefix}));
  elf.setOutputDir(b.cache_root);

  elf.disable_stack_probing = true;

  elf.install();

  //elf.step.dependOn(&source_blob.step);

  return elf;
}

pub fn pad_file(b: *Builder, dep: *std.build.Step, path: []const u8) !*TransformFileCommandStep {
  const padded_path = b.fmt("{}.pad", .{path});

  const pad_step = try make_transform(b, dep,
    &[_][]const u8 {
      "/bin/sh", "-c",
      b.fmt("cp {} {} && truncate -s 64M {}",
        .{path, padded_path, padded_path})
    },
    padded_path,
  );

  pad_step.step.dependOn(dep);
  return pad_step;
}

const pad_mode = enum{Padded, NotPadded};

fn section_blob(b: *Builder, elf: *std.build.LibExeObjStep, mode: pad_mode, section_name: []const u8) !*TransformFileCommandStep {
  const dumped_path = b.fmt("{}.bin", .{elf.getOutputPath()});

  const dump_step = try make_transform(b, &elf.step,
    &[_][]const u8 {
      "llvm-objcopy", "-O", "binary", "--only-section", section_name,
      elf.getOutputPath(), dumped_path,
    },
    dumped_path,
  );

  dump_step.step.dependOn(&elf.step);

  if(mode == .Padded)
    return pad_file(b, &dump_step.step, dump_step.output_path);

  return dump_step;
}

fn blob(b: *Builder, elf: *std.build.LibExeObjStep, mode: pad_mode) !*TransformFileCommandStep {
  return section_blob(b, elf, mode, ".blob");
}

fn assembly_blob(b: *Builder, arch: builtin.Arch, name: []const u8, asm_file: []const u8) !*TransformFileCommandStep {
  const elf_filename = b.fmt("{}_{}.elf", .{name, @tagName(arch)});

  const elf = b.addExecutable(elf_filename, null);
  elf.setLinkerScriptPath("src/blob.ld");
  elf.addAssemblyFile(asm_file);

  target(elf, arch, false);
  elf.setBuildMode(.ReleaseSafe);

  elf.setMainPkgPath("src/");
  elf.setOutputDir(b.cache_root);

  elf.install();

  return blob(b, elf, .NotPadded);
}

pub fn build_blob(b: *Builder, arch: builtin.Arch, target_name: []const u8, path_prefix: []const u8) !*TransformFileCommandStep {
  const elf = try build_elf(b, arch, target_name, path_prefix);
  return blob(b, elf, .Padded);
}

fn qemu_aarch64(b: *Builder, board_name: []const u8, desc: []const u8, dep_elf: *std.build.LibExeObjStep) !void {
  const command_step = b.step(board_name, desc);

  const dep = try blob(b, dep_elf, .Padded);

  const params =
    &[_][]const u8 {
      "qemu-system-aarch64",
      "-M", board_name,
      "-cpu", "cortex-a57",
      "-drive", b.fmt("if=pflash,format=raw,file={},readonly=on", .{dep.output_path}),
      "-drive", "if=pflash,format=raw,file=test/Flork_stivale2_aarch64.pad,readonly=on",
      "-m", "4G",
      "-serial", "stdio",
      //"-S", "-s",
      "-d", "int",
      "-smp", "8",
      "-device", "ramfb",
    };

  const run_step = b.addSystemCommand(params);
  run_step.step.dependOn(&dep.step);
  command_step.dependOn(&run_step.step);
}

const Device = struct {
  name: []const u8,
  arch: builtin.Arch,
};

const AssemblyBlobSpec = struct {
  name: []const u8,
  arch: builtin.Arch,
  path: []const u8,
};

pub fn build(b: *Builder) !void {
  //make_source_blob(b);

  try qemu_aarch64(b,
    "virt",
    "Run aarch64 sabaton on for the qemu virt board",
    try build_elf(b, builtin.Arch.aarch64, "virt", "./"),
  );

  {
    const assembly_blobs = &[_]AssemblyBlobSpec {
      .{.path = "src/platform/pine_aarch64/identity.asm", .name = "identity_pine", .arch = .aarch64},
    };

    for(assembly_blobs) |spec| {
      const blob_file = try assembly_blob(b, spec.arch, spec.name, spec.path);
      b.default_step.dependOn(&blob_file.step);
    }
  }

  {
    const elf_devices = &[_]Device{
    };

    for(elf_devices) |dev| {
      const elf_file = try build_elf(b, builtin.Arch.aarch64, dev.name);
      const s = b.step(dev.name, b.fmt("Build the blob for {}", .{dev.name}));
      s.dependOn(&elf_file.step);
      b.default_step.dependOn(s);
    }
  }

  {
    const blob_devices = &[_]Device{
      .{.name = "pine", .arch = builtin.Arch.aarch64},
    };

    for(blob_devices) |dev| {
      const elf_file = try build_elf(b, builtin.Arch.aarch64, dev.name, "./");
      const blob_file = try blob(b, elf_file, .NotPadded);
      const s = b.step(dev.name, b.fmt("Build the blob for {}", .{dev.name}));
      s.dependOn(&blob_file.step);
      b.default_step.dependOn(s);
    }
  }

  // qemu_riscv(b,
  //   "virt",
  //   "Run riscv64 sabaton on for the qemu virt board",
  //   build_elf(b, builtin.Arch.riscv64, "virt"),
  // );
}
