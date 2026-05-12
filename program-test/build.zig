const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    // Every program-test program is built from `examples/` so the
    // tree has one single source of truth for "real, deployable
    // example programs". The names below are kept stable because
    // the Rust integration tests reference them via
    // `zig-out/lib/<name>.so`.
    const programs = .{
        .{ "pubkey", "../examples/pubkey.zig" },
        .{ "cpi", "../examples/cpi.zig" },
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

    // Sub-package programs — built with the SDK plus the sub-package
    // as an extra import. The sub-package's `build.zig` exports a
    // module against the SBF target requested here, so the program
    // can `@import("spl_memo")` and CPI into the real on-chain Memo
    // program during program-test.
    const target = b.resolveTargetQuery(solana.sbfTarget());
    const spl_memo_dep = b.dependency("spl_memo", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_memo_mod = spl_memo_dep.module("spl_memo");

    _ = solana.buildProgram(b, .{
        .name = "example_spl_memo_cpi",
        .root_source_file = b.path("../packages/spl-memo/examples/cpi_demo.zig"),
        .optimize = optimize,
        .extra_imports = &.{
            .{ .name = "spl_memo", .module = spl_memo_mod },
        },
    });

    const spl_token_dep = b.dependency("spl_token", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_token_mod = spl_token_dep.module("spl_token");

    _ = solana.buildProgram(b, .{
        .name = "example_spl_token_cpi",
        .root_source_file = b.path("../packages/spl-token/examples/cpi_demo.zig"),
        .optimize = optimize,
        .extra_imports = &.{
            .{ .name = "spl_token", .module = spl_token_mod },
        },
    });

    const spl_ata_dep = b.dependency("spl_ata", .{
        .target = target,
        .optimize = optimize,
    });
    const spl_ata_mod = spl_ata_dep.module("spl_ata");

    _ = solana.buildProgram(b, .{
        .name = "example_spl_ata_cpi",
        .root_source_file = b.path("../packages/spl-ata/examples/cpi_demo.zig"),
        .optimize = optimize,
        .extra_imports = &.{
            .{ .name = "spl_ata", .module = spl_ata_mod },
        },
    });
}
