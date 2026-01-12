//! Solana Client SDK - RPC Client and Transaction Building
//!
//! Rust source: https://github.com/anza-xyz/agave/tree/master/rpc-client
//!
//! This module provides a complete client SDK for interacting with Solana:
//! - RPC client with all 52 HTTP RPC methods
//! - Transaction building with fluent API
//! - Transaction signing utilities
//!
//! ## RPC Client Usage
//!
//! ```zig
//! const client = try RpcClient.init(allocator, "https://api.mainnet-beta.solana.com");
//! defer client.deinit();
//!
//! const balance = try client.getBalance(pubkey);
//! ```
//!
//! ## Transaction Building Usage
//!
//! ```zig
//! var builder = transaction.TransactionBuilder.init(allocator);
//! defer builder.deinit();
//!
//! _ = builder.setFeePayer(payer_pubkey);
//! _ = builder.setRecentBlockhash(blockhash);
//! _ = try builder.addInstruction(instruction);
//!
//! var tx = try builder.buildSigned(&[_]*const Keypair{&payer_kp});
//! defer tx.deinit();
//! ```

const std = @import("std");

// Re-export SDK types
pub const sdk = @import("solana_sdk");
pub const PublicKey = sdk.PublicKey;
pub const Hash = sdk.Hash;
pub const Signature = sdk.Signature;
pub const Keypair = sdk.Keypair;
pub const AccountMeta = sdk.AccountMeta;

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
pub const CallResult = json_rpc.CallResult;
pub const JsonRpcError = json_rpc.JsonRpcError;

pub const rpc_client = @import("rpc_client.zig");
pub const RpcClient = rpc_client.RpcClient;

// ============================================================================
// Transaction Building Modules
// ============================================================================

pub const transaction = @import("transaction/root.zig");
pub const TransactionBuilder = transaction.TransactionBuilder;
pub const BuiltTransaction = transaction.BuiltTransaction;
pub const Message = transaction.Message;
pub const MessageHeader = transaction.MessageHeader;
pub const CompiledInstruction = transaction.CompiledInstruction;
pub const InstructionInput = transaction.InstructionInput;
pub const BuilderError = transaction.BuilderError;

// Signer utilities
pub const Signer = transaction.Signer;
pub const SignerError = transaction.SignerError;
pub const Presigner = transaction.Presigner;
pub const NullSigner = transaction.NullSigner;
pub const signTransaction = transaction.signTransaction;
pub const partialSignTransaction = transaction.partialSignTransaction;
pub const verifyTransaction = transaction.verifyTransaction;

// Convenience functions
pub const createTransfer = transaction.createTransfer;

// ============================================================================
// PubSub Module (WebSocket Subscriptions)
// ============================================================================

pub const pubsub = @import("pubsub/root.zig");
pub const PubsubClient = pubsub.PubsubClient;
pub const PubsubError = pubsub.PubsubError;
pub const SubscriptionId = pubsub.SubscriptionId;

// ============================================================================
// SPL Programs Module
// ============================================================================

pub const spl = @import("spl/root.zig");

// ============================================================================
// Anchor Client Helpers
// ============================================================================

pub const anchor = @import("anchor/root.zig");

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all module tests
    std.testing.refAllDecls(@This());
}
