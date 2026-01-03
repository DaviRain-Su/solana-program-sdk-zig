//! Zig implementation of Solana SDK's SHA-256 hasher module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/sha256-hasher/src/lib.rs
//!
//! This module provides SHA-256 hashing via Solana syscalls in BPF context,
//! or native Zig implementation for off-chain use.

const std = @import("std");
const syscalls = @import("syscalls.zig");
const log = @import("log.zig");
const Hash = @import("hash.zig").Hash;

/// Return a SHA-256 hash for the given data slices.
///
/// In BPF context, uses the sol_sha256 syscall.
/// In native context, uses Zig's std.crypto.hash.sha2.Sha256.
///
/// Rust equivalent: `solana_sha256_hasher::hashv`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/sha256-hasher/src/lib.rs
pub fn hashv(vals: []const []const u8) Hash {
    var result_hash: Hash = undefined;

    if (syscalls.is_bpf_program) {
        // BPF context: use syscall
        const syscall_result = syscalls.sol_sha256(@ptrCast(vals.ptr), vals.len, &result_hash.bytes);
        if (syscall_result != 0) {
            log.print("failed to get sha256 hash: error code {}", .{syscall_result});
            @panic("sha256 syscall failed");
        }
    } else {
        // Native context: use Zig's crypto library
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        for (vals) |val| {
            hasher.update(val);
        }
        hasher.final(&result_hash.bytes);
    }

    return result_hash;
}

/// Return a SHA-256 hash for the given data.
///
/// Convenience function for hashing a single slice.
///
/// Rust equivalent: `solana_sha256_hasher::hash`
pub fn hash(val: []const u8) Hash {
    return hashv(&[_][]const u8{val});
}

/// Extend an existing hasher with more data (native only).
///
/// For streaming hash computation in off-chain contexts.
pub const Hasher = struct {
    inner: std.crypto.hash.sha2.Sha256,

    pub fn init() Hasher {
        return .{ .inner = std.crypto.hash.sha2.Sha256.init(.{}) };
    }

    pub fn update(self: *Hasher, data: []const u8) void {
        self.inner.update(data);
    }

    pub fn final(self: *Hasher) Hash {
        var hash_bytes: [Hash.length]u8 = undefined;
        self.inner.final(&hash_bytes);
        return Hash.from(hash_bytes);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "sha256_hasher: hash empty" {
    const result = hash("");
    // SHA-256 of empty string
    const expected = [_]u8{
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}

test "sha256_hasher: hash hello world" {
    const result = hash("hello world");
    // SHA-256 of "hello world"
    const expected = [_]u8{
        0xb9, 0x4d, 0x27, 0xb9, 0x93, 0x4d, 0x3e, 0x08,
        0xa5, 0x2e, 0x52, 0xd7, 0xda, 0x7d, 0xab, 0xfa,
        0xc4, 0x84, 0xef, 0xe3, 0x7a, 0x53, 0x80, 0xee,
        0x90, 0x88, 0xf7, 0xac, 0xe2, 0xef, 0xcd, 0xe9,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}

test "sha256_hasher: hashv multiple inputs" {
    const result = hashv(&[_][]const u8{ "hello", " ", "world" });
    // Should be same as hash("hello world")
    const expected = hash("hello world");
    try std.testing.expectEqualSlices(u8, &expected.bytes, &result.bytes);
}

test "sha256_hasher: streaming hasher" {
    var hasher = Hasher.init();
    hasher.update("hello");
    hasher.update(" ");
    hasher.update("world");
    const result = hasher.final();

    const expected = hash("hello world");
    try std.testing.expectEqualSlices(u8, &expected.bytes, &result.bytes);
}

test "sha256_hasher: known test vector" {
    // Test vector from NIST
    const result = hash("abc");
    const expected = [_]u8{
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}
