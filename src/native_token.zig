//! Zig implementation of Solana SDK's native-token module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/native-token/src/lib.rs
//!
//! Definitions for the native SOL token and its fractional lamports.
//!
//! SOL is the native token of the Solana blockchain. Lamports are the smallest
//! unit of SOL, similar to how satoshis relate to Bitcoin or wei to Ethereum.

const std = @import("std");

/// There are 10^9 lamports in one SOL
pub const LAMPORTS_PER_SOL: u64 = 1_000_000_000;

/// Number of decimal places for SOL
pub const SOL_DECIMALS: u8 = 9;

/// The SOL symbol for display purposes
pub const SOL_SYMBOL: []const u8 = "◎";

/// Wrapper type for displaying lamports as SOL with proper formatting.
///
/// This provides a convenient way to format lamport amounts as SOL values
/// with the SOL symbol and proper decimal places.
///
/// Rust equivalent: `solana_native_token::Sol`
pub const Sol = struct {
    lamports: u64,

    /// Create a Sol from a lamport amount
    pub fn fromLamports(lamports: u64) Sol {
        return .{ .lamports = lamports };
    }

    /// Create a Sol from a SOL amount (may lose precision for large values)
    pub fn fromSol(sol: f64) Sol {
        const lamports: u64 = @intFromFloat(sol * @as(f64, @floatFromInt(LAMPORTS_PER_SOL)));
        return .{ .lamports = lamports };
    }

    /// Get the integer SOL portion
    pub fn wholeSol(self: Sol) u64 {
        return self.lamports / LAMPORTS_PER_SOL;
    }

    /// Get the fractional lamports (remainder after whole SOL)
    pub fn fractionalLamports(self: Sol) u64 {
        return self.lamports % LAMPORTS_PER_SOL;
    }

    /// Convert to f64 (may lose precision for very large values)
    pub fn toF64(self: Sol) f64 {
        return @as(f64, @floatFromInt(self.lamports)) / @as(f64, @floatFromInt(LAMPORTS_PER_SOL));
    }

    /// Format as SOL with symbol: ◎{integer}.{fractional:09}
    ///
    /// Rust equivalent: `impl fmt::Display for Sol`
    pub fn format(self: Sol, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const integer = self.wholeSol();
        const fractional = self.fractionalLamports();
        try writer.print("{s}{d}.{d:0>9}", .{ SOL_SYMBOL, integer, fractional });
    }
};

/// Convert a SOL string representation to lamports.
///
/// Parses a string like "1.5" or "0.000000001" and converts to lamports.
/// Supports up to 9 decimal places (full lamport precision).
///
/// Returns null for invalid inputs:
/// - Negative numbers (starting with '-')
/// - Values exceeding u64 max
/// - Invalid format (e.g., just ".", empty string, multiple decimal points)
/// - Non-numeric characters
///
/// Examples:
/// - "1" -> 1_000_000_000
/// - "0.5" -> 500_000_000
/// - "1.123456789" -> 1_123_456_789
/// - "0.000000001" -> 1
///
/// Rust equivalent: `solana_native_token::sol_str_to_lamports`
pub fn solStrToLamports(sol_str: []const u8) ?u64 {
    if (sol_str.len == 0) return null;

    // Check for negative numbers
    if (sol_str[0] == '-') return null;

    // Find decimal point
    var decimal_pos: ?usize = null;
    for (sol_str, 0..) |c, i| {
        if (c == '.') {
            if (decimal_pos != null) return null; // Multiple decimal points
            decimal_pos = i;
        }
    }

    // Handle case of just "."
    if (decimal_pos != null and sol_str.len == 1) return null;

    var integer_part: u64 = 0;
    var fractional_lamports: u64 = 0;

    if (decimal_pos) |pos| {
        // Parse integer part (before decimal)
        if (pos > 0) {
            integer_part = std.fmt.parseUnsigned(u64, sol_str[0..pos], 10) catch return null;
        }

        // Parse fractional part (after decimal)
        const frac_str = sol_str[pos + 1 ..];
        if (frac_str.len > 0) {
            if (frac_str.len > SOL_DECIMALS) {
                // Too many decimal places - could truncate or return null
                // Following Rust behavior: parse first 9 digits
                const truncated = frac_str[0..SOL_DECIMALS];
                fractional_lamports = std.fmt.parseUnsigned(u64, truncated, 10) catch return null;
            } else {
                // Pad with zeros to get full lamport precision
                const parsed = std.fmt.parseUnsigned(u64, frac_str, 10) catch return null;
                // Multiply by 10^(9 - len) to scale up
                const scale = std.math.pow(u64, 10, SOL_DECIMALS - @as(u8, @intCast(frac_str.len)));
                fractional_lamports = parsed * scale;
            }
        }
    } else {
        // No decimal point - just an integer SOL amount
        integer_part = std.fmt.parseUnsigned(u64, sol_str, 10) catch return null;
    }

    // Calculate total lamports with overflow check
    const integer_lamports = @mulWithOverflow(integer_part, LAMPORTS_PER_SOL);
    if (integer_lamports[1] != 0) return null; // Overflow

    const total = @addWithOverflow(integer_lamports[0], fractional_lamports);
    if (total[1] != 0) return null; // Overflow

    return total[0];
}

/// Convert lamports to SOL as f64 (may lose precision for very large values)
///
/// This is a convenience function for display purposes. For precise calculations,
/// use the Sol struct or work directly with lamports.
pub fn lamportsToSol(lamports: u64) f64 {
    return @as(f64, @floatFromInt(lamports)) / @as(f64, @floatFromInt(LAMPORTS_PER_SOL));
}

/// Convert SOL (f64) to lamports (may lose precision, use solStrToLamports for exact)
///
/// Note: This uses floating point math which can introduce small errors.
/// For exact conversions, use solStrToLamports with a string representation.
pub fn solToLamports(sol: f64) u64 {
    if (sol < 0) return 0;
    const result = sol * @as(f64, @floatFromInt(LAMPORTS_PER_SOL));
    if (result > @as(f64, @floatFromInt(std.math.maxInt(u64)))) {
        return std.math.maxInt(u64);
    }
    return @intFromFloat(result);
}

// ============================================================================
// Tests
// ============================================================================

test "native_token: constants" {
    try std.testing.expectEqual(@as(u64, 1_000_000_000), LAMPORTS_PER_SOL);
    try std.testing.expectEqual(@as(u8, 9), SOL_DECIMALS);
}

test "native_token: Sol formatting" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    // Zero
    {
        fbs.reset();
        const sol = Sol.fromLamports(0);
        try sol.format("", .{}, fbs.writer());
        try std.testing.expectEqualStrings("◎0.000000000", fbs.getWritten());
    }

    // One SOL
    {
        fbs.reset();
        const sol = Sol.fromLamports(LAMPORTS_PER_SOL);
        try sol.format("", .{}, fbs.writer());
        try std.testing.expectEqualStrings("◎1.000000000", fbs.getWritten());
    }

    // 1.5 SOL
    {
        fbs.reset();
        const sol = Sol.fromLamports(1_500_000_000);
        try sol.format("", .{}, fbs.writer());
        try std.testing.expectEqualStrings("◎1.500000000", fbs.getWritten());
    }

    // 1 lamport
    {
        fbs.reset();
        const sol = Sol.fromLamports(1);
        try sol.format("", .{}, fbs.writer());
        try std.testing.expectEqualStrings("◎0.000000001", fbs.getWritten());
    }
}

test "native_token: Sol methods" {
    const sol = Sol.fromLamports(1_234_567_890);
    try std.testing.expectEqual(@as(u64, 1), sol.wholeSol());
    try std.testing.expectEqual(@as(u64, 234_567_890), sol.fractionalLamports());
}

test "native_token: solStrToLamports basic conversions" {
    // Zero
    try std.testing.expectEqual(@as(?u64, 0), solStrToLamports("0"));
    try std.testing.expectEqual(@as(?u64, 0), solStrToLamports("0.0"));
    try std.testing.expectEqual(@as(?u64, 0), solStrToLamports("0.000000000"));

    // One lamport
    try std.testing.expectEqual(@as(?u64, 1), solStrToLamports("0.000000001"));

    // One SOL
    try std.testing.expectEqual(@as(?u64, 1_000_000_000), solStrToLamports("1"));
    try std.testing.expectEqual(@as(?u64, 1_000_000_000), solStrToLamports("1.0"));
    try std.testing.expectEqual(@as(?u64, 1_000_000_000), solStrToLamports("1.000000000"));

    // Various decimal places
    try std.testing.expectEqual(@as(?u64, 100_000_000), solStrToLamports("0.1"));
    try std.testing.expectEqual(@as(?u64, 500_000_000), solStrToLamports("0.5"));
    try std.testing.expectEqual(@as(?u64, 4_100_000_000), solStrToLamports("4.1"));
    try std.testing.expectEqual(@as(?u64, 8_502_282_880), solStrToLamports("8.50228288"));
    try std.testing.expectEqual(@as(?u64, 1_123_456_789), solStrToLamports("1.123456789"));
}

test "native_token: solStrToLamports edge cases" {
    // Max u64 value (18446744073.709551615 SOL)
    try std.testing.expectEqual(@as(?u64, std.math.maxInt(u64)), solStrToLamports("18446744073.709551615"));

    // Overflow - returns null
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("18446744073.709551616"));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("18446744074"));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("999999999999999999999"));

    // Invalid formats
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports(""));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("."));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports(".."));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("1..0"));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("abc"));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("1.2.3"));

    // Negative numbers
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("-1"));
    try std.testing.expectEqual(@as(?u64, null), solStrToLamports("-0.000000001"));
}

test "native_token: solStrToLamports decimal edge cases" {
    // Just decimal with digits
    try std.testing.expectEqual(@as(?u64, 100_000_000), solStrToLamports(".1"));

    // Trailing zeros
    try std.testing.expectEqual(@as(?u64, 1_000_000_000), solStrToLamports("1.00000000000"));

    // Large integer part
    try std.testing.expectEqual(@as(?u64, 1000_000_000_000), solStrToLamports("1000"));
}

test "native_token: lamportsToSol" {
    try std.testing.expectApproxEqRel(@as(f64, 0.0), lamportsToSol(0), 0.0001);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), lamportsToSol(LAMPORTS_PER_SOL), 0.0001);
    try std.testing.expectApproxEqRel(@as(f64, 1.5), lamportsToSol(1_500_000_000), 0.0001);
    try std.testing.expectApproxEqRel(@as(f64, 0.000000001), lamportsToSol(1), 0.0001);
}

test "native_token: solToLamports" {
    try std.testing.expectEqual(@as(u64, 0), solToLamports(0.0));
    try std.testing.expectEqual(@as(u64, 1_000_000_000), solToLamports(1.0));
    try std.testing.expectEqual(@as(u64, 1_500_000_000), solToLamports(1.5));
    try std.testing.expectEqual(@as(u64, 0), solToLamports(-1.0)); // Negative returns 0
}

test "native_token: roundtrip conversion" {
    const original: u64 = 1_234_567_890;
    const sol_f64 = lamportsToSol(original);
    const back = solToLamports(sol_f64);
    // Note: May have small precision loss with f64
    try std.testing.expectEqual(original, back);
}
