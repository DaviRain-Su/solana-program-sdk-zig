//! Solana Commitment Configuration
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/commitment-config/src/lib.rs
//!
//! This module provides commitment level configuration for RPC requests.
//! Commitment levels determine how finalized the data must be before it's returned.

const std = @import("std");

/// Commitment level for RPC requests
///
/// Determines how finalized the queried data must be.
///
/// Rust equivalent: `CommitmentLevel` from `solana-commitment-config`
pub const Commitment = enum {
    /// Query the most recent block which has been voted on by the supermajority of the cluster.
    /// - It incorporates votes from gossip and replay.
    /// - It does not count votes on descendants of a block, only direct votes on that block.
    /// - This confirmation level also upholds "optimistic confirmation" guarantees in
    ///   release 1.3 and onwards.
    processed,

    /// Query the most recent block that has been voted on by the supermajority of the cluster.
    /// - It incorporates votes from gossip and replay.
    /// - It does not count votes on descendants of a block, only direct votes on that block.
    /// - This confirmation level also upholds "optimistic confirmation" guarantees.
    confirmed,

    /// Query the most recent block which has been finalized by the cluster.
    /// - A finalized block cannot be rolled back.
    /// - This is the default and most secure commitment level.
    finalized,

    /// Convert to JSON string representation
    pub fn toJsonString(self: Commitment) []const u8 {
        return switch (self) {
            .processed => "processed",
            .confirmed => "confirmed",
            .finalized => "finalized",
        };
    }

    /// Parse from JSON string
    pub fn fromJsonString(s: []const u8) ?Commitment {
        if (std.mem.eql(u8, s, "processed")) return .processed;
        if (std.mem.eql(u8, s, "confirmed")) return .confirmed;
        if (std.mem.eql(u8, s, "finalized")) return .finalized;
        // Legacy aliases
        if (std.mem.eql(u8, s, "recent")) return .processed;
        if (std.mem.eql(u8, s, "single")) return .confirmed;
        if (std.mem.eql(u8, s, "singleGossip")) return .confirmed;
        if (std.mem.eql(u8, s, "root")) return .finalized;
        if (std.mem.eql(u8, s, "max")) return .finalized;
        return null;
    }

    /// Get the relative security level (higher = more secure)
    pub fn securityLevel(self: Commitment) u8 {
        return switch (self) {
            .processed => 0,
            .confirmed => 1,
            .finalized => 2,
        };
    }

    /// Check if this commitment is at least as secure as another
    pub fn isAtLeast(self: Commitment, other: Commitment) bool {
        return self.securityLevel() >= other.securityLevel();
    }
};

/// Configuration for commitment level in RPC requests
///
/// Rust equivalent: `CommitmentConfig` from `solana-commitment-config`
pub const CommitmentConfig = struct {
    commitment: Commitment,

    /// Default commitment (finalized)
    pub const default: CommitmentConfig = .{ .commitment = .finalized };

    /// Processed commitment
    pub const processed: CommitmentConfig = .{ .commitment = .processed };

    /// Confirmed commitment
    pub const confirmed: CommitmentConfig = .{ .commitment = .confirmed };

    /// Finalized commitment
    pub const finalized: CommitmentConfig = .{ .commitment = .finalized };

    /// Create a new commitment config
    pub fn init(commitment: Commitment) CommitmentConfig {
        return .{ .commitment = commitment };
    }

    /// Check if this is the default commitment
    pub fn isDefault(self: CommitmentConfig) bool {
        return self.commitment == .finalized;
    }

    /// Check if this uses finalized commitment
    pub fn isFinalized(self: CommitmentConfig) bool {
        return self.commitment == .finalized;
    }

    /// Check if this uses confirmed commitment
    pub fn isConfirmed(self: CommitmentConfig) bool {
        return self.commitment == .confirmed;
    }

    /// Check if this uses processed commitment
    pub fn isProcessed(self: CommitmentConfig) bool {
        return self.commitment == .processed;
    }

    /// Convert to JSON object for RPC requests
    pub fn toJsonObject(self: CommitmentConfig, writer: anytype) !void {
        try writer.writeAll("{\"commitment\":\"");
        try writer.writeAll(self.commitment.toJsonString());
        try writer.writeAll("\"}");
    }
};

/// RPC configuration that includes commitment and optional encoding
pub const RpcConfig = struct {
    commitment: ?Commitment = null,
    encoding: ?Encoding = null,
    min_context_slot: ?u64 = null,

    pub const Encoding = enum {
        base58,
        base64,
        base64_zstd,
        json,
        json_parsed,

        pub fn toJsonString(self: Encoding) []const u8 {
            return switch (self) {
                .base58 => "base58",
                .base64 => "base64",
                .base64_zstd => "base64+zstd",
                .json => "json",
                .json_parsed => "jsonParsed",
            };
        }
    };

    /// Create config with just commitment
    pub fn withCommitment(commitment: Commitment) RpcConfig {
        return .{ .commitment = commitment };
    }

    /// Create config with commitment and encoding
    pub fn withCommitmentAndEncoding(commitment: Commitment, encoding: Encoding) RpcConfig {
        return .{ .commitment = commitment, .encoding = encoding };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "commitment: toJsonString" {
    try std.testing.expectEqualStrings("processed", Commitment.processed.toJsonString());
    try std.testing.expectEqualStrings("confirmed", Commitment.confirmed.toJsonString());
    try std.testing.expectEqualStrings("finalized", Commitment.finalized.toJsonString());
}

test "commitment: fromJsonString" {
    try std.testing.expectEqual(Commitment.processed, Commitment.fromJsonString("processed").?);
    try std.testing.expectEqual(Commitment.confirmed, Commitment.fromJsonString("confirmed").?);
    try std.testing.expectEqual(Commitment.finalized, Commitment.fromJsonString("finalized").?);

    // Legacy aliases
    try std.testing.expectEqual(Commitment.processed, Commitment.fromJsonString("recent").?);
    try std.testing.expectEqual(Commitment.confirmed, Commitment.fromJsonString("single").?);
    try std.testing.expectEqual(Commitment.finalized, Commitment.fromJsonString("max").?);

    // Invalid
    try std.testing.expect(Commitment.fromJsonString("invalid") == null);
}

test "commitment: securityLevel" {
    try std.testing.expect(Commitment.processed.securityLevel() < Commitment.confirmed.securityLevel());
    try std.testing.expect(Commitment.confirmed.securityLevel() < Commitment.finalized.securityLevel());
}

test "commitment: isAtLeast" {
    try std.testing.expect(Commitment.finalized.isAtLeast(.processed));
    try std.testing.expect(Commitment.finalized.isAtLeast(.confirmed));
    try std.testing.expect(Commitment.finalized.isAtLeast(.finalized));

    try std.testing.expect(Commitment.confirmed.isAtLeast(.processed));
    try std.testing.expect(Commitment.confirmed.isAtLeast(.confirmed));
    try std.testing.expect(!Commitment.confirmed.isAtLeast(.finalized));

    try std.testing.expect(Commitment.processed.isAtLeast(.processed));
    try std.testing.expect(!Commitment.processed.isAtLeast(.confirmed));
    try std.testing.expect(!Commitment.processed.isAtLeast(.finalized));
}

test "commitment_config: constants" {
    try std.testing.expect(CommitmentConfig.default.isFinalized());
    try std.testing.expect(CommitmentConfig.processed.isProcessed());
    try std.testing.expect(CommitmentConfig.confirmed.isConfirmed());
    try std.testing.expect(CommitmentConfig.finalized.isFinalized());
}

test "commitment_config: toJsonObject" {
    var buffer: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try CommitmentConfig.finalized.toJsonObject(fbs.writer());
    try std.testing.expectEqualStrings("{\"commitment\":\"finalized\"}", fbs.getWritten());
}

test "rpc_config: withCommitment" {
    const config = RpcConfig.withCommitment(.confirmed);
    try std.testing.expectEqual(Commitment.confirmed, config.commitment.?);
    try std.testing.expect(config.encoding == null);
}

test "rpc_config: withCommitmentAndEncoding" {
    const config = RpcConfig.withCommitmentAndEncoding(.finalized, .base64);
    try std.testing.expectEqual(Commitment.finalized, config.commitment.?);
    try std.testing.expectEqual(RpcConfig.Encoding.base64, config.encoding.?);
}
