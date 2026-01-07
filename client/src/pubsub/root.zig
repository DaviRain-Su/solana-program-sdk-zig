//! Solana WebSocket PubSub Client Module
//!
//! Rust source: https://github.com/anza-xyz/agave/blob/master/pubsub-client/src/lib.rs
//!
//! This module provides a WebSocket client for subscribing to Solana blockchain events.
//!
//! ## Overview
//!
//! The PubSub client supports 9 subscription types:
//!
//! | Subscription | Description | Default Enabled |
//! |--------------|-------------|-----------------|
//! | `accountSubscribe` | Account changes | Yes |
//! | `blockSubscribe` | Block confirmations | No (requires flag) |
//! | `logsSubscribe` | Transaction logs | Yes |
//! | `programSubscribe` | Program account changes | Yes |
//! | `rootSubscribe` | Root slot updates | Yes |
//! | `signatureSubscribe` | Transaction confirmation | Yes |
//! | `slotSubscribe` | Slot processing | Yes |
//! | `slotsUpdatesSubscribe` | Detailed slot updates | Yes |
//! | `voteSubscribe` | Vote events | No (requires flag) |
//!
//! ## Quick Start
//!
//! ```zig
//! const pubsub = @import("pubsub");
//!
//! // Connect to WebSocket endpoint
//! var client = try pubsub.PubsubClient.init(allocator, "wss://api.mainnet-beta.solana.com");
//! defer client.deinit();
//!
//! // Subscribe to slot updates
//! const sub_id = try client.slotSubscribe();
//!
//! // Read notifications
//! while (try client.readNotification()) |notification| {
//!     std.debug.print("Slot update received\n", .{});
//! }
//!
//! // Unsubscribe
//! try client.slotUnsubscribe(sub_id);
//! ```
//!
//! ## Account Subscription Example
//!
//! ```zig
//! const pubkey = try PublicKey.fromBase58("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");
//!
//! const sub_id = try client.accountSubscribe(pubkey, .{
//!     .encoding = .base64,
//!     .commitment = "confirmed",
//! });
//!
//! while (try client.readNotification()) |notification| {
//!     // Handle account update
//! }
//! ```
//!
//! ## Signature Subscription Example (Single Notification)
//!
//! ```zig
//! const signature = try Signature.fromBase58("...");
//!
//! const sub_id = try client.signatureSubscribe(signature, .{
//!     .commitment = "confirmed",
//! });
//!
//! // Wait for confirmation (single notification)
//! if (try client.readNotification()) |notification| {
//!     std.debug.print("Transaction confirmed!\n", .{});
//! }
//! ```

const std = @import("std");

// ============================================================================
// Re-exports
// ============================================================================

pub const pubsub_client = @import("pubsub_client.zig");
pub const PubsubClient = pubsub_client.PubsubClient;
pub const PubsubError = pubsub_client.PubsubError;

pub const types = @import("types.zig");

// Subscription types
pub const SubscriptionId = types.SubscriptionId;
pub const RpcResponseContext = types.RpcResponseContext;
pub const RpcNotification = types.RpcNotification;

// Account types
pub const UiAccount = types.UiAccount;
pub const UiAccountData = types.UiAccountData;
pub const UiAccountEncoding = types.UiAccountEncoding;
pub const RpcAccountInfoConfig = types.RpcAccountInfoConfig;

// Slot types
pub const SlotInfo = types.SlotInfo;
pub const SlotUpdate = types.SlotUpdate;

// Signature types
pub const RpcSignatureResult = types.RpcSignatureResult;
pub const RpcSignatureSubscribeConfig = types.RpcSignatureSubscribeConfig;

// Logs types
pub const RpcTransactionLogsFilter = types.RpcTransactionLogsFilter;
pub const RpcTransactionLogsConfig = types.RpcTransactionLogsConfig;
pub const RpcLogsResponse = types.RpcLogsResponse;

// Program types
pub const RpcProgramAccountsConfig = types.RpcProgramAccountsConfig;
pub const RpcProgramAccountsFilter = types.RpcProgramAccountsFilter;
pub const RpcKeyedAccount = types.RpcKeyedAccount;

// Block types
pub const RpcBlockSubscribeFilter = types.RpcBlockSubscribeFilter;
pub const RpcBlockSubscribeConfig = types.RpcBlockSubscribeConfig;
pub const RpcBlockUpdate = types.RpcBlockUpdate;

// Vote types
pub const RpcVote = types.RpcVote;

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all submodule tests
    std.testing.refAllDecls(@This());
}
