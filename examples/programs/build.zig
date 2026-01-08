//! Build configuration for Solana example programs
//!
//! Build all programs:
//! ```bash
//! ./solana-zig/zig build
//! ```

const std = @import("std");
const solana = @import("solana_program_sdk");
const base58 = @import("base58");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
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
    base58.generateProgramKeypair(b, hello_world);

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
    base58.generateProgramKeypair(b, counter);

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
    base58.generateProgramKeypair(b, transfer_lamports);
}
