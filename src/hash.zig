//! Zig implementation of Solana SDK's hash module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/hash/src/lib.rs
//!
//! This module provides the Hash type representing a SHA-256 hash (32 bytes).
//! Used for transaction signatures, block hashes, and other cryptographic operations.

const std = @import("std");
const base58 = @import("base58");

/// Maximum string length of a base58 encoded Hash
pub const MAX_BASE58_LEN: usize = 44;

/// A SHA-256 hash (32 bytes)
///
/// Rust equivalent: `solana_hash::Hash`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/hash/src/lib.rs
pub const Hash = struct {
    pub const length: usize = 32;
    bytes: [Hash.length]u8,

    /// Create a Hash from bytes
    pub fn from(bytes: [Hash.length]u8) Hash {
        return .{ .bytes = bytes };
    }

    /// Create a default (zero) hash
    pub fn default() Hash {
        return .{ .bytes = [_]u8{0} ** Hash.length };
    }

    /// Create a unique hash for testing
    /// Rust equivalent: `Hash::new_unique()`
    pub fn newUnique() Hash {
        var bytes: [Hash.length]u8 = undefined;
        std.crypto.random.bytes(&bytes);
        return .{ .bytes = bytes };
    }

    /// Parse from base58 string
    /// Rust equivalent: `Hash::from_str()`
    pub fn fromBase58(str: []const u8) !Hash {
        // Check max length
        if (str.len > MAX_BASE58_LEN) {
            return error.WrongSize;
        }

        var buffer: [Hash.length]u8 = undefined;
        const decoded = base58.bitcoin.decode(&buffer, str) catch {
            return error.Invalid;
        };
        if (decoded.len != Hash.length) {
            return error.WrongSize;
        }
        return .{ .bytes = buffer };
    }

    /// Get the bytes as a slice
    pub fn asBytes(self: *const Hash) []const u8 {
        return &self.bytes;
    }

    /// Get reference to the bytes array
    pub fn asArray(self: *const Hash) *const [Hash.length]u8 {
        return &self.bytes;
    }

    pub fn format(self: Hash, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        var buffer: [base58.bitcoin.getEncodedLengthUpperBound(Hash.length)]u8 = undefined;
        try writer.print("{s}", .{base58.bitcoin.encode(&buffer, &self.bytes)});
    }

    /// Convert to base58 string
    pub fn toBase58(self: Hash, buffer: *[MAX_BASE58_LEN]u8) []const u8 {
        return base58.bitcoin.encode(buffer, &self.bytes);
    }
};

// ============================================================================
// Tests - Matching Rust: https://github.com/anza-xyz/solana-sdk/blob/master/hash/src/lib.rs
// ============================================================================

// Rust test: test_new_unique
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/hash/src/lib.rs#L164
test "hash: new_unique generates different hashes" {
    const hash1 = Hash.newUnique();
    const hash2 = Hash.newUnique();
    try std.testing.expect(!std.mem.eql(u8, &hash1.bytes, &hash2.bytes));
}

// Rust test: test_hash_fromstr
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/hash/src/lib.rs#L169
test "hash: fromBase58 parsing" {
    // Test valid base58 string parsing
    const valid_hash = Hash.from([_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
    });

    var buffer: [MAX_BASE58_LEN]u8 = undefined;
    const encoded = valid_hash.toBase58(&buffer);

    // Parse should succeed
    const parsed = try Hash.fromBase58(encoded);
    try std.testing.expectEqualSlices(u8, &valid_hash.bytes, &parsed.bytes);

    // Test string too long (concatenated) - should fail with WrongSize
    var long_str: [MAX_BASE58_LEN * 2]u8 = undefined;
    @memcpy(long_str[0..encoded.len], encoded);
    @memcpy(long_str[encoded.len .. encoded.len * 2], encoded);
    try std.testing.expectError(error.WrongSize, Hash.fromBase58(long_str[0 .. encoded.len * 2]));

    // Test invalid base58 characters
    try std.testing.expectError(error.Invalid, Hash.fromBase58("I am not base58"));
}

test "hash: default is zero" {
    const h = Hash.default();
    for (h.bytes) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }
}
