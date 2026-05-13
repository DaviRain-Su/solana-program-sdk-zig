const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(solana.sbfTarget());
    const sol_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const sol_mod = sol_dep.module("solana_program_sdk");
    const spl_token_mod = b.createModule(.{
        .root_source_file = b.path("../packages/spl-token/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "solana_program_sdk", .module = sol_mod },
        },
    });

    const benchmarks = .{
        .{ "benchmark_pubkey_cmp_safe", "pubkey_cmp_safe.zig" },
        .{ "benchmark_pubkey_cmp_safe_raw", "pubkey_cmp_safe_raw.zig" },
        .{ "benchmark_pubkey_cmp_unchecked", "pubkey_cmp_unchecked.zig" },
        .{ "benchmark_pubkey_cmp_comptime", "pubkey_cmp_comptime.zig" },
        .{ "benchmark_pubkey_cmp_any_2", "pubkey_cmp_any_2.zig" },
        .{ "benchmark_pubkey_cmp_runtime_const", "pubkey_cmp_runtime_const.zig" },
        .{ "benchmark_pda_runtime", "pda_runtime.zig" },
        .{ "benchmark_pda_comptime", "pda_comptime.zig" },
        .{ "benchmark_parse_accounts", "parse_accounts.zig" },
        .{ "benchmark_parse_accounts_with", "parse_accounts_with.zig" },
        .{ "benchmark_parse_accounts_with_unchecked", "parse_accounts_with_unchecked.zig" },
        .{ "benchmark_sysvar_copy", "sysvar_copy.zig" },
        .{ "benchmark_sysvar_ref", "sysvar_ref.zig" },
        .{ "benchmark_program_entry_1", "program_entry_1.zig" },
        .{ "benchmark_program_entry_lazy_1", "program_entry_lazy_1.zig" },
        .{ "benchmark_transfer_lamports", "transfer_lamports.zig" },
        .{ "benchmark_transfer_lamports_raw", "transfer_lamports_raw.zig" },
        .{ "example_vault", "../examples/vault.zig" },
        .{ "example_token_dispatch", "../examples/token_dispatch.zig" },
        .{ "example_hello", "../examples/hello.zig" },
        .{ "example_counter", "../examples/counter.zig" },
        .{ "example_escrow", "../examples/escrow.zig" },
        .{ "benchmark_token_dispatch_unchecked", "token_dispatch_unchecked.zig" },
        .{ "benchmark_token_dispatch_parse_only", "token_dispatch_parse_only.zig" },
        .{ "benchmark_token_dispatch_bind_only", "token_dispatch_bind_only.zig" },
        .{ "benchmark_noop_callee", "noop_callee.zig" },
    };

    inline for (benchmarks) |bench| {
        _ = solana.buildProgram(b, .{
            .name = bench[0],
            .root_source_file = b.path(bench[1]),
            .optimize = optimize,
        });
    }

    const spl_token_benchmarks = .{
        .{ "benchmark_spl_token_mint_to_checked_signed", "spl_token_mint_to_checked_signed.zig" },
        .{ "benchmark_spl_token_mint_to_checked_signed_single", "spl_token_mint_to_checked_signed_single.zig" },
    };

    inline for (spl_token_benchmarks) |bench| {
        _ = solana.buildProgram(b, .{
            .name = bench[0],
            .root_source_file = b.path(bench[1]),
            .optimize = optimize,
            .extra_imports = &.{
                .{ .name = "spl_token", .module = spl_token_mod },
            },
        });
    }
}
