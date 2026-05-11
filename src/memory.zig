//! Memory operations for Solana programs
//!
//! Provides safe wrappers around memory syscalls and helper functions
//! for common memory operations in the BPF runtime.

const std = @import("std");
const bpf = @import("bpf.zig");

/// Copy memory from src to dst
/// Uses sol_memcpy_ syscall when running on-chain, falls back to std.mem.copy on host
pub inline fn memcpy(dst: [*]u8, src: [*]const u8, n: usize) void {
    if (bpf.is_bpf_program) {
        solMemcpy(dst, src, n);
    } else {
        @memcpy(dst[0..n], src[0..n]);
    }
}

/// Set memory to a specific byte value
/// Uses sol_memset_ syscall when running on-chain, falls back to std.mem.set on host
pub inline fn memset(dst: [*]u8, c: u8, n: usize) void {
    if (bpf.is_bpf_program) {
        solMemset(dst, c, n);
    } else {
        @memset(dst[0..n], c);
    }
}

/// Compare two memory regions
/// Uses sol_memcmp_ syscall when running on-chain, falls back to std.mem.eql on host
/// Returns 0 if equal, non-zero otherwise (like C memcmp)
pub inline fn memcmp(a: [*]const u8, b: [*]const u8, n: usize) i32 {
    if (bpf.is_bpf_program) {
        return solMemcmp(a, b, n);
    } else {
        var i: usize = 0;
        while (i < n) : (i += 1) {
            if (a[i] != b[i]) {
                return @as(i32, a[i]) - @as(i32, b[i]);
            }
        }
        return 0;
    }
}

/// Zero out a memory region
pub inline fn zero(dst: [*]u8, n: usize) void {
    memset(dst, 0, n);
}

/// Safe cast from bytes to a typed pointer
/// Ensures proper alignment and size
pub inline fn fromBytes(comptime T: type, bytes: []const u8) *const T {
    std.debug.assert(bytes.len >= @sizeOf(T));
    std.debug.assert(@intFromPtr(bytes.ptr) % @alignOf(T) == 0);
    return @ptrCast(@alignCast(bytes.ptr));
}

/// Safe mutable cast from bytes to a typed pointer
pub inline fn fromBytesMut(comptime T: type, bytes: []u8) *T {
    std.debug.assert(bytes.len >= @sizeOf(T));
    std.debug.assert(@intFromPtr(bytes.ptr) % @alignOf(T) == 0);
    return @ptrCast(@alignCast(bytes.ptr));
}

/// Cast a value to its byte representation
pub inline fn asBytes(value: anytype) []const u8 {
    return std.mem.asBytes(value);
}

/// Cast a mutable value to its byte representation
pub inline fn asBytesMut(value: anytype) []u8 {
    return std.mem.asBytes(value);
}

// =============================================================================
// Syscalls (only available in BPF runtime)
// =============================================================================

extern fn sol_memcpy_(dst: [*]u8, src: [*]const u8, n: u64) callconv(.c) void;
extern fn sol_memset_(dst: [*]u8, c: u8, n: u64) callconv(.c) void;
extern fn sol_memcmp_(a: [*]const u8, b: [*]const u8, n: u64, result: *i32) callconv(.c) void;

inline fn solMemcpy(dst: [*]u8, src: [*]const u8, n: usize) void {
    sol_memcpy_(dst, src, n);
}

inline fn solMemset(dst: [*]u8, c: u8, n: usize) void {
    sol_memset_(dst, c, n);
}

inline fn solMemcmp(a: [*]const u8, b: [*]const u8, n: usize) i32 {
    var result: i32 = 0;
    sol_memcmp_(a, b, n, &result);
    return result;
}

// =============================================================================
// Tests
// =============================================================================

test "memory: memcpy" {
    var dst: [10]u8 = undefined;
    const src = "hello";
    memcpy(&dst, src, 5);
    try std.testing.expectEqualStrings("hello", dst[0..5]);
}

test "memory: memset" {
    var dst: [10]u8 = undefined;
    memset(&dst, 0xAA, 10);
    for (dst) |b| {
        try std.testing.expectEqual(@as(u8, 0xAA), b);
    }
}

test "memory: memcmp equal" {
    const a = "hello";
    const b = "hello";
    try std.testing.expectEqual(@as(i32, 0), memcmp(a, b, 5));
}

test "memory: memcmp not equal" {
    const a = "hello";
    const b = "world";
    try std.testing.expect(memcmp(a, b, 5) != 0);
}

test "memory: zero" {
    var dst: [10]u8 = undefined;
    @memset(&dst, 0xFF);
    zero(&dst, 10);
    for (dst) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }
}

test "memory: fromBytes" {
    var bytes align(4) = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    const value = fromBytes(u32, &bytes);
    try std.testing.expectEqual(@as(u32, 0x04030201), value.*);
}
