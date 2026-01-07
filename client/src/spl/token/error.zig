//! Zig implementation of SPL Token errors
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/error.rs
//!
//! This module provides error types for the SPL Token program.

const std = @import("std");

// ============================================================================
// TokenError Enum
// ============================================================================

/// Errors that may be returned by the Token program.
///
/// Rust source: https://github.com/solana-program/token/blob/master/interface/src/error.rs#L14
pub const TokenError = enum(u32) {
    /// Lamport balance below rent-exempt threshold
    NotRentExempt = 0,
    /// Insufficient funds for the operation requested
    InsufficientFunds = 1,
    /// Invalid Mint
    InvalidMint = 2,
    /// Account not associated with this Mint
    MintMismatch = 3,
    /// Owner does not match
    OwnerMismatch = 4,
    /// This token's supply is fixed and new tokens cannot be minted
    FixedSupply = 5,
    /// The account cannot be initialized because it is already being used
    AlreadyInUse = 6,
    /// Invalid number of provided signers
    InvalidNumberOfProvidedSigners = 7,
    /// Invalid number of required signers
    InvalidNumberOfRequiredSigners = 8,
    /// State is uninitialized
    UninitializedState = 9,
    /// Instruction does not support native tokens
    NativeNotSupported = 10,
    /// Non-native account can only be closed if its balance is zero
    NonNativeHasBalance = 11,
    /// Invalid instruction
    InvalidInstruction = 12,
    /// State is invalid for requested operation
    InvalidState = 13,
    /// Operation overflowed
    Overflow = 14,
    /// Account does not support specified authority type
    AuthorityTypeNotSupported = 15,
    /// This token mint cannot freeze accounts
    MintCannotFreeze = 16,
    /// Account is frozen; all account operations will fail
    AccountFrozen = 17,
    /// Mint decimals mismatch between the client and the mint
    MintDecimalsMismatch = 18,
    /// Instruction does not support non-native tokens
    NonNativeNotSupported = 19,

    /// Convert from u32 error code
    pub fn fromCode(code: u32) ?TokenError {
        return std.meta.intToEnum(TokenError, code) catch null;
    }

    /// Convert to u32 error code
    pub fn toCode(self: TokenError) u32 {
        return @intFromEnum(self);
    }

    /// Get human-readable error message
    pub fn message(self: TokenError) []const u8 {
        return switch (self) {
            .NotRentExempt => "Lamport balance below rent-exempt threshold",
            .InsufficientFunds => "Insufficient funds",
            .InvalidMint => "Invalid mint",
            .MintMismatch => "Account not associated with this mint",
            .OwnerMismatch => "Owner does not match",
            .FixedSupply => "Fixed supply",
            .AlreadyInUse => "Already in use",
            .InvalidNumberOfProvidedSigners => "Invalid number of provided signers",
            .InvalidNumberOfRequiredSigners => "Invalid number of required signers",
            .UninitializedState => "State is uninitialized",
            .NativeNotSupported => "Instruction does not support native tokens",
            .NonNativeHasBalance => "Non-native account can only be closed if its balance is zero",
            .InvalidInstruction => "Invalid instruction",
            .InvalidState => "State is invalid for requested operation",
            .Overflow => "Operation overflowed",
            .AuthorityTypeNotSupported => "Account does not support specified authority type",
            .MintCannotFreeze => "This token mint cannot freeze accounts",
            .AccountFrozen => "Account is frozen",
            .MintDecimalsMismatch => "Mint decimals mismatch",
            .NonNativeNotSupported => "Instruction does not support non-native tokens",
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TokenError: enum values match Rust SDK" {
    try std.testing.expectEqual(@as(u32, 0), TokenError.NotRentExempt.toCode());
    try std.testing.expectEqual(@as(u32, 1), TokenError.InsufficientFunds.toCode());
    try std.testing.expectEqual(@as(u32, 2), TokenError.InvalidMint.toCode());
    try std.testing.expectEqual(@as(u32, 3), TokenError.MintMismatch.toCode());
    try std.testing.expectEqual(@as(u32, 4), TokenError.OwnerMismatch.toCode());
    try std.testing.expectEqual(@as(u32, 5), TokenError.FixedSupply.toCode());
    try std.testing.expectEqual(@as(u32, 6), TokenError.AlreadyInUse.toCode());
    try std.testing.expectEqual(@as(u32, 7), TokenError.InvalidNumberOfProvidedSigners.toCode());
    try std.testing.expectEqual(@as(u32, 8), TokenError.InvalidNumberOfRequiredSigners.toCode());
    try std.testing.expectEqual(@as(u32, 9), TokenError.UninitializedState.toCode());
    try std.testing.expectEqual(@as(u32, 10), TokenError.NativeNotSupported.toCode());
    try std.testing.expectEqual(@as(u32, 11), TokenError.NonNativeHasBalance.toCode());
    try std.testing.expectEqual(@as(u32, 12), TokenError.InvalidInstruction.toCode());
    try std.testing.expectEqual(@as(u32, 13), TokenError.InvalidState.toCode());
    try std.testing.expectEqual(@as(u32, 14), TokenError.Overflow.toCode());
    try std.testing.expectEqual(@as(u32, 15), TokenError.AuthorityTypeNotSupported.toCode());
    try std.testing.expectEqual(@as(u32, 16), TokenError.MintCannotFreeze.toCode());
    try std.testing.expectEqual(@as(u32, 17), TokenError.AccountFrozen.toCode());
    try std.testing.expectEqual(@as(u32, 18), TokenError.MintDecimalsMismatch.toCode());
    try std.testing.expectEqual(@as(u32, 19), TokenError.NonNativeNotSupported.toCode());
}

test "TokenError: fromCode" {
    try std.testing.expectEqual(TokenError.NotRentExempt, TokenError.fromCode(0).?);
    try std.testing.expectEqual(TokenError.InsufficientFunds, TokenError.fromCode(1).?);
    try std.testing.expectEqual(TokenError.NonNativeNotSupported, TokenError.fromCode(19).?);

    // Invalid code should return null
    try std.testing.expect(TokenError.fromCode(100) == null);
    try std.testing.expect(TokenError.fromCode(20) == null);
}

test "TokenError: message" {
    try std.testing.expectEqualStrings("Insufficient funds", TokenError.InsufficientFunds.message());
    try std.testing.expectEqualStrings("Account is frozen", TokenError.AccountFrozen.message());
}
