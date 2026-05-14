const std = @import("std");

/// `zig build` exposes:
///   * `test` — run the package's host-side unit tests.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const keypair_dep = b.dependency("solana_keypair", .{
        .target = target,
        .optimize = optimize,
    });
    const keypair_mod = keypair_dep.module("solana_keypair");

    const solana_wallet_mod = b.addModule("solana_wallet", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_keypair", .module = keypair_mod },
        },
    });

    const tests = b.addTest(.{ .root_module = solana_wallet_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run host-side unit tests");
    test_step.dependOn(&run_tests.step);
}
