//! Solana Program Library (SPL) Module
//!
//! This module provides types for SPL programs that are shared between
//! on-chain programs and off-chain clients.
//!
//! ## Included Programs
//!
//! - `token` - SPL Token program types (Mint, Account, Multisig, instructions)
//!
//! ## Usage
//!
//! ```zig
//! const sdk = @import("solana_sdk");
//! const Mint = sdk.spl.token.Mint;
//! const Account = sdk.spl.token.Account;
//! const TokenInstruction = sdk.spl.token.TokenInstruction;
//! ```

const std = @import("std");

// SPL Token Program
pub const token = @import("token/root.zig");

// Convenience re-exports
pub const TOKEN_PROGRAM_ID = token.TOKEN_PROGRAM_ID;

test {
    std.testing.refAllDecls(@This());
}
