//! SPL Token state types (Client re-export)
//!
//! This module re-exports the SPL Token state types from the Program SDK.
//! All types are defined in `solana_program_sdk.spl.token`.
//!
//! ## Usage
//!
//! ```zig
//! const client = @import("solana_client");
//! const Mint = client.spl.token.Mint;
//! const Account = client.spl.token.Account;
//! ```

const sdk_spl = @import("solana_sdk").spl.token.state;

// Re-export state types from SDK
pub const COption = sdk_spl.COption;
pub const AccountState = sdk_spl.AccountState;
pub const Mint = sdk_spl.Mint;
pub const Account = sdk_spl.Account;
pub const Multisig = sdk_spl.Multisig;
pub const MAX_SIGNERS = sdk_spl.MAX_SIGNERS;
pub const TOKEN_PROGRAM_ID = sdk_spl.TOKEN_PROGRAM_ID;
