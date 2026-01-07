//! Zig implementation of Solana SDK's instruction_error module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/instruction-error/src/lib.rs
//!
//! This module defines the InstructionError enum which represents reasons
//! the runtime might have rejected an instruction. These errors are returned
//! to clients when transactions fail.
//!
//! ## Difference from ProgramError
//!
//! - `ProgramError`: Errors returned BY programs TO the runtime
//! - `InstructionError`: Errors returned BY the runtime TO clients
//!
//! InstructionError is a superset that includes all ProgramError variants
//! plus runtime-specific errors like UnbalancedInstruction, ModifiedProgramId, etc.

const std = @import("std");
const ProgramError = @import("error.zig").ProgramError;

/// Reasons the runtime might have rejected an instruction.
///
/// Members of this enum must not be removed, but new ones can be added.
/// This matches the Rust `InstructionError` enum.
///
/// Rust equivalent: `solana_instruction_error::InstructionError`
pub const InstructionError = union(enum) {
    /// Deprecated! Use CustomError instead!
    /// The program instruction returned an error
    GenericError,

    /// The arguments provided to a program were invalid
    InvalidArgument,

    /// An instruction's data contents were invalid
    InvalidInstructionData,

    /// An account's data contents was invalid
    InvalidAccountData,

    /// An account's data was too small
    AccountDataTooSmall,

    /// An account's balance was too small to complete the instruction
    InsufficientFunds,

    /// The account did not have the expected program id
    IncorrectProgramId,

    /// A signature was required but not found
    MissingRequiredSignature,

    /// An initialize instruction was sent to an account that has already been initialized
    AccountAlreadyInitialized,

    /// An attempt to operate on an account that hasn't been initialized
    UninitializedAccount,

    /// Program's instruction lamport balance does not equal the balance after the instruction
    UnbalancedInstruction,

    /// Program illegally modified an account's program id
    ModifiedProgramId,

    /// Program spent the lamports of an account that doesn't belong to it
    ExternalAccountLamportSpend,

    /// Program modified the data of an account that doesn't belong to it
    ExternalAccountDataModified,

    /// Read-only account's lamports modified
    ReadonlyLamportChange,

    /// Read-only account's data was modified
    ReadonlyDataModified,

    /// An account was referenced more than once in a single instruction
    /// Deprecated: instructions can now contain duplicate accounts
    DuplicateAccountIndex,

    /// Executable bit on account changed, but shouldn't have
    ExecutableModified,

    /// Rent_epoch account changed, but shouldn't have
    RentEpochModified,

    /// The instruction expected additional account keys
    /// Deprecated since 2.1.0: Use MissingAccount instead
    NotEnoughAccountKeys,

    /// Program other than the account's owner changed the size of the account data
    AccountDataSizeChanged,

    /// The instruction expected an executable account
    AccountNotExecutable,

    /// Failed to borrow a reference to account data, already borrowed
    AccountBorrowFailed,

    /// Account data has an outstanding reference after a program's execution
    AccountBorrowOutstanding,

    /// The same account was multiply passed to an on-chain program's entrypoint,
    /// but the program modified them differently
    DuplicateAccountOutOfSync,

    /// Allows on-chain programs to implement program-specific error types
    Custom: u32,

    /// The return value from the program was invalid
    InvalidError,

    /// Executable account's data was modified
    ExecutableDataModified,

    /// Executable account's lamports modified
    ExecutableLamportChange,

    /// Executable accounts must be rent exempt
    ExecutableAccountNotRentExempt,

    /// Unsupported program id
    UnsupportedProgramId,

    /// Cross-program invocation call depth too deep
    CallDepth,

    /// An account required by the instruction is missing
    MissingAccount,

    /// Cross-program invocation reentrancy not allowed for this instruction
    ReentrancyNotAllowed,

    /// Length of the seed is too long for address generation
    MaxSeedLengthExceeded,

    /// Provided seeds do not result in a valid address
    InvalidSeeds,

    /// Failed to reallocate account data of this length
    InvalidRealloc,

    /// Computational budget exceeded
    ComputationalBudgetExceeded,

    /// Cross-program invocation with unauthorized signer or writable account
    PrivilegeEscalation,

    /// Failed to create program execution environment
    ProgramEnvironmentSetupFailure,

    /// Program failed to complete
    ProgramFailedToComplete,

    /// Program failed to compile
    ProgramFailedToCompile,

    /// Account is immutable
    Immutable,

    /// Incorrect authority provided
    IncorrectAuthority,

    /// Failed to serialize or deserialize account data
    BorshIoError,

    /// An account does not have enough lamports to be rent-exempt
    AccountNotRentExempt,

    /// Invalid account owner
    InvalidAccountOwner,

    /// Program arithmetic overflowed
    ArithmeticOverflow,

    /// Unsupported sysvar
    UnsupportedSysvar,

    /// Illegal account owner
    IllegalOwner,

    /// Accounts data allocations exceeded the maximum allowed per transaction
    MaxAccountsDataAllocationsExceeded,

    /// Max accounts exceeded
    MaxAccountsExceeded,

    /// Max instruction trace length exceeded
    MaxInstructionTraceLengthExceeded,

    /// Builtin programs must consume compute units
    BuiltinProgramsMustConsumeComputeUnits,

    /// Get a human-readable description of the error
    pub fn toString(self: InstructionError) []const u8 {
        return switch (self) {
            .GenericError => "generic instruction error",
            .InvalidArgument => "invalid program argument",
            .InvalidInstructionData => "invalid instruction data",
            .InvalidAccountData => "invalid account data for instruction",
            .AccountDataTooSmall => "account data too small for instruction",
            .InsufficientFunds => "insufficient funds for instruction",
            .IncorrectProgramId => "incorrect program id for instruction",
            .MissingRequiredSignature => "missing required signature for instruction",
            .AccountAlreadyInitialized => "instruction requires an uninitialized account",
            .UninitializedAccount => "instruction requires an initialized account",
            .UnbalancedInstruction => "sum of account balances before and after instruction do not match",
            .ModifiedProgramId => "instruction illegally modified the program id of an account",
            .ExternalAccountLamportSpend => "instruction spent from the balance of an account it does not own",
            .ExternalAccountDataModified => "instruction modified data of an account it does not own",
            .ReadonlyLamportChange => "instruction changed the balance of a read-only account",
            .ReadonlyDataModified => "instruction modified data of a read-only account",
            .DuplicateAccountIndex => "instruction contains duplicate accounts",
            .ExecutableModified => "instruction changed executable bit of an account",
            .RentEpochModified => "instruction modified rent epoch of an account",
            .NotEnoughAccountKeys => "insufficient account keys for instruction",
            .AccountDataSizeChanged => "program other than the account's owner changed the size of the account data",
            .AccountNotExecutable => "instruction expected an executable account",
            .AccountBorrowFailed => "instruction tries to borrow reference for an account which is already borrowed",
            .AccountBorrowOutstanding => "instruction left account with an outstanding borrowed reference",
            .DuplicateAccountOutOfSync => "instruction modifications of multiply-passed account differ",
            .Custom => "custom program error",
            .InvalidError => "program returned invalid error code",
            .ExecutableDataModified => "instruction changed executable accounts data",
            .ExecutableLamportChange => "instruction changed the balance of an executable account",
            .ExecutableAccountNotRentExempt => "executable accounts must be rent exempt",
            .UnsupportedProgramId => "Unsupported program id",
            .CallDepth => "Cross-program invocation call depth too deep",
            .MissingAccount => "An account required by the instruction is missing",
            .ReentrancyNotAllowed => "Cross-program invocation reentrancy not allowed for this instruction",
            .MaxSeedLengthExceeded => "Length of the seed is too long for address generation",
            .InvalidSeeds => "Provided seeds do not result in a valid address",
            .InvalidRealloc => "Failed to reallocate account data",
            .ComputationalBudgetExceeded => "Computational budget exceeded",
            .PrivilegeEscalation => "Cross-program invocation with unauthorized signer or writable account",
            .ProgramEnvironmentSetupFailure => "Failed to create program execution environment",
            .ProgramFailedToComplete => "Program failed to complete",
            .ProgramFailedToCompile => "Program failed to compile",
            .Immutable => "Account is immutable",
            .IncorrectAuthority => "Incorrect authority provided",
            .BorshIoError => "Failed to serialize or deserialize account data",
            .AccountNotRentExempt => "An account does not have enough lamports to be rent-exempt",
            .InvalidAccountOwner => "Invalid account owner",
            .ArithmeticOverflow => "Program arithmetic overflowed",
            .UnsupportedSysvar => "Unsupported sysvar",
            .IllegalOwner => "Provided owner is not allowed",
            .MaxAccountsDataAllocationsExceeded => "Accounts data allocations exceeded the maximum allowed per transaction",
            .MaxAccountsExceeded => "Max accounts exceeded",
            .MaxInstructionTraceLengthExceeded => "Max instruction trace length exceeded",
            .BuiltinProgramsMustConsumeComputeUnits => "Builtin programs must consume compute units",
        };
    }

    /// Try to convert InstructionError to ProgramError
    ///
    /// Returns null if the error cannot be represented as a ProgramError
    /// (e.g., runtime-specific errors like UnbalancedInstruction)
    pub fn toProgramError(self: InstructionError) ?ProgramError {
        return switch (self) {
            .Custom => |code| ProgramError.custom(code),
            .InvalidArgument => .InvalidArgument,
            .InvalidInstructionData => .InvalidInstructionData,
            .InvalidAccountData => .InvalidAccountData,
            .AccountDataTooSmall => .AccountDataTooSmall,
            .InsufficientFunds => .InsufficientFunds,
            .IncorrectProgramId => .IncorrectProgramId,
            .MissingRequiredSignature => .MissingRequiredSignature,
            .AccountAlreadyInitialized => .AccountAlreadyInitialized,
            .UninitializedAccount => .UninitializedAccount,
            .NotEnoughAccountKeys, .MissingAccount => .NotEnoughAccountKeys,
            .AccountBorrowFailed => .AccountBorrowFailed,
            .MaxSeedLengthExceeded => .MaxSeedLengthExceeded,
            .InvalidSeeds => .InvalidSeeds,
            .BorshIoError => .BorshIoError,
            .AccountNotRentExempt => .AccountNotRentExempt,
            .UnsupportedSysvar => .UnsupportedSysvar,
            .IllegalOwner => .IllegalOwner,
            .MaxAccountsDataAllocationsExceeded => .MaxAccountsDataAllocationsExceeded,
            .InvalidRealloc => .InvalidRealloc,
            .MaxInstructionTraceLengthExceeded => .MaxInstructionTraceLengthExceeded,
            .BuiltinProgramsMustConsumeComputeUnits => .BuiltinProgramsMustConsumeComputeUnits,
            .InvalidAccountOwner => .InvalidAccountOwner,
            .ArithmeticOverflow => .ArithmeticOverflow,
            .Immutable => .Immutable,
            .IncorrectAuthority => .IncorrectAuthority,
            // Runtime-specific errors cannot be converted to ProgramError
            else => null,
        };
    }

    /// Create InstructionError from ProgramError
    pub fn fromProgramError(err: ProgramError) InstructionError {
        const custom_code = err.getCustomCode();
        if (custom_code) |code| {
            return .{ .Custom = code };
        }

        return switch (err) {
            .InvalidArgument => .InvalidArgument,
            .InvalidInstructionData => .InvalidInstructionData,
            .InvalidAccountData => .InvalidAccountData,
            .AccountDataTooSmall => .AccountDataTooSmall,
            .InsufficientFunds => .InsufficientFunds,
            .IncorrectProgramId => .IncorrectProgramId,
            .MissingRequiredSignature => .MissingRequiredSignature,
            .AccountAlreadyInitialized => .AccountAlreadyInitialized,
            .UninitializedAccount => .UninitializedAccount,
            .NotEnoughAccountKeys => .NotEnoughAccountKeys,
            .AccountBorrowFailed => .AccountBorrowFailed,
            .MaxSeedLengthExceeded => .MaxSeedLengthExceeded,
            .InvalidSeeds => .InvalidSeeds,
            .BorshIoError => .BorshIoError,
            .AccountNotRentExempt => .AccountNotRentExempt,
            .UnsupportedSysvar => .UnsupportedSysvar,
            .IllegalOwner => .IllegalOwner,
            .MaxAccountsDataAllocationsExceeded => .MaxAccountsDataAllocationsExceeded,
            .InvalidRealloc => .InvalidRealloc,
            .MaxInstructionTraceLengthExceeded => .MaxInstructionTraceLengthExceeded,
            .BuiltinProgramsMustConsumeComputeUnits => .BuiltinProgramsMustConsumeComputeUnits,
            .InvalidAccountOwner => .InvalidAccountOwner,
            .ArithmeticOverflow => .ArithmeticOverflow,
            .Immutable => .Immutable,
            .IncorrectAuthority => .IncorrectAuthority,
            .CustomZero => .{ .Custom = 0 },
            _ => .{ .Custom = @truncate(@intFromEnum(err)) },
        };
    }

    /// Create InstructionError from a u64 value (e.g., from RPC response)
    ///
    /// This mirrors Rust's `impl From<T: ToPrimitive> for InstructionError`.
    /// The encoding follows the same rules as ProgramError:
    /// - Builtin errors use upper 32 bits (value << 32)
    /// - Custom errors use lower 32 bits (value 1..0xFFFFFFFF)
    /// - Custom(0) uses CUSTOM_ZERO (1 << 32)
    ///
    /// Returns InvalidError for unrecognized builtin codes.
    pub fn fromU64(value: u64) InstructionError {
        const error_mod = @import("error.zig");
        const BUILTIN_BIT_SHIFT = error_mod.BUILTIN_BIT_SHIFT;

        // Check if it's a builtin error (upper 32 bits set)
        const builtin_code = value >> BUILTIN_BIT_SHIFT;
        if (builtin_code != 0) {
            // It's a builtin error, convert via ProgramError
            const prog_err = ProgramError.fromU64(value);
            return switch (prog_err) {
                .CustomZero => .{ .Custom = 0 },
                .InvalidArgument => .InvalidArgument,
                .InvalidInstructionData => .InvalidInstructionData,
                .InvalidAccountData => .InvalidAccountData,
                .AccountDataTooSmall => .AccountDataTooSmall,
                .InsufficientFunds => .InsufficientFunds,
                .IncorrectProgramId => .IncorrectProgramId,
                .MissingRequiredSignature => .MissingRequiredSignature,
                .AccountAlreadyInitialized => .AccountAlreadyInitialized,
                .UninitializedAccount => .UninitializedAccount,
                .NotEnoughAccountKeys => .NotEnoughAccountKeys,
                .AccountBorrowFailed => .AccountBorrowFailed,
                .MaxSeedLengthExceeded => .MaxSeedLengthExceeded,
                .InvalidSeeds => .InvalidSeeds,
                .BorshIoError => .BorshIoError,
                .AccountNotRentExempt => .AccountNotRentExempt,
                .UnsupportedSysvar => .UnsupportedSysvar,
                .IllegalOwner => .IllegalOwner,
                .MaxAccountsDataAllocationsExceeded => .MaxAccountsDataAllocationsExceeded,
                .InvalidRealloc => .InvalidRealloc,
                .MaxInstructionTraceLengthExceeded => .MaxInstructionTraceLengthExceeded,
                .BuiltinProgramsMustConsumeComputeUnits => .BuiltinProgramsMustConsumeComputeUnits,
                .InvalidAccountOwner => .InvalidAccountOwner,
                .ArithmeticOverflow => .ArithmeticOverflow,
                .Immutable => .Immutable,
                .IncorrectAuthority => .IncorrectAuthority,
                _ => .InvalidError, // Unknown builtin code
            };
        }

        // It's a custom error (lower 32 bits only)
        return .{ .Custom = @truncate(value) };
    }

    /// Convert InstructionError to u64 (for serialization)
    ///
    /// Note: Only errors that have a ProgramError equivalent can be converted.
    /// Runtime-only errors (like UnbalancedInstruction) return null.
    pub fn toU64(self: InstructionError) ?u64 {
        const prog_err = self.toProgramError() orelse return null;
        return prog_err.toU64();
    }
};

/// Lamports arithmetic error
///
/// Rust equivalent: `solana_instruction_error::LamportsError`
pub const LamportsError = enum {
    /// Arithmetic underflowed
    ArithmeticUnderflow,
    /// Arithmetic overflowed
    ArithmeticOverflow,

    pub fn toString(self: LamportsError) []const u8 {
        return switch (self) {
            .ArithmeticUnderflow => "Arithmetic underflowed",
            .ArithmeticOverflow => "Arithmetic overflowed",
        };
    }

    /// Convert to InstructionError
    pub fn toInstructionError(self: LamportsError) InstructionError {
        // Both underflow and overflow map to ArithmeticOverflow in InstructionError
        _ = self;
        return .ArithmeticOverflow;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "instruction_error: toString returns correct messages" {
    const err1: InstructionError = .InvalidArgument;
    try std.testing.expectEqualStrings(
        "invalid program argument",
        err1.toString(),
    );
    const err2: InstructionError = .InsufficientFunds;
    try std.testing.expectEqualStrings(
        "insufficient funds for instruction",
        err2.toString(),
    );
    const err3: InstructionError = .{ .Custom = 42 };
    try std.testing.expectEqualStrings(
        "custom program error",
        err3.toString(),
    );
}

test "instruction_error: Custom error holds value" {
    const err = InstructionError{ .Custom = 12345 };
    switch (err) {
        .Custom => |code| try std.testing.expectEqual(@as(u32, 12345), code),
        else => return error.UnexpectedError,
    }
}

test "instruction_error: toProgramError conversion" {
    // Errors that can be converted
    const convertible: InstructionError = .InvalidArgument;
    const prog_err = convertible.toProgramError();
    try std.testing.expect(prog_err != null);
    try std.testing.expectEqual(ProgramError.InvalidArgument, prog_err.?);

    // Custom error conversion
    const custom: InstructionError = .{ .Custom = 100 };
    const custom_prog = custom.toProgramError();
    try std.testing.expect(custom_prog != null);
    try std.testing.expectEqual(@as(?u32, 100), custom_prog.?.getCustomCode());

    // Runtime-only errors cannot be converted
    const runtime_only: InstructionError = .UnbalancedInstruction;
    try std.testing.expect(runtime_only.toProgramError() == null);
}

test "instruction_error: fromProgramError conversion" {
    const prog_err = ProgramError.InvalidArgument;
    const instr_err = InstructionError.fromProgramError(prog_err);
    const expected: InstructionError = .InvalidArgument;
    try std.testing.expectEqual(expected, instr_err);

    // Custom error
    const custom_prog = ProgramError.custom(200);
    const custom_instr = InstructionError.fromProgramError(custom_prog);
    switch (custom_instr) {
        .Custom => |code| try std.testing.expectEqual(@as(u32, 200), code),
        else => return error.UnexpectedError,
    }
}

test "instruction_error: roundtrip conversion" {
    // Test roundtrip: InstructionError -> ProgramError -> InstructionError
    const original: InstructionError = .AccountNotRentExempt;
    const prog = original.toProgramError().?;
    const back = InstructionError.fromProgramError(prog);
    try std.testing.expectEqual(original, back);
}

test "lamports_error: toString and conversion" {
    const underflow: LamportsError = .ArithmeticUnderflow;
    try std.testing.expectEqualStrings(
        "Arithmetic underflowed",
        underflow.toString(),
    );

    // Both map to ArithmeticOverflow in InstructionError
    const expected: InstructionError = .ArithmeticOverflow;
    try std.testing.expectEqual(
        expected,
        underflow.toInstructionError(),
    );
    const overflow: LamportsError = .ArithmeticOverflow;
    try std.testing.expectEqual(
        expected,
        overflow.toInstructionError(),
    );
}

test "instruction_error: fromU64 custom errors" {
    // Custom error with code 1 (lower 32 bits)
    const err1 = InstructionError.fromU64(1);
    switch (err1) {
        .Custom => |code| try std.testing.expectEqual(@as(u32, 1), code),
        else => return error.UnexpectedError,
    }

    // Custom error with code 42
    const err42 = InstructionError.fromU64(42);
    switch (err42) {
        .Custom => |code| try std.testing.expectEqual(@as(u32, 42), code),
        else => return error.UnexpectedError,
    }

    // Custom error with max u32
    const err_max = InstructionError.fromU64(0xFFFFFFFF);
    switch (err_max) {
        .Custom => |code| try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), code),
        else => return error.UnexpectedError,
    }
}

test "instruction_error: fromU64 builtin errors" {
    const error_mod = @import("error.zig");

    // Custom(0) uses CUSTOM_ZERO (1 << 32)
    const err0 = InstructionError.fromU64(1 << 32);
    switch (err0) {
        .Custom => |code| try std.testing.expectEqual(@as(u32, 0), code),
        else => return error.UnexpectedError,
    }

    // InvalidArgument (2 << 32)
    const err_invalid_arg = InstructionError.fromU64(2 << 32);
    const expected_invalid_arg: InstructionError = .InvalidArgument;
    try std.testing.expectEqual(expected_invalid_arg, err_invalid_arg);

    // IncorrectAuthority (26 << 32)
    const err_auth = InstructionError.fromU64(26 << 32);
    const expected_auth: InstructionError = .IncorrectAuthority;
    try std.testing.expectEqual(expected_auth, err_auth);

    // Unknown builtin code should return InvalidError
    const err_unknown = InstructionError.fromU64(100 << 32);
    const expected_unknown: InstructionError = .InvalidError;
    try std.testing.expectEqual(expected_unknown, err_unknown);

    _ = error_mod;
}

test "instruction_error: toU64 roundtrip" {
    // Test errors that have ProgramError equivalents
    const convertible_errors = [_]InstructionError{
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

    for (convertible_errors) |err| {
        const as_u64 = err.toU64();
        try std.testing.expect(as_u64 != null);
        const back = InstructionError.fromU64(as_u64.?);
        try std.testing.expectEqual(err, back);
    }

    // Custom errors roundtrip
    for ([_]u32{ 0, 1, 42, 100, 0xFFFFFFFF }) |code| {
        const err: InstructionError = .{ .Custom = code };
        const as_u64 = err.toU64();
        try std.testing.expect(as_u64 != null);
        const back = InstructionError.fromU64(as_u64.?);
        switch (back) {
            .Custom => |back_code| try std.testing.expectEqual(code, back_code),
            else => return error.UnexpectedError,
        }
    }
}

test "instruction_error: toU64 returns null for runtime-only errors" {
    // Runtime-only errors cannot be converted to u64
    // Note: MissingAccount maps to NotEnoughAccountKeys, so it CAN be converted
    const runtime_errors = [_]InstructionError{
        .GenericError,
        .UnbalancedInstruction,
        .ModifiedProgramId,
        .ExternalAccountLamportSpend,
        .ExternalAccountDataModified,
        .ReadonlyLamportChange,
        .ReadonlyDataModified,
        .DuplicateAccountIndex,
        .ExecutableModified,
        .RentEpochModified,
        .AccountDataSizeChanged,
        .AccountNotExecutable,
        .AccountBorrowOutstanding,
        .DuplicateAccountOutOfSync,
        .InvalidError,
        .ExecutableDataModified,
        .ExecutableLamportChange,
        .ExecutableAccountNotRentExempt,
        .UnsupportedProgramId,
        .CallDepth,
        // .MissingAccount - maps to NotEnoughAccountKeys, so it CAN be converted
        .ReentrancyNotAllowed,
        .ComputationalBudgetExceeded,
        .PrivilegeEscalation,
        .ProgramEnvironmentSetupFailure,
        .ProgramFailedToComplete,
        .ProgramFailedToCompile,
        .MaxAccountsExceeded,
    };

    for (runtime_errors) |err| {
        try std.testing.expect(err.toU64() == null);
    }
}
