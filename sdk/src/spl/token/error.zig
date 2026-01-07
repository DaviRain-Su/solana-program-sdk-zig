//! Zig implementation of SPL Token errors
//!
//! Rust source: https://github.com/solana-program/token/blob/master/interface/src/error.rs

const std = @import("std");

/// Errors that may be returned by the Token program.
pub const TokenError = enum(u32) {
    NotRentExempt = 0,
    InsufficientFunds = 1,
    InvalidMint = 2,
    MintMismatch = 3,
    OwnerMismatch = 4,
    FixedSupply = 5,
    AlreadyInUse = 6,
    InvalidNumberOfProvidedSigners = 7,
    InvalidNumberOfRequiredSigners = 8,
    UninitializedState = 9,
    NativeNotSupported = 10,
    NonNativeHasBalance = 11,
    InvalidInstruction = 12,
    InvalidState = 13,
    Overflow = 14,
    AuthorityTypeNotSupported = 15,
    MintCannotFreeze = 16,
    AccountFrozen = 17,
    MintDecimalsMismatch = 18,
    NonNativeNotSupported = 19,

    pub fn fromCode(code: u32) ?TokenError {
        return std.meta.intToEnum(TokenError, code) catch null;
    }

    pub fn toCode(self: TokenError) u32 {
        return @intFromEnum(self);
    }

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

test "TokenError: enum values" {
    try std.testing.expectEqual(@as(u32, 0), TokenError.NotRentExempt.toCode());
    try std.testing.expectEqual(@as(u32, 19), TokenError.NonNativeNotSupported.toCode());
}

test "TokenError: fromCode" {
    try std.testing.expectEqual(TokenError.NotRentExempt, TokenError.fromCode(0).?);
    try std.testing.expect(TokenError.fromCode(100) == null);
}
