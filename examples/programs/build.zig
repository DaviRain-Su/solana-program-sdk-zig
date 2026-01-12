//! Build configuration for Solana example programs
//!
//! Build all programs:
//! ```bash
//! ./solana-zig/zig build
//! ```

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
    const optimize = .ReleaseSmall;
    const target = b.resolveTargetQuery(solana.sbf_target);

    // Hello World program
    const hello_world = b.addLibrary(.{
        .name = "hello_world",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("hello_world/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });
    _ = solana.buildProgram(b, hello_world, target, optimize);
    b.installArtifact(hello_world);
    generateProgramKeypair(b, hello_world);

    // Counter program
    const counter = b.addLibrary(.{
        .name = "counter",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("counter/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });
    _ = solana.buildProgram(b, counter, target, optimize);
    b.installArtifact(counter);
    generateProgramKeypair(b, counter);

    // Transfer Lamports program
    const transfer_lamports = b.addLibrary(.{
        .name = "transfer_lamports",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("transfer_lamports/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });
    _ = solana.buildProgram(b, transfer_lamports, target, optimize);
    b.installArtifact(transfer_lamports);
    generateProgramKeypair(b, transfer_lamports);
}
