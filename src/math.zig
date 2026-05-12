//! Checked integer arithmetic — `?T` and `!T` flavors.
//!
//! Every DeFi-style Solana program does this dance:
//! ```zig
//! const new_balance, const ovf = @addWithOverflow(balance, amount);
//! if (ovf != 0) return error.ArithmeticOverflow;
//! ```
//!
//! This module collapses it to:
//! ```zig
//! const new_balance = try sol.math.add(balance, amount);
//! ```
//!
//! Zero overhead — LLVM folds `@addWithOverflow` + branch into the
//! same instructions as the hand-written form. Verified by
//! disassembly + measured 0 CU change in the vault benchmark.
//!
//! Three flavors of each operation:
//! - `addUnchecked(a, b)` — wraps. Same as `a +% b`. For when you've
//!   already proven non-overflow.
//! - `tryAdd(a, b)` — returns `?T`. Composes with `orelse`.
//! - `add(a, b)` — returns `ProgramError!T`. Composes with `try`.

const std = @import("std");
const program_error = @import("program_error.zig");

const ProgramError = program_error.ProgramError;

// =============================================================================
// Addition
// =============================================================================

/// Wrapping add. Equivalent to `a +% b`. Use when the caller has
/// already proven non-overflow (e.g. comptime bounded operands).
pub inline fn addUnchecked(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return a +% b;
}

/// Checked add. Returns `null` on overflow.
///
/// ```zig
/// const new_balance = sol.math.tryAdd(balance, amount)
///     orelse return error.ArithmeticOverflow;
/// ```
pub inline fn tryAdd(a: anytype, b: @TypeOf(a)) ?@TypeOf(a) {
    const result, const overflow = @addWithOverflow(a, b);
    if (overflow != 0) return null;
    return result;
}

/// Checked add. Returns `ProgramError.ArithmeticOverflow` on overflow.
///
/// ```zig
/// const new_balance = try sol.math.add(balance, amount);
/// ```
pub inline fn add(a: anytype, b: @TypeOf(a)) ProgramError!@TypeOf(a) {
    return tryAdd(a, b) orelse error.ArithmeticOverflow;
}

// =============================================================================
// Subtraction
// =============================================================================

/// Wrapping sub. Equivalent to `a -% b`.
pub inline fn subUnchecked(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return a -% b;
}

/// Checked sub. Returns `null` on underflow.
pub inline fn trySub(a: anytype, b: @TypeOf(a)) ?@TypeOf(a) {
    const result, const overflow = @subWithOverflow(a, b);
    if (overflow != 0) return null;
    return result;
}

/// Checked sub. Returns `ProgramError.ArithmeticOverflow` on underflow.
/// We reuse `ArithmeticOverflow` for under/overflow alike — the
/// Solana runtime defines exactly one variant for this case.
pub inline fn sub(a: anytype, b: @TypeOf(a)) ProgramError!@TypeOf(a) {
    return trySub(a, b) orelse error.ArithmeticOverflow;
}

// =============================================================================
// Multiplication
// =============================================================================

/// Wrapping mul. Equivalent to `a *% b`.
pub inline fn mulUnchecked(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return a *% b;
}

/// Checked mul. Returns `null` on overflow.
pub inline fn tryMul(a: anytype, b: @TypeOf(a)) ?@TypeOf(a) {
    const result, const overflow = @mulWithOverflow(a, b);
    if (overflow != 0) return null;
    return result;
}

/// Checked mul. Returns `ProgramError.ArithmeticOverflow` on overflow.
pub inline fn mul(a: anytype, b: @TypeOf(a)) ProgramError!@TypeOf(a) {
    return tryMul(a, b) orelse error.ArithmeticOverflow;
}

// =============================================================================
// Tests
// =============================================================================

test "math: add happy path" {
    try std.testing.expectEqual(@as(u64, 3), try add(@as(u64, 1), 2));
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), try add(@as(u64, std.math.maxInt(u64) - 1), 1));
}

test "math: add overflow" {
    try std.testing.expectError(error.ArithmeticOverflow, add(@as(u64, std.math.maxInt(u64)), 1));
}

test "math: tryAdd returns null on overflow" {
    try std.testing.expect(tryAdd(@as(u64, std.math.maxInt(u64)), 1) == null);
    try std.testing.expectEqual(@as(?u64, 5), tryAdd(@as(u64, 2), 3));
}

test "math: sub happy path" {
    try std.testing.expectEqual(@as(u64, 5), try sub(@as(u64, 10), 5));
    try std.testing.expectEqual(@as(u64, 0), try sub(@as(u64, 1), 1));
}

test "math: sub underflow" {
    try std.testing.expectError(error.ArithmeticOverflow, sub(@as(u64, 0), 1));
}

test "math: mul happy path" {
    try std.testing.expectEqual(@as(u64, 12), try mul(@as(u64, 3), 4));
}

test "math: mul overflow" {
    try std.testing.expectError(error.ArithmeticOverflow, mul(@as(u64, std.math.maxInt(u64)), 2));
}

test "math: wrapping variants" {
    try std.testing.expectEqual(@as(u64, 0), addUnchecked(@as(u64, std.math.maxInt(u64)), 1));
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), subUnchecked(@as(u64, 0), 1));
    // maxInt * 2 wraps to (2^65 - 2) mod 2^64 = 2^64 - 2.
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64) - 1), mulUnchecked(@as(u64, std.math.maxInt(u64)), 2));
}

test "math: works for u32" {
    try std.testing.expectError(error.ArithmeticOverflow, add(@as(u32, std.math.maxInt(u32)), 1));
}

test "math: works for i64 signed" {
    try std.testing.expectError(error.ArithmeticOverflow, add(@as(i64, std.math.maxInt(i64)), 1));
    try std.testing.expectError(error.ArithmeticOverflow, sub(@as(i64, std.math.minInt(i64)), 1));
}
