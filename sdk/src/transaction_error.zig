//! Zig implementation of Solana SDK's transaction error types
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/transaction-error/src/lib.rs
//!
//! This module provides error types for transaction processing, including
//! TransactionError, AddressLoaderError, and SanitizeMessageError.

const std = @import("std");
const InstructionError = @import("instruction_error.zig").InstructionError;

/// Reasons a transaction might be rejected.
///
/// Rust equivalent: `solana_transaction_error::TransactionError`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/transaction-error/src/lib.rs
pub const TransactionError = union(enum) {
    /// An account is already being processed in another transaction in a way
    /// that does not support parallelism
    AccountInUse,

    /// A `Pubkey` appears twice in the transaction's `account_keys`. Instructions can reference
    /// `Pubkey`s more than once but the message must contain a list with no duplicate keys
    AccountLoadedTwice,

    /// Attempt to debit an account but found no record of a prior credit.
    AccountNotFound,

    /// Attempt to load a program that does not exist
    ProgramAccountNotFound,

    /// The from `Pubkey` does not have sufficient balance to pay the fee to schedule the transaction
    InsufficientFundsForFee,

    /// This account may not be used to pay transaction fees
    InvalidAccountForFee,

    /// The bank has seen this transaction before. This can occur under normal operation
    /// when a UDP packet is duplicated, as a user error from a client not updating
    /// its `recent_blockhash`, or as a double-spend attack.
    AlreadyProcessed,

    /// The bank has not seen the given `recent_blockhash` or the transaction is too old and
    /// the `recent_blockhash` has been discarded.
    BlockhashNotFound,

    /// An error occurred while processing an instruction. The first element
    /// indicates the instruction index in which the error occurred.
    InstructionError: struct {
        index: u8,
        err: InstructionError,
    },

    /// Loader call chain is too deep
    CallChainTooDeep,

    /// Transaction requires a fee but has no signature present
    MissingSignatureForFee,

    /// Transaction contains an invalid account reference
    InvalidAccountIndex,

    /// Transaction did not pass signature verification
    SignatureFailure,

    /// This program may not be used for executing instructions
    InvalidProgramForExecution,

    /// Transaction failed to sanitize accounts offsets correctly
    /// implies that account locks are not taken for this TX, and should
    /// not be unlocked.
    SanitizeFailure,

    /// Cluster maintenance
    ClusterMaintenance,

    /// Transaction processing left an account with an outstanding borrowed reference
    AccountBorrowOutstanding,

    /// Transaction would exceed max Block Cost Limit
    WouldExceedMaxBlockCostLimit,

    /// Transaction version is unsupported
    UnsupportedVersion,

    /// Transaction loads a writable account that cannot be written
    InvalidWritableAccount,

    /// Transaction would exceed max account limit within the block
    WouldExceedMaxAccountCostLimit,

    /// Transaction would exceed account data limit within the block
    WouldExceedAccountDataBlockLimit,

    /// Transaction locked too many accounts
    TooManyAccountLocks,

    /// Address lookup table not found
    AddressLookupTableNotFound,

    /// Attempted to lookup addresses from an account owned by the wrong program
    InvalidAddressLookupTableOwner,

    /// Attempted to lookup addresses from an invalid account
    InvalidAddressLookupTableData,

    /// Address table lookup uses an invalid index
    InvalidAddressLookupTableIndex,

    /// Transaction leaves an account with a lower balance than rent-exempt minimum
    InvalidRentPayingAccount,

    /// Transaction would exceed max Vote Cost Limit
    WouldExceedMaxVoteCostLimit,

    /// Transaction would exceed total account data limit
    WouldExceedAccountDataTotalLimit,

    /// Transaction contains a duplicate instruction that is not allowed
    DuplicateInstruction: u8,

    /// Transaction results in an account with insufficient funds for rent
    InsufficientFundsForRent: struct {
        account_index: u8,
    },

    /// Transaction exceeded max loaded accounts data size cap
    MaxLoadedAccountsDataSizeExceeded,

    /// LoadedAccountsDataSizeLimit set for transaction must be greater than 0.
    InvalidLoadedAccountsDataSizeLimit,

    /// Sanitized transaction differed before/after feature activation. Needs to be resanitized.
    ResanitizationNeeded,

    /// Program execution is temporarily restricted on an account.
    ProgramExecutionTemporarilyRestricted: struct {
        account_index: u8,
    },

    /// The total balance before the transaction does not equal the total balance after the transaction
    UnbalancedTransaction,

    /// Program cache hit max limit.
    ProgramCacheHitMaxLimit,

    /// Commit cancelled internally.
    CommitCancelled,

    /// Get human-readable error message
    pub fn toString(self: TransactionError) []const u8 {
        return switch (self) {
            .AccountInUse => "Account in use",
            .AccountLoadedTwice => "Account loaded twice",
            .AccountNotFound => "Attempt to debit an account but found no record of a prior credit.",
            .ProgramAccountNotFound => "Attempt to load a program that does not exist",
            .InsufficientFundsForFee => "Insufficient funds for fee",
            .InvalidAccountForFee => "This account may not be used to pay transaction fees",
            .AlreadyProcessed => "This transaction has already been processed",
            .BlockhashNotFound => "Blockhash not found",
            .InstructionError => "Error processing instruction",
            .CallChainTooDeep => "Loader call chain is too deep",
            .MissingSignatureForFee => "Transaction requires a fee but has no signature present",
            .InvalidAccountIndex => "Transaction contains an invalid account reference",
            .SignatureFailure => "Transaction did not pass signature verification",
            .InvalidProgramForExecution => "This program may not be used for executing instructions",
            .SanitizeFailure => "Transaction failed to sanitize accounts offsets correctly",
            .ClusterMaintenance => "Transactions are currently disabled due to cluster maintenance",
            .AccountBorrowOutstanding => "Transaction processing left an account with an outstanding borrowed reference",
            .WouldExceedMaxBlockCostLimit => "Transaction would exceed max Block Cost Limit",
            .UnsupportedVersion => "Transaction version is unsupported",
            .InvalidWritableAccount => "Transaction loads a writable account that cannot be written",
            .WouldExceedMaxAccountCostLimit => "Transaction would exceed max account limit within the block",
            .WouldExceedAccountDataBlockLimit => "Transaction would exceed account data limit within the block",
            .TooManyAccountLocks => "Transaction locked too many accounts",
            .AddressLookupTableNotFound => "Transaction loads an address table account that doesn't exist",
            .InvalidAddressLookupTableOwner => "Transaction loads an address table account with an invalid owner",
            .InvalidAddressLookupTableData => "Transaction loads an address table account with invalid data",
            .InvalidAddressLookupTableIndex => "Transaction address table lookup uses an invalid index",
            .InvalidRentPayingAccount => "Transaction leaves an account with a lower balance than rent-exempt minimum",
            .WouldExceedMaxVoteCostLimit => "Transaction would exceed max Vote Cost Limit",
            .WouldExceedAccountDataTotalLimit => "Transaction would exceed total account data limit",
            .DuplicateInstruction => "Transaction contains a duplicate instruction that is not allowed",
            .InsufficientFundsForRent => "Transaction results in an account with insufficient funds for rent",
            .MaxLoadedAccountsDataSizeExceeded => "Transaction exceeded max loaded accounts data size cap",
            .InvalidLoadedAccountsDataSizeLimit => "LoadedAccountsDataSizeLimit set for transaction must be greater than 0.",
            .ResanitizationNeeded => "ResanitizationNeeded",
            .ProgramExecutionTemporarilyRestricted => "Program execution is temporarily restricted",
            .UnbalancedTransaction => "Sum of account balances before and after transaction do not match",
            .ProgramCacheHitMaxLimit => "Program cache hit max limit",
            .CommitCancelled => "Commit cancelled",
        };
    }

    /// Create an InstructionError variant
    pub fn instructionError(index: u8, err: InstructionError) TransactionError {
        return .{ .InstructionError = .{ .index = index, .err = err } };
    }

    /// Create a DuplicateInstruction variant
    pub fn duplicateInstruction(index: u8) TransactionError {
        return .{ .DuplicateInstruction = index };
    }

    /// Create an InsufficientFundsForRent variant
    pub fn insufficientFundsForRent(account_index: u8) TransactionError {
        return .{ .InsufficientFundsForRent = .{ .account_index = account_index } };
    }

    /// Create a ProgramExecutionTemporarilyRestricted variant
    pub fn programExecutionTemporarilyRestricted(account_index: u8) TransactionError {
        return .{ .ProgramExecutionTemporarilyRestricted = .{ .account_index = account_index } };
    }

    /// Convert from AddressLoaderError
    pub fn fromAddressLoaderError(err: AddressLoaderError) TransactionError {
        return switch (err) {
            .Disabled => .UnsupportedVersion,
            .SlotHashesSysvarNotFound => .AccountNotFound,
            .LookupTableAccountNotFound => .AddressLookupTableNotFound,
            .InvalidAccountOwner => .InvalidAddressLookupTableOwner,
            .InvalidAccountData => .InvalidAddressLookupTableData,
            .InvalidLookupIndex => .InvalidAddressLookupTableIndex,
        };
    }

    /// Convert from SanitizeMessageError
    pub fn fromSanitizeMessageError(err: SanitizeMessageError) TransactionError {
        return switch (err) {
            .AddressLoaderError => |loader_err| TransactionError.fromAddressLoaderError(loader_err),
            else => .SanitizeFailure,
        };
    }

    /// Check if this is an instruction error
    pub fn isInstructionError(self: TransactionError) bool {
        return switch (self) {
            .InstructionError => true,
            else => false,
        };
    }

    /// Get the instruction index if this is an instruction error
    pub fn getInstructionIndex(self: TransactionError) ?u8 {
        return switch (self) {
            .InstructionError => |data| data.index,
            else => null,
        };
    }

    /// Get the inner instruction error if this is an instruction error
    pub fn getInstructionError(self: TransactionError) ?InstructionError {
        return switch (self) {
            .InstructionError => |data| data.err,
            else => null,
        };
    }
};

/// Address loader error types
///
/// Rust equivalent: `solana_transaction_error::AddressLoaderError`
pub const AddressLoaderError = enum {
    /// Address loading from lookup tables is disabled
    Disabled,

    /// Failed to load slot hashes sysvar
    SlotHashesSysvarNotFound,

    /// Attempted to lookup addresses from a table that does not exist
    LookupTableAccountNotFound,

    /// Attempted to lookup addresses from an account owned by the wrong program
    InvalidAccountOwner,

    /// Attempted to lookup addresses from an invalid account
    InvalidAccountData,

    /// Address lookup contains an invalid index
    InvalidLookupIndex,

    /// Get human-readable error message
    pub fn toString(self: AddressLoaderError) []const u8 {
        return switch (self) {
            .Disabled => "Address loading from lookup tables is disabled",
            .SlotHashesSysvarNotFound => "Failed to load slot hashes sysvar",
            .LookupTableAccountNotFound => "Attempted to lookup addresses from a table that does not exist",
            .InvalidAccountOwner => "Attempted to lookup addresses from an account owned by the wrong program",
            .InvalidAccountData => "Attempted to lookup addresses from an invalid account",
            .InvalidLookupIndex => "Address lookup contains an invalid index",
        };
    }

    /// Convert to TransactionError
    pub fn toTransactionError(self: AddressLoaderError) TransactionError {
        return TransactionError.fromAddressLoaderError(self);
    }
};

/// Sanitize message error types
///
/// Rust equivalent: `solana_transaction_error::SanitizeMessageError`
pub const SanitizeMessageError = union(enum) {
    /// Index out of bounds
    IndexOutOfBounds,

    /// Value out of bounds
    ValueOutOfBounds,

    /// Invalid value
    InvalidValue,

    /// Address loader error
    AddressLoaderError: AddressLoaderError,

    /// Get human-readable error message
    pub fn toString(self: SanitizeMessageError) []const u8 {
        return switch (self) {
            .IndexOutOfBounds => "index out of bounds",
            .ValueOutOfBounds => "value out of bounds",
            .InvalidValue => "invalid value",
            .AddressLoaderError => |err| err.toString(),
        };
    }

    /// Convert to TransactionError
    pub fn toTransactionError(self: SanitizeMessageError) TransactionError {
        return TransactionError.fromSanitizeMessageError(self);
    }

    /// Create from AddressLoaderError
    pub fn fromAddressLoaderError(err: AddressLoaderError) SanitizeMessageError {
        return .{ .AddressLoaderError = err };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "transaction_error: toString returns correct messages" {
    const err1: TransactionError = .AccountInUse;
    try std.testing.expectEqualStrings(
        "Account in use",
        err1.toString(),
    );

    const err2: TransactionError = .BlockhashNotFound;
    try std.testing.expectEqualStrings(
        "Blockhash not found",
        err2.toString(),
    );

    const err3: TransactionError = .InsufficientFundsForFee;
    try std.testing.expectEqualStrings(
        "Insufficient funds for fee",
        err3.toString(),
    );
}

test "transaction_error: InstructionError variant" {
    const instr_err: InstructionError = .InvalidArgument;
    const tx_err = TransactionError.instructionError(2, instr_err);

    try std.testing.expect(tx_err.isInstructionError());
    try std.testing.expectEqual(@as(?u8, 2), tx_err.getInstructionIndex());

    const inner = tx_err.getInstructionError();
    try std.testing.expect(inner != null);
    const expected_inner: InstructionError = .InvalidArgument;
    try std.testing.expectEqual(expected_inner, inner.?);
}

test "transaction_error: DuplicateInstruction variant" {
    const err = TransactionError.duplicateInstruction(5);
    try std.testing.expectEqualStrings(
        "Transaction contains a duplicate instruction that is not allowed",
        err.toString(),
    );

    switch (err) {
        .DuplicateInstruction => |idx| try std.testing.expectEqual(@as(u8, 5), idx),
        else => return error.UnexpectedError,
    }
}

test "transaction_error: InsufficientFundsForRent variant" {
    const err = TransactionError.insufficientFundsForRent(3);

    switch (err) {
        .InsufficientFundsForRent => |data| try std.testing.expectEqual(@as(u8, 3), data.account_index),
        else => return error.UnexpectedError,
    }
}

test "transaction_error: ProgramExecutionTemporarilyRestricted variant" {
    const err = TransactionError.programExecutionTemporarilyRestricted(7);

    switch (err) {
        .ProgramExecutionTemporarilyRestricted => |data| try std.testing.expectEqual(@as(u8, 7), data.account_index),
        else => return error.UnexpectedError,
    }
}

test "address_loader_error: toString returns correct messages" {
    try std.testing.expectEqualStrings(
        "Address loading from lookup tables is disabled",
        AddressLoaderError.Disabled.toString(),
    );

    try std.testing.expectEqualStrings(
        "Failed to load slot hashes sysvar",
        AddressLoaderError.SlotHashesSysvarNotFound.toString(),
    );
}

test "address_loader_error: toTransactionError conversion" {
    const disabled_tx: TransactionError = .UnsupportedVersion;
    try std.testing.expectEqual(
        disabled_tx,
        AddressLoaderError.Disabled.toTransactionError(),
    );

    const not_found_tx: TransactionError = .AddressLookupTableNotFound;
    try std.testing.expectEqual(
        not_found_tx,
        AddressLoaderError.LookupTableAccountNotFound.toTransactionError(),
    );

    const invalid_owner_tx: TransactionError = .InvalidAddressLookupTableOwner;
    try std.testing.expectEqual(
        invalid_owner_tx,
        AddressLoaderError.InvalidAccountOwner.toTransactionError(),
    );
}

test "sanitize_message_error: toString returns correct messages" {
    const err1: SanitizeMessageError = .IndexOutOfBounds;
    try std.testing.expectEqualStrings(
        "index out of bounds",
        err1.toString(),
    );

    const err2: SanitizeMessageError = .ValueOutOfBounds;
    try std.testing.expectEqualStrings(
        "value out of bounds",
        err2.toString(),
    );

    const err3 = SanitizeMessageError.fromAddressLoaderError(.InvalidLookupIndex);
    try std.testing.expectEqualStrings(
        "Address lookup contains an invalid index",
        err3.toString(),
    );
}

test "sanitize_message_error: toTransactionError conversion" {
    const err1: SanitizeMessageError = .IndexOutOfBounds;
    const tx1: TransactionError = .SanitizeFailure;
    try std.testing.expectEqual(tx1, err1.toTransactionError());

    const err2 = SanitizeMessageError.fromAddressLoaderError(.InvalidLookupIndex);
    const tx2: TransactionError = .InvalidAddressLookupTableIndex;
    try std.testing.expectEqual(tx2, err2.toTransactionError());
}

test "transaction_error: non-instruction error returns null" {
    const err: TransactionError = .AccountInUse;
    try std.testing.expect(!err.isInstructionError());
    try std.testing.expect(err.getInstructionIndex() == null);
    try std.testing.expect(err.getInstructionError() == null);
}
