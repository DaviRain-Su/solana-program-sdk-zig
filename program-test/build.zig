const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    _ = solana.buildProgram(b, .{
        .name = "pubkey",
        .root_source_file = b.path("pubkey/main.zig"),
        .optimize = optimize,
    });
}
