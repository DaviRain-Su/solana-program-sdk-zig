//! Solana WebSocket PubSub Types
//!
//! Rust source: https://github.com/anza-xyz/agave/blob/master/rpc-client-api/src/response.rs
//!
//! This module defines the types used in WebSocket subscription responses.

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const Hash = sdk.Hash;
const Signature = sdk.Signature;

// ============================================================================
// Common Types
// ============================================================================

/// Context included in RPC responses
pub const RpcResponseContext = struct {
    slot: u64,
    api_version: ?[]const u8 = null,
};

/// Wrapper for subscription notifications with context
pub fn RpcNotification(comptime T: type) type {
    return struct {
        context: RpcResponseContext,
        value: T,
    };
}

// ============================================================================
// Account Subscription Types
// ============================================================================

/// Account encoding format
pub const UiAccountEncoding = enum {
    base58,
    base64,
    @"base64+zstd",
    jsonParsed,

    pub fn toString(self: UiAccountEncoding) []const u8 {
        return switch (self) {
            .base58 => "base58",
            .base64 => "base64",
            .@"base64+zstd" => "base64+zstd",
            .jsonParsed => "jsonParsed",
        };
    }
};

/// Account data representation
pub const UiAccountData = union(enum) {
    /// Legacy format: [data, encoding]
    legacy_binary: struct {
        data: []const u8,
        encoding: UiAccountEncoding,
    },
    /// JSON parsed format
    json_parsed: std.json.Value,
    /// Raw bytes (after decoding)
    binary: []const u8,
};

/// Account information returned by subscription
pub const UiAccount = struct {
    lamports: u64,
    data: UiAccountData,
    owner: []const u8,
    executable: bool,
    rent_epoch: u64,
    space: ?u64 = null,
};

/// Configuration for account subscription
pub const RpcAccountInfoConfig = struct {
    encoding: ?UiAccountEncoding = null,
    data_slice: ?DataSlice = null,
    commitment: ?[]const u8 = null,
    min_context_slot: ?u64 = null,

    pub const DataSlice = struct {
        offset: usize,
        length: usize,
    };

    pub fn toJson(self: RpcAccountInfoConfig, allocator: std.mem.Allocator) ![]const u8 {
        var obj = std.json.ObjectMap.init(allocator);
        defer obj.deinit();

        if (self.encoding) |enc| {
            try obj.put("encoding", .{ .string = enc.toString() });
        }
        if (self.data_slice) |slice| {
            var slice_obj = std.json.ObjectMap.init(allocator);
            try slice_obj.put("offset", .{ .integer = @intCast(slice.offset) });
            try slice_obj.put("length", .{ .integer = @intCast(slice.length) });
            try obj.put("dataSlice", .{ .object = slice_obj });
        }
        if (self.commitment) |c| {
            try obj.put("commitment", .{ .string = c });
        }
        if (self.min_context_slot) |slot| {
            try obj.put("minContextSlot", .{ .integer = @intCast(slot) });
        }

        return std.json.stringifyAlloc(allocator, std.json.Value{ .object = obj }, .{});
    }
};

// ============================================================================
// Slot Subscription Types
// ============================================================================

/// Slot information from slotSubscribe
pub const SlotInfo = struct {
    slot: u64,
    parent: u64,
    root: u64,
};

/// Slot update types from slotsUpdatesSubscribe
pub const SlotUpdate = union(enum) {
    first_shred_received: FirstShredReceived,
    completed: SlotCompleted,
    created_bank: CreatedBank,
    frozen: SlotFrozen,
    dead: SlotDead,
    optimistic_confirmation: OptimisticConfirmation,
    root: SlotRoot,

    pub const FirstShredReceived = struct {
        slot: u64,
        timestamp: u64,
    };

    pub const SlotCompleted = struct {
        slot: u64,
        timestamp: u64,
    };

    pub const CreatedBank = struct {
        slot: u64,
        parent: u64,
        timestamp: u64,
    };

    pub const SlotFrozen = struct {
        slot: u64,
        timestamp: u64,
        stats: ?FrozenStats = null,
    };

    pub const FrozenStats = struct {
        num_transaction_entries: u64,
        num_successful_transactions: u64,
        num_failed_transactions: u64,
        max_transactions_per_entry: u64,
    };

    pub const SlotDead = struct {
        slot: u64,
        timestamp: u64,
        err: []const u8,
    };

    pub const OptimisticConfirmation = struct {
        slot: u64,
        timestamp: u64,
    };

    pub const SlotRoot = struct {
        slot: u64,
        timestamp: u64,
    };
};

// ============================================================================
// Signature Subscription Types
// ============================================================================

/// Signature status from signatureSubscribe
pub const RpcSignatureResult = struct {
    err: ?TransactionErrorValue = null,

    pub const TransactionErrorValue = std.json.Value;
};

/// Configuration for signature subscription
pub const RpcSignatureSubscribeConfig = struct {
    commitment: ?[]const u8 = null,
    enable_received_notification: ?bool = null,
};

// ============================================================================
// Logs Subscription Types
// ============================================================================

/// Filter for logs subscription
pub const RpcTransactionLogsFilter = union(enum) {
    all,
    all_with_votes,
    mentions: []const []const u8,

    pub fn toJsonValue(self: RpcTransactionLogsFilter, allocator: std.mem.Allocator) !std.json.Value {
        return switch (self) {
            .all => .{ .string = "all" },
            .all_with_votes => .{ .string = "allWithVotes" },
            .mentions => |addrs| blk: {
                var arr = std.json.Array.init(allocator);
                for (addrs) |addr| {
                    try arr.append(.{ .string = addr });
                }
                var obj = std.json.ObjectMap.init(allocator);
                try obj.put("mentions", .{ .array = arr });
                break :blk .{ .object = obj };
            },
        };
    }
};

/// Configuration for logs subscription
pub const RpcTransactionLogsConfig = struct {
    commitment: ?[]const u8 = null,
};

/// Logs response from logsSubscribe
pub const RpcLogsResponse = struct {
    signature: []const u8,
    err: ?std.json.Value = null,
    logs: []const []const u8,
};

// ============================================================================
// Program Subscription Types
// ============================================================================

/// Filter for program subscription
pub const RpcProgramAccountsFilter = union(enum) {
    memcmp: MemcmpFilter,
    data_size: u64,

    pub const MemcmpFilter = struct {
        offset: usize,
        bytes: []const u8,
        encoding: ?[]const u8 = null,
    };
};

/// Configuration for program subscription
pub const RpcProgramAccountsConfig = struct {
    encoding: ?UiAccountEncoding = null,
    filters: ?[]const RpcProgramAccountsFilter = null,
    commitment: ?[]const u8 = null,
    min_context_slot: ?u64 = null,
    with_context: ?bool = null,
};

/// Keyed account from program subscription
pub const RpcKeyedAccount = struct {
    pubkey: []const u8,
    account: UiAccount,
};

// ============================================================================
// Block Subscription Types
// ============================================================================

/// Filter for block subscription
pub const RpcBlockSubscribeFilter = union(enum) {
    all,
    mentions_account_or_program: []const u8,
};

/// Configuration for block subscription
pub const RpcBlockSubscribeConfig = struct {
    commitment: ?[]const u8 = null,
    encoding: ?[]const u8 = null,
    transaction_details: ?[]const u8 = null,
    show_rewards: ?bool = null,
    max_supported_transaction_version: ?u8 = null,
};

/// Block update from blockSubscribe
pub const RpcBlockUpdate = struct {
    slot: u64,
    block: ?BlockData = null,
    err: ?std.json.Value = null,

    pub const BlockData = struct {
        blockhash: []const u8,
        previous_blockhash: []const u8,
        parent_slot: u64,
        transactions: ?[]const std.json.Value = null,
        rewards: ?[]const std.json.Value = null,
        block_time: ?i64 = null,
        block_height: ?u64 = null,
    };
};

// ============================================================================
// Vote Subscription Types
// ============================================================================

/// Vote from voteSubscribe
pub const RpcVote = struct {
    vote_pubkey: []const u8,
    slots: []const u64,
    hash: []const u8,
    timestamp: ?i64 = null,
    signature: []const u8,
};

// ============================================================================
// Subscription Management
// ============================================================================

/// Unique identifier for a subscription
pub const SubscriptionId = u64;

/// Result of a subscription request
pub const SubscriptionResult = struct {
    id: SubscriptionId,
};

/// Notification wrapper for all subscription types
pub const SubscriptionNotification = struct {
    jsonrpc: []const u8,
    method: []const u8,
    params: NotificationParams,

    pub const NotificationParams = struct {
        subscription: SubscriptionId,
        result: std.json.Value,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "SlotInfo parsing" {
    const json_str =
        \\{"slot": 100, "parent": 99, "root": 98}
    ;
    const parsed = try std.json.parseFromSlice(SlotInfo, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u64, 100), parsed.value.slot);
    try std.testing.expectEqual(@as(u64, 99), parsed.value.parent);
    try std.testing.expectEqual(@as(u64, 98), parsed.value.root);
}

test "RpcResponseContext parsing" {
    const json_str =
        \\{"slot": 12345, "apiVersion": "1.17.0"}
    ;
    const parsed = try std.json.parseFromSlice(RpcResponseContext, std.testing.allocator, json_str, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u64, 12345), parsed.value.slot);
}

test "UiAccountEncoding toString" {
    try std.testing.expectEqualStrings("base58", UiAccountEncoding.base58.toString());
    try std.testing.expectEqualStrings("base64", UiAccountEncoding.base64.toString());
    try std.testing.expectEqualStrings("base64+zstd", UiAccountEncoding.@"base64+zstd".toString());
    try std.testing.expectEqualStrings("jsonParsed", UiAccountEncoding.jsonParsed.toString());
}

test "RpcSignatureResult parsing" {
    const json_str =
        \\{"err": null}
    ;
    const parsed = try std.json.parseFromSlice(RpcSignatureResult, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    try std.testing.expect(parsed.value.err == null);
}

test "RpcLogsResponse parsing" {
    const json_str =
        \\{"signature": "abc123", "err": null, "logs": ["log1", "log2"]}
    ;
    const parsed = try std.json.parseFromSlice(RpcLogsResponse, std.testing.allocator, json_str, .{
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("abc123", parsed.value.signature);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.logs.len);
}
