//! Custom program error codes — Anchor-style `#[error_code]` for Zig.
//!
//! Programs typically need a small enum of program-specific errors
//! (Overflow, Unauthorized, NotInitialized, etc.) that the runtime
//! reports via the `Custom(u32)` wire format. This module provides a
//! one-line helper that:
//!
//!   1. Lets the user declare an `enum(u32)` of error codes — the
//!      `@intFromEnum` value goes on the wire as the custom error
//!      code.
//!   2. Declares a parallel `error{...}` set so the codes are usable
//!      in `try` chains alongside `ProgramError`. The two
//!      declarations are validated at comptime to have matching
//!      variant names.
//!   3. Bridges between the two: `toError(.X)` returns the matching
//!      error variant; `toU64(.X)` returns the runtime wire form.
//!
//! ## How custom codes survive to the wire
//!
//! Zig error sets can't carry payloads (every `error.X` is a global
//! interned name), and Solana programs **cannot use mutable global
//! state** (the SBPFv2 loader rejects `.bss` / `.data`). So unlike
//! Rust's `ProgramError::Custom(u32)`, we can't stash the
//! discriminator alongside `error.Custom`.
//!
//! Instead `ErrorCode(E, ErrSet)` ties an `enum(u32)` to an
//! `error{...}` set where the variants share names. The entrypoint's
//! `catch` block dispatches on the error name to recover the original
//! `u32` code. Cost: zero CU on the happy path.
//!
//! ## Example
//!
//! ```zig
//! const VaultErr = sol.ErrorCode(
//!     enum(u32) { Unauthorized = 6000, Overflow },
//!     error{ Unauthorized, Overflow },
//! );
//!
//! fn process(ctx: *InstructionContext) VaultErr.Error!void {
//!     try sol.system.transfer(...);                       // ProgramError
//!     if (bad) return VaultErr.toError(.Unauthorized);    // custom code
//! }
//!
//! export fn entrypoint(input: [*]u8) u64 {
//!     return sol.entrypoint.lazyEntrypointTyped(VaultErr, process)(input);
//! }
//! ```
//!
//! The variant duplication is intentional — Zig 0.16's compiler in
//! this fork doesn't expose `@Type` for synthesising error sets, so
//! we keep both lists side-by-side and validate they match at
//! comptime. Mismatched names produce a `@compileError`.

const std = @import("std");
const program_error = @import("program_error.zig");

const ProgramError = program_error.ProgramError;

/// Wrap a user `enum(u32)` + parallel error set so they act as a
/// typed custom-error namespace. The returned struct exposes:
///   - `Code`     — alias for the input enum.
///   - `ErrorSet` — the error set you passed.
///   - `Error`    — `ErrorSet || ProgramError`, for handler returns.
///   - `toU64(.X)` / `toError(.X)` / `catchToU64(err)`.
///
/// Validation: every field of `E` must have a same-named variant in
/// `ErrSet`, and vice-versa. Mismatches → `@compileError`.
pub fn ErrorCode(comptime E: type, comptime ErrSet: type) type {
    comptime {
        const einfo = @typeInfo(E);
        if (einfo != .@"enum") @compileError("ErrorCode(E, ErrSet): E must be an enum");
        const tag = einfo.@"enum".tag_type;
        if (tag != u32) @compileError("ErrorCode(E, ErrSet): E must be `enum(u32)` for runtime ABI compatibility");

        const sinfo = @typeInfo(ErrSet);
        if (sinfo != .error_set) @compileError("ErrorCode(E, ErrSet): ErrSet must be an error set type");
        const errs = sinfo.error_set orelse
            @compileError("ErrorCode(E, ErrSet): ErrSet must be a concrete error set, not anyerror");

        // Match field counts and names.
        if (einfo.@"enum".fields.len != errs.len) {
            @compileError("ErrorCode(E, ErrSet): E has " ++
                std.fmt.comptimePrint("{d}", .{einfo.@"enum".fields.len}) ++
                " variants but ErrSet has " ++
                std.fmt.comptimePrint("{d}", .{errs.len}));
        }
        for (einfo.@"enum".fields) |f| {
            var found = false;
            for (errs) |e| if (std.mem.eql(u8, f.name, e.name)) {
                found = true;
                break;
            };
            if (!found) {
                @compileError("ErrorCode: enum variant `" ++ f.name ++
                    "` has no matching error in ErrSet (add `" ++
                    f.name ++ "` to your error{...})");
            }
        }
    }

    return struct {
        pub const Code = E;
        pub const ErrorSet = ErrSet;
        pub const Error = ErrSet || ProgramError;

        /// Encode an error code into the runtime's `u64` wire format.
        /// Folded to a constant at monomorphic call sites.
        pub inline fn toU64(code: E) u64 {
            return program_error.customError(@intFromEnum(code));
        }

        /// Return the `ErrSet` variant whose name matches `code`'s
        /// enum tag.
        pub inline fn toError(comptime code: E) ErrSet {
            return @field(ErrSet, @tagName(code));
        }

        /// Map a caught `Error` back to its wire `u64`. Used by
        /// `lazyEntrypointTyped` / `programEntrypointTyped`.
        pub inline fn catchToU64(err: Error) u64 {
            inline for (@typeInfo(E).@"enum".fields) |f| {
                if (err == @field(ErrSet, f.name)) {
                    return program_error.customError(f.value);
                }
            }
            // Not a custom variant → it's a ProgramError.
            return program_error.errorToU64(@errorCast(err));
        }
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
const DemoErrSet = error{ NotInitialized, Overflow, Unauthorized };
const DemoErr = ErrorCode(Demo, DemoErrSet);

test "ErrorCode: toU64 passes through non-zero codes" {
    try std.testing.expectEqual(@as(u64, 6000), DemoErr.toU64(.NotInitialized));
    try std.testing.expectEqual(@as(u64, 6001), DemoErr.toU64(.Overflow));
}

test "ErrorCode: toU64 maps Custom(0) to sentinel" {
    const Zero = enum(u32) { ZeroCode = 0 };
    const ZeroErr = ErrorCode(Zero, error{ZeroCode});
    try std.testing.expectEqual(program_error.CUSTOM_ZERO, ZeroErr.toU64(.ZeroCode));
}

test "ErrorCode: toError returns matching ErrorSet variant" {
    const e: DemoErr.ErrorSet = DemoErr.toError(.Unauthorized);
    try std.testing.expectEqual(error.Unauthorized, e);
}

test "ErrorCode: catchToU64 maps custom variants to their u32 code" {
    try std.testing.expectEqual(@as(u64, 6000), DemoErr.catchToU64(error.NotInitialized));
    try std.testing.expectEqual(@as(u64, 6001), DemoErr.catchToU64(error.Overflow));
    try std.testing.expectEqual(@as(u64, 6002), DemoErr.catchToU64(error.Unauthorized));
}

test "ErrorCode: catchToU64 passes through ProgramError variants" {
    try std.testing.expectEqual(
        program_error.INVALID_ARGUMENT,
        DemoErr.catchToU64(error.InvalidArgument),
    );
    try std.testing.expectEqual(
        program_error.MISSING_REQUIRED_SIGNATURES,
        DemoErr.catchToU64(error.MissingRequiredSignature),
    );
}

test "ErrorCode: Error union combines both halves" {
    const make = struct {
        fn custom() DemoErr.Error!void {
            return DemoErr.toError(.Overflow);
        }
        fn builtin() DemoErr.Error!void {
            return error.InvalidArgument;
        }
        fn ok() DemoErr.Error!void {}
    };

    try std.testing.expectError(error.Overflow, make.custom());
    try std.testing.expectError(error.InvalidArgument, make.builtin());
    try make.ok();
}
