//! Anchor IDL JSON generator CLI
//!
//! Rust source: https://github.com/coral-xyz/anchor/blob/master/cli/src/lib.rs
//!
//! This tool writes Anchor-compatible IDL JSON to an output path.

const std = @import("std");
const anchor = @import("sol_anchor_zig");
const build_options = @import("build_options");
const program_mod = @import("idl_program");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const output = build_options.idl_output_path;
    try anchor.idl.writeJsonFile(allocator, program_mod.Program, .{}, output);
}
