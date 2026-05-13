const std = @import("std");

/// `zig build` exposes:
///   * `test` — run the package's host-side unit tests, a
///     consumer-style `@import("spl_token_metadata")` fixture, and a
///     combined metadata/group consumer import fixture.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sol_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const sol_mod = sol_dep.module("solana_program_sdk");
    const spl_token_group_dep = b.dependency("spl_token_group", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_token_group_mod = spl_token_group_dep.module("spl_token_group");

    const spl_token_metadata_mod = b.addModule("spl_token_metadata", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
        },
    });

    const package_tests = b.addTest(.{ .root_module = spl_token_metadata_mod });
    const run_package_tests = b.addRunArtifact(package_tests);

    const consumer_test_mod = b.createModule(.{
        .root_source_file = b.path("src/consumer_import_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "spl_token_metadata", .module = spl_token_metadata_mod },
        },
    });
    const consumer_tests = b.addTest(.{ .root_module = consumer_test_mod });
    const run_consumer_tests = b.addRunArtifact(consumer_tests);

    const combined_import_test_mod = b.createModule(.{
        .root_source_file = b.path("src/combined_import_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "spl_token_metadata", .module = spl_token_metadata_mod },
            .{ .name = "spl_token_group", .module = spl_token_group_mod },
        },
    });
    const combined_import_tests = b.addTest(.{ .root_module = combined_import_test_mod });
    const run_combined_import_tests = b.addRunArtifact(combined_import_tests);

    const test_step = b.step("test", "Run host-side unit tests");
    test_step.dependOn(&run_package_tests.step);
    test_step.dependOn(&run_consumer_tests.step);
    test_step.dependOn(&run_combined_import_tests.step);
}
