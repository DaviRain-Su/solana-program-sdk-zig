//! `spl_token_metadata` — on-chain/interface scaffold for the SPL
//! Token Metadata interface package.
//!
//! v0.1 intentionally wires only package metadata, stable imports,
//! interface-only public roots, and raw instruction-builder boundary
//! helpers.

const std = @import("std");

pub const id = @import("id.zig");
pub const instruction = @import("instruction.zig");
pub const state = @import("state.zig");

pub const PACKAGE_NAME = id.PACKAGE_NAME;
pub const MODULE_NAME = id.MODULE_NAME;
pub const INTERFACE_VERSION = id.INTERFACE_VERSION;
pub const INTERFACE_NAMESPACE = id.INTERFACE_NAMESPACE;
pub const SCOPE = id.SCOPE;

test "@import(\"spl_token_metadata\") exposes only interface scaffold declarations" {
    try std.testing.expect(@hasDecl(@This(), "id"));
    try std.testing.expect(@hasDecl(@This(), "instruction"));
    try std.testing.expect(@hasDecl(@This(), "state"));
    try std.testing.expect(@hasDecl(@This(), "PACKAGE_NAME"));
    try std.testing.expect(@hasDecl(@This(), "MODULE_NAME"));
    try std.testing.expect(@hasDecl(@This(), "INTERFACE_VERSION"));
    try std.testing.expect(@hasDecl(@This(), "INTERFACE_NAMESPACE"));
    try std.testing.expect(@hasDecl(@This(), "SCOPE"));

    try std.testing.expect(!@hasDecl(@This(), "PROGRAM_ID"));
    try std.testing.expect(!@hasDecl(@This(), "processor"));
    try std.testing.expect(!@hasDecl(@This(), "cpi"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "client"));
    try std.testing.expect(!@hasDecl(@This(), "keypair"));
    try std.testing.expect(!@hasDecl(@This(), "searcher"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}

fn expectNotContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) == null);
}

test "source-review guards keep spl_token_metadata interface scoped" {
    const root_source = @embedFile("root.zig");
    try expectContains(root_source, "spl_token_metadata");
    try expectContains(root_source, "pub const instruction = @import(\"instruction.zig\");");
    try expectContains(root_source, "pub const state = @import(\"state.zig\");");
    try expectNotContains(root_source, "pub const " ++ "PROGRAM_ID =");
    try expectNotContains(root_source, "pub const " ++ "processor =");
    try expectNotContains(root_source, "pub const " ++ "rpc =");
    try expectNotContains(root_source, "pub const " ++ "client =");
    try expectNotContains(root_source, "pub const " ++ "keypair =");
    try expectNotContains(root_source, "pub const " ++ "searcher =");
    try expectNotContains(root_source, "pub const " ++ "transaction =");

    const package_sources = [_][]const u8{
        root_source,
        @embedFile("id.zig"),
        @embedFile("instruction.zig"),
        @embedFile("state.zig"),
    };
    inline for (package_sources) |source| {
        try expectNotContains(source, "@import(\"solana_" ++ "client\")");
        try expectNotContains(source, "@import(\"solana_" ++ "tx\")");
        try expectNotContains(source, "@import(\"solana_" ++ "keypair\")");
        try expectNotContains(source, "pub const " ++ "processor =");
        try expectNotContains(source, "pub const " ++ "rpc =");
        try expectNotContains(source, "pub const " ++ "client =");
        try expectNotContains(source, "pub const " ++ "keypair =");
        try expectNotContains(source, "pub const " ++ "searcher =");
        try expectNotContains(source, "pub const " ++ "transaction =");
    }
}

test {
    std.testing.refAllDecls(@This());
}
