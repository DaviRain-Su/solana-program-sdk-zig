//! Standard program error types.
//!
//! ABI-compatible with `solana_program_error::ProgramError` (crate
//! `solana-program-error` 3.x). On entrypoint return / CPI propagation
//! the Solana runtime expects the code as a u64 in the canonical
//! encoding:
//!
//! - Builtin variants occupy the upper 32 bits: `(N << 32)` for the
//!   N-th builtin (matching Rust's `BUILTIN_BIT_SHIFT = 32`).
//! - `Custom(code)` returns `code` directly, except `Custom(0)` which
//!   collides with `SUCCESS` and is mapped to the sentinel `1 << 32`
//!   (`CUSTOM_ZERO`).
//!
//! See: <https://docs.rs/solana-program-error/latest/src/solana_program_error/lib.rs.html>

/// Reasons a program may fail. Variants and order match
/// `solana_program_error::ProgramError` 3.x so the on-wire u64 codes
/// agree with Rust programs.
pub const ProgramError = error{
    /// `Custom(0)` — programs use this for their own error 0. The
    /// runtime treats raw `0` as success, so we encode this as the
    /// sentinel `1 << 32` (`CUSTOM_ZERO`). For any non-zero custom
    /// code, use `customError(code)` directly instead of this variant.
    Custom,
    InvalidArgument,
    InvalidInstructionData,
    InvalidAccountData,
    AccountDataTooSmall,
    InsufficientFunds,
    IncorrectProgramId,
    MissingRequiredSignature,
    AccountAlreadyInitialized,
    UninitializedAccount,
    NotEnoughAccountKeys,
    AccountBorrowFailed,
    MaxSeedLengthExceeded,
    InvalidSeeds,
    BorshIoError,
    AccountNotRentExempt,
    UnsupportedSysvar,
    IllegalOwner,
    MaxAccountsDataAllocationsExceeded,
    InvalidRealloc,
    MaxInstructionTraceLengthExceeded,
    BuiltinProgramsMustConsumeComputeUnits,
    InvalidAccountOwner,
    ArithmeticOverflow,
    ImmutableAccount,
    IncorrectAuthority,
};

/// Success return value (raw u64 returned by the entrypoint).
pub const SUCCESS: u64 = 0;

/// Bit shift applied to builtin error codes (matches Rust's
/// `BUILTIN_BIT_SHIFT`).
pub const BUILTIN_BIT_SHIFT: u6 = 32;

/// `Custom(0)` sentinel — `0` itself means success.
pub const CUSTOM_ZERO: u64 = 1 << BUILTIN_BIT_SHIFT;

/// Compute a builtin code at compile time.
inline fn builtin(comptime n: u64) u64 {
    return n << BUILTIN_BIT_SHIFT;
}

// Builtin codes (kept as `pub const` so downstream code can compare or
// log them without re-shifting).
pub const INVALID_ARGUMENT: u64 = builtin(2);
pub const INVALID_INSTRUCTION_DATA: u64 = builtin(3);
pub const INVALID_ACCOUNT_DATA: u64 = builtin(4);
pub const ACCOUNT_DATA_TOO_SMALL: u64 = builtin(5);
pub const INSUFFICIENT_FUNDS: u64 = builtin(6);
pub const INCORRECT_PROGRAM_ID: u64 = builtin(7);
pub const MISSING_REQUIRED_SIGNATURES: u64 = builtin(8);
pub const ACCOUNT_ALREADY_INITIALIZED: u64 = builtin(9);
pub const UNINITIALIZED_ACCOUNT: u64 = builtin(10);
pub const NOT_ENOUGH_ACCOUNT_KEYS: u64 = builtin(11);
pub const ACCOUNT_BORROW_FAILED: u64 = builtin(12);
pub const MAX_SEED_LENGTH_EXCEEDED: u64 = builtin(13);
pub const INVALID_SEEDS: u64 = builtin(14);
pub const BORSH_IO_ERROR: u64 = builtin(15);
pub const ACCOUNT_NOT_RENT_EXEMPT: u64 = builtin(16);
pub const UNSUPPORTED_SYSVAR: u64 = builtin(17);
pub const ILLEGAL_OWNER: u64 = builtin(18);
pub const MAX_ACCOUNTS_DATA_ALLOCATIONS_EXCEEDED: u64 = builtin(19);
pub const INVALID_ACCOUNT_DATA_REALLOC: u64 = builtin(20);
pub const MAX_INSTRUCTION_TRACE_LENGTH_EXCEEDED: u64 = builtin(21);
pub const BUILTIN_PROGRAMS_MUST_CONSUME_COMPUTE_UNITS: u64 = builtin(22);
pub const INVALID_ACCOUNT_OWNER: u64 = builtin(23);
pub const ARITHMETIC_OVERFLOW: u64 = builtin(24);
pub const IMMUTABLE: u64 = builtin(25);
pub const INCORRECT_AUTHORITY: u64 = builtin(26);

/// Program result type — either success or a ProgramError
pub const ProgramResult = ProgramError!void;

/// Encode a custom error code into the runtime's u64 wire format.
///
/// Code `0` collides with `SUCCESS`, so the runtime reserves
/// `CUSTOM_ZERO` for it. Any non-zero `u32` is passed through as-is.
pub inline fn customError(code: u32) u64 {
    return if (code == 0) CUSTOM_ZERO else @as(u64, code);
}

/// Convert a `ProgramError` to the runtime's u64 wire format.
///
/// Uses `inline switch` so the resulting BPF code is a single
/// jump-table-like dispatch on the error tag.
pub inline fn errorToU64(err: ProgramError) u64 {
    return switch (err) {
        ProgramError.Custom => CUSTOM_ZERO,
        ProgramError.InvalidArgument => INVALID_ARGUMENT,
        ProgramError.InvalidInstructionData => INVALID_INSTRUCTION_DATA,
        ProgramError.InvalidAccountData => INVALID_ACCOUNT_DATA,
        ProgramError.AccountDataTooSmall => ACCOUNT_DATA_TOO_SMALL,
        ProgramError.InsufficientFunds => INSUFFICIENT_FUNDS,
        ProgramError.IncorrectProgramId => INCORRECT_PROGRAM_ID,
        ProgramError.MissingRequiredSignature => MISSING_REQUIRED_SIGNATURES,
        ProgramError.AccountAlreadyInitialized => ACCOUNT_ALREADY_INITIALIZED,
        ProgramError.UninitializedAccount => UNINITIALIZED_ACCOUNT,
        ProgramError.NotEnoughAccountKeys => NOT_ENOUGH_ACCOUNT_KEYS,
        ProgramError.AccountBorrowFailed => ACCOUNT_BORROW_FAILED,
        ProgramError.MaxSeedLengthExceeded => MAX_SEED_LENGTH_EXCEEDED,
        ProgramError.InvalidSeeds => INVALID_SEEDS,
        ProgramError.BorshIoError => BORSH_IO_ERROR,
        ProgramError.AccountNotRentExempt => ACCOUNT_NOT_RENT_EXEMPT,
        ProgramError.UnsupportedSysvar => UNSUPPORTED_SYSVAR,
        ProgramError.IllegalOwner => ILLEGAL_OWNER,
        ProgramError.MaxAccountsDataAllocationsExceeded => MAX_ACCOUNTS_DATA_ALLOCATIONS_EXCEEDED,
        ProgramError.InvalidRealloc => INVALID_ACCOUNT_DATA_REALLOC,
        ProgramError.MaxInstructionTraceLengthExceeded => MAX_INSTRUCTION_TRACE_LENGTH_EXCEEDED,
        ProgramError.BuiltinProgramsMustConsumeComputeUnits => BUILTIN_PROGRAMS_MUST_CONSUME_COMPUTE_UNITS,
        ProgramError.InvalidAccountOwner => INVALID_ACCOUNT_OWNER,
        ProgramError.ArithmeticOverflow => ARITHMETIC_OVERFLOW,
        ProgramError.ImmutableAccount => IMMUTABLE,
        ProgramError.IncorrectAuthority => INCORRECT_AUTHORITY,
    };
}

/// Decode a u64 returned by a CPI / syscall back into a `ProgramError`.
///
/// Anything that isn't a recognised builtin maps to
/// `ProgramError.Custom`.
pub fn u64ToError(code: u64) ProgramError {
    return switch (code) {
        CUSTOM_ZERO => ProgramError.Custom,
        INVALID_ARGUMENT => ProgramError.InvalidArgument,
        INVALID_INSTRUCTION_DATA => ProgramError.InvalidInstructionData,
        INVALID_ACCOUNT_DATA => ProgramError.InvalidAccountData,
        ACCOUNT_DATA_TOO_SMALL => ProgramError.AccountDataTooSmall,
        INSUFFICIENT_FUNDS => ProgramError.InsufficientFunds,
        INCORRECT_PROGRAM_ID => ProgramError.IncorrectProgramId,
        MISSING_REQUIRED_SIGNATURES => ProgramError.MissingRequiredSignature,
        ACCOUNT_ALREADY_INITIALIZED => ProgramError.AccountAlreadyInitialized,
        UNINITIALIZED_ACCOUNT => ProgramError.UninitializedAccount,
        NOT_ENOUGH_ACCOUNT_KEYS => ProgramError.NotEnoughAccountKeys,
        ACCOUNT_BORROW_FAILED => ProgramError.AccountBorrowFailed,
        MAX_SEED_LENGTH_EXCEEDED => ProgramError.MaxSeedLengthExceeded,
        INVALID_SEEDS => ProgramError.InvalidSeeds,
        BORSH_IO_ERROR => ProgramError.BorshIoError,
        ACCOUNT_NOT_RENT_EXEMPT => ProgramError.AccountNotRentExempt,
        UNSUPPORTED_SYSVAR => ProgramError.UnsupportedSysvar,
        ILLEGAL_OWNER => ProgramError.IllegalOwner,
        MAX_ACCOUNTS_DATA_ALLOCATIONS_EXCEEDED => ProgramError.MaxAccountsDataAllocationsExceeded,
        INVALID_ACCOUNT_DATA_REALLOC => ProgramError.InvalidRealloc,
        MAX_INSTRUCTION_TRACE_LENGTH_EXCEEDED => ProgramError.MaxInstructionTraceLengthExceeded,
        BUILTIN_PROGRAMS_MUST_CONSUME_COMPUTE_UNITS => ProgramError.BuiltinProgramsMustConsumeComputeUnits,
        INVALID_ACCOUNT_OWNER => ProgramError.InvalidAccountOwner,
        ARITHMETIC_OVERFLOW => ProgramError.ArithmeticOverflow,
        IMMUTABLE => ProgramError.ImmutableAccount,
        INCORRECT_AUTHORITY => ProgramError.IncorrectAuthority,
        else => ProgramError.Custom,
    };
}

// =============================================================================
// Tests
// =============================================================================

const std = @import("std");

test "program_error: builtin codes match Solana ABI" {
    // Spot-check against known builtin codes (see Rust source).
    try std.testing.expectEqual(@as(u64, 1 << 32), CUSTOM_ZERO);
    try std.testing.expectEqual(@as(u64, 2 << 32), INVALID_ARGUMENT);
    try std.testing.expectEqual(@as(u64, 7 << 32), INCORRECT_PROGRAM_ID);
    try std.testing.expectEqual(@as(u64, 11 << 32), NOT_ENOUGH_ACCOUNT_KEYS);
    try std.testing.expectEqual(@as(u64, 24 << 32), ARITHMETIC_OVERFLOW);
}

test "program_error: errorToU64 / u64ToError roundtrip" {
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
        ProgramError.BorshIoError,
        ProgramError.AccountNotRentExempt,
        ProgramError.UnsupportedSysvar,
        ProgramError.IllegalOwner,
        ProgramError.MaxAccountsDataAllocationsExceeded,
        ProgramError.InvalidRealloc,
        ProgramError.MaxInstructionTraceLengthExceeded,
        ProgramError.BuiltinProgramsMustConsumeComputeUnits,
        ProgramError.InvalidAccountOwner,
        ProgramError.ArithmeticOverflow,
        ProgramError.ImmutableAccount,
        ProgramError.IncorrectAuthority,
    };

    for (errors) |err| {
        try std.testing.expectEqual(err, u64ToError(errorToU64(err)));
    }
}

test "program_error: customError encodes Custom(0) as sentinel" {
    try std.testing.expectEqual(CUSTOM_ZERO, customError(0));
    try std.testing.expectEqual(@as(u64, 42), customError(42));
    try std.testing.expectEqual(@as(u64, 0xFFFF_FFFF), customError(0xFFFF_FFFF));
}
