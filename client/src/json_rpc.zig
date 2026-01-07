//! JSON-RPC 2.0 Client Implementation
//!
//! Rust source: https://github.com/anza-xyz/agave/blob/master/rpc-client/src/http_sender.rs
//!
//! This module provides a JSON-RPC 2.0 client for communicating with Solana RPC nodes.
//! It handles request serialization, response parsing, and error handling.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ClientError = @import("error.zig").ClientError;
const RpcError = @import("error.zig").RpcError;

/// JSON-RPC 2.0 request structure
pub const JsonRpcRequest = struct {
    jsonrpc: []const u8 = "2.0",
    id: u64,
    method: []const u8,
    params: ?std.json.Value = null,
};

/// JSON-RPC 2.0 response structure
pub const JsonRpcResponse = struct {
    jsonrpc: []const u8,
    id: u64,
    result: ?std.json.Value = null,
    @"error": ?JsonRpcError = null,
};

/// JSON-RPC 2.0 error structure
pub const JsonRpcError = struct {
    code: i64,
    message: []const u8,
    data: ?std.json.Value = null,

    /// Convert to RpcError
    pub fn toRpcError(self: JsonRpcError) RpcError {
        return .{
            .code = self.code,
            .message = self.message,
            .data = self.data,
        };
    }
};

/// JSON-RPC client for HTTP transport
pub const JsonRpcClient = struct {
    allocator: Allocator,
    endpoint: []const u8,
    request_id: std.atomic.Value(u64),
    timeout_ms: u32,

    /// Default timeout in milliseconds (30 seconds)
    pub const DEFAULT_TIMEOUT_MS: u32 = 30_000;

    /// Maximum retry attempts for rate limiting
    pub const MAX_RETRIES: u32 = 5;

    /// Initialize a new JSON-RPC client
    pub fn init(allocator: Allocator, endpoint: []const u8) JsonRpcClient {
        return .{
            .allocator = allocator,
            .endpoint = endpoint,
            .request_id = std.atomic.Value(u64).init(1),
            .timeout_ms = DEFAULT_TIMEOUT_MS,
        };
    }

    /// Initialize with custom timeout
    pub fn initWithTimeout(allocator: Allocator, endpoint: []const u8, timeout_ms: u32) JsonRpcClient {
        return .{
            .allocator = allocator,
            .endpoint = endpoint,
            .request_id = std.atomic.Value(u64).init(1),
            .timeout_ms = timeout_ms,
        };
    }

    /// Get the next request ID
    pub fn nextRequestId(self: *JsonRpcClient) u64 {
        return self.request_id.fetchAdd(1, .monotonic);
    }

    /// Build a JSON-RPC request body
    pub fn buildRequestBody(
        self: *JsonRpcClient,
        allocator: Allocator,
        method: []const u8,
        params: ?std.json.Value,
    ) ![]u8 {
        const request_id = self.nextRequestId();

        // Build JSON manually for Zig 0.15 compatibility
        var result = try std.ArrayList(u8).initCapacity(allocator, 256);
        errdefer result.deinit(allocator);

        try result.appendSlice(allocator, "{\"jsonrpc\":\"2.0\",\"id\":");

        // Write request ID
        var id_buf: [32]u8 = undefined;
        const id_str = std.fmt.bufPrint(&id_buf, "{d}", .{request_id}) catch unreachable;
        try result.appendSlice(allocator, id_str);

        try result.appendSlice(allocator, ",\"method\":\"");
        try result.appendSlice(allocator, method);
        try result.appendSlice(allocator, "\"");

        if (params) |p| {
            try result.appendSlice(allocator, ",\"params\":");
            try writeJsonValue(allocator, &result, p);
        }

        try result.appendSlice(allocator, "}");

        return result.toOwnedSlice(allocator);
    }

    /// Write a JSON value to an ArrayList
    fn writeJsonValue(allocator: Allocator, list: *std.ArrayList(u8), value: std.json.Value) !void {
        switch (value) {
            .null => try list.appendSlice(allocator, "null"),
            .bool => |b| try list.appendSlice(allocator, if (b) "true" else "false"),
            .integer => |i| {
                var buf: [32]u8 = undefined;
                const s = std.fmt.bufPrint(&buf, "{d}", .{i}) catch unreachable;
                try list.appendSlice(allocator, s);
            },
            .float => |f| {
                var buf: [64]u8 = undefined;
                const s = std.fmt.bufPrint(&buf, "{d}", .{f}) catch unreachable;
                try list.appendSlice(allocator, s);
            },
            .number_string => |s| try list.appendSlice(allocator, s),
            .string => |s| {
                try list.append(allocator, '"');
                for (s) |c| {
                    switch (c) {
                        '"' => try list.appendSlice(allocator, "\\\""),
                        '\\' => try list.appendSlice(allocator, "\\\\"),
                        '\n' => try list.appendSlice(allocator, "\\n"),
                        '\r' => try list.appendSlice(allocator, "\\r"),
                        '\t' => try list.appendSlice(allocator, "\\t"),
                        else => try list.append(allocator, c),
                    }
                }
                try list.append(allocator, '"');
            },
            .array => |arr| {
                try list.append(allocator, '[');
                for (arr.items, 0..) |item, i| {
                    if (i > 0) try list.append(allocator, ',');
                    try writeJsonValue(allocator, list, item);
                }
                try list.append(allocator, ']');
            },
            .object => |obj| {
                try list.append(allocator, '{');
                var first = true;
                var it = obj.iterator();
                while (it.next()) |entry| {
                    if (!first) try list.append(allocator, ',');
                    first = false;
                    try list.append(allocator, '"');
                    try list.appendSlice(allocator, entry.key_ptr.*);
                    try list.appendSlice(allocator, "\":");
                    try writeJsonValue(allocator, list, entry.value_ptr.*);
                }
                try list.append(allocator, '}');
            },
        }
    }

    /// Send a JSON-RPC request and return the parsed response
    pub fn call(
        self: *JsonRpcClient,
        allocator: Allocator,
        method: []const u8,
        params: ?std.json.Value,
    ) !std.json.Value {
        // Build request body
        const body = try self.buildRequestBody(allocator, method, params);
        defer allocator.free(body);

        // Send HTTP request
        const response_body = try self.sendHttpRequest(allocator, body);
        defer allocator.free(response_body);

        // Parse response
        const parsed = std.json.parseFromSlice(JsonRpcResponse, allocator, response_body, .{
            .ignore_unknown_fields = true,
        }) catch {
            return ClientError.JsonParseError;
        };
        defer parsed.deinit();

        const response = parsed.value;

        // Check for error
        if (response.@"error") |_| {
            return ClientError.RpcError;
        }

        // Return result
        if (response.result) |result| {
            // Clone the result since parsed will be freed
            return try cloneJsonValue(allocator, result);
        }

        return ClientError.InvalidResponse;
    }

    /// Send HTTP POST request using Zig 0.15 request/response API
    fn sendHttpRequest(self: *JsonRpcClient, allocator: Allocator, body: []const u8) ![]u8 {
        var client = std.http.Client{ .allocator = allocator };
        defer client.deinit();

        // Parse the URI
        const uri = std.Uri.parse(self.endpoint) catch return ClientError.InvalidResponse;

        // Create the request
        var req = client.request(.POST, uri, .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
            },
        }) catch return ClientError.ConnectionFailed;
        defer req.deinit();

        // Allocate buffer for body writing
        var body_buffer: [8192]u8 = undefined;

        // Copy body to mutable buffer
        var mutable_body: []u8 = undefined;
        if (body.len <= body_buffer.len) {
            @memcpy(body_buffer[0..body.len], body);
            mutable_body = body_buffer[0..body.len];
        } else {
            // For larger bodies, allocate
            const alloc_body = allocator.alloc(u8, body.len) catch return ClientError.ConnectionFailed;
            defer allocator.free(alloc_body);
            @memcpy(alloc_body, body);
            mutable_body = alloc_body;
        }

        // Send the request with body
        req.sendBodyComplete(mutable_body) catch return ClientError.ConnectionFailed;

        // Receive response head
        var redirect_buf: [4096]u8 = undefined;
        var response = req.receiveHead(&redirect_buf) catch return ClientError.ConnectionFailed;

        // Check status
        const status = @intFromEnum(response.head.status);
        if (status < 200 or status >= 300) {
            if (status == 429) {
                return ClientError.RateLimited;
            }
            return ClientError.UnexpectedStatus;
        }

        // Read the response body
        var body_reader = response.reader(&redirect_buf);
        const response_body = body_reader.allocRemaining(allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return ClientError.InvalidResponse;

        return response_body;
    }
};

/// Clone a JSON value (deep copy)
fn cloneJsonValue(allocator: Allocator, value: std.json.Value) !std.json.Value {
    return switch (value) {
        .null => .null,
        .bool => |b| .{ .bool = b },
        .integer => |i| .{ .integer = i },
        .float => |f| .{ .float = f },
        .number_string => |s| .{ .number_string = try allocator.dupe(u8, s) },
        .string => |s| .{ .string = try allocator.dupe(u8, s) },
        .array => |arr| blk: {
            var new_arr = std.json.Array.init(allocator);
            try new_arr.ensureTotalCapacity(arr.items.len);
            for (arr.items) |item| {
                new_arr.appendAssumeCapacity(try cloneJsonValue(allocator, item));
            }
            break :blk .{ .array = new_arr };
        },
        .object => |obj| blk: {
            var new_obj = std.json.ObjectMap.init(allocator);
            var it = obj.iterator();
            while (it.next()) |entry| {
                const key = try allocator.dupe(u8, entry.key_ptr.*);
                const val = try cloneJsonValue(allocator, entry.value_ptr.*);
                try new_obj.put(key, val);
            }
            break :blk .{ .object = new_obj };
        },
    };
}

/// Helper to create JSON array from values
pub fn jsonArray(allocator: Allocator, items: []const std.json.Value) !std.json.Value {
    var arr = std.json.Array.init(allocator);
    try arr.ensureTotalCapacity(items.len);
    for (items) |item| {
        arr.appendAssumeCapacity(item);
    }
    return .{ .array = arr };
}

/// Helper to create JSON object
pub fn jsonObject(allocator: Allocator) std.json.ObjectMap {
    return std.json.ObjectMap.init(allocator);
}

/// Helper to create JSON string
pub fn jsonString(s: []const u8) std.json.Value {
    return .{ .string = s };
}

/// Helper to create JSON integer
pub fn jsonInt(i: i64) std.json.Value {
    return .{ .integer = i };
}

/// Helper to create JSON bool
pub fn jsonBool(b: bool) std.json.Value {
    return .{ .bool = b };
}

// ============================================================================
// Tests
// ============================================================================

test "json_rpc: JsonRpcClient init" {
    const allocator = std.testing.allocator;
    const client = JsonRpcClient.init(allocator, "http://localhost:8899");

    try std.testing.expectEqualStrings("http://localhost:8899", client.endpoint);
    try std.testing.expectEqual(@as(u32, 30_000), client.timeout_ms);
}

test "json_rpc: nextRequestId increments" {
    const allocator = std.testing.allocator;
    var client = JsonRpcClient.init(allocator, "http://localhost:8899");

    const id1 = client.nextRequestId();
    const id2 = client.nextRequestId();
    const id3 = client.nextRequestId();

    try std.testing.expectEqual(@as(u64, 1), id1);
    try std.testing.expectEqual(@as(u64, 2), id2);
    try std.testing.expectEqual(@as(u64, 3), id3);
}

test "json_rpc: buildRequestBody" {
    const allocator = std.testing.allocator;
    var client = JsonRpcClient.init(allocator, "http://localhost:8899");

    const body = try client.buildRequestBody(allocator, "getBalance", null);
    defer allocator.free(body);

    // Verify it's valid JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqualStrings("2.0", obj.get("jsonrpc").?.string);
    try std.testing.expectEqualStrings("getBalance", obj.get("method").?.string);
}

test "json_rpc: buildRequestBody with params" {
    const allocator = std.testing.allocator;
    var client = JsonRpcClient.init(allocator, "http://localhost:8899");

    // Create params array
    var params_arr = std.json.Array.init(allocator);
    defer params_arr.deinit();
    try params_arr.append(jsonString("test_pubkey"));

    const body = try client.buildRequestBody(allocator, "getBalance", .{ .array = params_arr });
    defer allocator.free(body);

    // Verify it contains params
    try std.testing.expect(std.mem.indexOf(u8, body, "\"params\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "test_pubkey") != null);
}

test "json_rpc: JsonRpcError toRpcError" {
    const err = JsonRpcError{
        .code = -32600,
        .message = "Invalid request",
        .data = null,
    };

    const rpc_err = err.toRpcError();
    try std.testing.expectEqual(@as(i64, -32600), rpc_err.code);
    try std.testing.expectEqualStrings("Invalid request", rpc_err.message);
}

test "json_rpc: helper functions" {
    try std.testing.expectEqual(@as(i64, 42), jsonInt(42).integer);
    try std.testing.expectEqualStrings("hello", jsonString("hello").string);
    try std.testing.expectEqual(true, jsonBool(true).bool);
}

test "json_rpc: cloneJsonValue simple" {
    const allocator = std.testing.allocator;

    // Test simple values
    const null_val = try cloneJsonValue(allocator, .null);
    try std.testing.expectEqual(std.json.Value.null, null_val);

    const bool_val = try cloneJsonValue(allocator, .{ .bool = true });
    try std.testing.expectEqual(true, bool_val.bool);

    const int_val = try cloneJsonValue(allocator, .{ .integer = 42 });
    try std.testing.expectEqual(@as(i64, 42), int_val.integer);

    // Test string (needs free)
    const str_val = try cloneJsonValue(allocator, .{ .string = "test" });
    defer allocator.free(str_val.string);
    try std.testing.expectEqualStrings("test", str_val.string);
}

test "json_rpc: writeJsonValue" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(u8).initCapacity(allocator, 64);
    defer list.deinit(allocator);

    // Test writing an object
    var obj = jsonObject(allocator);
    defer obj.deinit();
    try obj.put("key", jsonString("value"));
    try obj.put("num", jsonInt(42));

    try JsonRpcClient.writeJsonValue(allocator, &list, .{ .object = obj });

    const result = list.items;
    try std.testing.expect(std.mem.indexOf(u8, result, "\"key\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"value\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "42") != null);
}
