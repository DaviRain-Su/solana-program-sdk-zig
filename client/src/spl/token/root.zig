//! SPL Token Program Module (Client)
//!
//! Rust source: https://github.com/solana-program/token/tree/master/interface/src
//!
//! This module provides types, instruction builders, and RPC client for the SPL Token program.
//! Core types (Mint, Account, TokenInstruction, etc.) are imported from the SDK.
//! Instruction builders are provided for client-side transaction construction.
//!
//! ## Features
//! - Token account state types (Mint, Account, Multisig) - from SDK
//! - Token instruction builders (25 instructions) - from SDK
//! - TokenClient for high-level RPC operations
//! - Token error types - from SDK
//!
//! ## Usage
//!
//! ```zig
//! const spl = @import("solana_client").spl;
//!
//! // Low-level: Parse a mint account
//! const mint = try spl.token.Mint.unpackFromSlice(account_data);
//!
//! // Low-level: Create a transfer instruction
//! const ix = spl.token.transfer(source, dest, owner, amount);
//!
//! // High-level: Use TokenClient for RPC operations
//! var client = spl.token.TokenClient.init(allocator, rpc);
//! const sig = try client.transfer(source, dest, owner, amount, signers);
//! ```

const std = @import("std");

// Re-export state types from SDK (via local re-export)
pub const state = @import("state.zig");

/// RPC client wrapper for token operations
pub const client = @import("client.zig");
pub const TokenClient = client.TokenClient;
pub const COption = state.COption;
pub const AccountState = state.AccountState;
pub const Mint = state.Mint;
pub const Account = state.Account;
pub const Multisig = state.Multisig;
pub const MAX_SIGNERS = state.MAX_SIGNERS;
pub const TOKEN_PROGRAM_ID = state.TOKEN_PROGRAM_ID;
pub const isInitializedAccount = state.isInitializedAccount;

// Re-export instruction types and builders
pub const instruction = @import("instruction.zig");
pub const TokenInstruction = instruction.TokenInstruction;
pub const AuthorityType = instruction.AuthorityType;

// Instruction builders
pub const initializeMint = instruction.initializeMint;
pub const initializeMint2 = instruction.initializeMint2;
pub const initializeAccount = instruction.initializeAccount;
pub const initializeAccount2 = instruction.initializeAccount2;
pub const initializeAccount3 = instruction.initializeAccount3;
pub const initializeMultisig = instruction.initializeMultisig;
pub const initializeMultisig2 = instruction.initializeMultisig2;
pub const transfer = instruction.transfer;
pub const transferMultisig = instruction.transferMultisig;
pub const transferChecked = instruction.transferChecked;
pub const approve = instruction.approve;
pub const approveChecked = instruction.approveChecked;
pub const revoke = instruction.revoke;
pub const setAuthority = instruction.setAuthority;
pub const mintTo = instruction.mintTo;
pub const mintToChecked = instruction.mintToChecked;
pub const burn = instruction.burn;
pub const burnChecked = instruction.burnChecked;
pub const closeAccount = instruction.closeAccount;
pub const freezeAccount = instruction.freezeAccount;
pub const thawAccount = instruction.thawAccount;
pub const syncNative = instruction.syncNative;
pub const getAccountDataSize = instruction.getAccountDataSize;
pub const initializeImmutableOwner = instruction.initializeImmutableOwner;
pub const amountToUiAmount = instruction.amountToUiAmount;
pub const uiAmountToAmount = instruction.uiAmountToAmount;

// Re-export error types from SDK (via local re-export)
pub const errors = @import("error.zig");
pub const TokenError = errors.TokenError;

test {
    std.testing.refAllDecls(@This());
}
