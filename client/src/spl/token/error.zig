//! SPL Token errors (Client re-export)
//!
//! This module re-exports the SPL Token error types from the SDK.
//! All types are defined in `solana_sdk.spl.token`.
//!
//! ## Usage
//!
//! ```zig
//! const client = @import("solana_client");
//! const TokenError = client.spl.token.TokenError;
//! ```

const sdk_token = @import("solana_sdk").spl.token;

// Re-export error types from SDK
pub const TokenError = sdk_token.TokenError;
