//! `spl_transfer_hook` — on-chain/interface scaffold for the SPL
//! Transfer Hook package.
//!
//! v0.1 currently wires package metadata, import visibility, and API
//! surface guards only. Transfer-hook programs are caller-supplied,
//! so this scaffold intentionally does not publish a fixed
//! `PROGRAM_ID`.

const std = @import("std");

pub const id = @import("id.zig");
pub const instruction = @import("instruction.zig");
pub const meta = @import("meta.zig");
pub const resolve = @import("resolve.zig");
pub const Seed = @import("seed.zig").Seed;
pub const PubkeyData = @import("pubkey_data.zig").PubkeyData;

pub const PACKAGE_NAME = id.PACKAGE_NAME;
pub const MODULE_NAME = id.MODULE_NAME;
pub const INTERFACE_VERSION = id.INTERFACE_VERSION;
pub const SCOPE = id.SCOPE;
pub const ProgramDerivedAddress = resolve.ProgramDerivedAddress;
pub const AccountKeyData = resolve.AccountKeyData;
pub const EXTRA_ACCOUNT_METAS_SEED = resolve.EXTRA_ACCOUNT_METAS_SEED;
pub const findValidationAddress = resolve.findValidationAddress;
pub const resolveExtraAccountMeta = resolve.resolveExtraAccountMeta;
pub const resolveExtraAccountMetaList = resolve.resolveExtraAccountMetaList;

test "@import(\"spl_transfer_hook\") exposes only the intended scaffold surface" {
    try std.testing.expect(@hasDecl(@This(), "id"));
    try std.testing.expect(@hasDecl(@This(), "PACKAGE_NAME"));
    try std.testing.expect(@hasDecl(@This(), "MODULE_NAME"));
    try std.testing.expect(@hasDecl(@This(), "INTERFACE_VERSION"));
    try std.testing.expect(@hasDecl(@This(), "SCOPE"));
    try std.testing.expect(@hasDecl(@This(), "ProgramDerivedAddress"));
    try std.testing.expect(@hasDecl(@This(), "Seed"));
    try std.testing.expect(@hasDecl(@This(), "PubkeyData"));
    try std.testing.expect(@hasDecl(@This(), "AccountKeyData"));
    try std.testing.expect(@hasDecl(@This(), "EXTRA_ACCOUNT_METAS_SEED"));
    try std.testing.expect(@hasDecl(@This(), "findValidationAddress"));
    try std.testing.expect(@hasDecl(@This(), "resolveExtraAccountMeta"));
    try std.testing.expect(@hasDecl(@This(), "resolveExtraAccountMetaList"));
    try std.testing.expect(@hasDecl(@This(), "instruction"));
    try std.testing.expect(@hasDecl(@This(), "meta"));
    try std.testing.expect(@hasDecl(@This(), "resolve"));

    try std.testing.expect(!@hasDecl(@This(), "PROGRAM_ID"));
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

test "source-review guards keep spl_transfer_hook on-chain/interface scoped" {
    const root_source = @embedFile("root.zig");
    try expectContains(root_source, "spl_transfer_hook");
    try expectContains(root_source, "pub const ProgramDerivedAddress = resolve.ProgramDerivedAddress;");
    try expectContains(root_source, "pub const Seed = @import(\"seed.zig\").Seed;");
    try expectContains(root_source, "pub const PubkeyData = @import(\"pubkey_data.zig\").PubkeyData;");
    try expectContains(root_source, "pub const AccountKeyData = resolve.AccountKeyData;");
    try expectContains(root_source, "pub const EXTRA_ACCOUNT_METAS_SEED = resolve.EXTRA_ACCOUNT_METAS_SEED;");
    try expectContains(root_source, "pub const findValidationAddress = resolve.findValidationAddress;");
    try expectContains(root_source, "pub const resolveExtraAccountMeta = resolve.resolveExtraAccountMeta;");
    try expectContains(root_source, "pub const resolveExtraAccountMetaList = resolve.resolveExtraAccountMetaList;");
    try expectNotContains(root_source, "pub const " ++ "PROGRAM_ID =");
    try expectNotContains(root_source, "pub const " ++ "rpc =");
    try expectNotContains(root_source, "pub const " ++ "client =");
    try expectNotContains(root_source, "pub const " ++ "keypair =");
    try expectNotContains(root_source, "pub const " ++ "searcher =");
    try expectNotContains(root_source, "pub const " ++ "transaction =");

    const package_sources = [_][]const u8{
        root_source,
        @embedFile("id.zig"),
        @embedFile("instruction.zig"),
        @embedFile("meta.zig"),
        @embedFile("seed.zig"),
        @embedFile("pubkey_data.zig"),
        @embedFile("resolve.zig"),
    };
    inline for (package_sources) |source| {
        try expectNotContains(source, "@import(\"solana_" ++ "client\")");
        try expectNotContains(source, "@import(\"solana_" ++ "tx\")");
        try expectNotContains(source, "@import(\"solana_" ++ "keypair\")");
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
