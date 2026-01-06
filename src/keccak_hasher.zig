//! Zig implementation of Solana SDK's Keccak-256 hasher module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/keccak-hasher/src/lib.rs
//!
//! This module provides Keccak-256 hashing via Solana syscalls in BPF context,
//! or native Zig implementation for off-chain use.
//!
//! Note: Keccak-256 is used by Ethereum and differs from SHA3-256.

const std = @import("std");
const syscalls = @import("syscalls.zig");
const log = @import("log.zig");
const Hash = @import("solana_sdk").Hash;

/// Return a Keccak-256 hash for the given data slices.
///
/// In BPF context, uses the sol_keccak256 syscall.
/// In native context, uses Zig's std.crypto.hash.sha3.Keccak256.
///
/// Rust equivalent: `solana_keccak_hasher::hashv`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/keccak-hasher/src/lib.rs
pub fn hashv(vals: []const []const u8) Hash {
    var result_hash: Hash = undefined;

    if (syscalls.is_bpf_program) {
        // BPF context: use syscall
        const syscall_result = syscalls.sol_keccak256(@ptrCast(vals.ptr), vals.len, &result_hash.bytes);
        if (syscall_result != 0) {
            log.print("failed to get keccak256 hash: error code {}", .{syscall_result});
            @panic("keccak256 syscall failed");
        }
    } else {
        // Native context: use Zig's crypto library
        var hasher = std.crypto.hash.sha3.Keccak256.init(.{});
        for (vals) |val| {
            hasher.update(val);
        }
        hasher.final(&result_hash.bytes);
    }

    return result_hash;
}

/// Return a Keccak-256 hash for the given data.
///
/// Convenience function for hashing a single slice.
///
/// Rust equivalent: `solana_keccak_hasher::hash`
pub fn hash(val: []const u8) Hash {
    return hashv(&[_][]const u8{val});
}

/// Extend an existing hasher with more data (native only).
///
/// For streaming hash computation in off-chain contexts.
pub const Hasher = struct {
    inner: std.crypto.hash.sha3.Keccak256,

    pub fn init() Hasher {
        return .{ .inner = std.crypto.hash.sha3.Keccak256.init(.{}) };
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

test "keccak_hasher: hash empty" {
    const result = hash("");
    // Keccak-256 of empty string
    const expected = [_]u8{
        0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c,
        0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0,
        0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b,
        0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}

test "keccak_hasher: hash hello world" {
    const result = hash("hello world");
    // Keccak-256 of "hello world"
    const expected = [_]u8{
        0x47, 0x17, 0x32, 0x85, 0xa8, 0xd7, 0x34, 0x1e,
        0x5e, 0x97, 0x2f, 0xc6, 0x77, 0x28, 0x63, 0x84,
        0xf8, 0x02, 0xf8, 0xef, 0x42, 0xa5, 0xec, 0x5f,
        0x03, 0xbb, 0xfa, 0x25, 0x4c, 0xb0, 0x1f, 0xad,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}

test "keccak_hasher: hashv multiple inputs" {
    const result = hashv(&[_][]const u8{ "hello", " ", "world" });
    // Should be same as hash("hello world")
    const expected = hash("hello world");
    try std.testing.expectEqualSlices(u8, &expected.bytes, &result.bytes);
}

test "keccak_hasher: streaming hasher" {
    var hasher = Hasher.init();
    hasher.update("hello");
    hasher.update(" ");
    hasher.update("world");
    const result = hasher.final();

    const expected = hash("hello world");
    try std.testing.expectEqualSlices(u8, &expected.bytes, &result.bytes);
}

test "keccak_hasher: known ethereum test vector" {
    // Common Ethereum test vector
    const result = hash("testing");
    // Keccak-256 of "testing" (verified with pycryptodome)
    const expected = [_]u8{
        0x5f, 0x16, 0xf4, 0xc7, 0xf1, 0x49, 0xac, 0x4f,
        0x95, 0x10, 0xd9, 0xcf, 0x8c, 0xf3, 0x84, 0x03,
        0x8a, 0xd3, 0x48, 0xb3, 0xbc, 0xdc, 0x01, 0x91,
        0x5f, 0x95, 0xde, 0x12, 0xdf, 0x9d, 0x1b, 0x02,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}
