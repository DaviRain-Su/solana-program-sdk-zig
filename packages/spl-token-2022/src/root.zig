//! `spl_token_2022` — on-chain-safe Token-2022 parsing foundations.
//!
//! v0.1 exposes parsing/foundation surfaces plus base Token-2022 and selected
//! extension instruction builders.

const std = @import("std");

pub const id = @import("id.zig");
pub const state = @import("state.zig");
pub const tlv = @import("tlv.zig");
pub const extension = @import("extension.zig");
pub const instruction = @import("instruction.zig");
pub const cpi = @import("cpi.zig");
pub const variable_extensions = @import("variable_extensions.zig");

pub const PROGRAM_ID = id.PROGRAM_ID;
pub const NATIVE_MINT = id.NATIVE_MINT;

pub const AccountType = state.AccountType;
pub const AccountState = state.AccountState;
pub const parseAccountType = state.parseAccountType;
pub const parseAccountState = state.parseAccountState;

pub const ExtensionType = extension.ExtensionType;
pub const TlvError = tlv.Error;
pub const TlvRecord = tlv.Record;
pub const TlvIterator = tlv.Iterator;
pub const ParsedAccountData = tlv.Parsed;

pub const MINT_BASE_LEN = tlv.MINT_BASE_LEN;
pub const ACCOUNT_BASE_LEN = tlv.ACCOUNT_BASE_LEN;
pub const MINT_PADDING_START = tlv.MINT_PADDING_START;
pub const MINT_PADDING_END = tlv.MINT_PADDING_END;
pub const ACCOUNT_TYPE_OFFSET = tlv.ACCOUNT_TYPE_OFFSET;
pub const TLV_START_OFFSET = tlv.TLV_START_OFFSET;
pub const parseMint = tlv.parseMint;
pub const parseAccount = tlv.parseAccount;
pub const findMintExtension = tlv.findMintExtension;
pub const findAccountExtension = tlv.findAccountExtension;

pub const MetadataAdditional = variable_extensions.MetadataAdditional;
pub const TokenMetadata = variable_extensions.TokenMetadata;
pub const TokenGroup = variable_extensions.TokenGroup;
pub const TokenGroupMember = variable_extensions.TokenGroupMember;
pub const parseTokenMetadata = variable_extensions.parseTokenMetadata;
pub const parseTokenMetadataMint = variable_extensions.parseTokenMetadataMint;
pub const parseTokenGroup = variable_extensions.parseTokenGroup;
pub const parseTokenGroupMint = variable_extensions.parseTokenGroupMint;
pub const parseTokenGroupMember = variable_extensions.parseTokenGroupMember;
pub const parseTokenGroupMemberMint = variable_extensions.parseTokenGroupMemberMint;

pub const Token2022Instruction = instruction.Token2022Instruction;
pub const AuthorityType = instruction.AuthorityType;
pub const ConfidentialProofLocation = instruction.ConfidentialProofLocation;
pub const TransferFeeInstruction = instruction.TransferFeeInstruction;
pub const ConfidentialTransferInstruction = instruction.ConfidentialTransferInstruction;
pub const ConfidentialTransferFeeInstruction = instruction.ConfidentialTransferFeeInstruction;
pub const DefaultAccountStateInstruction = instruction.DefaultAccountStateInstruction;
pub const RequiredMemoTransfersInstruction = instruction.RequiredMemoTransfersInstruction;
pub const CpiGuardInstruction = instruction.CpiGuardInstruction;
pub const InterestBearingMintInstruction = instruction.InterestBearingMintInstruction;
pub const PausableInstruction = instruction.PausableInstruction;
pub const MetadataPointerInstruction = instruction.MetadataPointerInstruction;
pub const GroupPointerInstruction = instruction.GroupPointerInstruction;
pub const GroupMemberPointerInstruction = instruction.GroupMemberPointerInstruction;
pub const TransferHookInstruction = instruction.TransferHookInstruction;
pub const ScaledUiAmountInstruction = instruction.ScaledUiAmountInstruction;

test "@import(\"spl_token_2022\") exposes parsing and instruction declarations" {
    try std.testing.expect(@hasDecl(@This(), "PROGRAM_ID"));
    try std.testing.expect(@hasDecl(@This(), "NATIVE_MINT"));
    try std.testing.expect(@hasDecl(@This(), "id"));
    try std.testing.expect(@hasDecl(@This(), "state"));
    try std.testing.expect(@hasDecl(@This(), "tlv"));
    try std.testing.expect(@hasDecl(@This(), "extension"));
    try std.testing.expect(@hasDecl(@This(), "instruction"));
    try std.testing.expect(@hasDecl(@This(), "cpi"));
    try std.testing.expect(@hasDecl(@This(), "variable_extensions"));
    try std.testing.expect(@hasDecl(@This(), "AccountType"));
    try std.testing.expect(@hasDecl(@This(), "AccountState"));
    try std.testing.expect(@hasDecl(@This(), "parseAccountType"));
    try std.testing.expect(@hasDecl(@This(), "parseAccountState"));
    try std.testing.expect(@hasDecl(@This(), "ExtensionType"));
    try std.testing.expect(@hasDecl(@This(), "TlvError"));
    try std.testing.expect(@hasDecl(@This(), "TlvRecord"));
    try std.testing.expect(@hasDecl(@This(), "TlvIterator"));
    try std.testing.expect(@hasDecl(@This(), "ParsedAccountData"));
    try std.testing.expect(@hasDecl(@This(), "MINT_BASE_LEN"));
    try std.testing.expect(@hasDecl(@This(), "ACCOUNT_BASE_LEN"));
    try std.testing.expect(@hasDecl(@This(), "ACCOUNT_TYPE_OFFSET"));
    try std.testing.expect(@hasDecl(@This(), "TLV_START_OFFSET"));
    try std.testing.expect(@hasDecl(@This(), "parseMint"));
    try std.testing.expect(@hasDecl(@This(), "parseAccount"));
    try std.testing.expect(@hasDecl(@This(), "findMintExtension"));
    try std.testing.expect(@hasDecl(@This(), "findAccountExtension"));
    try std.testing.expect(@hasDecl(@This(), "TokenMetadata"));
    try std.testing.expect(@hasDecl(@This(), "TokenGroup"));
    try std.testing.expect(@hasDecl(@This(), "TokenGroupMember"));
    try std.testing.expect(@hasDecl(@This(), "parseTokenMetadataMint"));
    try std.testing.expect(@hasDecl(@This(), "parseTokenGroupMint"));
    try std.testing.expect(@hasDecl(@This(), "parseTokenGroupMemberMint"));
    try std.testing.expect(@hasDecl(@This(), "Token2022Instruction"));
    try std.testing.expect(@hasDecl(@This(), "AuthorityType"));
    try std.testing.expect(@hasDecl(@This(), "ConfidentialProofLocation"));
    try std.testing.expect(@hasDecl(@This(), "TransferFeeInstruction"));
    try std.testing.expect(@hasDecl(@This(), "ConfidentialTransferInstruction"));
    try std.testing.expect(@hasDecl(@This(), "ConfidentialTransferFeeInstruction"));
    try std.testing.expect(@hasDecl(@This(), "DefaultAccountStateInstruction"));
    try std.testing.expect(@hasDecl(@This(), "RequiredMemoTransfersInstruction"));
    try std.testing.expect(@hasDecl(@This(), "CpiGuardInstruction"));
    try std.testing.expect(@hasDecl(@This(), "InterestBearingMintInstruction"));
    try std.testing.expect(@hasDecl(@This(), "PausableInstruction"));
    try std.testing.expect(@hasDecl(@This(), "MetadataPointerInstruction"));
    try std.testing.expect(@hasDecl(@This(), "GroupPointerInstruction"));
    try std.testing.expect(@hasDecl(@This(), "GroupMemberPointerInstruction"));
    try std.testing.expect(@hasDecl(@This(), "TransferHookInstruction"));
    try std.testing.expect(@hasDecl(@This(), "ScaledUiAmountInstruction"));

    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "client"));
    try std.testing.expect(!@hasDecl(@This(), "keypair"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}

test "PROGRAM_ID aliases id.PROGRAM_ID" {
    try std.testing.expectEqualSlices(u8, &id.PROGRAM_ID, &PROGRAM_ID);
}

test "NATIVE_MINT aliases id.NATIVE_MINT" {
    try std.testing.expectEqualSlices(u8, &id.NATIVE_MINT, &NATIVE_MINT);
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}

fn expectNotContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) == null);
}

test "source-review guards keep spl_token_2022 canonically wired" {
    const root_source = @embedFile("root.zig");
    try expectNotContains(root_source, "pub const " ++ "rpc =");
    try expectNotContains(root_source, "pub const " ++ "client =");
    try expectNotContains(root_source, "pub const " ++ "keypair =");
    try expectNotContains(root_source, "pub const " ++ "transaction =");

    const package_sources = [_][]const u8{
        root_source,
        @embedFile("id.zig"),
        @embedFile("state.zig"),
        @embedFile("tlv.zig"),
        @embedFile("extension.zig"),
        @embedFile("instruction.zig"),
        @embedFile("cpi.zig"),
        @embedFile("variable_extensions.zig"),
    };
    inline for (package_sources) |source| {
        try expectNotContains(source, "solana_" ++ "client");
        try expectNotContains(source, "solana_" ++ "tx");
        try expectNotContains(source, "solana_" ++ "keypair");
        try expectNotContains(source, "@import(\"spl" ++ "_token\")");
        try expectNotContains(source, "@import(\"spl" ++ "_ata\")");
        try expectNotContains(source, "@import(\"spl" ++ "_memo\")");
    }
}

test {
    std.testing.refAllDecls(@This());
}
