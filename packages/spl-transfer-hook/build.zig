const std = @import("std");

/// `zig build` exposes:
///   * `test` — run the package's host-side unit tests, including a
///     consumer-style `@import("spl_transfer_hook")` fixture.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sol_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const sol_mod = sol_dep.module("solana_program_sdk");
    const codec_dep = b.dependency("solana_codec", .{
        .target = target,
        .optimize = optimize,
    });
    const codec_mod = codec_dep.module("solana_codec");
    const spl_token_2022_dep = b.dependency("spl_token_2022", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_token_2022_mod = spl_token_2022_dep.module("spl_token_2022");

    const spl_transfer_hook_mod = b.addModule("spl_transfer_hook", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "solana_codec", .module = codec_mod },
        },
    });

    const package_tests = b.addTest(.{ .root_module = spl_transfer_hook_mod });
    const run_package_tests = b.addRunArtifact(package_tests);

    const consumer_test_mod = b.createModule(.{
        .root_source_file = b.path("src/consumer_import_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "spl_transfer_hook", .module = spl_transfer_hook_mod },
        },
    });
    const consumer_tests = b.addTest(.{ .root_module = consumer_test_mod });
    const run_consumer_tests = b.addRunArtifact(consumer_tests);

    const coexistence_test_mod = b.createModule(.{
        .root_source_file = b.path("src/token_2022_coexistence_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
            .{ .name = "spl_transfer_hook", .module = spl_transfer_hook_mod },
            .{ .name = "spl_token_2022", .module = spl_token_2022_mod },
        },
    });
    const coexistence_tests = b.addTest(.{ .root_module = coexistence_test_mod });
    const run_coexistence_tests = b.addRunArtifact(coexistence_tests);

    const test_step = b.step("test", "Run host-side unit tests");
    test_step.dependOn(&run_package_tests.step);
    test_step.dependOn(&run_consumer_tests.step);
    test_step.dependOn(&run_coexistence_tests.step);
}
