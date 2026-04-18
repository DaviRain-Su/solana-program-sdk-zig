const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Export self as a module
    const solana_mod = b.addModule("solana_program_sdk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");
    solana_mod.addImport("base58", base58_mod);

    const lib_unit_tests = b.addTest(.{
        .root_module = solana_mod,
    });

    lib_unit_tests.root_module.addImport("base58", base58_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

pub const LinkedProgram = struct {
    name: []const u8,
    module: *std.Build.Module,
    so: std.Build.LazyPath,
    step: *std.Build.Step,
};

pub const BuildProgramElf2SbpfOptions = struct {
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    elf2sbpf_bin: []const u8 = "elf2sbpf",
};

pub fn buildProgramElf2sbpf(b: *std.Build, options: BuildProgramElf2SbpfOptions) LinkedProgram {
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    const program_mod = b.createModule(.{
        .root_source_file = options.root_source_file,
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = solana_mod },
        },
    });
    program_mod.pic = true;
    program_mod.strip = true;

    const bitcode_obj = b.addObject(.{
        .name = b.fmt("{s}-bitcode", .{options.name}),
        .root_module = program_mod,
    });
    const bitcode = bitcode_obj.getEmittedLlvmBc();

    const zig_cc = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "cc",
        "-target",
        "bpfel-freestanding",
        "-mcpu=v2",
        "-O2",
        "-mllvm",
        "-bpf-stack-size=4096",
        "-c",
    });
    zig_cc.addFileArg(bitcode);
    zig_cc.addArg("-o");
    const obj = zig_cc.addOutputFileArg(b.fmt("{s}.o", .{options.name}));

    const link_program = b.addSystemCommand(&.{options.elf2sbpf_bin});
    link_program.addFileArg(obj);
    const so = link_program.addOutputFileArg(b.fmt("{s}.so", .{options.name}));

    b.getInstallStep().dependOn(&b.addInstallLibFile(so, b.fmt("{s}.so", .{options.name})).step);

    return .{
        .name = options.name,
        .module = solana_mod,
        .so = so,
        .step = &link_program.step,
    };
}

pub const bpf_target: std.Target.Query = .{
    .cpu_arch = .bpfel,
    .cpu_model = .{
        .explicit = &std.Target.bpf.cpu.v2,
    },
    .os_tag = .freestanding,
    .cpu_features_add = std.Target.bpf.cpu.v2.features,
};
