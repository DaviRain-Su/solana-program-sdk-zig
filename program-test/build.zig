const std = @import("std");
const solana = @import("solana_program_sdk");
const base58 = @import("base58");

fn generateProgramKeypair(b: *std.Build, program: *std.Build.Step.Compile) void {
    const program_name = program.out_filename[0 .. program.out_filename.len - std.fs.path.extension(program.out_filename).len];
    const path = b.fmt("{s}-keypair.json", .{program_name});
    const lib_path = b.getInstallPath(.lib, path);
    const lib_dir = b.getInstallPath(.lib, "");

    const ensure_dir = b.addSystemCommand(&.{ "mkdir", "-p", lib_dir });
    const run_step = base58.generateKeypairRunStep(b, lib_path);
    run_step.step.dependOn(&program.step);
    run_step.step.dependOn(&ensure_dir.step);
    b.getInstallStep().dependOn(&run_step.step);
}

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(solana.sbf_target);
    const program = b.addLibrary(.{
        .name = "pubkey",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("pubkey/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    // Adding required dependencies, link the program properly, and get a
    // prepared modules
    _ = solana.buildProgram(b, program, target, optimize);
    b.installArtifact(program);
    generateProgramKeypair(b, program);
}
