//! SPL Token state types (Client re-export)
//!
//! This module re-exports the SPL Token state types from the SDK.
//! All types are defined in `solana_sdk.spl.token`.
//!
//! ## Usage
//!
//! ```zig
//! const client = @import("solana_client");
//! const Mint = client.spl.token.Mint;
//! const Account = client.spl.token.Account;
//! ```

const sdk_token = @import("solana_sdk").spl.token;

// Re-export state types from SDK
pub const COption = sdk_token.COption;
pub const AccountState = sdk_token.AccountState;
pub const Mint = sdk_token.Mint;
pub const Account = sdk_token.Account;
pub const Multisig = sdk_token.Multisig;
pub const MAX_SIGNERS = sdk_token.MAX_SIGNERS;
pub const TOKEN_PROGRAM_ID = sdk_token.TOKEN_PROGRAM_ID;
pub const isInitializedAccount = sdk_token.isInitializedAccount;
