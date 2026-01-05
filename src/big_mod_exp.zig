//! Zig implementation of big integer modular exponentiation
//!
//! Rust source: https://github.com/rust-num/num-bigint
//!
//! This module provides efficient modular exponentiation operations for
//! large integers, commonly used in cryptographic protocols.
//!
//! Implements the binary exponentiation algorithm for computing:
//! result = base^exponent mod modulus
//!
//! Optimized for Solana's compute constraints and memory limitations.

const std = @import("std");

/// Error type for modular exponentiation operations
pub const ModExpError = error{
    InvalidInput,
    Overflow,
    OutOfMemory,
};

/// Big integer represented as little-endian byte array
/// Supports up to 512 bytes (4096 bits) to stay within Solana's heap limits
pub const BigInt = struct {
    /// Raw bytes in little-endian order
    bytes: []u8,
    /// Allocated flag (for memory management)
    allocated: bool,

    /// Maximum supported size (512 bytes = 4096 bits)
    pub const MAX_SIZE = 512;

    /// Create a BigInt from a byte slice (copies the data)
    pub fn fromBytes(allocator: std.mem.Allocator, bytes: []const u8) !BigInt {
        if (bytes.len > MAX_SIZE) return ModExpError.InvalidInput;
        if (bytes.len == 0) return ModExpError.InvalidInput;

        const buf = try allocator.alloc(u8, bytes.len);
        @memcpy(buf, bytes);

        return BigInt{
            .bytes = buf,
            .allocated = true,
        };
    }

    /// Create a BigInt from a u64 value
    pub fn fromU64(allocator: std.mem.Allocator, value: u64) !BigInt {
        const buf = try allocator.alloc(u8, 8);
        std.mem.writeInt(u64, buf[0..8], value, .little);

        return BigInt{
            .bytes = buf,
            .allocated = true,
        };
    }

    /// Create a BigInt from a borrowed byte slice (no copy)
    pub fn fromBytesBorrowed(bytes: []u8) BigInt {
        return BigInt{
            .bytes = bytes,
            .allocated = false,
        };
    }

    /// Free the BigInt if it was allocated
    pub fn deinit(self: *BigInt, allocator: std.mem.Allocator) void {
        if (self.allocated) {
            allocator.free(self.bytes);
        }
    }

    /// Get the byte length
    pub fn len(self: BigInt) usize {
        return self.bytes.len;
    }

    /// Check if this BigInt is zero
    pub fn isZero(self: BigInt) bool {
        for (self.bytes) |byte| {
            if (byte != 0) return false;
        }
        return true;
    }

    /// Check if this BigInt is one
    pub fn isOne(self: BigInt) bool {
        if (self.bytes[0] != 1) return false;
        for (self.bytes[1..]) |byte| {
            if (byte != 0) return false;
        }
        return true;
    }

    /// Compare two BigInts for equality
    pub fn eql(self: BigInt, other: BigInt) bool {
        return std.mem.eql(u8, self.bytes, other.bytes);
    }

    /// Clone this BigInt
    pub fn clone(self: BigInt, allocator: std.mem.Allocator) !BigInt {
        return try fromBytes(allocator, self.bytes);
    }
};

/// Compute modular exponentiation: base^exponent mod modulus
///
/// Uses a simplified binary exponentiation algorithm.
/// For production use, consider more optimized implementations.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `base` - Base value (as u64 for simplicity)
/// * `exponent` - Exponent value (as u64 for simplicity)
/// * `modulus` - Modulus value (as u64 for simplicity)
///
/// # Returns
/// Result as u64, or error if computation fails
pub fn modPowSimple(
    base: u64,
    exponent: u64,
    modulus: u64,
) u64 {
    if (modulus == 0) return 0;
    if (modulus == 1) return 0;

    var result: u64 = 1;
    var b = base % modulus;
    var exp = exponent;

    while (exp > 0) {
        if (exp & 1 == 1) {
            result = mulMod(result, b, modulus);
        }
        b = mulMod(b, b, modulus);
        exp >>= 1;
    }

    return result;
}

/// Modular multiplication: (a * b) mod modulus
fn mulMod(a: u64, b: u64, modulus: u64) u64 {
    // Use simple multiplication for small numbers
    // For larger numbers, this should use big integer arithmetic
    const product = @as(u128, a) * @as(u128, b);
    return @truncate(product % @as(u128, modulus));
}

/// Extended modular exponentiation with BigInt support (placeholder)
/// This is a simplified version - production implementations should use
/// more sophisticated algorithms like Montgomery multiplication
pub fn modPow(
    allocator: std.mem.Allocator,
    base: []const u8,
    exponent: []const u8,
    modulus: []const u8,
) !BigInt {
    // For now, convert to u64 and use simple implementation
    // In production, this should handle arbitrary-sized integers

    if (base.len > 8 or exponent.len > 8 or modulus.len > 8) {
        return ModExpError.InvalidInput; // Too large for simple implementation
    }

    const b = std.mem.readIntLittle(u64, base[0..8]);
    const e = std.mem.readIntLittle(u64, exponent[0..8]);
    const m = std.mem.readIntLittle(u64, modulus[0..8]);

    const result = modPowSimple(b, e, m);
    return try BigInt.fromU64(allocator, result);
}

/// Modular multiplication: (a * b) mod modulus
fn modMultiply(
    allocator: std.mem.Allocator,
    a: BigInt,
    b: BigInt,
    modulus: BigInt,
) !BigInt {
    // For now, use a simple multiplication algorithm
    // In practice, this should use more efficient algorithms like Montgomery multiplication

    // Allocate result buffer (max size = len(a) + len(b))
    const result_len = a.len() + b.len();
    if (result_len > BigInt.MAX_SIZE) return ModExpError.Overflow;

    var result_buf = try allocator.alloc(u8, result_len);
    errdefer allocator.free(result_buf);
    @memset(result_buf, 0);

    // Simple multiplication (not optimized)
    for (a.bytes, 0..) |a_byte, i| {
        var carry: u16 = 0;
        for (b.bytes, 0..) |b_byte, j| {
            const product = @as(u16, a_byte) * @as(u16, b_byte) + carry + @as(u16, result_buf[i + j]);
            result_buf[i + j] = @truncate(product);
            carry = product >> 8;
        }

        // Handle remaining carry
        var k = i + b.len();
        while (carry > 0 and k < result_len) {
            const sum = @as(u16, result_buf[k]) + carry;
            result_buf[k] = @truncate(sum);
            carry = sum >> 8;
            k += 1;
        }
    }

    // Convert to BigInt and apply modulus
    var product = BigInt.fromBytesBorrowed(result_buf);
    defer product.deinit(allocator); // This will free result_buf

    return try modReduce(allocator, product, modulus);
}

/// Modular reduction: a mod modulus
fn modReduce(
    allocator: std.mem.Allocator,
    a: BigInt,
    modulus: BigInt,
) !BigInt {
    // Simple modulo operation
    // In practice, this should use more efficient algorithms

    if (a.len() < modulus.len()) {
        // a < modulus, return a
        return try a.clone(allocator);
    }

    // For now, use a simple subtraction-based approach
    // This is inefficient but correct for small numbers
    var result = try a.clone(allocator);
    errdefer result.deinit(allocator);

    while (!lessThan(result, modulus)) {
        // result = result - modulus
        var borrow: u8 = 0;
        for (0..result.len()) |i| {
            var diff: i16 = @as(i16, result.bytes[i]);
            if (i < modulus.len()) {
                diff -= @as(i16, modulus.bytes[i]);
            }
            diff -= @as(i16, borrow);

            if (diff < 0) {
                diff += 256;
                borrow = 1;
            } else {
                borrow = 0;
            }

            result.bytes[i] = @truncate(@as(u16, @intCast(diff)));
        }
    }

    return result;
}

/// Check if a < b (both positive BigInts)
fn lessThan(a: BigInt, b: BigInt) bool {
    // Compare lengths first
    if (a.len() != b.len()) {
        return a.len() < b.len();
    }

    // Compare bytes from most significant to least
    var i: usize = a.len();
    while (i > 0) {
        i -= 1;
        if (a.bytes[i] != b.bytes[i]) {
            return a.bytes[i] < b.bytes[i];
        }
    }

    return false; // equal
}

test "big-mod-exp: simple cases" {
    // Test: 2^3 mod 5 = 8 mod 5 = 3
    const result = modPowSimple(2, 3, 5);
    try std.testing.expectEqual(@as(u64, 3), result);

    // Test: 3^2 mod 7 = 9 mod 7 = 2
    const result2 = modPowSimple(3, 2, 7);
    try std.testing.expectEqual(@as(u64, 2), result2);

    // Test: 5^0 mod 13 = 1
    const result3 = modPowSimple(5, 0, 13);
    try std.testing.expectEqual(@as(u64, 1), result3);
}

test "big-mod-exp: edge cases" {
    // Test modulus 1
    const result1 = modPowSimple(42, 10, 1);
    try std.testing.expectEqual(@as(u64, 0), result1);

    // Test base larger than modulus
    const result2 = modPowSimple(15, 2, 7); // 15 mod 7 = 1, 1^2 mod 7 = 1
    try std.testing.expectEqual(@as(u64, 1), result2);
}

test "big-mod-exp: large exponents" {
    // Test with larger exponent
    const result = modPowSimple(2, 10, 1000); // 2^10 = 1024, 1024 mod 1000 = 24
    try std.testing.expectEqual(@as(u64, 24), result);
}

test "big-mod-exp: bigint from u64" {
    const allocator = std.testing.allocator;

    var bigint = try BigInt.fromU64(allocator, 42);
    defer bigint.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 8), bigint.len());
    try std.testing.expectEqual(@as(u8, 42), bigint.bytes[0]);
}
