const std = @import("std");

/// `zig build` exposes:
///   * `test` — run the package's host-side unit tests.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tx_dep = b.dependency("solana_tx", .{
        .target = target,
        .optimize = optimize,
    });
    const tx_mod = tx_dep.module("solana_tx");

    const keypair_dep = b.dependency("solana_keypair", .{
        .target = target,
        .optimize = optimize,
    });
    const keypair_mod = keypair_dep.module("solana_keypair");

    const system_dep = b.dependency("solana_system", .{
        .target = target,
        .optimize = optimize,
    });
    const system_mod = system_dep.module("solana_system");

    const compute_budget_dep = b.dependency("solana_compute_budget", .{
        .target = target,
        .optimize = optimize,
    });
    const compute_budget_mod = compute_budget_dep.module("solana_compute_budget");

    const spl_token_dep = b.dependency("spl_token", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_token_mod = spl_token_dep.module("spl_token");

    const spl_ata_dep = b.dependency("spl_ata", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_ata_mod = spl_ata_dep.module("spl_ata");

    const alt_dep = b.dependency("solana_address_lookup_table", .{
        .target = target,
        .optimize = optimize,
    });
    const alt_mod = alt_dep.module("solana_address_lookup_table");

    const builder_mod = b.addModule("solana_transaction_builder", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_tx", .module = tx_mod },
            .{ .name = "solana_keypair", .module = keypair_mod },
            .{ .name = "solana_system", .module = system_mod },
            .{ .name = "solana_compute_budget", .module = compute_budget_mod },
            .{ .name = "spl_token", .module = spl_token_mod },
            .{ .name = "spl_ata", .module = spl_ata_mod },
            .{ .name = "solana_address_lookup_table", .module = alt_mod },
        },
    });

    const tests = b.addTest(.{ .root_module = builder_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run host-side unit tests");
    test_step.dependOn(&run_tests.step);
}
