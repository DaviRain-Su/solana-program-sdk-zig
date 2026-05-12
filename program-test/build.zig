const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    const programs = .{
        // In-tree test programs.
        .{ "pubkey", "pubkey/main.zig" },
        .{ "cpi", "cpi/main.zig" },
        // Example programs from `examples/` — wired into the
        // program-test build so Mollusk tests can exercise their
        // actual on-chain behaviour (not just host-side unit tests).
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
