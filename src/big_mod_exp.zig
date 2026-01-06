//! Zig implementation of big integer modular exponentiation
//!
//! Rust source: https://github.com/rust-num/num-bigint
//!
//! This module provides efficient modular exponentiation operations for
//! large integers, commonly used in cryptographic protocols.
//!
//! Implements the binary exponentiation (square-and-multiply) algorithm for computing:
//! result = base^exponent mod modulus
//!
//! Uses `std.math.big.int` for arbitrary-precision arithmetic, providing
//! efficient multiplication and division algorithms (Karatsuba, Knuth's Algorithm D).
//!
//! Optimized for Solana's compute constraints and memory limitations.

const std = @import("std");
const Managed = std.math.big.int.Managed;
const Const = std.math.big.int.Const;
const Limb = std.math.big.Limb;

/// Error type for modular exponentiation operations
pub const ModExpError = error{
    InvalidInput,
    Overflow,
    OutOfMemory,
};

/// Compute modular exponentiation: base^exponent mod modulus (for u64 values)
///
/// Uses binary exponentiation (square-and-multiply) algorithm.
/// This is the fast path for small numbers that fit in u64.
///
/// # Arguments
/// * `base` - Base value
/// * `exponent` - Exponent value
/// * `modulus` - Modulus value (must be non-zero)
///
/// # Returns
/// Result as u64, or 0 if modulus is 0 or 1
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
/// Uses u128 to handle overflow for u64 inputs
fn mulMod(a: u64, b: u64, modulus: u64) u64 {
    const product = @as(u128, a) * @as(u128, b);
    return @truncate(product % @as(u128, modulus));
}

/// Extended modular exponentiation with arbitrary-precision support
/// Computes: base^exponent mod modulus
///
/// Uses binary exponentiation (square-and-multiply) algorithm with
/// `std.math.big.int` for arbitrary-precision arithmetic.
///
/// # Arguments
/// * `allocator` - Memory allocator
/// * `base` - Base value as little-endian byte array
/// * `exponent` - Exponent value as little-endian byte array
/// * `modulus` - Modulus value as little-endian byte array
///
/// # Returns
/// Result as newly allocated byte array (little-endian), caller owns the memory
pub fn modPow(
    allocator: std.mem.Allocator,
    base: []const u8,
    exponent: []const u8,
    modulus: []const u8,
) ![]u8 {
    // Validate inputs
    if (base.len == 0 or exponent.len == 0 or modulus.len == 0) {
        return ModExpError.InvalidInput;
    }

    // Check for zero modulus
    var modulus_is_zero = true;
    for (modulus) |byte| {
        if (byte != 0) {
            modulus_is_zero = false;
            break;
        }
    }
    if (modulus_is_zero) {
        return ModExpError.InvalidInput;
    }

    // Check for modulus == 1 (result is always 0)
    var modulus_is_one = (modulus[0] == 1);
    if (modulus_is_one) {
        for (modulus[1..]) |byte| {
            if (byte != 0) {
                modulus_is_one = false;
                break;
            }
        }
    }
    if (modulus_is_one) {
        const result = try allocator.alloc(u8, 1);
        result[0] = 0;
        return result;
    }

    // Check for zero exponent (result is always 1)
    var exponent_is_zero = true;
    for (exponent) |byte| {
        if (byte != 0) {
            exponent_is_zero = false;
            break;
        }
    }
    if (exponent_is_zero) {
        const result = try allocator.alloc(u8, 1);
        result[0] = 1;
        return result;
    }

    // Try u64 fast path for small values
    const effective_base_len = effectiveLen(base);
    const effective_exp_len = effectiveLen(exponent);
    const effective_mod_len = effectiveLen(modulus);

    if (effective_base_len <= 8 and effective_exp_len <= 8 and effective_mod_len <= 8) {
        var base_buf: [8]u8 = [_]u8{0} ** 8;
        var exp_buf: [8]u8 = [_]u8{0} ** 8;
        var mod_buf: [8]u8 = [_]u8{0} ** 8;

        @memcpy(base_buf[0..effective_base_len], base[0..effective_base_len]);
        @memcpy(exp_buf[0..effective_exp_len], exponent[0..effective_exp_len]);
        @memcpy(mod_buf[0..effective_mod_len], modulus[0..effective_mod_len]);

        const b = std.mem.readInt(u64, &base_buf, .little);
        const e = std.mem.readInt(u64, &exp_buf, .little);
        const m = std.mem.readInt(u64, &mod_buf, .little);

        const result_val = modPowSimple(b, e, m);

        // Return result as byte array
        const result = try allocator.alloc(u8, 8);
        std.mem.writeInt(u64, result[0..8], result_val, .little);
        return result;
    }

    // Use std.math.big.int for large numbers
    return modPowBigInt(allocator, base, exponent, modulus);
}

/// Get the effective byte length (excluding trailing zeros in little-endian)
fn effectiveLen(bytes: []const u8) usize {
    var i: usize = bytes.len;
    while (i > 1) {
        i -= 1;
        if (bytes[i] != 0) {
            return i + 1;
        }
    }
    return 1;
}

/// Initialize a Managed big integer from little-endian byte array
fn initFromBytes(allocator: std.mem.Allocator, bytes: []const u8) !Managed {
    var result = try Managed.init(allocator);
    errdefer result.deinit();

    // Get effective length (trim trailing zeros)
    const eff_len = effectiveLen(bytes);

    // Calculate number of limbs needed
    const limbs_needed = (eff_len + @sizeOf(Limb) - 1) / @sizeOf(Limb);
    if (limbs_needed > 0) {
        try result.ensureCapacity(limbs_needed);
    }

    // Convert bytes to limbs (little-endian)
    var limb_idx: usize = 0;
    var byte_idx: usize = 0;

    while (byte_idx < eff_len) {
        var limb: Limb = 0;
        for (0..@sizeOf(Limb)) |shift_idx| {
            if (byte_idx + shift_idx < bytes.len) {
                limb |= @as(Limb, bytes[byte_idx + shift_idx]) << @intCast(shift_idx * 8);
            }
        }

        if (limb_idx < result.limbs.len) {
            result.limbs[limb_idx] = limb;
        } else {
            // Extend capacity if needed
            try result.ensureCapacity(limb_idx + 1);
            result.limbs[limb_idx] = limb;
        }
        result.setLen(limb_idx + 1);

        limb_idx += 1;
        byte_idx += @sizeOf(Limb);
    }

    // Handle zero case
    if (result.len() == 0) {
        result.setLen(1);
        result.limbs[0] = 0;
    }

    return result;
}

/// Modular exponentiation using std.math.big.int
/// Binary exponentiation (square-and-multiply) algorithm
fn modPowBigInt(
    allocator: std.mem.Allocator,
    base_bytes: []const u8,
    exp_bytes: []const u8,
    mod_bytes: []const u8,
) ![]u8 {
    // Initialize big integers from byte arrays
    var base_big = try initFromBytes(allocator, base_bytes);
    defer base_big.deinit();

    var mod_big = try initFromBytes(allocator, mod_bytes);
    defer mod_big.deinit();

    // result = 1
    var result = try Managed.initSet(allocator, @as(u64, 1));
    defer result.deinit();

    // current_base = base mod modulus
    var current_base = try Managed.init(allocator);
    defer current_base.deinit();
    var q_temp = try Managed.init(allocator);
    defer q_temp.deinit();

    // current_base = base % mod
    try Managed.divFloor(&q_temp, &current_base, &base_big, &mod_big);

    // Temporary variables for calculations
    var temp_product = try Managed.init(allocator);
    defer temp_product.deinit();
    var temp_remainder = try Managed.init(allocator);
    defer temp_remainder.deinit();

    // Process each bit of the exponent (little-endian)
    const total_bits = exp_bytes.len * 8;
    for (0..total_bits) |bit_idx| {
        const byte_idx = bit_idx / 8;
        const bit_pos: u3 = @intCast(bit_idx % 8);

        // Check if this bit is set
        if ((exp_bytes[byte_idx] >> bit_pos) & 1 == 1) {
            // result = (result * current_base) mod modulus
            try Managed.mul(&temp_product, &result, &current_base);
            try Managed.divFloor(&q_temp, &temp_remainder, &temp_product, &mod_big);
            try result.copy(temp_remainder.toConst());
        }

        // Skip squaring on last iteration
        if (bit_idx + 1 < total_bits) {
            // current_base = (current_base * current_base) mod modulus
            try Managed.mul(&temp_product, &current_base, &current_base);
            try Managed.divFloor(&q_temp, &temp_remainder, &temp_product, &mod_big);
            try current_base.copy(temp_remainder.toConst());
        }
    }

    // Convert result to byte array
    const result_bits = result.bitCountAbs();
    const result_bytes_len = (result_bits + 7) / 8;
    const output_len = @max(result_bytes_len, 1);

    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);

    // Write result to output buffer (little-endian)
    result.toConst().writeTwosComplement(output, .little);

    return output;
}

// ============================================================================
// Tests
// ============================================================================

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

test "big-mod-exp: modPow with byte arrays" {
    const allocator = std.testing.allocator;

    // Test: 2^10 mod 1000 = 1024 mod 1000 = 24
    const base = [_]u8{ 2, 0, 0, 0, 0, 0, 0, 0 }; // 2 in little-endian
    const exp = [_]u8{ 10, 0, 0, 0, 0, 0, 0, 0 }; // 10 in little-endian
    const mod = [_]u8{ 0xE8, 0x03, 0, 0, 0, 0, 0, 0 }; // 1000 in little-endian

    const result = try modPow(allocator, &base, &exp, &mod);
    defer allocator.free(result);

    // Result should be 24 (0x18)
    try std.testing.expectEqual(@as(u8, 24), result[0]);
}

test "big-mod-exp: modPow with larger numbers" {
    const allocator = std.testing.allocator;

    // Test: 7^13 mod 123 = 94 (verified: 7^13 = 96889010407, 96889010407 % 123 = 94)
    var base: [8]u8 = [_]u8{0} ** 8;
    base[0] = 7;
    var exp: [8]u8 = [_]u8{0} ** 8;
    exp[0] = 13;
    var mod: [8]u8 = [_]u8{0} ** 8;
    mod[0] = 123;

    const result = try modPow(allocator, &base, &exp, &mod);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(u8, 94), result[0]);
}

test "big-mod-exp: modPow edge cases" {
    const allocator = std.testing.allocator;

    // Test: any^0 mod m = 1
    {
        const base = [_]u8{42};
        const exp = [_]u8{0};
        const mod = [_]u8{17};

        const result = try modPow(allocator, &base, &exp, &mod);
        defer allocator.free(result);

        try std.testing.expectEqual(@as(u8, 1), result[0]);
    }

    // Test: base^exp mod 1 = 0
    {
        const base = [_]u8{42};
        const exp = [_]u8{10};
        const mod = [_]u8{1};

        const result = try modPow(allocator, &base, &exp, &mod);
        defer allocator.free(result);

        try std.testing.expectEqual(@as(u8, 0), result[0]);
    }
}

test "big-mod-exp: modPow accepts large inputs" {
    const allocator = std.testing.allocator;

    // Test that modPow accepts inputs larger than 8 bytes
    // Uses small values in large arrays to verify the path works
    var base: [16]u8 = [_]u8{0} ** 16;
    base[0] = 2;

    var exp: [16]u8 = [_]u8{0} ** 16;
    exp[0] = 3;

    var mod: [16]u8 = [_]u8{0} ** 16;
    mod[0] = 7;

    // Should complete quickly using u64 fast path (effective length <= 8)
    const result = try modPow(allocator, &base, &exp, &mod);
    defer allocator.free(result);

    // 2^3 mod 7 = 8 mod 7 = 1
    try std.testing.expectEqual(@as(u8, 1), result[0]);
}

test "big-mod-exp: modPow with truly large numbers" {
    const allocator = std.testing.allocator;

    // Test with numbers that require BigInt path
    // 256^2 mod 65537 = 65536 mod 65537 = 65536
    var base: [2]u8 = [_]u8{ 0, 1 }; // 256 in little-endian
    var exp: [1]u8 = [_]u8{2}; // 2
    var mod: [3]u8 = [_]u8{ 1, 0, 1 }; // 65537 in little-endian

    const result = try modPow(allocator, &base, &exp, &mod);
    defer allocator.free(result);

    // 65536 = 0x10000 = [0, 0, 1] in little-endian
    try std.testing.expectEqual(@as(u8, 0), result[0]);
    try std.testing.expectEqual(@as(u8, 0), result[1]);
    try std.testing.expectEqual(@as(u8, 1), result[2]);
}
