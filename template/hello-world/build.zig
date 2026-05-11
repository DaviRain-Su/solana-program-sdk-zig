const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    // Build the on-chain program only when explicitly requested.
    // `zig build test` only runs unit tests; use `zig build -Dbuild-program` to also build the .so.
    const build_program = b.option(bool, "build-program", "Build the on-chain program") orelse false;

    if (build_program) {
        _ = solana.buildProgram(b, .{
            .name = "hello_world",
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
        });
    }

    const host_dep = b.dependency("solana_program_sdk", .{
        .target = b.graph.host,
        .optimize = optimize,
    });
    const host_mod = host_dep.module("solana_program_sdk");
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = host_mod },
        },
    });
    const unit_tests = b.addTest(.{ .root_module = test_mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run template tests");
    test_step.dependOn(&run_unit_tests.step);
}
