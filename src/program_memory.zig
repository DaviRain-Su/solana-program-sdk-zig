//! Zig implementation of Solana SDK's program-memory module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-memory/src/lib.rs
//!
//! This module provides safe memory operations that use Solana runtime syscalls
//! in BPF mode. These functions are preferred over standard library functions
//! because they are guaranteed to work correctly in the SBF/BPF environment.
//!
//! ## Key Functions
//! - `sol_memcpy` - Copy memory (source and destination must not overlap)
//! - `sol_memmove` - Move memory (handles overlapping regions)
//! - `sol_memset` - Fill memory with a byte value
//! - `sol_memcmp` - Compare two memory regions
//!
//! ## BPF vs Non-BPF
//! - In BPF mode: Uses Solana runtime syscalls
//! - In test mode: Uses Zig standard library implementations

const std = @import("std");
const bpf = @import("bpf.zig");

// ============================================================================
// Syscall Definitions
// ============================================================================

/// sol_memcpy_ syscall (Hash: 0x717cc4a3)
const sol_memcpy_syscall = @as(
    *align(1) const fn ([*]u8, [*]const u8, u64) callconv(.c) void,
    @ptrFromInt(0x717cc4a3),
);

/// sol_memmove_ syscall (Hash: 0x434371f8)
const sol_memmove_syscall = @as(
    *align(1) const fn ([*]u8, [*]const u8, u64) callconv(.c) void,
    @ptrFromInt(0x434371f8),
);

/// sol_memcmp_ syscall (Hash: 0x5fdcde31)
const sol_memcmp_syscall = @as(
    *align(1) const fn ([*]const u8, [*]const u8, u64, [*]i32) callconv(.c) void,
    @ptrFromInt(0x5fdcde31),
);

/// sol_memset_ syscall (Hash: 0x3770fb22)
const sol_memset_syscall = @as(
    *align(1) const fn ([*]u8, u8, u64) callconv(.c) void,
    @ptrFromInt(0x3770fb22),
);

// ============================================================================
// Public API
// ============================================================================

/// Copy `n` bytes from `src` to `dst`.
///
/// **SAFETY**: The source and destination memory regions MUST NOT overlap.
/// If they might overlap, use `sol_memmove` instead.
///
/// This uses the `sol_memcpy_` syscall in BPF mode, which may have better
/// performance characteristics than a naive byte-by-byte copy.
///
/// Rust equivalent: `solana_program_memory::sol_memcpy`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/program-memory/src/lib.rs
pub fn sol_memcpy(dst: []u8, src: []const u8, n: usize) void {
    const len = @min(@min(n, dst.len), src.len);
    if (len == 0) return;

    if (comptime bpf.is_bpf_program) {
        sol_memcpy_syscall(dst.ptr, src.ptr, len);
    } else {
        @memcpy(dst[0..len], src[0..len]);
    }
}

/// Copy `n` bytes from `src` to `dst`, handling overlapping regions correctly.
///
/// Unlike `sol_memcpy`, this function correctly handles the case where the
/// source and destination memory regions overlap. This is slightly slower
/// than `sol_memcpy` due to the overlap handling.
///
/// Rust equivalent: `solana_program_memory::sol_memmove`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/program-memory/src/lib.rs
pub fn sol_memmove(dst: []u8, src: []const u8, n: usize) void {
    const len = @min(@min(n, dst.len), src.len);
    if (len == 0) return;

    if (comptime bpf.is_bpf_program) {
        sol_memmove_syscall(dst.ptr, src.ptr, len);
    } else {
        // Use backwards copy if overlapping and dst > src
        const dst_addr = @intFromPtr(dst.ptr);
        const src_addr = @intFromPtr(src.ptr);

        if (dst_addr > src_addr and dst_addr < src_addr + len) {
            // Overlapping, copy backwards
            var i: usize = len;
            while (i > 0) {
                i -= 1;
                dst[i] = src[i];
            }
        } else {
            @memcpy(dst[0..len], src[0..len]);
        }
    }
}

/// Fill `n` bytes of `dst` with the byte value `val`.
///
/// This is useful for zeroing memory or initializing it to a known value.
///
/// Rust equivalent: `solana_program_memory::sol_memset`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/program-memory/src/lib.rs
pub fn sol_memset(dst: []u8, val: u8, n: usize) void {
    const len = @min(n, dst.len);
    if (len == 0) return;

    if (comptime bpf.is_bpf_program) {
        sol_memset_syscall(dst.ptr, val, len);
    } else {
        @memset(dst[0..len], val);
    }
}

/// Compare `n` bytes of memory at `s1` and `s2`.
///
/// Returns:
/// - A negative value if `s1` < `s2`
/// - Zero if `s1` == `s2`
/// - A positive value if `s1` > `s2`
///
/// The comparison is done byte-by-byte in lexicographic order.
///
/// Rust equivalent: `solana_program_memory::sol_memcmp`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/program-memory/src/lib.rs
pub fn sol_memcmp(s1: []const u8, s2: []const u8, n: usize) i32 {
    const len = @min(@min(n, s1.len), s2.len);
    if (len == 0) return 0;

    if (comptime bpf.is_bpf_program) {
        var result: i32 = 0;
        sol_memcmp_syscall(s1.ptr, s2.ptr, len, &result);
        return result;
    } else {
        for (0..len) |i| {
            if (s1[i] != s2[i]) {
                return @as(i32, s1[i]) - @as(i32, s2[i]);
            }
        }
        return 0;
    }
}

// ============================================================================
// Convenience Functions
// ============================================================================

/// Zero out the given memory region.
///
/// Equivalent to `sol_memset(dst, 0, dst.len)`.
pub fn sol_memzero(dst: []u8) void {
    sol_memset(dst, 0, dst.len);
}

/// Check if two memory regions are equal.
///
/// Returns true if the first `n` bytes of `s1` and `s2` are identical.
pub fn sol_memeq(s1: []const u8, s2: []const u8, n: usize) bool {
    return sol_memcmp(s1, s2, n) == 0;
}

// ============================================================================
// Tests
// ============================================================================

test "program_memory: sol_memcpy basic" {
    var dst: [16]u8 = undefined;
    const src = "Hello, Solana!!";

    sol_memcpy(&dst, src, src.len);

    try std.testing.expectEqualSlices(u8, "Hello, Solana!!", dst[0..15]);
}

test "program_memory: sol_memcpy partial" {
    var dst: [16]u8 = [_]u8{0} ** 16;
    const src = "Hello, World!";

    // Copy only 5 bytes
    sol_memcpy(&dst, src, 5);

    try std.testing.expectEqualSlices(u8, "Hello", dst[0..5]);
    try std.testing.expectEqual(@as(u8, 0), dst[5]);
}

test "program_memory: sol_memcpy zero length" {
    var dst: [8]u8 = [_]u8{0xFF} ** 8;
    const src = "Test";

    sol_memcpy(&dst, src, 0);

    // Should be unchanged
    try std.testing.expectEqual(@as(u8, 0xFF), dst[0]);
}

test "program_memory: sol_memmove non-overlapping" {
    var dst: [16]u8 = undefined;
    const src = "Hello, Solana!!";

    sol_memmove(&dst, src, src.len);

    try std.testing.expectEqualSlices(u8, "Hello, Solana!!", dst[0..15]);
}

test "program_memory: sol_memmove overlapping forward" {
    var buf = [_]u8{ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H' };

    // Move "ABCD" to position 2 (overlapping)
    const src = buf[0..4];
    const dst = buf[2..6];
    sol_memmove(dst, src, 4);

    // Should be: A, B, A, B, C, D, G, H
    try std.testing.expectEqualSlices(u8, &[_]u8{ 'A', 'B', 'A', 'B', 'C', 'D', 'G', 'H' }, &buf);
}

test "program_memory: sol_memset" {
    var buf: [8]u8 = undefined;

    sol_memset(&buf, 0xAB, buf.len);

    for (buf) |byte| {
        try std.testing.expectEqual(@as(u8, 0xAB), byte);
    }
}

test "program_memory: sol_memset partial" {
    var buf: [8]u8 = [_]u8{0} ** 8;

    sol_memset(&buf, 0xFF, 4);

    try std.testing.expectEqual(@as(u8, 0xFF), buf[0]);
    try std.testing.expectEqual(@as(u8, 0xFF), buf[3]);
    try std.testing.expectEqual(@as(u8, 0), buf[4]);
}

test "program_memory: sol_memzero" {
    var buf: [8]u8 = [_]u8{0xFF} ** 8;

    sol_memzero(&buf);

    for (buf) |byte| {
        try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

test "program_memory: sol_memcmp equal" {
    const a = "Hello";
    const b = "Hello";

    try std.testing.expectEqual(@as(i32, 0), sol_memcmp(a, b, 5));
}

test "program_memory: sol_memcmp less than" {
    const a = "Apple";
    const b = "Banana";

    try std.testing.expect(sol_memcmp(a, b, 5) < 0);
}

test "program_memory: sol_memcmp greater than" {
    const a = "Zebra";
    const b = "Apple";

    try std.testing.expect(sol_memcmp(a, b, 5) > 0);
}

test "program_memory: sol_memcmp partial equal" {
    const a = "Hello, World!";
    const b = "Hello, Solana!";

    // First 7 bytes are equal
    try std.testing.expectEqual(@as(i32, 0), sol_memcmp(a, b, 7));
    // But full comparison differs
    try std.testing.expect(sol_memcmp(a, b, 13) != 0);
}

test "program_memory: sol_memeq" {
    const a = "Test123";
    const b = "Test123";
    const c = "Test456";

    try std.testing.expect(sol_memeq(a, b, 7));
    try std.testing.expect(!sol_memeq(a, c, 7));
    try std.testing.expect(sol_memeq(a, c, 4)); // First 4 bytes match
}
