//! Zig implementation of Solana SDK's program_error module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-error/src/lib.rs
//!
//! This module provides the ProgramError enum which defines all standard
//! error codes that Solana programs can return. Custom errors use the lower
//! 32 bits, while builtin errors use the upper 32 bits.
//!
//! ## Usage
//! ```zig
//! const error_mod = @import("error.zig");
//! const ProgramError = error_mod.ProgramError;
//! const ProgramResult = error_mod.ProgramResult;
//!
//! fn process(data: []const u8) ProgramResult {
//!     if (data.len == 0) return ProgramError.InvalidInstructionData;
//!     return null; // Success
//! }
//! ```

const std = @import("std");

/// Result type for Solana program instructions.
///
/// Returns null on success, or a ProgramError on failure.
///
/// Rust equivalent: `ProgramResult = Result<(), ProgramError>`
pub const ProgramResult = ?ProgramError;

/// Builtin return values occupy the upper 32 bits
///
/// Rust equivalent: `solana_program_error::BUILTIN_BIT_SHIFT`
pub const BUILTIN_BIT_SHIFT: u6 = 32;

fn toBuiltin(comptime error_code: u64) u64 {
    return error_code << BUILTIN_BIT_SHIFT;
}

/// Reasons the program may fail
/// Matches the Solana SDK ProgramError enum values
pub const ProgramError = enum(u64) {
    /// Custom program error with code 0
    CustomZero = toBuiltin(1),
    /// The arguments provided to a program instruction were invalid
    InvalidArgument = toBuiltin(2),
    /// An instruction's data contents was invalid
    InvalidInstructionData = toBuiltin(3),
    /// An account's data contents was invalid
    InvalidAccountData = toBuiltin(4),
    /// An account's data was too small
    AccountDataTooSmall = toBuiltin(5),
    /// An account's balance was too small to complete the instruction
    InsufficientFunds = toBuiltin(6),
    /// The account did not have the expected program id
    IncorrectProgramId = toBuiltin(7),
    /// A signature was required but not found
    MissingRequiredSignature = toBuiltin(8),
    /// An initialize instruction was sent to an account that has already been initialized
    AccountAlreadyInitialized = toBuiltin(9),
    /// An attempt to operate on an account that hasn't been initialized
    UninitializedAccount = toBuiltin(10),
    /// The instruction expected additional account keys
    NotEnoughAccountKeys = toBuiltin(11),
    /// Failed to borrow a reference to account data, already borrowed
    AccountBorrowFailed = toBuiltin(12),
    /// Length of the seed is too long for address generation
    MaxSeedLengthExceeded = toBuiltin(13),
    /// Provided seeds do not result in a valid address
    InvalidSeeds = toBuiltin(14),
    /// IO Error
    BorshIoError = toBuiltin(15),
    /// An account does not have enough lamports to be rent-exempt
    AccountNotRentExempt = toBuiltin(16),
    /// Unsupported sysvar
    UnsupportedSysvar = toBuiltin(17),
    /// Provided owner is not allowed
    IllegalOwner = toBuiltin(18),
    /// Accounts data allocations exceeded the maximum allowed per transaction
    MaxAccountsDataAllocationsExceeded = toBuiltin(19),
    /// Account data reallocation was invalid
    InvalidRealloc = toBuiltin(20),
    /// Instruction trace length exceeded the maximum allowed per transaction
    MaxInstructionTraceLengthExceeded = toBuiltin(21),
    /// Builtin programs must consume compute units
    BuiltinProgramsMustConsumeComputeUnits = toBuiltin(22),
    /// Invalid account owner
    InvalidAccountOwner = toBuiltin(23),
    /// Program arithmetic overflowed
    ArithmeticOverflow = toBuiltin(24),
    /// Account is immutable
    Immutable = toBuiltin(25),
    /// Incorrect authority provided
    IncorrectAuthority = toBuiltin(26),

    // Non-builtin errors that can be used with _
    _,

    /// Convert error to u64 for return from entrypoint
    pub fn toU64(self: ProgramError) u64 {
        return @intFromEnum(self);
    }

    /// Create a custom error from a u32 error code
    /// Custom errors occupy the lower 32 bits
    pub fn custom(error_code: u32) ProgramError {
        if (error_code == 0) {
            return .CustomZero;
        }
        return @enumFromInt(error_code);
    }

    /// Get the custom error code if this is a custom error
    /// Returns null for builtin errors
    pub fn getCustomCode(self: ProgramError) ?u32 {
        const val = @intFromEnum(self);
        if (val == @intFromEnum(ProgramError.CustomZero)) {
            return 0;
        }
        // If value is less than BUILTIN threshold, it's a custom error
        if (val < toBuiltin(1)) {
            return @truncate(val);
        }
        return null;
    }

    /// Check if this is a builtin error
    pub fn isBuiltin(self: ProgramError) bool {
        return self.getCustomCode() == null;
    }

    /// Get a human-readable description of the error
    pub fn toString(self: ProgramError) []const u8 {
        return switch (self) {
            .CustomZero => "Custom program error: 0x0",
            .InvalidArgument => "The arguments provided to a program instruction were invalid",
            .InvalidInstructionData => "An instruction's data contents was invalid",
            .InvalidAccountData => "An account's data contents was invalid",
            .AccountDataTooSmall => "An account's data was too small",
            .InsufficientFunds => "An account's balance was too small to complete the instruction",
            .IncorrectProgramId => "The account did not have the expected program id",
            .MissingRequiredSignature => "A signature was required but not found",
            .AccountAlreadyInitialized => "An initialize instruction was sent to an account that has already been initialized",
            .UninitializedAccount => "An attempt to operate on an account that hasn't been initialized",
            .NotEnoughAccountKeys => "The instruction expected additional account keys",
            .AccountBorrowFailed => "Failed to borrow a reference to account data, already borrowed",
            .MaxSeedLengthExceeded => "Length of the seed is too long for address generation",
            .InvalidSeeds => "Provided seeds do not result in a valid address",
            .BorshIoError => "IO Error",
            .AccountNotRentExempt => "An account does not have enough lamports to be rent-exempt",
            .UnsupportedSysvar => "Unsupported sysvar",
            .IllegalOwner => "Provided owner is not allowed",
            .MaxAccountsDataAllocationsExceeded => "Accounts data allocations exceeded the maximum allowed per transaction",
            .InvalidRealloc => "Account data reallocation was invalid",
            .MaxInstructionTraceLengthExceeded => "Instruction trace length exceeded the maximum allowed per transaction",
            .BuiltinProgramsMustConsumeComputeUnits => "Builtin programs must consume compute units",
            .InvalidAccountOwner => "Invalid account owner",
            .ArithmeticOverflow => "Program arithmetic overflowed",
            .Immutable => "Account is immutable",
            .IncorrectAuthority => "Incorrect authority provided",
            _ => "Custom program error",
        };
    }

    /// Create ProgramError from a u64 value (e.g., from runtime)
    pub fn fromU64(value: u64) ProgramError {
        return @enumFromInt(value);
    }
};

test "ProgramError values match Rust SDK" {
    // Verify builtin error values match Rust SDK
    // Rust: pub const CUSTOM_ZERO: u64 = to_builtin!(1);  // 1 << 32
    // Rust: pub const INVALID_ARGUMENT: u64 = to_builtin!(2);  // 2 << 32
    // etc.
    try std.testing.expectEqual(@as(u64, 1 << 32), @intFromEnum(ProgramError.CustomZero));
    try std.testing.expectEqual(@as(u64, 2 << 32), @intFromEnum(ProgramError.InvalidArgument));
    try std.testing.expectEqual(@as(u64, 3 << 32), @intFromEnum(ProgramError.InvalidInstructionData));
    try std.testing.expectEqual(@as(u64, 4 << 32), @intFromEnum(ProgramError.InvalidAccountData));
    try std.testing.expectEqual(@as(u64, 5 << 32), @intFromEnum(ProgramError.AccountDataTooSmall));
    try std.testing.expectEqual(@as(u64, 6 << 32), @intFromEnum(ProgramError.InsufficientFunds));
    try std.testing.expectEqual(@as(u64, 7 << 32), @intFromEnum(ProgramError.IncorrectProgramId));
    try std.testing.expectEqual(@as(u64, 8 << 32), @intFromEnum(ProgramError.MissingRequiredSignature));
    try std.testing.expectEqual(@as(u64, 9 << 32), @intFromEnum(ProgramError.AccountAlreadyInitialized));
    try std.testing.expectEqual(@as(u64, 10 << 32), @intFromEnum(ProgramError.UninitializedAccount));
    try std.testing.expectEqual(@as(u64, 11 << 32), @intFromEnum(ProgramError.NotEnoughAccountKeys));
    try std.testing.expectEqual(@as(u64, 12 << 32), @intFromEnum(ProgramError.AccountBorrowFailed));
    try std.testing.expectEqual(@as(u64, 13 << 32), @intFromEnum(ProgramError.MaxSeedLengthExceeded));
    try std.testing.expectEqual(@as(u64, 14 << 32), @intFromEnum(ProgramError.InvalidSeeds));
    try std.testing.expectEqual(@as(u64, 15 << 32), @intFromEnum(ProgramError.BorshIoError));
    try std.testing.expectEqual(@as(u64, 16 << 32), @intFromEnum(ProgramError.AccountNotRentExempt));
    try std.testing.expectEqual(@as(u64, 17 << 32), @intFromEnum(ProgramError.UnsupportedSysvar));
    try std.testing.expectEqual(@as(u64, 18 << 32), @intFromEnum(ProgramError.IllegalOwner));
    try std.testing.expectEqual(@as(u64, 19 << 32), @intFromEnum(ProgramError.MaxAccountsDataAllocationsExceeded));
    try std.testing.expectEqual(@as(u64, 20 << 32), @intFromEnum(ProgramError.InvalidRealloc));
    try std.testing.expectEqual(@as(u64, 21 << 32), @intFromEnum(ProgramError.MaxInstructionTraceLengthExceeded));
    try std.testing.expectEqual(@as(u64, 22 << 32), @intFromEnum(ProgramError.BuiltinProgramsMustConsumeComputeUnits));
    try std.testing.expectEqual(@as(u64, 23 << 32), @intFromEnum(ProgramError.InvalidAccountOwner));
    try std.testing.expectEqual(@as(u64, 24 << 32), @intFromEnum(ProgramError.ArithmeticOverflow));
    try std.testing.expectEqual(@as(u64, 25 << 32), @intFromEnum(ProgramError.Immutable));
    try std.testing.expectEqual(@as(u64, 26 << 32), @intFromEnum(ProgramError.IncorrectAuthority));
}

test "custom errors" {
    // Custom error with code 0 should map to CustomZero (special case)
    // Rust: if error == 0 { CUSTOM_ZERO } else { error as u64 }
    const err0 = ProgramError.custom(0);
    try std.testing.expectEqual(ProgramError.CustomZero, err0);
    try std.testing.expectEqual(@as(?u32, 0), err0.getCustomCode());
    try std.testing.expectEqual(@as(u64, 1 << 32), err0.toU64());

    // Custom error with non-zero code uses lower 32 bits directly
    const err1 = ProgramError.custom(1);
    try std.testing.expectEqual(@as(u64, 1), err1.toU64());
    try std.testing.expectEqual(@as(?u32, 1), err1.getCustomCode());

    const err42 = ProgramError.custom(42);
    try std.testing.expectEqual(@as(u64, 42), err42.toU64());
    try std.testing.expectEqual(@as(?u32, 42), err42.getCustomCode());

    // Max u32 custom error
    const err_max = ProgramError.custom(0xFFFFFFFF);
    try std.testing.expectEqual(@as(u64, 0xFFFFFFFF), err_max.toU64());
    try std.testing.expectEqual(@as(?u32, 0xFFFFFFFF), err_max.getCustomCode());

    // Builtin errors should return null for getCustomCode
    try std.testing.expectEqual(@as(?u32, null), ProgramError.InvalidArgument.getCustomCode());
    try std.testing.expectEqual(@as(?u32, null), ProgramError.IncorrectAuthority.getCustomCode());
}

test "ProgramError roundtrip: toU64 -> fromU64" {
    // Test all builtin errors roundtrip correctly
    const builtins = [_]ProgramError{
        .CustomZero,
        .InvalidArgument,
        .InvalidInstructionData,
        .InvalidAccountData,
        .AccountDataTooSmall,
        .InsufficientFunds,
        .IncorrectProgramId,
        .MissingRequiredSignature,
        .AccountAlreadyInitialized,
        .UninitializedAccount,
        .NotEnoughAccountKeys,
        .AccountBorrowFailed,
        .MaxSeedLengthExceeded,
        .InvalidSeeds,
        .BorshIoError,
        .AccountNotRentExempt,
        .UnsupportedSysvar,
        .IllegalOwner,
        .MaxAccountsDataAllocationsExceeded,
        .InvalidRealloc,
        .MaxInstructionTraceLengthExceeded,
        .BuiltinProgramsMustConsumeComputeUnits,
        .InvalidAccountOwner,
        .ArithmeticOverflow,
        .Immutable,
        .IncorrectAuthority,
    };

    for (builtins) |err| {
        const as_u64 = err.toU64();
        const back = ProgramError.fromU64(as_u64);
        try std.testing.expectEqual(err, back);
    }

    // Test custom errors roundtrip
    for ([_]u32{ 0, 1, 42, 100, 1000, 0xFFFFFFFF }) |code| {
        const err = ProgramError.custom(code);
        const as_u64 = err.toU64();
        const back = ProgramError.fromU64(as_u64);

        // For custom(0), we get CustomZero which has getCustomCode() == 0
        const back_code = back.getCustomCode();
        try std.testing.expect(back_code != null);
        try std.testing.expectEqual(code, back_code.?);
    }
}

test "ProgramError isBuiltin" {
    // Builtin errors
    try std.testing.expect(ProgramError.InvalidArgument.isBuiltin());
    try std.testing.expect(ProgramError.IncorrectAuthority.isBuiltin());

    // CustomZero is semantically Custom(0), so it's NOT a builtin error
    try std.testing.expect(!ProgramError.CustomZero.isBuiltin());

    // Custom errors are not builtin
    try std.testing.expect(!ProgramError.custom(0).isBuiltin());
    try std.testing.expect(!ProgramError.custom(1).isBuiltin());
    try std.testing.expect(!ProgramError.custom(42).isBuiltin());
    try std.testing.expect(!ProgramError.custom(0xFFFFFFFF).isBuiltin());
}
