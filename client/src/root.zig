//! Solana Client SDK - RPC Client Implementation
//!
//! Rust source: https://github.com/anza-xyz/agave/tree/master/rpc-client
//!
//! This module provides a complete RPC client for interacting with Solana nodes.
//! It implements all 52 HTTP RPC methods from the Solana JSON-RPC API.
//!
//! ## Usage
//!
//! ```zig
//! const client = try RpcClient.init(allocator, "https://api.mainnet-beta.solana.com");
//! defer client.deinit();
//!
//! const balance = try client.getBalance(pubkey);
//! ```

const std = @import("std");

// Re-export SDK types
pub const sdk = @import("solana_sdk");
pub const PublicKey = sdk.PublicKey;
pub const Hash = sdk.Hash;
pub const Signature = sdk.Signature;
pub const Keypair = sdk.Keypair;

// ============================================================================
// Client Modules
// ============================================================================

pub const error_types = @import("error.zig");
pub const ClientError = error_types.ClientError;
pub const RpcError = error_types.RpcError;
pub const RpcErrorCode = error_types.RpcErrorCode;

pub const commitment = @import("commitment.zig");
pub const Commitment = commitment.Commitment;
pub const CommitmentConfig = commitment.CommitmentConfig;

pub const types = @import("types.zig");
pub const RpcResponseContext = types.RpcResponseContext;
pub const Response = types.Response;
pub const AccountInfo = types.AccountInfo;
pub const LatestBlockhash = types.LatestBlockhash;
pub const SignatureStatus = types.SignatureStatus;
pub const TransactionStatus = types.TransactionStatus;

pub const json_rpc = @import("json_rpc.zig");
pub const JsonRpcClient = json_rpc.JsonRpcClient;

pub const rpc_client = @import("rpc_client.zig");
pub const RpcClient = rpc_client.RpcClient;

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all module tests
    std.testing.refAllDecls(@This());
}
