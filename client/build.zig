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

    // Create rpc_client module for integration tests
    const rpc_client_mod = b.addModule("rpc_client", .{
        .root_source_file = b.path("src/rpc_client.zig"),
        .target = target,
        .optimize = optimize,
    });
    rpc_client_mod.addImport("base58", base58_mod);
    rpc_client_mod.addImport("solana_sdk", solana_sdk_mod);

    // Create transaction module for integration tests
    const transaction_mod = b.addModule("transaction", .{
        .root_source_file = b.path("src/transaction/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    transaction_mod.addImport("base58", base58_mod);
    transaction_mod.addImport("solana_sdk", solana_sdk_mod);

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = solana_client_mod,
    });

    lib_unit_tests.root_module.addImport("base58", base58_mod);
    lib_unit_tests.root_module.addImport("solana_sdk", solana_sdk_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Integration tests (requires running local validator)
    // RPC integration tests
    const rpc_integration_test_mod = b.createModule(.{
        .root_source_file = b.path("integration/test_rpc.zig"),
        .target = target,
        .optimize = optimize,
    });
    rpc_integration_test_mod.addImport("rpc_client", rpc_client_mod);
    rpc_integration_test_mod.addImport("solana_sdk", solana_sdk_mod);

    const rpc_integration_tests = b.addTest(.{
        .root_module = rpc_integration_test_mod,
    });

    const run_rpc_integration_tests = b.addRunArtifact(rpc_integration_tests);

    // Transaction integration tests
    const tx_integration_test_mod = b.createModule(.{
        .root_source_file = b.path("integration/test_transaction.zig"),
        .target = target,
        .optimize = optimize,
    });
    tx_integration_test_mod.addImport("rpc_client", rpc_client_mod);
    tx_integration_test_mod.addImport("solana_sdk", solana_sdk_mod);
    tx_integration_test_mod.addImport("transaction", transaction_mod);

    const tx_integration_tests = b.addTest(.{
        .root_module = tx_integration_test_mod,
    });

    const run_tx_integration_tests = b.addRunArtifact(tx_integration_tests);

    // Combined integration test step
    const integration_test_step = b.step("integration-test", "Run all integration tests (requires local validator)");
    integration_test_step.dependOn(&run_rpc_integration_tests.step);
    integration_test_step.dependOn(&run_tx_integration_tests.step);

    // Separate steps for individual test suites
    const rpc_test_step = b.step("integration-test-rpc", "Run RPC integration tests");
    rpc_test_step.dependOn(&run_rpc_integration_tests.step);

    const tx_test_step = b.step("integration-test-tx", "Run transaction integration tests");
    tx_test_step.dependOn(&run_tx_integration_tests.step);
}
