//! Zig implementation of SPL Token instruction types
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/instruction.rs
//!
//! This module provides instruction type definitions and parsing for the SPL Token program.

const std = @import("std");
const PublicKey = @import("../../public_key.zig").PublicKey;
const state = @import("state.zig");

pub const TOKEN_PROGRAM_ID = state.TOKEN_PROGRAM_ID;

// ============================================================================
// Token Instruction Enum
// ============================================================================

/// Token program instruction types (25 total).
pub const TokenInstruction = enum(u8) {
    InitializeMint = 0,
    InitializeAccount = 1,
    InitializeMultisig = 2,
    Transfer = 3,
    Approve = 4,
    Revoke = 5,
    SetAuthority = 6,
    MintTo = 7,
    Burn = 8,
    CloseAccount = 9,
    FreezeAccount = 10,
    ThawAccount = 11,
    TransferChecked = 12,
    ApproveChecked = 13,
    MintToChecked = 14,
    BurnChecked = 15,
    InitializeAccount2 = 16,
    SyncNative = 17,
    InitializeAccount3 = 18,
    InitializeMultisig2 = 19,
    InitializeMint2 = 20,
    GetAccountDataSize = 21,
    InitializeImmutableOwner = 22,
    AmountToUiAmount = 23,
    UiAmountToAmount = 24,

    pub fn fromByte(byte: u8) ?TokenInstruction {
        return std.meta.intToEnum(TokenInstruction, byte) catch null;
    }
};

// ============================================================================
// Authority Type Enum
// ============================================================================

/// Types of authority that can be set on a mint or account.
pub const AuthorityType = enum(u8) {
    MintTokens = 0,
    FreezeAccount = 1,
    AccountOwner = 2,
    CloseAccount = 3,

    pub fn fromByte(byte: u8) ?AuthorityType {
        return std.meta.intToEnum(AuthorityType, byte) catch null;
    }
};

// ============================================================================
// Instruction Data Parsing
// ============================================================================

/// Parsed Transfer instruction data
pub const TransferData = struct {
    amount: u64,

    pub fn unpack(data: []const u8) !TransferData {
        if (data.len < 9) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.Transfer)) return error.InvalidInstructionData;
        return .{ .amount = std.mem.readInt(u64, data[1..9], .little) };
    }
};

/// Parsed TransferChecked instruction data
pub const TransferCheckedData = struct {
    amount: u64,
    decimals: u8,

    pub fn unpack(data: []const u8) !TransferCheckedData {
        if (data.len < 10) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.TransferChecked)) return error.InvalidInstructionData;
        return .{
            .amount = std.mem.readInt(u64, data[1..9], .little),
            .decimals = data[9],
        };
    }
};

/// Parsed MintTo instruction data
pub const MintToData = struct {
    amount: u64,

    pub fn unpack(data: []const u8) !MintToData {
        if (data.len < 9) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.MintTo)) return error.InvalidInstructionData;
        return .{ .amount = std.mem.readInt(u64, data[1..9], .little) };
    }
};

/// Parsed Burn instruction data
pub const BurnData = struct {
    amount: u64,

    pub fn unpack(data: []const u8) !BurnData {
        if (data.len < 9) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.Burn)) return error.InvalidInstructionData;
        return .{ .amount = std.mem.readInt(u64, data[1..9], .little) };
    }
};

/// Parsed SetAuthority instruction data
pub const SetAuthorityData = struct {
    authority_type: AuthorityType,
    new_authority: ?PublicKey,

    pub fn unpack(data: []const u8) !SetAuthorityData {
        if (data.len < 3) return error.InvalidInstructionData;
        if (data[0] != @intFromEnum(TokenInstruction.SetAuthority)) return error.InvalidInstructionData;

        const authority_type = AuthorityType.fromByte(data[1]) orelse return error.InvalidInstructionData;
        const new_authority: ?PublicKey = if (data.len >= 35 and data[2] == 1)
            PublicKey.from(data[3..35].*)
        else
            null;

        return .{ .authority_type = authority_type, .new_authority = new_authority };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TokenInstruction: enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(TokenInstruction.InitializeMint));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(TokenInstruction.Transfer));
    try std.testing.expectEqual(@as(u8, 12), @intFromEnum(TokenInstruction.TransferChecked));
    try std.testing.expectEqual(@as(u8, 24), @intFromEnum(TokenInstruction.UiAmountToAmount));
}

test "AuthorityType: enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AuthorityType.MintTokens));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(AuthorityType.CloseAccount));
}

test "TransferData: unpack" {
    var data: [9]u8 = undefined;
    data[0] = @intFromEnum(TokenInstruction.Transfer);
    std.mem.writeInt(u64, data[1..9], 1_000_000, .little);

    const parsed = try TransferData.unpack(&data);
    try std.testing.expectEqual(@as(u64, 1_000_000), parsed.amount);
}
