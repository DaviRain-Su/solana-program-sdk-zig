//! Zig implementation of Solana SDK's Blake3 hasher module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/blake3-hasher/src/lib.rs
//!
//! This module provides Blake3 hashing via Solana syscalls in BPF context,
//! or native Zig implementation for off-chain use.

const std = @import("std");
const syscalls = @import("syscalls.zig");
const log = @import("log.zig");
const Hash = @import("solana_sdk").Hash;

/// Return a Blake3 hash for the given data slices.
///
/// In BPF context, uses the sol_blake3 syscall.
/// In native context, uses Zig's std.crypto.hash.Blake3.
///
/// Rust equivalent: `solana_blake3_hasher::hashv`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/blake3-hasher/src/lib.rs
pub fn hashv(vals: []const []const u8) Hash {
    var result_hash: Hash = undefined;

    if (syscalls.is_bpf_program) {
        // BPF context: use syscall
        const syscall_result = syscalls.sol_blake3(@ptrCast(vals.ptr), vals.len, &result_hash.bytes);
        if (syscall_result != 0) {
            log.print("failed to get blake3 hash: error code {}", .{syscall_result});
            @panic("blake3 syscall failed");
        }
    } else {
        // Native context: use Zig's crypto library
        var hasher = std.crypto.hash.Blake3.init(.{});
        for (vals) |val| {
            hasher.update(val);
        }
        hasher.final(&result_hash.bytes);
    }

    return result_hash;
}

/// Return a Blake3 hash for the given data.
///
/// Convenience function for hashing a single slice.
///
/// Rust equivalent: `solana_blake3_hasher::hash`
pub fn hash(val: []const u8) Hash {
    return hashv(&[_][]const u8{val});
}

/// Extend an existing hasher with more data (native only).
///
/// For streaming hash computation in off-chain contexts.
pub const Hasher = struct {
    inner: std.crypto.hash.Blake3,

    pub fn init() Hasher {
        return .{ .inner = std.crypto.hash.Blake3.init(.{}) };
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

test "blake3: hash empty" {
    const result = hash("");
    // Blake3 of empty string
    const expected = [_]u8{
        0xaf, 0x13, 0x49, 0xb9, 0xf5, 0xf9, 0xa1, 0xa6,
        0xa0, 0x40, 0x4d, 0xea, 0x36, 0xdc, 0xc9, 0x49,
        0x9b, 0xcb, 0x25, 0xc9, 0xad, 0xc1, 0x12, 0xb7,
        0xcc, 0x9a, 0x93, 0xca, 0xe4, 0x1f, 0x32, 0x62,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}

test "blake3: hash hello world" {
    const result = hash("hello world");
    // Blake3 of "hello world"
    const expected = [_]u8{
        0xd7, 0x49, 0x81, 0xef, 0xa7, 0x0a, 0x0c, 0x88,
        0x0b, 0x8d, 0x8c, 0x19, 0x85, 0xd0, 0x75, 0xdb,
        0xcb, 0xf6, 0x79, 0xb9, 0x9a, 0x5f, 0x99, 0x14,
        0xe5, 0xaa, 0xf9, 0x6b, 0x83, 0x1a, 0x9e, 0x24,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}

test "blake3: hashv multiple inputs" {
    const result = hashv(&[_][]const u8{ "hello", " ", "world" });
    // Should be same as hash("hello world")
    const expected = hash("hello world");
    try std.testing.expectEqualSlices(u8, &expected.bytes, &result.bytes);
}

test "blake3: streaming hasher" {
    var hasher = Hasher.init();
    hasher.update("hello");
    hasher.update(" ");
    hasher.update("world");
    const result = hasher.final();

    const expected = hash("hello world");
    try std.testing.expectEqualSlices(u8, &expected.bytes, &result.bytes);
}

test "blake3: known test vector" {
    // Test with "abc"
    const result = hash("abc");
    const expected = [_]u8{
        0x64, 0x37, 0xb3, 0xac, 0x38, 0x46, 0x51, 0x33,
        0xff, 0xb6, 0x3b, 0x75, 0x27, 0x3a, 0x8d, 0xb5,
        0x48, 0xc5, 0x58, 0x46, 0x5d, 0x79, 0xdb, 0x03,
        0xfd, 0x35, 0x9c, 0x6c, 0xd5, 0xbd, 0x9d, 0x85,
    };
    try std.testing.expectEqualSlices(u8, &expected, &result.bytes);
}
