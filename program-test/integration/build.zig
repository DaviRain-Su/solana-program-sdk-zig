const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_dep = b.dependency("solana_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const sdk_mod = sdk_dep.module("solana_sdk");

    const test_mod = b.createModule(.{
        .root_source_file = b.path("test_pubkey.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("solana_sdk", sdk_mod);

    const integration_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_tests = b.addRunArtifact(integration_tests);
    const test_step = b.step("test", "Run integration tests");
    test_step.dependOn(&run_tests.step);
}
