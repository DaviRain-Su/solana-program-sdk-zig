const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(solana.bpf_target);
    const elf2sbpf_bin = b.option(
        []const u8,
        "elf2sbpf-bin",
        "Path to the elf2sbpf executable (default: look up on PATH)",
    ) orelse "elf2sbpf";

    _ = solana.buildProgramElf2sbpf(b, .{
        .name = "pubkey",
        .root_source_file = b.path("pubkey/main.zig"),
        .optimize = optimize,
        .target = target,
        .elf2sbpf_bin = elf2sbpf_bin,
    });
}
