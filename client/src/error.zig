//! Solana RPC Client Error Types
//!
//! Rust source: https://github.com/anza-xyz/agave/blob/master/rpc-client-api/src/client_error.rs
//!
//! This module provides error types for the RPC client, including network errors,
//! JSON parsing errors, and RPC-specific errors.

const std = @import("std");

/// RPC error codes as defined by Solana
///
/// Rust equivalent: Custom error codes from `rpc-client-api/src/custom_error.rs`
pub const RpcErrorCode = struct {
    /// Standard JSON-RPC errors
    pub const PARSE_ERROR: i64 = -32700;
    pub const INVALID_REQUEST: i64 = -32600;
    pub const METHOD_NOT_FOUND: i64 = -32601;
    pub const INVALID_PARAMS: i64 = -32602;
    pub const INTERNAL_ERROR: i64 = -32603;

    /// Solana-specific errors
    pub const BLOCK_CLEANED_UP: i64 = -32001;
    pub const SEND_TRANSACTION_PREFLIGHT_FAILURE: i64 = -32002;
    pub const TRANSACTION_SIGNATURE_VERIFICATION_FAILURE: i64 = -32003;
    pub const BLOCK_NOT_AVAILABLE: i64 = -32004;
    pub const NODE_UNHEALTHY: i64 = -32005;
    pub const TRANSACTION_PRECOMPILE_VERIFICATION_FAILURE: i64 = -32006;
    pub const SLOT_SKIPPED: i64 = -32007;
    pub const NO_SNAPSHOT: i64 = -32008;
    pub const LONG_TERM_STORAGE_SLOT_SKIPPED: i64 = -32009;
    pub const KEY_EXCLUDED_FROM_SECONDARY_INDEX: i64 = -32010;
    pub const TRANSACTION_HISTORY_NOT_AVAILABLE: i64 = -32011;
    pub const SCAN_ERROR: i64 = -32012;
    pub const TRANSACTION_SIGNATURE_LEN_MISMATCH: i64 = -32013;
    pub const BLOCK_STATUS_NOT_AVAILABLE_YET: i64 = -32014;
    pub const UNSUPPORTED_TRANSACTION_VERSION: i64 = -32015;
    pub const MIN_CONTEXT_SLOT_NOT_REACHED: i64 = -32016;

    /// Get human-readable message for error code
    pub fn getMessage(code: i64) []const u8 {
        return switch (code) {
            PARSE_ERROR => "Parse error",
            INVALID_REQUEST => "Invalid request",
            METHOD_NOT_FOUND => "Method not found",
            INVALID_PARAMS => "Invalid params",
            INTERNAL_ERROR => "Internal error",
            BLOCK_CLEANED_UP => "Block cleaned up",
            SEND_TRANSACTION_PREFLIGHT_FAILURE => "Transaction preflight failure",
            TRANSACTION_SIGNATURE_VERIFICATION_FAILURE => "Transaction signature verification failure",
            BLOCK_NOT_AVAILABLE => "Block not available",
            NODE_UNHEALTHY => "Node is unhealthy",
            TRANSACTION_PRECOMPILE_VERIFICATION_FAILURE => "Transaction precompile verification failure",
            SLOT_SKIPPED => "Slot was skipped",
            NO_SNAPSHOT => "No snapshot available",
            LONG_TERM_STORAGE_SLOT_SKIPPED => "Long term storage slot skipped",
            KEY_EXCLUDED_FROM_SECONDARY_INDEX => "Key excluded from secondary index",
            TRANSACTION_HISTORY_NOT_AVAILABLE => "Transaction history not available",
            SCAN_ERROR => "Scan error",
            TRANSACTION_SIGNATURE_LEN_MISMATCH => "Transaction signature length mismatch",
            BLOCK_STATUS_NOT_AVAILABLE_YET => "Block status not available yet",
            UNSUPPORTED_TRANSACTION_VERSION => "Unsupported transaction version",
            MIN_CONTEXT_SLOT_NOT_REACHED => "Minimum context slot not reached",
            else => "Unknown error",
        };
    }
};

/// RPC error information returned by the server
///
/// Rust equivalent: `RpcError` from `rpc-client-api/src/client_error.rs`
pub const RpcError = struct {
    /// Error code
    code: i64,
    /// Error message
    message: []const u8,
    /// Optional additional data
    data: ?std.json.Value,

    /// Check if this is a preflight failure
    pub fn isPreflightFailure(self: RpcError) bool {
        return self.code == RpcErrorCode.SEND_TRANSACTION_PREFLIGHT_FAILURE;
    }

    /// Check if this is a node unhealthy error
    pub fn isNodeUnhealthy(self: RpcError) bool {
        return self.code == RpcErrorCode.NODE_UNHEALTHY;
    }

    /// Check if this is a standard JSON-RPC error
    pub fn isStandardError(self: RpcError) bool {
        return self.code >= -32700 and self.code <= -32600;
    }

    /// Get a human-readable description
    pub fn getDescription(self: RpcError) []const u8 {
        return RpcErrorCode.getMessage(self.code);
    }

    /// Format error for display
    pub fn format(self: RpcError, writer: anytype) !void {
        try writer.print("RpcError({d}): {s}", .{ self.code, self.message });
    }
};

/// Client error types
///
/// Rust equivalent: `ErrorKind` from `rpc-client-api/src/client_error.rs`
pub const ClientError = error{
    /// HTTP connection failed
    ConnectionFailed,
    /// HTTP request failed
    HttpError,
    /// Request timed out
    Timeout,
    /// JSON parsing error
    JsonParseError,
    /// RPC returned an error
    RpcError,
    /// Invalid response format
    InvalidResponse,
    /// Invalid URL
    InvalidUrl,
    /// Too many requests (rate limited)
    RateLimited,
    /// Server returned unexpected status code
    UnexpectedStatus,
    /// Request was cancelled
    Cancelled,
    /// Out of memory
    OutOfMemory,
    /// Invalid parameter
    InvalidParameter,
    /// Signature verification failed
    SignatureVerificationFailed,
    /// Transaction error
    TransactionError,
};

/// Extended error with context
pub const ClientErrorWithContext = struct {
    /// The underlying error
    err: ClientError,
    /// RPC error details (if available)
    rpc_error: ?RpcError,
    /// HTTP status code (if available)
    http_status: ?u16,
    /// Request method that failed
    method: ?[]const u8,

    /// Create from a client error
    pub fn fromError(err: ClientError) ClientErrorWithContext {
        return .{
            .err = err,
            .rpc_error = null,
            .http_status = null,
            .method = null,
        };
    }

    /// Create from an RPC error
    pub fn fromRpcError(rpc_err: RpcError, method: []const u8) ClientErrorWithContext {
        return .{
            .err = ClientError.RpcError,
            .rpc_error = rpc_err,
            .http_status = null,
            .method = method,
        };
    }

    /// Format for display
    pub fn format(self: ClientErrorWithContext, writer: anytype) !void {
        if (self.method) |m| {
            try writer.print("Error in {s}: ", .{m});
        }

        switch (self.err) {
            ClientError.RpcError => {
                if (self.rpc_error) |rpc_err| {
                    try rpc_err.format(writer);
                } else {
                    try writer.writeAll("RPC error");
                }
            },
            ClientError.HttpError => {
                try writer.writeAll("HTTP error");
                if (self.http_status) |status| {
                    try writer.print(" (status: {d})", .{status});
                }
            },
            else => {
                try writer.print("{s}", .{@errorName(self.err)});
            },
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "error: RpcErrorCode getMessage" {
    try std.testing.expectEqualStrings(
        "Parse error",
        RpcErrorCode.getMessage(RpcErrorCode.PARSE_ERROR),
    );

    try std.testing.expectEqualStrings(
        "Node is unhealthy",
        RpcErrorCode.getMessage(RpcErrorCode.NODE_UNHEALTHY),
    );

    try std.testing.expectEqualStrings(
        "Transaction preflight failure",
        RpcErrorCode.getMessage(RpcErrorCode.SEND_TRANSACTION_PREFLIGHT_FAILURE),
    );
}

test "error: RpcError methods" {
    const preflight_err = RpcError{
        .code = RpcErrorCode.SEND_TRANSACTION_PREFLIGHT_FAILURE,
        .message = "Transaction simulation failed",
        .data = null,
    };

    try std.testing.expect(preflight_err.isPreflightFailure());
    try std.testing.expect(!preflight_err.isNodeUnhealthy());
    try std.testing.expect(!preflight_err.isStandardError());

    const unhealthy_err = RpcError{
        .code = RpcErrorCode.NODE_UNHEALTHY,
        .message = "Node is behind",
        .data = null,
    };

    try std.testing.expect(!unhealthy_err.isPreflightFailure());
    try std.testing.expect(unhealthy_err.isNodeUnhealthy());

    const parse_err = RpcError{
        .code = RpcErrorCode.PARSE_ERROR,
        .message = "Invalid JSON",
        .data = null,
    };

    try std.testing.expect(parse_err.isStandardError());
}

test "error: ClientErrorWithContext" {
    const ctx = ClientErrorWithContext.fromError(ClientError.ConnectionFailed);

    try std.testing.expectEqual(ClientError.ConnectionFailed, ctx.err);
    try std.testing.expect(ctx.rpc_error == null);
    try std.testing.expect(ctx.http_status == null);
    try std.testing.expect(ctx.method == null);
}

test "error: ClientErrorWithContext from RpcError" {
    const rpc_err = RpcError{
        .code = -32600,
        .message = "Invalid request",
        .data = null,
    };

    const ctx = ClientErrorWithContext.fromRpcError(rpc_err, "getBalance");

    try std.testing.expectEqual(ClientError.RpcError, ctx.err);
    try std.testing.expect(ctx.rpc_error != null);
    try std.testing.expectEqualStrings("getBalance", ctx.method.?);
}
