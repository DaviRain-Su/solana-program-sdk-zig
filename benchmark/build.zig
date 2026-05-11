const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const target = b.resolveTargetQuery(solana.bpf_target);
    const optimize = .ReleaseFast;
    const elf2sbpf_bin = b.option([]const u8, "elf2sbpf-bin", "Path to the elf2sbpf executable");

    _ = solana.buildProgramElf2sbpf(b, .{
        .name = "benchmark_pubkey_cmp_raw",
        .root_source_file = b.path("pubkey_cmp_raw.zig"),
        .target = target,
        .optimize = optimize,
        .elf2sbpf_bin = elf2sbpf_bin,
    });
}
