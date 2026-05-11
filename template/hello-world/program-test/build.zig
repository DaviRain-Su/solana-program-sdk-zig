const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    // Use `-Dsolana-zig` to select the fork path (sbf target, best CU).
    // Without the flag, defaults to stock Zig + elf2sbpf fallback path.
    const use_fork = b.option(bool, "solana-zig", "Use solana-zig fork path (sbf target)") orelse false;

    if (use_fork) {
        _ = solana.buildProgram(b, .{
            .name = "hello_world",
            .root_source_file = b.path("../src/main.zig"),
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
            .name = "hello_world",
            .root_source_file = b.path("../src/main.zig"),
            .target = target,
            .optimize = optimize,
            .elf2sbpf_bin = elf2sbpf_bin,
        });
    }
}
