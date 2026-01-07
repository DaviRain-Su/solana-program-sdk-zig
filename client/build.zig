const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get dependencies
    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");

    const solana_sdk_dep = b.dependency("solana_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_sdk_mod = solana_sdk_dep.module("solana_sdk");

    // Export self as a module
    const solana_client_mod = b.addModule("solana_client", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    solana_client_mod.addImport("base58", base58_mod);
    solana_client_mod.addImport("solana_sdk", solana_sdk_mod);

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = solana_client_mod,
    });

    lib_unit_tests.root_module.addImport("base58", base58_mod);
    lib_unit_tests.root_module.addImport("solana_sdk", solana_sdk_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
