//! Solana Program Library (SPL) Module
//!
//! This module provides types for SPL programs that are shared between
//! on-chain programs and off-chain clients.
//!
//! ## Included Programs
//!
//! - `token` - SPL Token program types (Mint, Account, Multisig, instructions)
//! - `memo` - SPL Memo program for attaching UTF-8 text to transactions
//! - `stake` - Stake program types (StakeStateV2, Delegation, instructions)
//!
//! ## Usage
//!
//! ```zig
//! const sdk = @import("solana_sdk");
//!
//! // Token
//! const Mint = sdk.spl.token.Mint;
//! const Account = sdk.spl.token.Account;
//! const TokenInstruction = sdk.spl.token.TokenInstruction;
//!
//! // Memo
//! const memo = sdk.spl.memo;
//! const memo_ix = memo.MemoInstruction.init("Hello!");
//!
//! // Stake
//! const stake = sdk.spl.stake;
//! const state = try stake.StakeStateV2.unpack(data);
//! ```

const std = @import("std");

// SPL Token Program
pub const token = @import("token/root.zig");

// SPL Memo Program
pub const memo = @import("memo.zig");

// Stake Program
pub const stake = @import("stake/root.zig");

// Convenience re-exports
pub const TOKEN_PROGRAM_ID = token.TOKEN_PROGRAM_ID;
pub const MEMO_PROGRAM_ID = memo.MEMO_PROGRAM_ID;
pub const STAKE_PROGRAM_ID = stake.STAKE_PROGRAM_ID;

test {
    std.testing.refAllDecls(@This());
}
