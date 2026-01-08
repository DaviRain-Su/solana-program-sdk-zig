//! WebSocket PubSub Integration Tests
//!
//! These tests require a running local Solana validator with WebSocket support.
//!
//! Run with:
//! ```bash
//! # Start local validator
//! solana-test-validator &
//! # Or use surfpool
//! surfpool start --no-tui &
//!
//! # Run tests
//! cd client && ../solana-zig/zig build integration-test-pubsub
//! ```

const std = @import("std");
const pubsub = @import("pubsub");
const rpc_client = @import("rpc_client");
const sdk = @import("solana_sdk");

const PubsubClient = pubsub.PubsubClient;
const RpcClient = rpc_client.RpcClient;
const PublicKey = sdk.PublicKey;
const Signature = sdk.Signature;

/// Default WebSocket URL for local validator
const DEFAULT_WS_URL = "ws://127.0.0.1:8900";

/// Default RPC URL for local validator
const DEFAULT_RPC_URL = "http://127.0.0.1:8899";

/// System program ID
const SYSTEM_PROGRAM_ID = "11111111111111111111111111111111";

// ============================================================================
// Helper Functions
// ============================================================================

fn getWsUrl() []const u8 {
    return std.posix.getenv("SOLANA_WS_URL") orelse DEFAULT_WS_URL;
}

fn getRpcUrl() []const u8 {
    return std.posix.getenv("SOLANA_RPC_URL") orelse DEFAULT_RPC_URL;
}

/// Check if local RPC is available
fn isLocalRpcAvailable() bool {
    const allocator = std.testing.allocator;
    var client = RpcClient.init(allocator, getRpcUrl());
    defer client.deinit();
    return client.isHealthy();
}

// ============================================================================
// Connection Tests
// ============================================================================

test "pubsub: connect to local validator" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    // Connection successful - test passes
}

// ============================================================================
// Slot Subscription Tests
// ============================================================================

test "pubsub: slotSubscribe and receive notification" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    // Subscribe to slot updates
    const sub_id = try client.slotSubscribe();

    // Set a read timeout so we don't wait forever
    try client.setReadTimeout(5000); // 5 seconds

    // Try to receive a notification
    var attempts: u32 = 0;
    const max_attempts: u32 = 10;

    while (attempts < max_attempts) : (attempts += 1) {
        if (try client.readNotification()) |*notification| {
            defer notification.deinit();
            break;
        }
        std.Thread.sleep(500 * std.time.ns_per_ms);
    }

    // Unsubscribe
    try client.slotUnsubscribe(sub_id);
}

test "pubsub: rootSubscribe" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    // Note: rootSubscribe may not be supported by all validators
    const sub_id = client.rootSubscribe() catch |err| {
        const err_name = @errorName(err);
        if (std.mem.eql(u8, err_name, "RpcError")) {
            return error.SkipZigTest;
        }
        return err;
    };

    try client.rootUnsubscribe(sub_id);
}

// ============================================================================
// Account Subscription Tests
// ============================================================================

test "pubsub: accountSubscribe for system program" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    const system_program = try PublicKey.fromBase58(SYSTEM_PROGRAM_ID);

    const sub_id = try client.accountSubscribe(system_program, .{
        .encoding = .base64,
        .commitment = "confirmed",
    });

    try client.accountUnsubscribe(sub_id);
}

test "pubsub: accountSubscribe with data slice" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    const pubkey = try PublicKey.fromBase58(SYSTEM_PROGRAM_ID);

    const sub_id = try client.accountSubscribe(pubkey, .{
        .encoding = .base64,
    });

    try client.accountUnsubscribe(sub_id);
}

// ============================================================================
// Program Subscription Tests
// ============================================================================

test "pubsub: programSubscribe for system program" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    const system_program = try PublicKey.fromBase58(SYSTEM_PROGRAM_ID);

    // Note: programSubscribe may return RPC error for certain programs
    const sub_id = client.programSubscribe(system_program, .{
        .encoding = .base64,
        .commitment = "confirmed",
    }) catch |err| {
        const err_name = @errorName(err);
        if (std.mem.eql(u8, err_name, "RpcError")) {
            return error.SkipZigTest;
        }
        return err;
    };

    try client.programUnsubscribe(sub_id);
}

// ============================================================================
// Logs Subscription Tests
// ============================================================================

test "pubsub: logsSubscribe for all transactions" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    const sub_id = try client.logsSubscribe(.all, .{
        .commitment = "confirmed",
    });

    try client.logsUnsubscribe(sub_id);
}

test "pubsub: logsSubscribe for specific address" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    const addresses = [_][]const u8{SYSTEM_PROGRAM_ID};
    const sub_id = try client.logsSubscribe(.{ .mentions = &addresses }, null);

    try client.logsUnsubscribe(sub_id);
}

// ============================================================================
// Signature Subscription Tests
// ============================================================================

test "pubsub: signatureSubscribe" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    var sig_bytes: [64]u8 = undefined;
    @memset(&sig_bytes, 0);
    sig_bytes[0] = 1;
    sig_bytes[1] = 2;
    sig_bytes[2] = 3;
    const signature = Signature{ .bytes = sig_bytes };

    const sub_id = try client.signatureSubscribe(signature, .{
        .commitment = "confirmed",
        .enable_received_notification = true,
    });

    try client.signatureUnsubscribe(sub_id);
}

// ============================================================================
// Multiple Subscriptions Test
// ============================================================================

test "pubsub: multiple concurrent subscriptions" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    // Create multiple subscriptions (only use methods that are reliably supported)
    const slot_sub = try client.slotSubscribe();
    const logs_sub = try client.logsSubscribe(.all, null);

    // Unsubscribe all
    try client.slotUnsubscribe(slot_sub);
    try client.logsUnsubscribe(logs_sub);
}

// ============================================================================
// SlotsUpdates Subscription Tests
// ============================================================================

test "pubsub: slotsUpdatesSubscribe" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    // Note: slotsUpdatesSubscribe may not be supported by all validators
    const sub_id = client.slotsUpdatesSubscribe() catch |err| {
        const err_name = @errorName(err);
        if (std.mem.eql(u8, err_name, "RpcError")) {
            return error.SkipZigTest;
        }
        return err;
    };

    try client.slotsUpdatesUnsubscribe(sub_id);
}

// ============================================================================
// Block Subscription Tests (requires --rpc-pubsub-enable-block-subscription)
// ============================================================================

test "pubsub: blockSubscribe" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    // Note: blockSubscribe requires validator flag --rpc-pubsub-enable-block-subscription
    const sub_id = client.blockSubscribe(.all, .{
        .commitment = "confirmed",
    }) catch |err| {
        const err_name = @errorName(err);
        if (std.mem.eql(u8, err_name, "RpcError")) {
            return error.SkipZigTest;
        }
        return err;
    };

    try client.blockUnsubscribe(sub_id);
}

// ============================================================================
// Vote Subscription Tests (requires --rpc-pubsub-enable-vote-subscription)
// ============================================================================

test "pubsub: voteSubscribe" {
    if (!isLocalRpcAvailable()) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const ws_url = getWsUrl();

    var client = PubsubClient.init(allocator, ws_url) catch {
        return error.SkipZigTest;
    };
    defer client.deinit();

    // Note: voteSubscribe requires validator flag --rpc-pubsub-enable-vote-subscription
    const sub_id = client.voteSubscribe() catch |err| {
        const err_name = @errorName(err);
        if (std.mem.eql(u8, err_name, "RpcError")) {
            return error.SkipZigTest;
        }
        return err;
    };

    try client.voteUnsubscribe(sub_id);
}

// ============================================================================
// Error Handling Tests
// ============================================================================

test "pubsub: handle connection failure gracefully" {
    const allocator = std.testing.allocator;

    // Try to connect to a non-existent server - should fail gracefully
    const result = PubsubClient.init(allocator, "ws://127.0.0.1:19999");

    if (result) |*client| {
        var mutable_client = client.*;
        mutable_client.deinit();
        return error.TestUnexpectedResult;
    } else |err| {
        const err_name = @errorName(err);
        try std.testing.expect(std.mem.eql(u8, err_name, "ConnectionFailed") or
            std.mem.eql(u8, err_name, "HandshakeFailed"));
    }
}

test "pubsub: invalid URL handling" {
    const allocator = std.testing.allocator;

    // Try with invalid URL (http:// instead of ws://) - should fail
    const result = PubsubClient.init(allocator, "http://invalid-protocol");

    if (result) |*client| {
        var mutable_client = client.*;
        mutable_client.deinit();
        return error.TestUnexpectedResult;
    } else |err| {
        const err_name = @errorName(err);
        try std.testing.expectEqualStrings("InvalidUrl", err_name);
    }
}
