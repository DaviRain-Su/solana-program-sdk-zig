//! Zig implementation of Solana SDK's program-pack module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/program-pack/src/lib.rs
//!
//! The Pack serialization trait provides a fixed-size serialization API used by
//! many older programs in the Solana Program Library (SPL) to manage account state.
//!
//! ## Key Concepts
//! - `Pack` - Interface for fixed-size account data serialization
//! - `IsInitialized` - Check if an account state is initialized
//! - `Sealed` - Marker for types with known sizes
//!
//! ## Usage Pattern
//! Types that implement Pack have a known serialized size (LEN) and can be
//! efficiently packed into and unpacked from byte slices.
//!
//! ## Note
//! For new code, Borsh serialization is generally recommended. Pack is primarily
//! used for compatibility with existing SPL programs like SPL Token.

const std = @import("std");
const ProgramError = @import("solana_sdk").ProgramError;

// ============================================================================
// Error Types
// ============================================================================

/// Errors that can occur during pack/unpack operations
pub const PackError = error{
    /// Account data is invalid or corrupted
    InvalidAccountData,
    /// Account is not initialized
    UninitializedAccount,
    /// Buffer size doesn't match expected length
    InvalidLength,
};

// ============================================================================
// Pack Interface
// ============================================================================

/// Check if a type implements the Pack interface.
///
/// A type implements Pack if it has:
/// - `const LEN: usize` - The serialized size in bytes
/// - `fn packIntoSlice(self: T, dst: []u8) void` - Serialize to bytes
/// - `fn unpackFromSlice(src: []const u8) PackError!T` - Deserialize from bytes
///
/// Optionally:
/// - `fn isInitialized(self: T) bool` - Check if initialized
pub fn isPack(comptime T: type) bool {
    // Must be a struct, enum, or union to implement Pack
    const info = @typeInfo(T);
    const is_composite = info == .@"struct" or info == .@"enum" or info == .@"union";
    if (!is_composite) return false;

    const has_len = @hasDecl(T, "LEN");
    const has_pack = @hasDecl(T, "packIntoSlice");
    const has_unpack = @hasDecl(T, "unpackFromSlice");
    return has_len and has_pack and has_unpack;
}

/// Check if a type implements IsInitialized
pub fn isInitializedType(comptime T: type) bool {
    // Must be a struct, enum, or union to implement IsInitialized
    const info = @typeInfo(T);
    const is_composite = info == .@"struct" or info == .@"enum" or info == .@"union";
    if (!is_composite) return false;

    return @hasDecl(T, "isInitialized");
}

// ============================================================================
// Pack Helper Functions
// ============================================================================

/// Get the packed length of a Pack type
pub fn getPackedLen(comptime T: type) PackError!usize {
    if (!isPack(T)) {
        return PackError.InvalidAccountData;
    }
    return T.LEN;
}

/// Unpack from slice and check if initialized.
///
/// Rust equivalent: `Pack::unpack`
pub fn unpack(comptime T: type, input: []const u8) PackError!T {
    if (!isPack(T)) {
        return PackError.InvalidAccountData;
    }
    if (!isInitializedType(T)) {
        return PackError.InvalidAccountData;
    }

    const value = try unpackUnchecked(T, input);
    if (!value.isInitialized()) {
        return PackError.UninitializedAccount;
    }
    return value;
}

/// Unpack from slice without checking if initialized.
///
/// Rust equivalent: `Pack::unpack_unchecked`
pub fn unpackUnchecked(comptime T: type, input: []const u8) PackError!T {
    if (!isPack(T)) {
        return PackError.InvalidAccountData;
    }

    if (input.len != T.LEN) {
        return PackError.InvalidLength;
    }
    return T.unpackFromSlice(input);
}

/// Pack into slice.
///
/// Rust equivalent: `Pack::pack`
pub fn pack(comptime T: type, src: T, dst: []u8) PackError!void {
    if (!isPack(T)) {
        return PackError.InvalidAccountData;
    }

    if (dst.len != T.LEN) {
        return PackError.InvalidLength;
    }
    src.packIntoSlice(dst);
}

// ============================================================================
// Generic Pack Implementation Helpers
// ============================================================================

/// Pack a simple struct with fixed-size fields into bytes.
/// Fields must all be primitive types or fixed-size arrays.
pub fn packStruct(comptime T: type, value: T, dst: []u8) void {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("packStruct only works with structs");
    }

    var offset: usize = 0;
    inline for (info.@"struct".fields) |field| {
        const field_value = @field(value, field.name);
        const field_size = packFieldSize(field.type);

        packField(field.type, field_value, dst[offset..][0..field_size]);
        offset += field_size;
    }
}

/// Unpack a simple struct from bytes.
pub fn unpackStruct(comptime T: type, src: []const u8) PackError!T {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("unpackStruct only works with structs");
    }

    var result: T = undefined;
    var offset: usize = 0;

    inline for (info.@"struct".fields) |field| {
        const field_size = packFieldSize(field.type);
        if (offset + field_size > src.len) {
            return PackError.InvalidLength;
        }

        @field(result, field.name) = unpackField(field.type, src[offset..][0..field_size]);
        offset += field_size;
    }

    return result;
}

/// Calculate the packed size of a struct
pub fn packedStructSize(comptime T: type) usize {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("packedStructSize only works with structs");
    }

    var size: usize = 0;
    inline for (info.@"struct".fields) |field| {
        size += packFieldSize(field.type);
    }
    return size;
}

fn packFieldSize(comptime T: type) usize {
    const info = @typeInfo(T);
    return switch (info) {
        .int => |i| i.bits / 8,
        .bool => 1,
        .array => |a| a.len * packFieldSize(a.child),
        .@"struct" => packedStructSize(T),
        else => @compileError("Unsupported type for Pack: " ++ @typeName(T)),
    };
}

fn packField(comptime T: type, value: T, dst: []u8) void {
    const info = @typeInfo(T);
    switch (info) {
        .int => {
            const IntType = std.meta.Int(.unsigned, @bitSizeOf(T));
            const unsigned_value: IntType = @bitCast(value);
            const bytes = std.mem.toBytes(unsigned_value);
            @memcpy(dst, &bytes);
        },
        .bool => {
            dst[0] = if (value) 1 else 0;
        },
        .array => |a| {
            const elem_size = packFieldSize(a.child);
            for (value, 0..) |elem, i| {
                packField(a.child, elem, dst[i * elem_size ..][0..elem_size]);
            }
        },
        .@"struct" => {
            packStruct(T, value, dst);
        },
        else => @compileError("Unsupported type for Pack"),
    }
}

fn unpackField(comptime T: type, src: []const u8) T {
    const info = @typeInfo(T);
    return switch (info) {
        .int => blk: {
            const IntType = std.meta.Int(.unsigned, @bitSizeOf(T));
            var bytes: [@sizeOf(T)]u8 = undefined;
            @memcpy(&bytes, src[0..@sizeOf(T)]);
            const unsigned_value = std.mem.bytesToValue(IntType, &bytes);
            break :blk @bitCast(unsigned_value);
        },
        .bool => src[0] != 0,
        .array => |a| blk: {
            var result: T = undefined;
            const elem_size = packFieldSize(a.child);
            for (0..a.len) |i| {
                result[i] = unpackField(a.child, src[i * elem_size ..][0..elem_size]);
            }
            break :blk result;
        },
        .@"struct" => unpackStruct(T, src) catch unreachable,
        else => @compileError("Unsupported type for Pack"),
    };
}

// ============================================================================
// Example Pack Implementation
// ============================================================================

/// Example of a type that implements the Pack interface.
/// This demonstrates the pattern for implementing Pack in user types.
pub const ExamplePackable = struct {
    /// The serialized size in bytes
    pub const LEN: usize = 1 + 8 + 32; // is_initialized + amount + owner

    is_initialized: bool,
    amount: u64,
    owner: [32]u8,

    /// Check if this account is initialized
    pub fn isInitialized(self: ExamplePackable) bool {
        return self.is_initialized;
    }

    /// Pack into a byte slice
    pub fn packIntoSlice(self: ExamplePackable, dst: []u8) void {
        var offset: usize = 0;

        // is_initialized (1 byte)
        dst[offset] = if (self.is_initialized) 1 else 0;
        offset += 1;

        // amount (8 bytes, little-endian)
        std.mem.writeInt(u64, dst[offset..][0..8], self.amount, .little);
        offset += 8;

        // owner (32 bytes)
        @memcpy(dst[offset..][0..32], &self.owner);
    }

    /// Unpack from a byte slice
    pub fn unpackFromSlice(src: []const u8) PackError!ExamplePackable {
        if (src.len < LEN) {
            return PackError.InvalidLength;
        }

        var offset: usize = 0;

        // is_initialized
        const is_initialized = src[offset] != 0;
        offset += 1;

        // amount
        const amount = std.mem.readInt(u64, src[offset..][0..8], .little);
        offset += 8;

        // owner
        var owner: [32]u8 = undefined;
        @memcpy(&owner, src[offset..][0..32]);

        return ExamplePackable{
            .is_initialized = is_initialized,
            .amount = amount,
            .owner = owner,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "program_pack: isPack check" {
    try std.testing.expect(isPack(ExamplePackable));
    try std.testing.expect(!isPack(u64));
}

test "program_pack: isInitializedType check" {
    try std.testing.expect(isInitializedType(ExamplePackable));
    try std.testing.expect(!isInitializedType(u64));
}

test "program_pack: getPackedLen" {
    try std.testing.expect(isPack(ExamplePackable));
    try std.testing.expectEqual(@as(usize, 41), try getPackedLen(ExamplePackable));
}

test "program_pack: pack and unpack ExamplePackable" {
    const original = ExamplePackable{
        .is_initialized = true,
        .amount = 1_000_000_000,
        .owner = [_]u8{0xAB} ** 32,
    };

    var buffer: [ExamplePackable.LEN]u8 = undefined;
    try pack(ExamplePackable, original, &buffer);

    const unpacked = try unpackUnchecked(ExamplePackable, &buffer);

    try std.testing.expectEqual(original.is_initialized, unpacked.is_initialized);
    try std.testing.expectEqual(original.amount, unpacked.amount);
    try std.testing.expectEqualSlices(u8, &original.owner, &unpacked.owner);
}

test "program_pack: unpack checks initialization" {
    // Create uninitialized data
    var buffer: [ExamplePackable.LEN]u8 = [_]u8{0} ** ExamplePackable.LEN;

    // unpack should fail because is_initialized is false
    const result = unpack(ExamplePackable, &buffer);
    try std.testing.expectError(PackError.UninitializedAccount, result);

    // unpackUnchecked should succeed
    const unpacked = try unpackUnchecked(ExamplePackable, &buffer);
    try std.testing.expect(!unpacked.isInitialized());
}

test "program_pack: wrong buffer size returns error" {
    const original = ExamplePackable{
        .is_initialized = true,
        .amount = 100,
        .owner = [_]u8{0} ** 32,
    };

    // Buffer too small
    var small_buffer: [10]u8 = undefined;
    try std.testing.expectError(PackError.InvalidLength, pack(ExamplePackable, original, &small_buffer));

    // Buffer too large
    var large_buffer: [100]u8 = undefined;
    try std.testing.expectError(PackError.InvalidLength, pack(ExamplePackable, original, &large_buffer));
}

test "program_pack: packStruct helper" {
    const SimpleStruct = struct {
        a: u8,
        b: u32,
        c: bool,
    };

    const value = SimpleStruct{ .a = 0x42, .b = 0x12345678, .c = true };
    var buffer: [6]u8 = undefined;

    packStruct(SimpleStruct, value, &buffer);

    try std.testing.expectEqual(@as(u8, 0x42), buffer[0]);
    // Little-endian u32
    try std.testing.expectEqual(@as(u8, 0x78), buffer[1]);
    try std.testing.expectEqual(@as(u8, 0x56), buffer[2]);
    try std.testing.expectEqual(@as(u8, 0x34), buffer[3]);
    try std.testing.expectEqual(@as(u8, 0x12), buffer[4]);
    try std.testing.expectEqual(@as(u8, 1), buffer[5]);
}

test "program_pack: unpackStruct helper" {
    const SimpleStruct = struct {
        a: u8,
        b: u32,
        c: bool,
    };

    const buffer = [_]u8{ 0x42, 0x78, 0x56, 0x34, 0x12, 1 };
    const result = try unpackStruct(SimpleStruct, &buffer);

    try std.testing.expectEqual(@as(u8, 0x42), result.a);
    try std.testing.expectEqual(@as(u32, 0x12345678), result.b);
    try std.testing.expect(result.c);
}

test "program_pack: packedStructSize" {
    const SimpleStruct = struct {
        a: u8,
        b: u32,
        c: bool,
    };

    try std.testing.expectEqual(@as(usize, 6), packedStructSize(SimpleStruct));
}

test "program_pack: nested struct packing" {
    const Inner = struct {
        x: u16,
        y: u16,
    };

    const Outer = struct {
        inner: Inner,
        z: u32,
    };

    const value = Outer{
        .inner = Inner{ .x = 0x1234, .y = 0x5678 },
        .z = 0xDEADBEEF,
    };

    var buffer: [8]u8 = undefined;
    packStruct(Outer, value, &buffer);

    const unpacked = try unpackStruct(Outer, &buffer);
    try std.testing.expectEqual(value.inner.x, unpacked.inner.x);
    try std.testing.expectEqual(value.inner.y, unpacked.inner.y);
    try std.testing.expectEqual(value.z, unpacked.z);
}

test "program_pack: array field packing" {
    const WithArray = struct {
        data: [4]u8,
        value: u32,
    };

    const original = WithArray{
        .data = [_]u8{ 1, 2, 3, 4 },
        .value = 0x12345678,
    };

    var buffer: [8]u8 = undefined;
    packStruct(WithArray, original, &buffer);

    const unpacked = try unpackStruct(WithArray, &buffer);
    try std.testing.expectEqualSlices(u8, &original.data, &unpacked.data);
    try std.testing.expectEqual(original.value, unpacked.value);
}
