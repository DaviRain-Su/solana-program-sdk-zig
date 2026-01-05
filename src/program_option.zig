//! Zig implementation of Solana SDK's program-option module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-option/src/lib.rs
//!
//! This module provides a C-compatible Option type for use in Solana programs.
//! Unlike Zig's native `?T` type, COption<T> has a stable, predictable memory layout
//! that is compatible with C ABIs and can be safely used across FFI boundaries.
//!
//! ## Key Features
//! - C-compatible memory layout
//! - No null pointer optimization (always same size regardless of T)
//! - Safe and explicit handling of optional values
//! - Serialization support

const std = @import("std");

/// A C-compatible Option type that can be safely used across FFI boundaries.
///
/// This is equivalent to Rust's `COption<T>` from the `solana-program-option` crate.
/// Unlike Zig's `?T`, this type has a predictable size and layout that is compatible
/// with C ABIs, making it suitable for use in Solana programs that need to interface
/// with C code or maintain stable memory layouts.
///
/// The layout is:
/// ```zig
/// COption(T) = extern struct {
///     is_some: bool,
///     value: T,  // present regardless of is_some value
/// }
/// ```
pub fn COption(comptime T: type) type {
    return extern struct {
        const Self = @This();

        /// Whether this option contains a value
        is_some: bool,

        /// The contained value (present regardless of is_some for C compatibility)
        value: T,

        /// Create an option containing a value
        pub fn some(value: T) Self {
            return .{
                .is_some = true,
                .value = value,
            };
        }

        /// Create an empty option
        pub fn none() Self {
            return .{
                .is_some = false,
                .value = undefined,
            };
        }

        /// Create an option from a Zig optional value
        pub fn fromOptional(optional: ?T) Self {
            return if (optional) |value| Self.some(value) else Self.none();
        }

        /// Check if this option contains a value
        pub fn isSome(self: Self) bool {
            return self.is_some;
        }

        /// Check if this option is empty
        pub fn isNone(self: Self) bool {
            return !self.is_some;
        }

        /// Get a reference to the contained value, or null if empty
        pub fn asRef(self: *const Self) ?*const T {
            return if (self.is_some) &self.value else null;
        }

        /// Get a mutable reference to the contained value, or null if empty
        pub fn asMut(self: *Self) ?*T {
            return if (self.is_some) &self.value else null;
        }

        /// Get the contained value, assuming it exists
        /// Panics if the option is empty
        pub fn unwrap(self: Self) T {
            if (!self.is_some) {
                @panic("Called unwrap on a None value");
            }
            return self.value;
        }

        /// Get the contained value, or return the provided default if empty
        pub fn unwrapOr(self: Self, default: T) T {
            return if (self.is_some) self.value else default;
        }

        /// Get the contained value, or compute a default using the provided function
        pub fn unwrapOrElse(self: Self, default_fn: fn () T) T {
            return if (self.is_some) self.value else default_fn();
        }

        /// Transform the contained value using a function, or return None if empty
        pub fn map(self: Self, comptime U: type, f: fn (T) U) COption(U) {
            return if (self.is_some) COption(U).some(f(self.value)) else COption(U).none();
        }

        /// Convert to a Zig optional value
        pub fn toOptional(self: Self) ?T {
            return if (self.is_some) self.value else null;
        }

        /// Returns the size of this COption type in bytes
        pub fn size() usize {
            return @sizeOf(Self);
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "COption: basic functionality" {
    const opt_some = COption(u32).some(42);
    const opt_none = COption(u32).none();

    try std.testing.expect(opt_some.isSome());
    try std.testing.expect(!opt_some.isNone());
    try std.testing.expect(!opt_none.isSome());
    try std.testing.expect(opt_none.isNone());
}

test "COption: unwrap operations" {
    const opt_some = COption(u32).some(42);
    const opt_none = COption(u32).none();

    try std.testing.expectEqual(@as(u32, 42), opt_some.unwrap());
    try std.testing.expectEqual(@as(u32, 42), opt_some.unwrapOr(0));
    try std.testing.expectEqual(@as(u32, 0), opt_none.unwrapOr(0));

    const default_value = opt_none.unwrapOrElse(struct {
        fn call() u32 {
            return 99;
        }
    }.call);
    try std.testing.expectEqual(@as(u32, 99), default_value);
}

test "COption: reference access" {
    var opt_some = COption(u32).some(42);
    const opt_none = COption(u32).none();

    const ref_some = opt_some.asRef();
    const ref_none = opt_none.asRef();

    try std.testing.expect(ref_some != null);
    try std.testing.expectEqual(@as(u32, 42), ref_some.?.*);

    try std.testing.expect(ref_none == null);

    const mut_ref = opt_some.asMut();
    try std.testing.expect(mut_ref != null);
    mut_ref.?.* = 100;
    try std.testing.expectEqual(@as(u32, 100), opt_some.unwrap());
}

test "COption: map operation" {
    const opt_some = COption(u32).some(42);
    const opt_none = COption(u32).none();

    const mapped_some = opt_some.map(u64, struct {
        fn double(x: u32) u64 {
            return @as(u64, x) * 2;
        }
    }.double);

    const mapped_none = opt_none.map(u64, struct {
        fn double(x: u32) u64 {
            return @as(u64, x) * 2;
        }
    }.double);

    try std.testing.expect(mapped_some.isSome());
    try std.testing.expectEqual(@as(u64, 84), mapped_some.unwrap());

    try std.testing.expect(mapped_none.isNone());
}

test "COption: conversion to/from Zig optional" {
    const zig_some: ?u32 = 42;
    const zig_none: ?u32 = null;

    const c_some = COption(u32).fromOptional(zig_some);
    const c_none = COption(u32).fromOptional(zig_none);

    try std.testing.expect(c_some.isSome());
    try std.testing.expectEqual(@as(u32, 42), c_some.unwrap());

    try std.testing.expect(c_none.isNone());

    const back_to_zig_some = c_some.toOptional();
    const back_to_zig_none = c_none.toOptional();

    try std.testing.expectEqual(@as(u32, 42), back_to_zig_some.?);
    try std.testing.expect(back_to_zig_none == null);
}

test "COption: size and memory layout" {
    // COption should have a stable size regardless of whether it contains a value
    const size_u32 = COption(u32).size();
    const size_u64 = COption(u64).size();

    try std.testing.expect(size_u32 > 0);
    try std.testing.expect(size_u64 > 0);

    // The size should be 1 (for bool) + size of T, with potential padding
    try std.testing.expect(size_u32 >= 1 + @sizeOf(u32));
    try std.testing.expect(size_u64 >= 1 + @sizeOf(u64));
}

test "COption: simple types" {
    // Test with simple types that are extern-compatible
    const opt_u32 = COption(u32).some(42);
    try std.testing.expect(opt_u32.isSome());
    try std.testing.expectEqual(@as(u32, 42), opt_u32.unwrap());

    const opt_u64 = COption(u64).some(123456789);
    try std.testing.expect(opt_u64.isSome());
    try std.testing.expectEqual(@as(u64, 123456789), opt_u64.unwrap());
}
