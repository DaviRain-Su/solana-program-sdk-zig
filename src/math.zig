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
const program_error = @import("program_error/root.zig");

const ProgramError = program_error.ProgramError;

pub const ArithmeticError = error{
    InvalidArgument,
    ArithmeticOverflow,
};

pub const SlippageError = error{SlippageExceeded};
pub const RouterMathError = ArithmeticError || SlippageError;

pub const Rounding = enum {
    down,
    up,
};

pub const SlippageBound = enum {
    min_out,
    max_in,
};

pub const BASIS_POINTS_DENOMINATOR: u64 = 10_000;
pub const PARTS_PER_MILLION_DENOMINATOR: u64 = 1_000_000;

inline fn requireUnsignedInt(comptime T: type) void {
    comptime {
        const info = @typeInfo(T);
        if (info != .int or info.int.signedness != .unsigned) {
            @compileError("router math helpers require an unsigned integer type");
        }
    }
}

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
// Router-grade division / mulDiv / fees / slippage
// =============================================================================

/// Checked truncating division. Returns `error.InvalidArgument` for a
/// zero denominator and `error.ArithmeticOverflow` for signed overflow
/// (`minInt / -1`).
pub inline fn checkedDiv(a: anytype, b: @TypeOf(a)) ArithmeticError!@TypeOf(a) {
    const T = @TypeOf(a);
    if (b == 0) return error.InvalidArgument;

    const info = @typeInfo(T);
    if (info == .int and info.int.signedness == .signed and a == std.math.minInt(T) and b == -1) {
        return error.ArithmeticOverflow;
    }

    return @divTrunc(a, b);
}

/// Optional-returning version of `checkedDiv`.
pub inline fn tryCheckedDiv(a: anytype, b: @TypeOf(a)) ?@TypeOf(a) {
    return checkedDiv(a, b) catch null;
}

/// Multiply `a * b`, divide by `denominator`, and apply the explicit
/// rounding mode. Uses a double-width intermediate (`u128` for `u64`)
/// so intermediate multiplication never truncates.
pub inline fn mulDiv(
    a: anytype,
    b: @TypeOf(a),
    denominator: @TypeOf(a),
    rounding: Rounding,
) ArithmeticError!@TypeOf(a) {
    const T = @TypeOf(a);
    requireUnsignedInt(T);

    if (denominator == 0) return error.InvalidArgument;

    const wide = std.math.mulWide(T, a, b);
    const WideT = @TypeOf(wide);
    const denominator_wide: WideT = denominator;
    const quotient_wide = @divTrunc(wide, denominator_wide);
    if (quotient_wide > std.math.maxInt(T)) return error.ArithmeticOverflow;

    var quotient: T = @intCast(quotient_wide);
    if (rounding == .up and @rem(wide, denominator_wide) != 0) {
        quotient = tryAdd(quotient, 1) orelse return error.ArithmeticOverflow;
    }
    return quotient;
}

/// Optional-returning version of `mulDiv`.
pub inline fn tryMulDiv(
    a: anytype,
    b: @TypeOf(a),
    denominator: @TypeOf(a),
    rounding: Rounding,
) ?@TypeOf(a) {
    return mulDiv(a, b, denominator, rounding) catch null;
}

inline fn requireFeeScale(rate: anytype, denominator: @TypeOf(rate)) ArithmeticError!void {
    if (denominator == 0 or rate > denominator) return error.InvalidArgument;
}

/// Compute a fee amount with an explicit denominator and rounding
/// policy.
pub inline fn feeAmount(
    amount: anytype,
    rate: @TypeOf(amount),
    denominator: @TypeOf(amount),
    rounding: Rounding,
) ArithmeticError!@TypeOf(amount) {
    requireUnsignedInt(@TypeOf(amount));
    try requireFeeScale(rate, denominator);
    return mulDiv(amount, rate, denominator, rounding);
}

pub inline fn feeAmountBps(amount: anytype, bps: @TypeOf(amount), rounding: Rounding) ArithmeticError!@TypeOf(amount) {
    const T = @TypeOf(amount);
    requireUnsignedInt(T);
    return feeAmount(amount, bps, @as(T, BASIS_POINTS_DENOMINATOR), rounding);
}

pub inline fn feeAmountPpm(amount: anytype, ppm: @TypeOf(amount), rounding: Rounding) ArithmeticError!@TypeOf(amount) {
    const T = @TypeOf(amount);
    requireUnsignedInt(T);
    return feeAmount(amount, ppm, @as(T, PARTS_PER_MILLION_DENOMINATOR), rounding);
}

/// Subtract the computed fee from `amount`, rejecting underflow.
pub inline fn amountAfterFee(
    amount: anytype,
    rate: @TypeOf(amount),
    denominator: @TypeOf(amount),
    rounding: Rounding,
) ArithmeticError!@TypeOf(amount) {
    requireUnsignedInt(@TypeOf(amount));
    const fee = try feeAmount(amount, rate, denominator, rounding);
    return trySub(amount, fee) orelse error.ArithmeticOverflow;
}

pub inline fn amountAfterFeeBps(
    amount: anytype,
    bps: @TypeOf(amount),
    rounding: Rounding,
) ArithmeticError!@TypeOf(amount) {
    const T = @TypeOf(amount);
    requireUnsignedInt(T);
    return amountAfterFee(amount, bps, @as(T, BASIS_POINTS_DENOMINATOR), rounding);
}

pub inline fn amountAfterFeePpm(
    amount: anytype,
    ppm: @TypeOf(amount),
    rounding: Rounding,
) ArithmeticError!@TypeOf(amount) {
    const T = @TypeOf(amount);
    requireUnsignedInt(T);
    return amountAfterFee(amount, ppm, @as(T, PARTS_PER_MILLION_DENOMINATOR), rounding);
}

/// Derive a slippage threshold from an expected amount. `.min_out`
/// subtracts the tolerance; `.max_in` adds it.
pub inline fn deriveSlippageThreshold(
    expected_amount: anytype,
    tolerance: @TypeOf(expected_amount),
    denominator: @TypeOf(expected_amount),
    bound: SlippageBound,
    rounding: Rounding,
) ArithmeticError!@TypeOf(expected_amount) {
    requireUnsignedInt(@TypeOf(expected_amount));
    const delta = try feeAmount(expected_amount, tolerance, denominator, rounding);
    return switch (bound) {
        .min_out => trySub(expected_amount, delta) orelse error.ArithmeticOverflow,
        .max_in => tryAdd(expected_amount, delta) orelse error.ArithmeticOverflow,
    };
}

pub inline fn deriveSlippageThresholdBps(
    expected_amount: anytype,
    bps: @TypeOf(expected_amount),
    bound: SlippageBound,
    rounding: Rounding,
) ArithmeticError!@TypeOf(expected_amount) {
    const T = @TypeOf(expected_amount);
    requireUnsignedInt(T);
    return deriveSlippageThreshold(expected_amount, bps, @as(T, BASIS_POINTS_DENOMINATOR), bound, rounding);
}

pub inline fn deriveSlippageThresholdPpm(
    expected_amount: anytype,
    ppm: @TypeOf(expected_amount),
    bound: SlippageBound,
    rounding: Rounding,
) ArithmeticError!@TypeOf(expected_amount) {
    const T = @TypeOf(expected_amount);
    requireUnsignedInt(T);
    return deriveSlippageThreshold(expected_amount, ppm, @as(T, PARTS_PER_MILLION_DENOMINATOR), bound, rounding);
}

pub inline fn deriveMinOutBps(
    expected_amount: anytype,
    bps: @TypeOf(expected_amount),
    rounding: Rounding,
) ArithmeticError!@TypeOf(expected_amount) {
    return deriveSlippageThresholdBps(expected_amount, bps, .min_out, rounding);
}

pub inline fn deriveMinOutPpm(
    expected_amount: anytype,
    ppm: @TypeOf(expected_amount),
    rounding: Rounding,
) ArithmeticError!@TypeOf(expected_amount) {
    return deriveSlippageThresholdPpm(expected_amount, ppm, .min_out, rounding);
}

/// Require `actual_out >= min_out`.
pub inline fn requireMinOut(actual_out: anytype, min_out: @TypeOf(actual_out)) SlippageError!void {
    if (actual_out < min_out) return error.SlippageExceeded;
}

/// Derive the minimum acceptable output from an expected amount and
/// then enforce it.
pub inline fn requireSlippage(
    actual_out: anytype,
    expected_out: @TypeOf(actual_out),
    tolerance: @TypeOf(actual_out),
    denominator: @TypeOf(actual_out),
    rounding: Rounding,
) RouterMathError!void {
    const min_out = try deriveSlippageThreshold(expected_out, tolerance, denominator, .min_out, rounding);
    try requireMinOut(actual_out, min_out);
}

pub inline fn requireSlippageBps(
    actual_out: anytype,
    expected_out: @TypeOf(actual_out),
    bps: @TypeOf(actual_out),
    rounding: Rounding,
) RouterMathError!void {
    const T = @TypeOf(actual_out);
    requireUnsignedInt(T);
    return requireSlippage(actual_out, expected_out, bps, @as(T, BASIS_POINTS_DENOMINATOR), rounding);
}

pub inline fn requireSlippagePpm(
    actual_out: anytype,
    expected_out: @TypeOf(actual_out),
    ppm: @TypeOf(actual_out),
    rounding: Rounding,
) RouterMathError!void {
    const T = @TypeOf(actual_out);
    requireUnsignedInt(T);
    return requireSlippage(actual_out, expected_out, ppm, @as(T, PARTS_PER_MILLION_DENOMINATOR), rounding);
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

test "math: checkedDiv rejects zero and preserves quotient semantics" {
    const Case = struct {
        numerator: u64,
        denominator: u64,
        expected: u64,
    };

    const cases = [_]Case{
        .{ .numerator = 5, .denominator = 2, .expected = 2 },
        .{ .numerator = 0, .denominator = 9, .expected = 0 },
        .{ .numerator = std.math.maxInt(u64), .denominator = std.math.maxInt(u64), .expected = 1 },
        .{ .numerator = std.math.maxInt(u64), .denominator = 2, .expected = std.math.maxInt(u64) / 2 },
    };

    try std.testing.expectError(error.InvalidArgument, checkedDiv(@as(u64, 1), 0));
    try std.testing.expect(tryCheckedDiv(@as(u64, 1), 0) == null);

    inline for (cases) |case| {
        try std.testing.expectEqual(case.expected, try checkedDiv(case.numerator, case.denominator));
        try std.testing.expectEqual(case.expected, tryCheckedDiv(case.numerator, case.denominator).?);
    }
}

test "math: mulDiv uses double-width intermediate and rejects overflow" {
    try std.testing.expectEqual(
        std.math.maxInt(u64),
        try mulDiv(@as(u64, std.math.maxInt(u64)), std.math.maxInt(u64), std.math.maxInt(u64), .down),
    );
    try std.testing.expectError(
        error.ArithmeticOverflow,
        mulDiv(@as(u64, std.math.maxInt(u64)), std.math.maxInt(u64), 1, .down),
    );
    try std.testing.expectError(error.InvalidArgument, mulDiv(@as(u64, 9), 3, 0, .down));
    try std.testing.expect(tryMulDiv(@as(u64, 9), 3, 0, .down) == null);
}

test "math: mulDiv rounding modes are explicit and correct" {
    try std.testing.expectEqual(@as(u64, 4), try mulDiv(@as(u64, 12), 1, 3, .down));
    try std.testing.expectEqual(@as(u64, 4), try mulDiv(@as(u64, 12), 1, 3, .up));
    try std.testing.expectEqual(@as(u64, 3), try mulDiv(@as(u64, 7), 1, 2, .down));
    try std.testing.expectEqual(@as(u64, 4), try mulDiv(@as(u64, 7), 1, 2, .up));
    try std.testing.expectEqual(@as(u64, 0), try mulDiv(@as(u64, 0), 9, 7, .up));
    try std.testing.expectEqual(@as(u64, 1), try mulDiv(@as(u64, 1), 1, std.math.maxInt(u64), .up));
    try std.testing.expectError(
        error.ArithmeticOverflow,
        mulDiv(@as(u8, 254), 202, 201, .up),
    );
}

test "math: fee helpers use explicit denominators and rounding" {
    try std.testing.expectEqual(@as(u64, 123), try feeAmountBps(@as(u64, 12_300), 100, .down));
    try std.testing.expectEqual(@as(u64, 124), try feeAmountBps(@as(u64, 12_301), 100, .up));
    try std.testing.expectEqual(@as(u64, 250), try feeAmountPpm(@as(u64, 1_000_000), 250, .down));
    try std.testing.expectEqual(@as(u64, 251), try feeAmountPpm(@as(u64, 1_000_001), 250, .up));
    try std.testing.expectError(error.InvalidArgument, feeAmountBps(@as(u64, 100), 10_001, .down));
    try std.testing.expectError(error.InvalidArgument, feeAmountPpm(@as(u64, 100), 1_000_001, .up));
}

test "math: amountAfterFee rejects underflow and allows exact full fee" {
    try std.testing.expectEqual(@as(u64, 0), try amountAfterFeeBps(@as(u64, 50), 10_000, .down));
    try std.testing.expectEqual(@as(u64, 9), try amountAfterFee(@as(u64, 10), 1, 10, .down));
    try std.testing.expectError(error.InvalidArgument, amountAfterFee(@as(u64, 10), 11, 10, .down));
}

test "math: min-out and slippage checks accept equality and reject below threshold" {
    try requireMinOut(@as(u64, 50), 50);
    try std.testing.expectError(error.SlippageExceeded, requireMinOut(@as(u64, 49), 50));
    try requireMinOut(@as(u64, 0), 0);
    try std.testing.expectError(error.SlippageExceeded, requireMinOut(@as(u64, 0), 1));

    try requireSlippageBps(@as(u64, 95), 100, 500, .down);
    try std.testing.expectError(error.SlippageExceeded, requireSlippageBps(@as(u64, 94), 100, 500, .down));
    try requireSlippageBps(@as(u64, 0), 0, 500, .down);
    try requireSlippagePpm(@as(u64, 1_000_000), 1_000_000, 0, .down);
}

test "math: derived slippage thresholds use checked math" {
    try std.testing.expectEqual(@as(u64, 95), try deriveMinOutBps(@as(u64, 100), 500, .down));
    try std.testing.expectEqual(@as(u64, 999_000), try deriveMinOutPpm(@as(u64, 1_000_000), 1_000, .down));
    try std.testing.expectEqual(@as(u64, 106), try deriveSlippageThresholdBps(@as(u64, 100), 550, .max_in, .up));
    try std.testing.expectError(
        error.ArithmeticOverflow,
        deriveSlippageThreshold(@as(u64, std.math.maxInt(u64)), 1, 1, .max_in, .up),
    );
}
