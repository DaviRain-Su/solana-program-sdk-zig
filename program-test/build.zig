const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .bpfel,
        .cpu_model = .{
            .explicit = &std.Target.bpf.cpu.v2,
        },
        .os_tag = .freestanding,
        .cpu_features_add = std.Target.bpf.cpu.v2.features,
    });
    const elf2sbpf_bin = b.option(
        []const u8,
        "elf2sbpf-bin",
        "Path to the elf2sbpf executable (default: look up on PATH)",
    ) orelse "elf2sbpf";

    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");

    const program_mod = b.createModule(.{
        .root_source_file = b.path("pubkey/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = solana_mod },
        },
    });
    program_mod.pic = true;
    program_mod.strip = true;

    const bitcode_obj = b.addObject(.{
        .name = "pubkey-bitcode",
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
    const obj = zig_cc.addOutputFileArg("pubkey.o");

    const link_program = b.addSystemCommand(&.{elf2sbpf_bin});
    link_program.addFileArg(obj);
    const so = link_program.addOutputFileArg("pubkey.so");

    b.getInstallStep().dependOn(&b.addInstallLibFile(so, "pubkey.so").step);
}
