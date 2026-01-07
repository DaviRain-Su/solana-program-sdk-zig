//! Zig implementation of Solana SDK's program-option module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-option/src/lib.rs
//!
//! This module provides a C-compatible `Option<T>` type for use in Solana programs.
//! Unlike Zig's native `?T` type, COption<T> has a stable, predictable memory layout
//! that is compatible with C ABIs and can be safely used across FFI boundaries.
//!
//! ## Memory Layout
//!
//! `COption<T>` uses a 4-byte (u32) tag followed by the value:
//! - Tag = 0: None (value bytes are zero-filled)
//! - Tag = 1: Some (value bytes contain the actual value)
//!
//! For example:
//! - `COption<Pubkey>`: 4 byte tag + 32 byte pubkey = 36 bytes
//! - `COption<u64>`: 4 byte tag + 8 byte u64 = 12 bytes
//!
//! ## Rust Equivalent
//!
//! ```rust
//! #[repr(C)]
//! pub enum COption<T> {
//!     None,
//!     Some(T),
//! }
//! ```

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

/// A C-compatible `Option<T>` type for Solana account state.
///
/// This is the Zig equivalent of `solana_program_option::COption<T>`.
/// It uses a 4-byte tag (little-endian u32) followed by the value.
///
/// ## Supported Types
///
/// Currently supports:
/// - `PublicKey` (36 bytes total: 4 byte tag + 32 byte key)
/// - `u64` (12 bytes total: 4 byte tag + 8 byte value)
///
/// ## Example
///
/// ```zig
/// const COptionPubkey = COption(PublicKey);
///
/// // Create Some value
/// const some_key = COptionPubkey.some(my_pubkey);
///
/// // Create None
/// const none_key = COptionPubkey.none();
///
/// // Pack to bytes
/// var buffer: [COptionPubkey.SIZE]u8 = undefined;
/// some_key.pack(&buffer);
///
/// // Unpack from bytes
/// const unpacked = try COptionPubkey.unpack(&buffer);
/// ```
pub fn COption(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The optional value (internal representation)
        value: ?T,

        /// Size of this COption in bytes when serialized
        ///
        /// - COption<PublicKey>: 36 bytes (4 byte tag + 32 byte pubkey)
        /// - COption<u64>: 12 bytes (4 byte tag + 8 byte u64)
        pub const SIZE: usize = switch (T) {
            PublicKey => 36, // 4 byte tag + 32 byte pubkey
            u64 => 12, // 4 byte tag + 8 byte u64
            else => @compileError("COption only supports PublicKey and u64"),
        };

        /// Tag value for None variant
        pub const TAG_NONE: u32 = 0;
        /// Tag value for Some variant
        pub const TAG_SOME: u32 = 1;

        // ====================================================================
        // Constructors
        // ====================================================================

        /// Create a COption containing a value (Some)
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).some(42);
        /// std.debug.assert(opt.isSome());
        /// ```
        pub fn some(val: T) Self {
            return .{ .value = val };
        }

        /// Create an empty COption (None)
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).none();
        /// std.debug.assert(opt.isNone());
        /// ```
        pub fn none() Self {
            return .{ .value = null };
        }

        /// Create a COption from a Zig optional value
        ///
        /// ## Example
        /// ```zig
        /// const zig_opt: ?u64 = 42;
        /// const c_opt = COption(u64).fromOptional(zig_opt);
        /// ```
        pub fn fromOptional(optional: ?T) Self {
            return .{ .value = optional };
        }

        // ====================================================================
        // Querying
        // ====================================================================

        /// Returns `true` if this option contains a value
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).some(42);
        /// std.debug.assert(opt.isSome() == true);
        /// ```
        pub fn isSome(self: Self) bool {
            return self.value != null;
        }

        /// Returns `true` if this option is empty
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).none();
        /// std.debug.assert(opt.isNone() == true);
        /// ```
        pub fn isNone(self: Self) bool {
            return self.value == null;
        }

        // ====================================================================
        // Unwrapping
        // ====================================================================

        /// Unwrap the contained value
        ///
        /// ## Panics
        /// Panics if the option is None
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).some(42);
        /// const val = opt.unwrap(); // val == 42
        /// ```
        pub fn unwrap(self: Self) T {
            return self.value.?;
        }

        /// Unwrap the contained value, or return a default if None
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).none();
        /// const val = opt.unwrapOr(0); // val == 0
        /// ```
        pub fn unwrapOr(self: Self, default: T) T {
            return self.value orelse default;
        }

        /// Convert to a Zig optional value
        ///
        /// ## Example
        /// ```zig
        /// const c_opt = COption(u64).some(42);
        /// const zig_opt: ?u64 = c_opt.toOptional();
        /// ```
        pub fn toOptional(self: Self) ?T {
            return self.value;
        }

        // ====================================================================
        // Serialization
        // ====================================================================

        /// Pack this COption into a byte slice
        ///
        /// The format is:
        /// - bytes[0..4]: tag (little-endian u32, 0 = None, 1 = Some)
        /// - bytes[4..]: value (if Some) or zeros (if None)
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).some(42);
        /// var buffer: [COption(u64).SIZE]u8 = undefined;
        /// opt.pack(&buffer);
        /// ```
        pub fn pack(self: Self, dest: []u8) void {
            if (dest.len < SIZE) return;

            if (T == PublicKey) {
                if (self.value) |v| {
                    // Write tag = 1 (Some)
                    std.mem.writeInt(u32, dest[0..4], TAG_SOME, .little);
                    // Write pubkey bytes
                    @memcpy(dest[4..36], &v.bytes);
                } else {
                    // Write all zeros for None
                    @memset(dest[0..SIZE], 0);
                }
            } else if (T == u64) {
                if (self.value) |v| {
                    // Write tag = 1 (Some)
                    std.mem.writeInt(u32, dest[0..4], TAG_SOME, .little);
                    // Write u64 value
                    std.mem.writeInt(u64, dest[4..12], v, .little);
                } else {
                    // Write all zeros for None
                    @memset(dest[0..SIZE], 0);
                }
            }
        }

        /// Pack this COption into a fixed-size array
        ///
        /// ## Example
        /// ```zig
        /// const opt = COption(u64).some(42);
        /// const bytes = opt.packToArray();
        /// ```
        pub fn packToArray(self: Self) [SIZE]u8 {
            var result: [SIZE]u8 = undefined;
            self.pack(&result);
            return result;
        }

        /// Unpack a COption from a byte slice
        ///
        /// ## Errors
        /// Returns `error.InvalidAccountData` if:
        /// - The slice is too short
        /// - The tag is not 0 or 1
        ///
        /// ## Example
        /// ```zig
        /// const bytes = [_]u8{ 1, 0, 0, 0, 42, 0, 0, 0, 0, 0, 0, 0 };
        /// const opt = try COption(u64).unpack(&bytes);
        /// std.debug.assert(opt.unwrap() == 42);
        /// ```
        pub fn unpack(src: []const u8) !Self {
            if (src.len < SIZE) return error.InvalidAccountData;

            const tag = std.mem.readInt(u32, src[0..4], .little);

            if (T == PublicKey) {
                return switch (tag) {
                    TAG_NONE => Self.none(),
                    TAG_SOME => Self.some(PublicKey.from(src[4..36].*)),
                    else => error.InvalidAccountData,
                };
            } else if (T == u64) {
                return switch (tag) {
                    TAG_NONE => Self.none(),
                    TAG_SOME => Self.some(std.mem.readInt(u64, src[4..12], .little)),
                    else => error.InvalidAccountData,
                };
            }
            unreachable;
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "COption(u64): basic functionality" {
    const COptionU64 = COption(u64);

    const some_val = COptionU64.some(42);
    const none_val = COptionU64.none();

    try std.testing.expect(some_val.isSome());
    try std.testing.expect(!some_val.isNone());
    try std.testing.expect(!none_val.isSome());
    try std.testing.expect(none_val.isNone());

    try std.testing.expectEqual(@as(u64, 42), some_val.unwrap());
    try std.testing.expectEqual(@as(u64, 42), some_val.unwrapOr(0));
    try std.testing.expectEqual(@as(u64, 0), none_val.unwrapOr(0));
}

test "COption(u64): pack and unpack" {
    const COptionU64 = COption(u64);

    // Test Some
    const some_val = COptionU64.some(0x123456789ABCDEF0);
    var buffer: [COptionU64.SIZE]u8 = undefined;
    some_val.pack(&buffer);

    // Verify tag
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, buffer[0..4], .little));
    // Verify value
    try std.testing.expectEqual(@as(u64, 0x123456789ABCDEF0), std.mem.readInt(u64, buffer[4..12], .little));

    // Unpack and verify
    const unpacked_some = try COptionU64.unpack(&buffer);
    try std.testing.expect(unpacked_some.isSome());
    try std.testing.expectEqual(@as(u64, 0x123456789ABCDEF0), unpacked_some.unwrap());

    // Test None
    const none_val = COptionU64.none();
    none_val.pack(&buffer);

    // Verify all zeros
    for (buffer) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }

    // Unpack and verify
    const unpacked_none = try COptionU64.unpack(&buffer);
    try std.testing.expect(unpacked_none.isNone());
}

test "COption(PublicKey): pack and unpack" {
    const COptionPubkey = COption(PublicKey);

    // Create a test pubkey
    var pubkey_bytes: [32]u8 = undefined;
    for (&pubkey_bytes, 0..) |*b, i| {
        b.* = @intCast(i);
    }
    const pubkey = PublicKey.from(pubkey_bytes);

    // Test Some
    const some_val = COptionPubkey.some(pubkey);
    var buffer: [COptionPubkey.SIZE]u8 = undefined;
    some_val.pack(&buffer);

    // Verify tag
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, buffer[0..4], .little));
    // Verify pubkey bytes
    try std.testing.expectEqualSlices(u8, &pubkey_bytes, buffer[4..36]);

    // Unpack and verify
    const unpacked_some = try COptionPubkey.unpack(&buffer);
    try std.testing.expect(unpacked_some.isSome());
    try std.testing.expectEqualSlices(u8, &pubkey_bytes, &unpacked_some.unwrap().bytes);

    // Test None
    const none_val = COptionPubkey.none();
    none_val.pack(&buffer);

    // Verify all zeros
    for (buffer) |b| {
        try std.testing.expectEqual(@as(u8, 0), b);
    }

    // Unpack and verify
    const unpacked_none = try COptionPubkey.unpack(&buffer);
    try std.testing.expect(unpacked_none.isNone());
}

test "COption: SIZE constants" {
    try std.testing.expectEqual(@as(usize, 12), COption(u64).SIZE);
    try std.testing.expectEqual(@as(usize, 36), COption(PublicKey).SIZE);
}

test "COption: fromOptional and toOptional" {
    const COptionU64 = COption(u64);

    const zig_some: ?u64 = 42;
    const zig_none: ?u64 = null;

    const c_some = COptionU64.fromOptional(zig_some);
    const c_none = COptionU64.fromOptional(zig_none);

    try std.testing.expect(c_some.isSome());
    try std.testing.expectEqual(@as(u64, 42), c_some.unwrap());
    try std.testing.expect(c_none.isNone());

    try std.testing.expectEqual(zig_some, c_some.toOptional());
    try std.testing.expectEqual(zig_none, c_none.toOptional());
}

test "COption: invalid tag returns error" {
    const COptionU64 = COption(u64);

    // Create buffer with invalid tag (2)
    var buffer: [COptionU64.SIZE]u8 = undefined;
    std.mem.writeInt(u32, buffer[0..4], 2, .little);

    const result = COptionU64.unpack(&buffer);
    try std.testing.expectError(error.InvalidAccountData, result);
}

test "COption: buffer too short returns error" {
    const COptionU64 = COption(u64);

    var short_buffer: [8]u8 = undefined; // Too short (needs 12)
    const result = COptionU64.unpack(&short_buffer);
    try std.testing.expectError(error.InvalidAccountData, result);
}
