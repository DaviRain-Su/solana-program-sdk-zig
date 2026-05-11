const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    const benchmarks = .{
        .{ "benchmark_pubkey_cmp_safe", "pubkey_cmp_safe.zig" },
        .{ "benchmark_pubkey_cmp_safe_raw", "pubkey_cmp_safe_raw.zig" },
        .{ "benchmark_pubkey_cmp_unchecked", "pubkey_cmp_unchecked.zig" },
        .{ "benchmark_transfer_lamports", "transfer_lamports.zig" },
        .{ "benchmark_transfer_lamports_raw", "transfer_lamports_raw.zig" },
    };

    inline for (benchmarks) |bench| {
        _ = solana.buildProgram(b, .{
            .name = bench[0],
            .root_source_file = b.path(bench[1]),
            .optimize = optimize,
        });
    }
}
