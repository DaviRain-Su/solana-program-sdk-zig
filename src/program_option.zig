//! Zig implementation of Solana SDK's program-option module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-option/src/lib.rs
//!
//! This module re-exports the COption type from the shared SDK.
//! See `sdk.c_option` for full documentation.
//!
//! ## Memory Layout
//!
//! `COption<T>` uses a 4-byte (u32) tag followed by the value:
//! - Tag = 0: None (value bytes are zero-filled)
//! - Tag = 1: Some (value bytes contain the actual value)
//!
//! For example:
//! - `COption<Pubkey>`: 4 byte tag + 32 byte pubkey = 36 bytes
//! - `COption<u64>`: 4 byte tag + 8 byte u64 = 12 bytes

const sdk = @import("solana_sdk");

/// A C-compatible `Option<T>` type for Solana account state.
///
/// Re-exported from `sdk.c_option.COption`. See that module for full documentation.
pub const COption = sdk.COption;

// Re-run SDK tests to ensure compatibility
test {
    _ = sdk.c_option;
}
