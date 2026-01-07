//! Solana Program Library (SPL) Module
//!
//! Rust source: https://github.com/solana-program
//!
//! This module provides types and instruction builders for common SPL programs:
//! - SPL Token
//! - Associated Token Account (ATA)
//!
//! ## Usage
//!
//! ```zig
//! const spl = @import("solana_client").spl;
//!
//! // Work with SPL Token
//! const mint = try spl.token.Mint.unpackFromSlice(account_data);
//! const ix = spl.token.transfer(source, dest, owner, amount);
//!
//! // Work with Associated Token Accounts
//! const ata = spl.associated_token.findAssociatedTokenAddress(wallet, mint);
//! ```

const std = @import("std");

/// SPL Token Program
pub const token = @import("token/root.zig");

/// Associated Token Account Program
pub const associated_token = @import("associated_token.zig");
pub const ASSOCIATED_TOKEN_PROGRAM_ID = associated_token.ASSOCIATED_TOKEN_PROGRAM_ID;

test {
    std.testing.refAllDecls(@This());
}
