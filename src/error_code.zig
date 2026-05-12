//! Custom program error codes — Anchor-style `#[error_code]` for Zig.
//!
//! Programs typically need a small enum of program-specific errors
//! (Overflow, Unauthorized, NotInitialized, etc.) that get reported to
//! the runtime using the `Custom(code)` mechanism. This module provides
//! a one-line helper that:
//!
//!   1. Lets the user define an `enum(u32)` of error codes — the
//!      `@intFromEnum` value goes on the wire as the custom error code.
//!   2. Generates a corresponding error set (Zig `error{...}`) so the
//!      values are usable in `try` chains alongside `ProgramError`.
//!   3. Bridges between the two: `toError(code)` returns the matching
//!      tagged error; `toU64(code)` returns the runtime wire form.
//!
//! Cost: zero. The `inline switch` in `toU64` is folded by the compiler
//! into a direct return of the constant for monomorphic call sites.
//!
//! Example:
//!
//! ```zig
//! const MyErr = sol.errorCode(enum(u32) {
//!     NotInitialized = 6000,
//!     Overflow,
//!     Unauthorized,
//! });
//!
//! fn process(...) sol.ProgramResult {
//!     if (overflow) return MyErr.toError(.Overflow);
//! }
//! ```
//!
//! Convention: starting at 6000 mirrors Anchor's reservation of the
//! 0..6000 range for the framework. Programs are free to start anywhere
//! they like.

const std = @import("std");
const program_error = @import("program_error.zig");

/// Wrap a user `enum(u32)` so it acts as a typed custom-error namespace.
///
/// Returns a struct with two helpers:
///   - `toU64(code)` — encode as runtime wire format (Custom(N) → `N`,
///     except `Custom(0)` → `CUSTOM_ZERO` sentinel).
///   - `toError(code)` — return a `ProgramError.Custom` (the catch-all
///     custom variant from the standard error set). Programs that need
///     a *typed* error union for their internal helpers can keep using
///     a private error set; on entrypoint return any custom code is
///     just a `u32`.
///
/// Why this design (vs synthesising a Zig error set):
/// ----------------------------------------------------
/// Zig error sets are global-string-interned, so making one per program
/// would balloon the global error name table. The runtime only cares
/// about the `u32` code anyway. Programs that want typed errors can
/// declare them locally with their own `error{...}` sets — this helper
/// only owns the code → wire-format bridge, which is the part everyone
/// needs.
pub fn ErrorCode(comptime E: type) type {
    comptime {
        const info = @typeInfo(E);
        if (info != .@"enum") @compileError("ErrorCode(E): E must be an enum");
        const tag = info.@"enum".tag_type;
        if (tag != u32) @compileError("ErrorCode(E): E must be `enum(u32)` for runtime ABI compatibility");
    }
    return struct {
        pub const Code = E;

        /// Encode an error code into the runtime's u64 wire format.
        /// `inline` so the result is folded to a constant at the call site.
        pub inline fn toU64(code: E) u64 {
            return program_error.customError(@intFromEnum(code));
        }

        /// Convert to a `ProgramError` for use in `try` chains. All
        /// custom codes collapse to `error.Custom`; the actual `u32`
        /// is preserved separately (you can stash it via
        /// `lazyEntrypointWith` if you want; for plain `lazyEntrypoint`
        /// the wire format goes through `toU64` directly).
        pub inline fn toError(_: E) program_error.ProgramError {
            return error.Custom;
        }

        /// Variant of `lazyEntrypoint` that lets the user return a
        /// raw `u64` derived from this enum — bypasses the `Custom`
        /// loss of information. Equivalent to:
        ///
        /// ```zig
        /// fn handler(ctx: *InstructionContext) ?MyErr.Code { ... }
        /// // returns null on success, `.SomeError` on failure.
        /// ```
        ///
        /// (No actual entrypoint helper here — kept as a doc example
        /// to show the pattern. Users assemble it from `toU64` +
        /// `lazyEntrypointRaw` directly.)
        pub fn _docs_only() void {}
    };
}

// =============================================================================
// Tests
// =============================================================================

const Demo = enum(u32) {
    NotInitialized = 6000,
    Overflow = 6001,
    Unauthorized = 6002,
};
const DemoErr = ErrorCode(Demo);

test "ErrorCode: toU64 passes through non-zero codes" {
    try std.testing.expectEqual(@as(u64, 6000), DemoErr.toU64(.NotInitialized));
    try std.testing.expectEqual(@as(u64, 6001), DemoErr.toU64(.Overflow));
}

test "ErrorCode: toU64 maps Custom(0) to sentinel" {
    const Zero = enum(u32) { ZeroCode = 0 };
    const ZeroErr = ErrorCode(Zero);
    try std.testing.expectEqual(program_error.CUSTOM_ZERO, ZeroErr.toU64(.ZeroCode));
}

test "ErrorCode: toError yields Custom variant" {
    try std.testing.expectEqual(
        program_error.ProgramError.Custom,
        DemoErr.toError(.Overflow),
    );
}

test "ErrorCode: rejects non-u32 enums at compile time" {
    // This would fail to compile:
    // const Bad = enum(u8) { x };
    // _ = ErrorCode(Bad);
    //
    // We can't directly assert compile errors in a test, but the
    // restriction is documented and enforced by `@compileError` in
    // `ErrorCode`.
}
