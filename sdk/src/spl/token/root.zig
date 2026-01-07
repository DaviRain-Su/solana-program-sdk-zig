//! SPL Token Program Module
//!
//! Rust source: https://github.com/solana-program/token/tree/master/interface/src
//!
//! This module provides types for the SPL Token program:
//! - Token account state types (Mint, Account, Multisig)
//! - Token instruction type definitions
//! - Token error types
//!
//! ## Usage
//!
//! ```zig
//! const sdk = @import("solana_sdk");
//!
//! // Parse a mint account
//! const mint = try sdk.spl.token.Mint.unpackFromSlice(account_data);
//!
//! // Check instruction type
//! const ix_type = sdk.spl.token.TokenInstruction.fromByte(data[0]);
//! ```

const std = @import("std");

// ============================================================================
// State types (Mint, Account, Multisig)
// ============================================================================

pub const state = @import("state.zig");

/// C-compatible Option type for Solana account state
pub const COption = state.COption;

/// Account state enum (Uninitialized, Initialized, Frozen)
pub const AccountState = state.AccountState;

/// Mint data - token configuration
pub const Mint = state.Mint;

/// Account data - token account holding tokens
pub const Account = state.Account;

/// Multisignature data
pub const Multisig = state.Multisig;

/// SPL Token Program ID
pub const TOKEN_PROGRAM_ID = state.TOKEN_PROGRAM_ID;

/// Maximum number of multisignature signers
pub const MAX_SIGNERS = state.MAX_SIGNERS;

/// Check if account data represents an initialized account
pub const isInitializedAccount = state.isInitializedAccount;

// ============================================================================
// Instruction types
// ============================================================================

pub const instruction = @import("instruction.zig");

/// Token program instruction types (25 variants)
pub const TokenInstruction = instruction.TokenInstruction;

/// Authority types for SetAuthority instruction
pub const AuthorityType = instruction.AuthorityType;

/// Minimum number of multisignature signers
pub const MIN_SIGNERS = instruction.MIN_SIGNERS;

// Instruction data parsing types
pub const TransferData = instruction.TransferData;
pub const TransferCheckedData = instruction.TransferCheckedData;
pub const MintToData = instruction.MintToData;
pub const MintToCheckedData = instruction.MintToCheckedData;
pub const BurnData = instruction.BurnData;
pub const BurnCheckedData = instruction.BurnCheckedData;
pub const ApproveData = instruction.ApproveData;
pub const ApproveCheckedData = instruction.ApproveCheckedData;
pub const SetAuthorityData = instruction.SetAuthorityData;
pub const InitializeMintData = instruction.InitializeMintData;
pub const InitializeMultisigData = instruction.InitializeMultisigData;

// ============================================================================
// Error types
// ============================================================================

pub const errors = @import("error.zig");

/// Errors that may be returned by the Token program
pub const TokenError = errors.TokenError;

// ============================================================================
// Tests
// ============================================================================

test {
    std.testing.refAllDecls(@This());
}
