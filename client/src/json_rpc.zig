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

    /// Convert to RpcError (copies strings to ensure lifetime)
    pub fn toRpcError(self: JsonRpcError, allocator: Allocator) !RpcError {
        return .{
            .code = self.code,
            .message = try allocator.dupe(u8, self.message),
            .data = if (self.data) |d| try cloneJsonValue(allocator, d) else null,
        };
    }

    /// Convert to RpcError without allocation (caller must ensure lifetime)
    pub fn toRpcErrorUnmanaged(self: JsonRpcError) RpcError {
        return .{
            .code = self.code,
            .message = self.message,
            .data = self.data,
        };
    }
};

/// Result of a JSON-RPC call
///
/// This type allows returning either a successful result or detailed RPC error
/// information, similar to Rust's approach.
pub const CallResult = struct {
    allocator: Allocator,
    /// The successful result value (if no error)
    value: ?std.json.Value,
    /// RPC error details (if error occurred)
    rpc_error: ?RpcError,

    const Self = @This();

    /// Create a success result
    pub fn success(allocator: Allocator, value: std.json.Value) Self {
        return .{
            .allocator = allocator,
            .value = value,
            .rpc_error = null,
        };
    }

    /// Create an error result
    pub fn err(allocator: Allocator, rpc_error: RpcError) Self {
        return .{
            .allocator = allocator,
            .value = null,
            .rpc_error = rpc_error,
        };
    }

    /// Check if this is an error result
    pub fn isError(self: Self) bool {
        return self.rpc_error != null;
    }

    /// Check if this is a success result
    pub fn isSuccess(self: Self) bool {
        return self.value != null and self.rpc_error == null;
    }

    /// Get the value, returning ClientError.RpcError if this is an error result
    pub fn unwrap(self: Self) ClientError!std.json.Value {
        if (self.rpc_error != null) {
            return ClientError.RpcError;
        }
        return self.value orelse ClientError.InvalidResponse;
    }

    /// Get the RPC error code (if error)
    pub fn getErrorCode(self: Self) ?i64 {
        if (self.rpc_error) |e| {
            return e.code;
        }
        return null;
    }

    /// Check if this is a specific error code
    pub fn isErrorCode(self: Self, code: i64) bool {
        if (self.rpc_error) |e| {
            return e.code == code;
        }
        return false;
    }

    /// Free allocated resources
    pub fn deinit(self: *Self) void {
        if (self.value) |v| {
            freeJsonValue(self.allocator, v);
            self.value = null;
        }
        if (self.rpc_error) |e| {
            self.allocator.free(e.message);
            if (e.data) |d| {
                freeJsonValue(self.allocator, d);
            }
            self.rpc_error = null;
        }
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

    /// Send a JSON-RPC request and return the parsed response.
    ///
    /// This method returns only the result value. For access to RPC error details
    /// (code, message, data), use `callWithResult` instead.
    ///
    /// ## Errors
    /// - `ClientError.RpcError` if the RPC returns an error (use `callWithResult` for details)
    /// - `ClientError.JsonParseError` if response parsing fails
    /// - `ClientError.InvalidResponse` if response has no result
    pub fn call(
        self: *JsonRpcClient,
        allocator: Allocator,
        method: []const u8,
        params: ?std.json.Value,
    ) ClientError!std.json.Value {
        var result = try self.callWithResult(allocator, method, params);

        // If there's an RPC error, clean up and return error
        if (result.rpc_error != null) {
            result.deinit();
            return ClientError.RpcError;
        }

        // Return the value (caller owns it)
        if (result.value) |v| {
            result.value = null; // Prevent deinit from freeing
            return v;
        }

        result.deinit();
        return ClientError.InvalidResponse;
    }

    /// Send a JSON-RPC request and return full result with error details.
    ///
    /// Unlike `call`, this method provides access to RPC error information
    /// including error code, message, and optional data. This allows callers
    /// to distinguish between different error types (rate limiting, invalid
    /// params, preflight failures, etc.).
    ///
    /// ## Usage
    /// ```zig
    /// var result = try client.callWithResult(allocator, "getBalance", params);
    /// defer result.deinit();
    ///
    /// if (result.isError()) {
    ///     const code = result.getErrorCode().?;
    ///     if (code == RpcErrorCode.NODE_UNHEALTHY) {
    ///         // Handle node unhealthy
    ///     }
    ///     // Access full error: result.rpc_error.?
    /// } else {
    ///     const value = result.value.?;
    ///     // Process result
    /// }
    /// ```
    pub fn callWithResult(
        self: *JsonRpcClient,
        allocator: Allocator,
        method: []const u8,
        params: ?std.json.Value,
    ) ClientError!CallResult {
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

        // Check for error - return full error details
        if (response.@"error") |json_err| {
            const rpc_error = json_err.toRpcError(allocator) catch {
                return ClientError.OutOfMemory;
            };
            return CallResult.err(allocator, rpc_error);
        }

        // Return result
        if (response.result) |result| {
            // Clone the result since parsed will be freed
            const cloned = cloneJsonValue(allocator, result) catch {
                return ClientError.OutOfMemory;
            };
            return CallResult.success(allocator, cloned);
        }

        return ClientError.InvalidResponse;
    }

    /// Send HTTP POST request using Zig 0.15.2 request/response API
    ///
    /// API Reference (Zig 0.15.2):
    /// - client.request(method, uri, options) -> Request
    /// - req.sendBodyComplete(body) - sends body and flushes
    /// - req.receiveHead(buffer) -> Response
    /// - response.reader(buffer) -> *std.Io.Reader
    /// - reader.allocRemaining(allocator, limit) -> []u8
    fn sendHttpRequest(self: *JsonRpcClient, allocator: Allocator, body: []const u8) ![]u8 {
        var client = std.http.Client{ .allocator = allocator };
        defer client.deinit();

        // Parse the URI
        const uri = std.Uri.parse(self.endpoint) catch return ClientError.InvalidResponse;

        // Create the request using client.request() (Zig 0.15.2 API)
        var req = client.request(.POST, uri, .{
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
            },
        }) catch return ClientError.ConnectionFailed;
        defer req.deinit();

        // Send the request body
        // Note: sendBodyComplete internally only reads from body, so @constCast is safe here
        req.sendBodyComplete(@constCast(body)) catch return ClientError.ConnectionFailed;

        // Receive response head
        var redirect_buf: [4096]u8 = undefined;
        var response = req.receiveHead(&redirect_buf) catch return ClientError.ConnectionFailed;

        // Check status code
        const status = @intFromEnum(response.head.status);
        if (status < 200 or status >= 300) {
            if (status == 429) {
                return ClientError.RateLimited;
            }
            return ClientError.UnexpectedStatus;
        }

        // Read response body using std.Io.Reader (Zig 0.15.2 Writergate API)
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

/// Free a JSON value (deep free for cloned values)
fn freeJsonValue(allocator: Allocator, value: std.json.Value) void {
    switch (value) {
        .null, .bool, .integer, .float => {},
        .number_string => |s| allocator.free(s),
        .string => |s| allocator.free(s),
        .array => |arr| {
            for (arr.items) |item| {
                freeJsonValue(allocator, item);
            }
            @constCast(&arr).deinit();
        },
        .object => |obj| {
            var it = obj.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                freeJsonValue(allocator, entry.value_ptr.*);
            }
            @constCast(&obj).deinit();
        },
    }
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

test "json_rpc: JsonRpcError toRpcErrorUnmanaged" {
    const err = JsonRpcError{
        .code = -32600,
        .message = "Invalid request",
        .data = null,
    };

    const rpc_err = err.toRpcErrorUnmanaged();
    try std.testing.expectEqual(@as(i64, -32600), rpc_err.code);
    try std.testing.expectEqualStrings("Invalid request", rpc_err.message);
}

test "json_rpc: JsonRpcError toRpcError with allocation" {
    const allocator = std.testing.allocator;

    const err = JsonRpcError{
        .code = -32602,
        .message = "Invalid params",
        .data = null,
    };

    const rpc_err = try err.toRpcError(allocator);
    defer allocator.free(rpc_err.message);

    try std.testing.expectEqual(@as(i64, -32602), rpc_err.code);
    try std.testing.expectEqualStrings("Invalid params", rpc_err.message);
}

test "json_rpc: CallResult success" {
    const allocator = std.testing.allocator;

    const value = try cloneJsonValue(allocator, .{ .integer = 42 });
    var result = CallResult.success(allocator, value);
    defer result.deinit();

    try std.testing.expect(result.isSuccess());
    try std.testing.expect(!result.isError());
    try std.testing.expectEqual(@as(?i64, null), result.getErrorCode());

    const unwrapped = try result.unwrap();
    try std.testing.expectEqual(@as(i64, 42), unwrapped.integer);
}

test "json_rpc: CallResult error" {
    const allocator = std.testing.allocator;

    const rpc_error = RpcError{
        .code = -32600,
        .message = try allocator.dupe(u8, "Invalid request"),
        .data = null,
    };

    var result = CallResult.err(allocator, rpc_error);
    defer result.deinit();

    try std.testing.expect(result.isError());
    try std.testing.expect(!result.isSuccess());
    try std.testing.expectEqual(@as(?i64, -32600), result.getErrorCode());
    try std.testing.expect(result.isErrorCode(-32600));
    try std.testing.expect(!result.isErrorCode(-32601));

    // unwrap should return error
    try std.testing.expectError(ClientError.RpcError, result.unwrap());
}

test "json_rpc: freeJsonValue" {
    const allocator = std.testing.allocator;

    // Clone a complex value
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put(try allocator.dupe(u8, "key"), .{ .string = try allocator.dupe(u8, "value") });

    // Free should not leak
    freeJsonValue(allocator, .{ .object = obj });
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
