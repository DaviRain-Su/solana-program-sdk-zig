//! `spl_token_2022` — on-chain-safe Token-2022 parsing foundations.
//!
//! v0.1 intentionally exposes only parsing/foundation surfaces:
//! program id, account-type parsing, base layout constants, and
//! placeholder namespaces for future TLV and extension views.

const std = @import("std");

pub const id = @import("id.zig");
pub const state = @import("state.zig");
pub const tlv = @import("tlv.zig");
pub const extension = @import("extension.zig");

pub const PROGRAM_ID = id.PROGRAM_ID;

pub const AccountType = state.AccountType;
pub const parseAccountType = state.parseAccountType;

pub const ExtensionType = extension.ExtensionType;

pub const MINT_BASE_LEN = tlv.MINT_BASE_LEN;
pub const ACCOUNT_BASE_LEN = tlv.ACCOUNT_BASE_LEN;
pub const MINT_PADDING_START = tlv.MINT_PADDING_START;
pub const MINT_PADDING_END = tlv.MINT_PADDING_END;
pub const ACCOUNT_TYPE_OFFSET = tlv.ACCOUNT_TYPE_OFFSET;
pub const TLV_START_OFFSET = tlv.TLV_START_OFFSET;

test "@import(\"spl_token_2022\") exposes parsing-only foundation declarations" {
    try std.testing.expect(@hasDecl(@This(), "PROGRAM_ID"));
    try std.testing.expect(@hasDecl(@This(), "id"));
    try std.testing.expect(@hasDecl(@This(), "state"));
    try std.testing.expect(@hasDecl(@This(), "tlv"));
    try std.testing.expect(@hasDecl(@This(), "extension"));
    try std.testing.expect(@hasDecl(@This(), "AccountType"));
    try std.testing.expect(@hasDecl(@This(), "parseAccountType"));
    try std.testing.expect(@hasDecl(@This(), "ExtensionType"));
    try std.testing.expect(@hasDecl(@This(), "MINT_BASE_LEN"));
    try std.testing.expect(@hasDecl(@This(), "ACCOUNT_BASE_LEN"));
    try std.testing.expect(@hasDecl(@This(), "ACCOUNT_TYPE_OFFSET"));
    try std.testing.expect(@hasDecl(@This(), "TLV_START_OFFSET"));

    try std.testing.expect(!@hasDecl(@This(), "instruction"));
    try std.testing.expect(!@hasDecl(@This(), "cpi"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "client"));
    try std.testing.expect(!@hasDecl(@This(), "keypair"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}

test "PROGRAM_ID aliases id.PROGRAM_ID" {
    try std.testing.expectEqualSlices(u8, &id.PROGRAM_ID, &PROGRAM_ID);
}

test {
    std.testing.refAllDecls(@This());
}
