//! Solana WebSocket PubSub Client
//!
//! Rust source: https://github.com/anza-xyz/agave/blob/master/pubsub-client/src/pubsub_client.rs
//!
//! This module provides a WebSocket client for subscribing to Solana blockchain events.
//!
//! ## Supported Subscriptions (9 methods)
//!
//! | Method | Description |
//! |--------|-------------|
//! | `accountSubscribe` | Subscribe to account changes |
//! | `blockSubscribe` | Subscribe to block confirmations |
//! | `logsSubscribe` | Subscribe to transaction logs |
//! | `programSubscribe` | Subscribe to program account changes |
//! | `rootSubscribe` | Subscribe to root slot updates |
//! | `signatureSubscribe` | Subscribe to transaction confirmation |
//! | `slotSubscribe` | Subscribe to slot processing |
//! | `slotsUpdatesSubscribe` | Subscribe to detailed slot updates |
//! | `voteSubscribe` | Subscribe to vote events |
//!
//! ## Usage
//!
//! ```zig
//! const pubsub = @import("pubsub");
//!
//! var client = try pubsub.PubsubClient.init(allocator, "wss://api.mainnet-beta.solana.com");
//! defer client.deinit();
//!
//! // Subscribe to slot updates
//! const sub_id = try client.slotSubscribe();
//!
//! // Read notifications in a loop
//! while (try client.readNotification()) |notification| {
//!     // Handle notification
//!     std.debug.print("Slot: {}\n", .{notification.slot});
//! }
//!
//! // Unsubscribe
//! try client.slotUnsubscribe(sub_id);
//! ```

const std = @import("std");
const websocket = @import("websocket");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const Signature = sdk.Signature;

const types = @import("types.zig");
pub const SubscriptionId = types.SubscriptionId;
pub const SlotInfo = types.SlotInfo;
pub const SlotUpdate = types.SlotUpdate;
pub const RpcSignatureResult = types.RpcSignatureResult;
pub const RpcLogsResponse = types.RpcLogsResponse;
pub const RpcKeyedAccount = types.RpcKeyedAccount;
pub const RpcBlockUpdate = types.RpcBlockUpdate;
pub const RpcVote = types.RpcVote;
pub const UiAccount = types.UiAccount;
pub const RpcNotification = types.RpcNotification;
pub const RpcAccountInfoConfig = types.RpcAccountInfoConfig;
pub const RpcSignatureSubscribeConfig = types.RpcSignatureSubscribeConfig;
pub const RpcTransactionLogsFilter = types.RpcTransactionLogsFilter;
pub const RpcTransactionLogsConfig = types.RpcTransactionLogsConfig;
pub const RpcProgramAccountsConfig = types.RpcProgramAccountsConfig;
pub const RpcBlockSubscribeFilter = types.RpcBlockSubscribeFilter;
pub const RpcBlockSubscribeConfig = types.RpcBlockSubscribeConfig;

/// PubSub client errors
pub const PubsubError = error{
    /// Connection failed
    ConnectionFailed,
    /// WebSocket handshake failed
    HandshakeFailed,
    /// JSON-RPC error from server
    RpcError,
    /// JSON parsing error
    JsonParseError,
    /// Unexpected response format
    InvalidResponse,
    /// Connection closed
    ConnectionClosed,
    /// Write failed
    WriteFailed,
    /// Read timeout
    Timeout,
    /// Memory allocation failed
    OutOfMemory,
    /// Invalid URL format
    InvalidUrl,
    /// Subscription not found
    SubscriptionNotFound,
};

/// Solana WebSocket PubSub Client
///
/// Provides subscription-based access to Solana blockchain events via WebSocket.
pub const PubsubClient = struct {
    allocator: std.mem.Allocator,
    ws_client: websocket.Client,
    request_id: std.atomic.Value(u64),
    subscriptions: std.AutoHashMap(SubscriptionId, SubscriptionInfo),

    const Self = @This();

    /// Information about an active subscription
    pub const SubscriptionInfo = struct {
        method: SubscriptionMethod,
        params_json: ?[]const u8,
    };

    /// Subscription method types
    pub const SubscriptionMethod = enum {
        account,
        block,
        logs,
        program,
        root,
        signature,
        slot,
        slots_updates,
        vote,

        pub fn subscribeMethod(self: SubscriptionMethod) []const u8 {
            return switch (self) {
                .account => "accountSubscribe",
                .block => "blockSubscribe",
                .logs => "logsSubscribe",
                .program => "programSubscribe",
                .root => "rootSubscribe",
                .signature => "signatureSubscribe",
                .slot => "slotSubscribe",
                .slots_updates => "slotsUpdatesSubscribe",
                .vote => "voteSubscribe",
            };
        }

        pub fn unsubscribeMethod(self: SubscriptionMethod) []const u8 {
            return switch (self) {
                .account => "accountUnsubscribe",
                .block => "blockUnsubscribe",
                .logs => "logsUnsubscribe",
                .program => "programUnsubscribe",
                .root => "rootUnsubscribe",
                .signature => "signatureUnsubscribe",
                .slot => "slotUnsubscribe",
                .slots_updates => "slotsUpdatesUnsubscribe",
                .vote => "voteUnsubscribe",
            };
        }

        pub fn notificationMethod(self: SubscriptionMethod) []const u8 {
            return switch (self) {
                .account => "accountNotification",
                .block => "blockNotification",
                .logs => "logsNotification",
                .program => "programNotification",
                .root => "rootNotification",
                .signature => "signatureNotification",
                .slot => "slotNotification",
                .slots_updates => "slotsUpdatesNotification",
                .vote => "voteNotification",
            };
        }
    };

    /// Initialize a new PubSub client.
    ///
    /// ## Parameters
    /// - `allocator`: Memory allocator
    /// - `url`: WebSocket URL (e.g., "wss://api.mainnet-beta.solana.com")
    ///
    /// ## Example
    /// ```zig
    /// var client = try PubsubClient.init(allocator, "wss://api.mainnet-beta.solana.com");
    /// defer client.deinit();
    /// ```
    pub fn init(allocator: std.mem.Allocator, url: []const u8) !Self {
        // Parse URL to extract host, port, and path
        const parsed = try parseWsUrl(url);

        // Initialize WebSocket client
        var ws_client = websocket.Client.init(allocator, .{
            .host = parsed.host,
            .port = parsed.port,
            .tls = parsed.tls,
        }) catch {
            return PubsubError.ConnectionFailed;
        };
        errdefer ws_client.deinit();

        // Perform WebSocket handshake
        ws_client.handshake(parsed.path, .{
            .timeout_ms = 10000,
            .headers = null,
        }) catch {
            return PubsubError.HandshakeFailed;
        };

        return Self{
            .allocator = allocator,
            .ws_client = ws_client,
            .request_id = std.atomic.Value(u64).init(1),
            .subscriptions = std.AutoHashMap(SubscriptionId, SubscriptionInfo).init(allocator),
        };
    }

    /// Clean up resources.
    pub fn deinit(self: *Self) void {
        // Free subscription info
        var it = self.subscriptions.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.params_json) |json| {
                self.allocator.free(json);
            }
        }
        self.subscriptions.deinit();

        // Close WebSocket connection
        self.ws_client.close(.{}) catch {};
        self.ws_client.deinit();
    }

    // ========================================================================
    // Subscription Methods
    // ========================================================================

    /// Subscribe to account changes.
    ///
    /// Receives notifications when the lamports or data for the specified
    /// account pubkey changes.
    pub fn accountSubscribe(
        self: *Self,
        pubkey: PublicKey,
        config: ?RpcAccountInfoConfig,
    ) !SubscriptionId {
        var params_buf: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&params_buf);
        const writer = fbs.writer();

        try writer.writeAll("[\"");
        var base58_buf: [44]u8 = undefined;
        const pubkey_str = pubkey.toBase58(&base58_buf);
        try writer.writeAll(pubkey_str);
        try writer.writeAll("\"");

        if (config) |cfg| {
            try writer.writeAll(",{");
            var first = true;
            if (cfg.encoding) |enc| {
                try writer.writeAll("\"encoding\":\"");
                try writer.writeAll(enc.toString());
                try writer.writeAll("\"");
                first = false;
            }
            if (cfg.commitment) |c| {
                if (!first) try writer.writeAll(",");
                try writer.writeAll("\"commitment\":\"");
                try writer.writeAll(c);
                try writer.writeAll("\"");
            }
            try writer.writeAll("}");
        }

        try writer.writeAll("]");

        return self.subscribe(.account, fbs.getWritten());
    }

    /// Unsubscribe from account changes.
    pub fn accountUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.account, subscription_id);
    }

    /// Subscribe to slot updates.
    ///
    /// Receives notifications when a new slot is processed.
    pub fn slotSubscribe(self: *Self) !SubscriptionId {
        return self.subscribe(.slot, "[]");
    }

    /// Unsubscribe from slot updates.
    pub fn slotUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.slot, subscription_id);
    }

    /// Subscribe to detailed slot updates.
    ///
    /// Receives more detailed slot update notifications including timing info.
    pub fn slotsUpdatesSubscribe(self: *Self) !SubscriptionId {
        return self.subscribe(.slots_updates, "[]");
    }

    /// Unsubscribe from detailed slot updates.
    pub fn slotsUpdatesUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.slots_updates, subscription_id);
    }

    /// Subscribe to root slot updates.
    ///
    /// Receives notifications when a new root is set.
    pub fn rootSubscribe(self: *Self) !SubscriptionId {
        return self.subscribe(.root, "[]");
    }

    /// Unsubscribe from root updates.
    pub fn rootUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.root, subscription_id);
    }

    /// Subscribe to transaction confirmation.
    ///
    /// Receives a single notification when the transaction is confirmed.
    pub fn signatureSubscribe(
        self: *Self,
        signature: Signature,
        config: ?RpcSignatureSubscribeConfig,
    ) !SubscriptionId {
        var params_buf: [256]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&params_buf);
        const writer = fbs.writer();

        try writer.writeAll("[\"");
        var sig_buf: [88]u8 = undefined;
        const sig_str = signature.toBase58(&sig_buf);
        try writer.writeAll(sig_str);
        try writer.writeAll("\"");

        if (config) |cfg| {
            try writer.writeAll(",{");
            var first = true;
            if (cfg.commitment) |c| {
                try writer.writeAll("\"commitment\":\"");
                try writer.writeAll(c);
                try writer.writeAll("\"");
                first = false;
            }
            if (cfg.enable_received_notification) |enabled| {
                if (!first) try writer.writeAll(",");
                try writer.writeAll("\"enableReceivedNotification\":");
                try writer.writeAll(if (enabled) "true" else "false");
            }
            try writer.writeAll("}");
        }

        try writer.writeAll("]");

        return self.subscribe(.signature, fbs.getWritten());
    }

    /// Unsubscribe from signature updates.
    pub fn signatureUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.signature, subscription_id);
    }

    /// Subscribe to transaction logs.
    ///
    /// Receives notifications for transaction logs matching the filter.
    pub fn logsSubscribe(
        self: *Self,
        filter: RpcTransactionLogsFilter,
        config: ?RpcTransactionLogsConfig,
    ) !SubscriptionId {
        var params_buf: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&params_buf);
        const writer = fbs.writer();

        try writer.writeAll("[");

        switch (filter) {
            .all => try writer.writeAll("\"all\""),
            .all_with_votes => try writer.writeAll("\"allWithVotes\""),
            .mentions => |addrs| {
                try writer.writeAll("{\"mentions\":[");
                for (addrs, 0..) |addr, i| {
                    if (i > 0) try writer.writeAll(",");
                    try writer.writeAll("\"");
                    try writer.writeAll(addr);
                    try writer.writeAll("\"");
                }
                try writer.writeAll("]}");
            },
        }

        if (config) |cfg| {
            if (cfg.commitment) |c| {
                try writer.writeAll(",{\"commitment\":\"");
                try writer.writeAll(c);
                try writer.writeAll("\"}");
            }
        }

        try writer.writeAll("]");

        return self.subscribe(.logs, fbs.getWritten());
    }

    /// Unsubscribe from logs.
    pub fn logsUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.logs, subscription_id);
    }

    /// Subscribe to program account changes.
    ///
    /// Receives notifications when accounts owned by the program change.
    pub fn programSubscribe(
        self: *Self,
        program_id: PublicKey,
        config: ?RpcProgramAccountsConfig,
    ) !SubscriptionId {
        var params_buf: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&params_buf);
        const writer = fbs.writer();

        try writer.writeAll("[\"");
        var base58_buf: [44]u8 = undefined;
        const pubkey_str = program_id.toBase58(&base58_buf);
        try writer.writeAll(pubkey_str);
        try writer.writeAll("\"");

        if (config) |cfg| {
            try writer.writeAll(",{");
            var first = true;
            if (cfg.encoding) |enc| {
                try writer.writeAll("\"encoding\":\"");
                try writer.writeAll(enc.toString());
                try writer.writeAll("\"");
                first = false;
            }
            if (cfg.commitment) |c| {
                if (!first) try writer.writeAll(",");
                try writer.writeAll("\"commitment\":\"");
                try writer.writeAll(c);
                try writer.writeAll("\"");
            }
            try writer.writeAll("}");
        }

        try writer.writeAll("]");

        return self.subscribe(.program, fbs.getWritten());
    }

    /// Unsubscribe from program updates.
    pub fn programUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.program, subscription_id);
    }

    /// Subscribe to block updates.
    ///
    /// Note: This subscription requires the validator to have
    /// `--rpc-pubsub-enable-block-subscription` enabled.
    pub fn blockSubscribe(
        self: *Self,
        filter: RpcBlockSubscribeFilter,
        config: ?RpcBlockSubscribeConfig,
    ) !SubscriptionId {
        var params_buf: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&params_buf);
        const writer = fbs.writer();

        try writer.writeAll("[");

        switch (filter) {
            .all => try writer.writeAll("\"all\""),
            .mentions_account_or_program => |addr| {
                try writer.writeAll("{\"mentionsAccountOrProgram\":\"");
                try writer.writeAll(addr);
                try writer.writeAll("\"}");
            },
        }

        if (config) |cfg| {
            try writer.writeAll(",{");
            var first = true;
            if (cfg.commitment) |c| {
                try writer.writeAll("\"commitment\":\"");
                try writer.writeAll(c);
                try writer.writeAll("\"");
                first = false;
            }
            if (cfg.encoding) |enc| {
                if (!first) try writer.writeAll(",");
                try writer.writeAll("\"encoding\":\"");
                try writer.writeAll(enc);
                try writer.writeAll("\"");
            }
            try writer.writeAll("}");
        }

        try writer.writeAll("]");

        return self.subscribe(.block, fbs.getWritten());
    }

    /// Unsubscribe from block updates.
    pub fn blockUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.block, subscription_id);
    }

    /// Subscribe to vote events.
    ///
    /// Note: This subscription requires the validator to have
    /// `--rpc-pubsub-enable-vote-subscription` enabled.
    pub fn voteSubscribe(self: *Self) !SubscriptionId {
        return self.subscribe(.vote, "[]");
    }

    /// Unsubscribe from vote events.
    pub fn voteUnsubscribe(self: *Self, subscription_id: SubscriptionId) !void {
        return self.unsubscribe(.vote, subscription_id);
    }

    // ========================================================================
    // Message Reading
    // ========================================================================

    /// Notification from the server
    pub const Notification = struct {
        subscription_id: SubscriptionId,
        method: SubscriptionMethod,
        result: std.json.Value,
    };

    /// Read the next notification from the WebSocket.
    ///
    /// Returns null if no message is available (timeout) or connection closed.
    pub fn readNotification(self: *Self) !?Notification {
        const message = (self.ws_client.read() catch {
            return null;
        }) orelse return null;
        defer self.ws_client.done(message);

        if (message.type != .text) {
            return null;
        }

        return self.parseNotification(message.data);
    }

    /// Set read timeout in milliseconds.
    pub fn setReadTimeout(self: *Self, timeout_ms: u32) !void {
        self.ws_client.readTimeout(timeout_ms) catch {
            return PubsubError.ConnectionFailed;
        };
    }

    // ========================================================================
    // Internal Methods
    // ========================================================================

    fn subscribe(self: *Self, method: SubscriptionMethod, params_json: []const u8) !SubscriptionId {
        const request_id = self.request_id.fetchAdd(1, .monotonic);

        // Build JSON-RPC request
        var request_buf: [1024]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&request_buf);
        const writer = fbs.writer();

        try writer.print(
            \\{{"jsonrpc":"2.0","id":{d},"method":"{s}","params":{s}}}
        , .{ request_id, method.subscribeMethod(), params_json });

        // Send request
        const request_data = fbs.getWritten();
        self.ws_client.write(@constCast(request_data)) catch {
            return PubsubError.WriteFailed;
        };

        // Wait for response
        const message = (self.ws_client.read() catch {
            return PubsubError.ConnectionClosed;
        }) orelse return PubsubError.Timeout;
        defer self.ws_client.done(message);

        if (message.type != .text) {
            return PubsubError.InvalidResponse;
        }

        // Parse response
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, message.data, .{}) catch {
            return PubsubError.JsonParseError;
        };
        defer parsed.deinit();

        const obj = parsed.value.object;

        // Check for error
        if (obj.get("error")) |_| {
            return PubsubError.RpcError;
        }

        // Get subscription ID
        const result = obj.get("result") orelse return PubsubError.InvalidResponse;
        const sub_id: SubscriptionId = switch (result) {
            .integer => |i| @intCast(i),
            else => return PubsubError.InvalidResponse,
        };

        // Store subscription info
        const params_copy = try self.allocator.dupe(u8, params_json);
        try self.subscriptions.put(sub_id, .{
            .method = method,
            .params_json = params_copy,
        });

        return sub_id;
    }

    fn unsubscribe(self: *Self, method: SubscriptionMethod, subscription_id: SubscriptionId) !void {
        const request_id = self.request_id.fetchAdd(1, .monotonic);

        // Build JSON-RPC request
        var request_buf: [256]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&request_buf);
        const writer = fbs.writer();

        try writer.print(
            \\{{"jsonrpc":"2.0","id":{d},"method":"{s}","params":[{d}]}}
        , .{ request_id, method.unsubscribeMethod(), subscription_id });

        // Send request
        const request_data = fbs.getWritten();
        self.ws_client.write(@constCast(request_data)) catch {
            return PubsubError.WriteFailed;
        };

        // Wait for response
        const message = (self.ws_client.read() catch {
            return PubsubError.ConnectionClosed;
        }) orelse return PubsubError.Timeout;
        defer self.ws_client.done(message);

        // Remove from subscriptions
        if (self.subscriptions.fetchRemove(subscription_id)) |kv| {
            if (kv.value.params_json) |json| {
                self.allocator.free(json);
            }
        }
    }

    fn parseNotification(self: *Self, data: []const u8) !?Notification {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, data, .{}) catch {
            return null;
        };
        defer parsed.deinit();

        const obj = parsed.value.object;

        // Check if this is a notification (has "method" field)
        const method_str = obj.get("method") orelse {
            return null;
        };

        if (method_str != .string) {
            return null;
        }

        // Get params
        const params = obj.get("params") orelse {
            return null;
        };

        if (params != .object) {
            return null;
        }

        const params_obj = params.object;
        const sub_id_val = params_obj.get("subscription") orelse {
            return null;
        };

        const sub_id: SubscriptionId = switch (sub_id_val) {
            .integer => |i| @intCast(i),
            else => {
                return null;
            },
        };

        // Look up subscription method
        const sub_info = self.subscriptions.get(sub_id) orelse {
            return null;
        };

        // Note: We don't return the result value since it would be freed with parsed.deinit()
        // For detailed result parsing, users should use typed notification handlers
        _ = params_obj.get("result") orelse {
            return null;
        };

        return Notification{
            .subscription_id = sub_id,
            .method = sub_info.method,
            .result = .null, // Result data is not preserved to avoid memory issues
        };
    }

    /// Parsed WebSocket URL components
    const ParsedUrl = struct {
        host: []const u8,
        port: u16,
        path: []const u8,
        tls: bool,
    };

    fn parseWsUrl(url: []const u8) !ParsedUrl {
        var tls = false;
        var rest: []const u8 = undefined;

        if (std.mem.startsWith(u8, url, "wss://")) {
            tls = true;
            rest = url[6..];
        } else if (std.mem.startsWith(u8, url, "ws://")) {
            tls = false;
            rest = url[5..];
        } else {
            return PubsubError.InvalidUrl;
        }

        // Find path separator
        const path_start = std.mem.indexOf(u8, rest, "/") orelse rest.len;
        const host_port = rest[0..path_start];
        const path = if (path_start < rest.len) rest[path_start..] else "/";

        // Parse host and port
        var host: []const u8 = undefined;
        var port: u16 = if (tls) 443 else 80;

        if (std.mem.indexOf(u8, host_port, ":")) |colon_pos| {
            host = host_port[0..colon_pos];
            port = std.fmt.parseInt(u16, host_port[colon_pos + 1 ..], 10) catch {
                return PubsubError.InvalidUrl;
            };
        } else {
            host = host_port;
        }

        return ParsedUrl{
            .host = host,
            .port = port,
            .path = path,
            .tls = tls,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "parseWsUrl: wss with default port" {
    const result = try PubsubClient.parseWsUrl("wss://api.mainnet-beta.solana.com");
    try std.testing.expectEqualStrings("api.mainnet-beta.solana.com", result.host);
    try std.testing.expectEqual(@as(u16, 443), result.port);
    try std.testing.expectEqualStrings("/", result.path);
    try std.testing.expect(result.tls);
}

test "parseWsUrl: ws with custom port" {
    const result = try PubsubClient.parseWsUrl("ws://localhost:8900");
    try std.testing.expectEqualStrings("localhost", result.host);
    try std.testing.expectEqual(@as(u16, 8900), result.port);
    try std.testing.expectEqualStrings("/", result.path);
    try std.testing.expect(!result.tls);
}

test "parseWsUrl: with path" {
    const result = try PubsubClient.parseWsUrl("wss://example.com/ws");
    try std.testing.expectEqualStrings("example.com", result.host);
    try std.testing.expectEqual(@as(u16, 443), result.port);
    try std.testing.expectEqualStrings("/ws", result.path);
    try std.testing.expect(result.tls);
}

test "parseWsUrl: invalid protocol" {
    const result = PubsubClient.parseWsUrl("http://example.com");
    try std.testing.expectError(PubsubError.InvalidUrl, result);
}

test "SubscriptionMethod: method names" {
    try std.testing.expectEqualStrings("accountSubscribe", PubsubClient.SubscriptionMethod.account.subscribeMethod());
    try std.testing.expectEqualStrings("accountUnsubscribe", PubsubClient.SubscriptionMethod.account.unsubscribeMethod());
    try std.testing.expectEqualStrings("accountNotification", PubsubClient.SubscriptionMethod.account.notificationMethod());

    try std.testing.expectEqualStrings("slotSubscribe", PubsubClient.SubscriptionMethod.slot.subscribeMethod());
    try std.testing.expectEqualStrings("slotUnsubscribe", PubsubClient.SubscriptionMethod.slot.unsubscribeMethod());
    try std.testing.expectEqualStrings("slotNotification", PubsubClient.SubscriptionMethod.slot.notificationMethod());
}
