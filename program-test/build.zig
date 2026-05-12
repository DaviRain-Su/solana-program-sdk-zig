const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    // Every program-test program is built from `examples/` so the
    // tree has one single source of truth for "real, deployable
    // example programs". The names below are kept stable because
    // the Rust integration tests reference them via
    // `zig-out/lib/<name>.so`.
    const programs = .{
        .{ "pubkey", "../examples/pubkey.zig" },
        .{ "cpi", "../examples/cpi.zig" },
        .{ "example_hello", "../examples/hello.zig" },
        .{ "example_counter", "../examples/counter.zig" },
        .{ "example_vault", "../examples/vault.zig" },
        .{ "example_escrow", "../examples/escrow.zig" },
    };

    inline for (programs) |p| {
        _ = solana.buildProgram(b, .{
            .name = p[0],
            .root_source_file = b.path(p[1]),
            .optimize = optimize,
        });
    }
}
