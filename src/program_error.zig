//! Standard program error types
//! Matches Rust solana-program error codes

/// Program execution errors
/// Error codes match Rust solana-program for compatibility
pub const ProgramError = error{
    /// Custom error (0) — used with custom error codes
    Custom,
    /// Invalid argument (1)
    InvalidArgument,
    /// Invalid instruction data (2)
    InvalidInstructionData,
    /// Invalid account data (3)
    InvalidAccountData,
    /// Account data too small (4)
    AccountDataTooSmall,
    /// Insufficient funds (5)
    InsufficientFunds,
    /// Incorrect program id (6)
    IncorrectProgramId,
    /// Missing required signature (7)
    MissingRequiredSignature,
    /// Account already initialized (8)
    AccountAlreadyInitialized,
    /// Uninitialized account (9)
    UninitializedAccount,
    /// Not enough account keys (10)
    NotEnoughAccountKeys,
    /// Account borrow failed (11)
    AccountBorrowFailed,
    /// Max seed length exceeded (12)
    MaxSeedLengthExceeded,
    /// Invalid seeds (13)
    InvalidSeeds,
    /// Invalid realloc (14)
    InvalidRealloc,
    /// Arithmetic overflow (15)
    ArithmeticOverflow,
    /// Immutable account (16)
    ImmutableAccount,
    /// Incorrect authority (17)
    IncorrectAuthority,
};

/// Success return value
pub const SUCCESS: u64 = 0;

/// Program result type — either success or a ProgramError
pub const ProgramResult = ProgramError!void;

/// Convert ProgramError to u64 error code
/// Always inlined — the switch is a simple jump table
pub inline fn errorToU64(err: ProgramError) u64 {
    return switch (err) {
        ProgramError.Custom => 0,
        ProgramError.InvalidArgument => 1,
        ProgramError.InvalidInstructionData => 2,
        ProgramError.InvalidAccountData => 3,
        ProgramError.AccountDataTooSmall => 4,
        ProgramError.InsufficientFunds => 5,
        ProgramError.IncorrectProgramId => 6,
        ProgramError.MissingRequiredSignature => 7,
        ProgramError.AccountAlreadyInitialized => 8,
        ProgramError.UninitializedAccount => 9,
        ProgramError.NotEnoughAccountKeys => 10,
        ProgramError.AccountBorrowFailed => 11,
        ProgramError.MaxSeedLengthExceeded => 12,
        ProgramError.InvalidSeeds => 13,
        ProgramError.InvalidRealloc => 14,
        ProgramError.ArithmeticOverflow => 15,
        ProgramError.ImmutableAccount => 16,
        ProgramError.IncorrectAuthority => 17,
    };
}

/// Convert u64 error code to ProgramError
pub fn u64ToError(code: u64) ProgramError {
    return switch (code) {
        0 => ProgramError.Custom,
        1 => ProgramError.InvalidArgument,
        2 => ProgramError.InvalidInstructionData,
        3 => ProgramError.InvalidAccountData,
        4 => ProgramError.AccountDataTooSmall,
        5 => ProgramError.InsufficientFunds,
        6 => ProgramError.IncorrectProgramId,
        7 => ProgramError.MissingRequiredSignature,
        8 => ProgramError.AccountAlreadyInitialized,
        9 => ProgramError.UninitializedAccount,
        10 => ProgramError.NotEnoughAccountKeys,
        11 => ProgramError.AccountBorrowFailed,
        12 => ProgramError.MaxSeedLengthExceeded,
        13 => ProgramError.InvalidSeeds,
        14 => ProgramError.InvalidRealloc,
        15 => ProgramError.ArithmeticOverflow,
        16 => ProgramError.ImmutableAccount,
        17 => ProgramError.IncorrectAuthority,
        else => ProgramError.Custom,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "program_error: errorToU64 roundtrip" {
    const errors = [_]ProgramError{
        ProgramError.Custom,
        ProgramError.InvalidArgument,
        ProgramError.InvalidInstructionData,
        ProgramError.InvalidAccountData,
        ProgramError.AccountDataTooSmall,
        ProgramError.InsufficientFunds,
        ProgramError.IncorrectProgramId,
        ProgramError.MissingRequiredSignature,
        ProgramError.AccountAlreadyInitialized,
        ProgramError.UninitializedAccount,
        ProgramError.NotEnoughAccountKeys,
        ProgramError.AccountBorrowFailed,
        ProgramError.MaxSeedLengthExceeded,
        ProgramError.InvalidSeeds,
        ProgramError.InvalidRealloc,
        ProgramError.ArithmeticOverflow,
        ProgramError.ImmutableAccount,
        ProgramError.IncorrectAuthority,
    };

    for (errors) |err| {
        const code = errorToU64(err);
        const recovered = u64ToError(code);
        try @import("std").testing.expectEqual(err, recovered);
    }
}
