//! SPL Token Program Module
//!
//! Rust source: https://github.com/solana-program/token/tree/master/interface/src
//!
//! This module provides types for the SPL Token program:
//! - Token account state types (Mint, Account, Multisig)
//! - Token instruction type definitions
//! - Token error types

const std = @import("std");

// State types
pub const state = @import("state.zig");
pub const COption = state.COption;
pub const AccountState = state.AccountState;
pub const Mint = state.Mint;
pub const Account = state.Account;
pub const Multisig = state.Multisig;
pub const MAX_SIGNERS = state.MAX_SIGNERS;
pub const TOKEN_PROGRAM_ID = state.TOKEN_PROGRAM_ID;

// Instruction types
pub const instruction = @import("instruction.zig");
pub const TokenInstruction = instruction.TokenInstruction;
pub const AuthorityType = instruction.AuthorityType;
pub const TransferData = instruction.TransferData;
pub const TransferCheckedData = instruction.TransferCheckedData;
pub const MintToData = instruction.MintToData;
pub const BurnData = instruction.BurnData;
pub const SetAuthorityData = instruction.SetAuthorityData;

// Error types
pub const errors = @import("error.zig");
pub const TokenError = errors.TokenError;

test {
    std.testing.refAllDecls(@This());
}
