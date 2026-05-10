const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    // Use `-Dsolana-zig` to force fork path, otherwise auto-detect.
    const use_fork = b.option(bool, "solana-zig", "Use solana-zig fork path (sbf target)") orelse blk: {
        if (b.graph.environ_map.get("SOLANA_ZIG_BIN")) |sz| {
            break :blk std.mem.eql(u8, sz, b.graph.zig_exe);
        }
        break :blk false;
    };

    if (use_fork and !solana.has_sbf_target) {
        std.log.err("-Dsolana-zig requested but compiler does not support sbf target", .{});
        return error.SbfTargetNotSupported;
    }

    if (use_fork) {
        _ = solana.buildProgram(b, .{
            .name = "pubkey",
            .root_source_file = b.path("pubkey/main.zig"),
            .optimize = optimize,
        });
    } else {
        const target = b.resolveTargetQuery(solana.bpf_target);
        const elf2sbpf_bin = b.option(
            []const u8,
            "elf2sbpf-bin",
            "Path to the elf2sbpf executable",
        );
        _ = solana.buildProgramElf2sbpf(b, .{
            .name = "pubkey",
            .root_source_file = b.path("pubkey/main.zig"),
            .target = target,
            .optimize = optimize,
            .elf2sbpf_bin = elf2sbpf_bin,
        });
    }
}
