//! Anchor-style `require!` family — assert-and-log-and-return.
//!
//! Each helper is the Zig analogue of one of Anchor's `require_*!`
//! macros, with the same trade-off: on the happy path it compiles down
//! to a single `if` + branch (zero overhead, fully inline); on failure
//! it logs the comptime tag and returns the supplied `ProgramError`.
//!
//! Why use these instead of an inline `if (...) return error.X;`? Two
//! reasons:
//!
//!   1. **The log tag pinpoints the failure** on Explorer / RPC logs.
//!      The wire return code is a coarse builtin (`InvalidArgument`,
//!      `IncorrectAuthority`, …) so without the tag you can't tell
//!      which constraint actually fired.
//!   2. **One name per shape** — comparing two pubkeys is its own
//!      idiom worth naming; the comptime variant folds the 32-byte
//!      compare into four `u64`-immediate compares.
//!
//! Anchor parity table:
//!
//! | Anchor (Rust) | This SDK (Zig) |
//! |---|---|
//! | `require!(cond, err)` | `try sol.require(@src(), cond, "tag", err)` |
//! | `require_eq!(a, b, err)` | `try sol.requireEq(@src(), a, b, "tag", err)` |
//! | `require_neq!(a, b, err)` | `try sol.requireNeq(@src(), a, b, "tag", err)` |
//! | `require_keys_eq!(a, b, err)` | `try sol.requireKeysEq(@src(), &a, &b, "tag", err)` |
//! | `require_keys_neq!(a, b, err)` | `try sol.requireKeysNeq(@src(), &a, &b, "tag", err)` |
//!
//! Tag convention: `"<module>:<reason>"` — keep it short, every byte
//! costs ~1 CU when the failure path runs.
//!
//! ## Why `@src()` is the first argument
//!
//! Anchor's macros automatically pick up `file!()` / `line!()` at the
//! call site. Zig's `@src()` is a builtin not a macro — it expands at
//! the function definition site, so a helper that calls `@src()`
//! internally gets *its own* file:line, not the caller's. The only way
//! to surface caller-site context is to take it as a parameter. The
//! cost is 8 characters per callsite (`@src(), `); the payoff is a log
//! line that looks like `vault.zig:142 vault:wrong_authority`.

const std = @import("std");
const program_error = @import("program_error/root.zig");
const pubkey_mod = @import("pubkey.zig");

const ProgramError = program_error.ProgramError;
const Pubkey = pubkey_mod.Pubkey;

/// Assert `cond`, else log `<file>:<line> <tag>` and return `err`.
///
/// Equivalent to Anchor's `require!(cond, err)` macro.
pub inline fn require(
    comptime src: std.builtin.SourceLocation,
    cond: bool,
    comptime tag: []const u8,
    err: ProgramError,
) ProgramError!void {
    if (!cond) return program_error.fail(src, tag, err);
}

/// Assert `a == b` (any equality-comparable type), else log + fail.
///
/// Works for any type that `std.meta.eql` supports. For `Pubkey`
/// (`[32]u8`) prefer `requireKeysEq` — it goes through the
/// hand-tuned 4×u64 compare path.
pub inline fn requireEq(
    comptime src: std.builtin.SourceLocation,
    a: anytype,
    b: @TypeOf(a),
    comptime tag: []const u8,
    err: ProgramError,
) ProgramError!void {
    if (!std.meta.eql(a, b)) return program_error.fail(src, tag, err);
}

/// Assert `a != b`, else log + fail.
pub inline fn requireNeq(
    comptime src: std.builtin.SourceLocation,
    a: anytype,
    b: @TypeOf(a),
    comptime tag: []const u8,
    err: ProgramError,
) ProgramError!void {
    if (std.meta.eql(a, b)) return program_error.fail(src, tag, err);
}

/// Assert two `Pubkey`s are equal, else log + fail.
///
/// Routes through `pubkey.pubkeyEq` which lowers to a 4×u64
/// immediate compare — much cheaper than a generic `meta.eql` over
/// `[32]u8`.
pub inline fn requireKeysEq(
    comptime src: std.builtin.SourceLocation,
    a: *const Pubkey,
    b: *const Pubkey,
    comptime tag: []const u8,
    err: ProgramError,
) ProgramError!void {
    if (!pubkey_mod.pubkeyEq(a, b)) return program_error.fail(src, tag, err);
}

/// Assert two `Pubkey`s differ, else log + fail.
pub inline fn requireKeysNeq(
    comptime src: std.builtin.SourceLocation,
    a: *const Pubkey,
    b: *const Pubkey,
    comptime tag: []const u8,
    err: ProgramError,
) ProgramError!void {
    if (pubkey_mod.pubkeyEq(a, b)) return program_error.fail(src, tag, err);
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "require: passes on true, fails with err on false" {
    try require(@src(), true, "ok", error.InvalidArgument);
    try testing.expectError(
        error.InvalidArgument,
        require(@src(), false, "fail:test", error.InvalidArgument),
    );
}

test "requireEq / requireNeq for ints" {
    try requireEq(@src(), @as(u64, 7), @as(u64, 7), "eq:ok", error.InvalidArgument);
    try testing.expectError(
        error.InvalidArgument,
        requireEq(@src(), @as(u64, 7), @as(u64, 8), "eq:fail", error.InvalidArgument),
    );
    try requireNeq(@src(), @as(u64, 7), @as(u64, 8), "neq:ok", error.InvalidArgument);
    try testing.expectError(
        error.InvalidArgument,
        requireNeq(@src(), @as(u64, 7), @as(u64, 7), "neq:fail", error.InvalidArgument),
    );
}

test "requireKeysEq / requireKeysNeq" {
    const a: Pubkey = .{1} ** 32;
    const b: Pubkey = .{1} ** 32;
    const c: Pubkey = .{2} ** 32;
    try requireKeysEq(@src(), &a, &b, "keyseq:ok", error.IncorrectAuthority);
    try testing.expectError(
        error.IncorrectAuthority,
        requireKeysEq(@src(), &a, &c, "keyseq:fail", error.IncorrectAuthority),
    );
    try requireKeysNeq(@src(), &a, &c, "keysneq:ok", error.IncorrectAuthority);
    try testing.expectError(
        error.IncorrectAuthority,
        requireKeysNeq(@src(), &a, &b, "keysneq:fail", error.IncorrectAuthority),
    );
}
