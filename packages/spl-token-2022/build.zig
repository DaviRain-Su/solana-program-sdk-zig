const std = @import("std");

/// `zig build` exposes:
///   * `test` — run the package's host-side unit tests.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sol_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const sol_mod = sol_dep.module("solana_program_sdk");
    const spl_token_metadata_dep = b.dependency("spl_token_metadata", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_token_metadata_mod = spl_token_metadata_dep.module("spl_token_metadata");
    const spl_token_group_dep = b.dependency("spl_token_group", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_token_group_mod = spl_token_group_dep.module("spl_token_group");

    const spl_token_2022_mod = b.addModule("spl_token_2022", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "spl_token_metadata", .module = spl_token_metadata_mod },
            .{ .name = "spl_token_group", .module = spl_token_group_mod },
        },
    });

    const tests = b.addTest(.{ .root_module = spl_token_2022_mod });
    const run_tests = b.addRunArtifact(tests);

    const composition_test_mod = b.createModule(.{
        .root_source_file = b.path("src/metadata_group_composition_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "spl_token_2022", .module = spl_token_2022_mod },
            .{ .name = "spl_token_metadata", .module = spl_token_metadata_mod },
            .{ .name = "spl_token_group", .module = spl_token_group_mod },
        },
    });
    const composition_tests = b.addTest(.{ .root_module = composition_test_mod });
    const run_composition_tests = b.addRunArtifact(composition_tests);

    const test_step = b.step("test", "Run host-side unit tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_composition_tests.step);
}
