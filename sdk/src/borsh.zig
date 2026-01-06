//! Zig implementation of Borsh serialization format
//!
//! Rust source: https://github.com/near/borsh-rs
//!
//! Borsh (Binary Object Representation Serializer for Hashing) is a binary
//! serialization format designed for security-critical applications. It is
//! used by Solana for program data serialization.
//!
//! ## Encoding Rules
//! - Little-endian byte order for all multi-byte integers
//! - Fixed-size types: Serialize directly as bytes
//! - Variable-size types: u32 length prefix followed by elements
//! - Optionals: 0 for null, 1 + value for present
//! - Structs: Fields serialized in declaration order
//! - Enums: u8 variant tag followed by variant data

const std = @import("std");

/// Errors that can occur during Borsh serialization/deserialization
pub const BorshError = error{
    /// Not enough bytes in input buffer
    UnexpectedEndOfInput,
    /// Input buffer not fully consumed after deserialization
    ExtraDataAfterDeserialize,
    /// Invalid boolean value (not 0 or 1)
    InvalidBool,
    /// Invalid option tag (not 0 or 1)
    InvalidOptionTag,
    /// Invalid enum variant tag
    InvalidEnumTag,
    /// String contains invalid UTF-8
    InvalidUtf8,
    /// Float value is NaN (not portable)
    NanNotAllowed,
    /// Output buffer too small
    BufferTooSmall,
    /// Length exceeds maximum allowed
    LengthOverflow,
};

// ============================================================================
// Serialization
// ============================================================================

/// Serialize a value to a byte slice using Borsh encoding.
/// Returns the number of bytes written.
pub fn serialize(comptime T: type, value: T, buffer: []u8) BorshError!usize {
    var stream = BufferStream{ .buffer = buffer, .pos = 0 };
    try serializeToWriter(T, value, &stream);
    return stream.pos;
}

/// Serialize a value to a dynamically allocated buffer.
pub fn serializeAlloc(allocator: std.mem.Allocator, comptime T: type, value: T) ![]u8 {
    const size = serializedSize(T, value);
    const buffer = try allocator.alloc(u8, size);
    errdefer allocator.free(buffer);

    const written = try serialize(T, value, buffer);
    std.debug.assert(written == size);
    return buffer;
}

/// Calculate the serialized size of a value without actually serializing.
pub fn serializedSize(comptime T: type, value: T) usize {
    return serializedSizeImpl(T, value);
}

fn serializedSizeImpl(comptime T: type, value: T) usize {
    const info = @typeInfo(T);

    return switch (info) {
        .bool => 1,
        .int => |i| i.bits / 8,
        .float => |f| f.bits / 8,
        .optional => |opt| blk: {
            if (value) |v| {
                break :blk 1 + serializedSizeImpl(opt.child, v);
            } else {
                break :blk 1;
            }
        },
        .array => |arr| arr.len * serializedSizeImpl(arr.child, undefined),
        .pointer => |ptr| blk: {
            if (ptr.size == .slice) {
                const elem_size = serializedSizeImpl(ptr.child, undefined);
                break :blk 4 + value.len * elem_size;
            } else {
                @compileError("Unsupported pointer type for Borsh serialization");
            }
        },
        .@"struct" => |s| blk: {
            var total: usize = 0;
            inline for (s.fields) |field| {
                total += serializedSizeImpl(field.type, @field(value, field.name));
            }
            break :blk total;
        },
        .@"enum" => |e| blk: {
            _ = e;
            // Enum is just the tag (u8)
            break :blk 1;
        },
        .@"union" => |u| blk: {
            if (u.tag_type) |_| {
                // Tagged union: tag + payload
                const tag_size: usize = 1;
                const active_tag = std.meta.activeTag(value);
                inline for (u.fields) |field| {
                    if (active_tag == @field(std.meta.Tag(T), field.name)) {
                        if (field.type == void) {
                            break :blk tag_size;
                        }
                        const payload = @field(value, field.name);
                        break :blk tag_size + serializedSizeImpl(field.type, payload);
                    }
                }
                break :blk tag_size;
            } else {
                @compileError("Untagged unions not supported for Borsh serialization");
            }
        },
        else => @compileError("Unsupported type for Borsh serialization: " ++ @typeName(T)),
    };
}

/// Writer interface for serialization
const BufferStream = struct {
    buffer: []u8,
    pos: usize,

    fn write(self: *BufferStream, data: []const u8) BorshError!void {
        if (self.pos + data.len > self.buffer.len) {
            return BorshError.BufferTooSmall;
        }
        @memcpy(self.buffer[self.pos..][0..data.len], data);
        self.pos += data.len;
    }
};

fn serializeToWriter(comptime T: type, value: T, writer: *BufferStream) BorshError!void {
    const info = @typeInfo(T);

    switch (info) {
        .bool => {
            try writer.write(&[_]u8{if (value) 1 else 0});
        },
        .int => {
            const bytes = std.mem.asBytes(&std.mem.nativeToLittle(T, value));
            try writer.write(bytes);
        },
        .float => |f| {
            // Check for NaN - not portable across platforms
            if (std.math.isNan(value)) {
                return BorshError.NanNotAllowed;
            }
            const IntType = std.meta.Int(.unsigned, f.bits);
            const bits: IntType = @bitCast(value);
            const bytes = std.mem.asBytes(&std.mem.nativeToLittle(IntType, bits));
            try writer.write(bytes);
        },
        .optional => |opt| {
            if (value) |v| {
                try writer.write(&[_]u8{1});
                try serializeToWriter(opt.child, v, writer);
            } else {
                try writer.write(&[_]u8{0});
            }
        },
        .array => |arr| {
            // Fixed-size arrays: no length prefix
            for (value) |elem| {
                try serializeToWriter(arr.child, elem, writer);
            }
        },
        .pointer => |ptr| {
            if (ptr.size == .slice) {
                // Slices: u32 length prefix + elements
                if (value.len > std.math.maxInt(u32)) {
                    return BorshError.LengthOverflow;
                }
                const len: u32 = @intCast(value.len);
                const len_bytes = std.mem.asBytes(&std.mem.nativeToLittle(u32, len));
                try writer.write(len_bytes);

                for (value) |elem| {
                    try serializeToWriter(ptr.child, elem, writer);
                }
            } else {
                @compileError("Unsupported pointer type for Borsh serialization");
            }
        },
        .@"struct" => |s| {
            // Structs: serialize fields in order
            inline for (s.fields) |field| {
                try serializeToWriter(field.type, @field(value, field.name), writer);
            }
        },
        .@"enum" => {
            // Enum: serialize as u8 tag
            const tag: u8 = @intFromEnum(value);
            try writer.write(&[_]u8{tag});
        },
        .@"union" => |u| {
            if (u.tag_type) |_| {
                // Tagged union: tag + payload
                const active_tag = std.meta.activeTag(value);
                const tag: u8 = @intFromEnum(active_tag);
                try writer.write(&[_]u8{tag});

                inline for (u.fields) |field| {
                    if (active_tag == @field(std.meta.Tag(T), field.name)) {
                        if (field.type != void) {
                            const payload = @field(value, field.name);
                            try serializeToWriter(field.type, payload, writer);
                        }
                        return;
                    }
                }
            } else {
                @compileError("Untagged unions not supported for Borsh serialization");
            }
        },
        else => @compileError("Unsupported type for Borsh serialization: " ++ @typeName(T)),
    }
}

// ============================================================================
// Deserialization
// ============================================================================

/// Deserialize a value from a byte slice using Borsh encoding.
/// Returns the deserialized value and the number of bytes consumed.
pub fn deserialize(comptime T: type, buffer: []const u8) BorshError!struct { value: T, bytes_read: usize } {
    var reader = BufferReader{ .buffer = buffer, .pos = 0 };
    const value = try deserializeFromReader(T, &reader);
    return .{ .value = value, .bytes_read = reader.pos };
}

/// Deserialize a value, requiring that all bytes are consumed.
pub fn deserializeExact(comptime T: type, buffer: []const u8) BorshError!T {
    const result = try deserialize(T, buffer);
    if (result.bytes_read != buffer.len) {
        return BorshError.ExtraDataAfterDeserialize;
    }
    return result.value;
}

/// Reader interface for deserialization
const BufferReader = struct {
    buffer: []const u8,
    pos: usize,

    fn read(self: *BufferReader, comptime n: usize) BorshError![n]u8 {
        if (self.pos + n > self.buffer.len) {
            return BorshError.UnexpectedEndOfInput;
        }
        const result: *const [n]u8 = @ptrCast(self.buffer[self.pos..][0..n]);
        self.pos += n;
        return result.*;
    }

    fn readSlice(self: *BufferReader, n: usize) BorshError![]const u8 {
        if (self.pos + n > self.buffer.len) {
            return BorshError.UnexpectedEndOfInput;
        }
        const result = self.buffer[self.pos..][0..n];
        self.pos += n;
        return result;
    }
};

fn deserializeFromReader(comptime T: type, reader: *BufferReader) BorshError!T {
    const info = @typeInfo(T);

    return switch (info) {
        .bool => blk: {
            const byte = try reader.read(1);
            if (byte[0] == 0) {
                break :blk false;
            } else if (byte[0] == 1) {
                break :blk true;
            } else {
                break :blk BorshError.InvalidBool;
            }
        },
        .int => |i| blk: {
            const bytes = try reader.read(i.bits / 8);
            break :blk std.mem.littleToNative(T, @bitCast(bytes));
        },
        .float => |f| blk: {
            const IntType = std.meta.Int(.unsigned, f.bits);
            const bytes = try reader.read(f.bits / 8);
            const bits = std.mem.littleToNative(IntType, @bitCast(bytes));
            const result: T = @bitCast(bits);
            if (std.math.isNan(result)) {
                break :blk BorshError.NanNotAllowed;
            }
            break :blk result;
        },
        .optional => |opt| blk: {
            const tag = try reader.read(1);
            if (tag[0] == 0) {
                break :blk null;
            } else if (tag[0] == 1) {
                break :blk try deserializeFromReader(opt.child, reader);
            } else {
                break :blk BorshError.InvalidOptionTag;
            }
        },
        .array => |arr| blk: {
            var result: T = undefined;
            for (&result) |*elem| {
                elem.* = try deserializeFromReader(arr.child, reader);
            }
            break :blk result;
        },
        .@"struct" => |s| blk: {
            var result: T = undefined;
            inline for (s.fields) |field| {
                @field(result, field.name) = try deserializeFromReader(field.type, reader);
            }
            break :blk result;
        },
        .@"enum" => |e| blk: {
            const tag_bytes = try reader.read(1);
            const tag = tag_bytes[0];
            inline for (e.fields, 0..) |_, i| {
                if (tag == i) {
                    break :blk @enumFromInt(tag);
                }
            }
            break :blk BorshError.InvalidEnumTag;
        },
        .@"union" => |u| blk: {
            if (u.tag_type) |TagType| {
                const tag_bytes = try reader.read(1);
                const tag: u8 = tag_bytes[0];

                inline for (u.fields, 0..) |field, i| {
                    if (tag == i) {
                        if (field.type == void) {
                            break :blk @unionInit(T, field.name, {});
                        } else {
                            const payload = try deserializeFromReader(field.type, reader);
                            break :blk @unionInit(T, field.name, payload);
                        }
                    }
                }
                _ = TagType;
                break :blk BorshError.InvalidEnumTag;
            } else {
                @compileError("Untagged unions not supported for Borsh deserialization");
            }
        },
        else => @compileError("Unsupported type for Borsh deserialization: " ++ @typeName(T)),
    };
}

// ============================================================================
// Convenience functions for common Solana types
// ============================================================================

/// Serialize a Pubkey (32 bytes)
pub fn serializePubkey(pubkey: [32]u8, buffer: []u8) BorshError!usize {
    return serialize([32]u8, pubkey, buffer);
}

/// Deserialize a Pubkey (32 bytes)
pub fn deserializePubkey(buffer: []const u8) BorshError![32]u8 {
    const result = try deserialize([32]u8, buffer);
    return result.value;
}

// ============================================================================
// Tests
// ============================================================================

// Test struct for serialization tests
const TestStruct = struct {
    a: u32,
    b: u8,
    c: bool,
};

const TestEnum = enum(u8) {
    variant_a,
    variant_b,
    variant_c,
};

const TestUnion = union(enum) {
    none: void,
    some_u32: u32,
    some_bool: bool,
};

// Rust test: test integers serialization
test "borsh: serialize integers" {
    var buffer: [100]u8 = undefined;

    // u8
    {
        const written = try serialize(u8, 42, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 42), buffer[0]);
    }

    // u16 little-endian
    {
        const written = try serialize(u16, 0x1234, &buffer);
        try std.testing.expectEqual(@as(usize, 2), written);
        try std.testing.expectEqual(@as(u8, 0x34), buffer[0]);
        try std.testing.expectEqual(@as(u8, 0x12), buffer[1]);
    }

    // u32 little-endian
    {
        const written = try serialize(u32, 0x12345678, &buffer);
        try std.testing.expectEqual(@as(usize, 4), written);
        try std.testing.expectEqualSlices(u8, &[_]u8{ 0x78, 0x56, 0x34, 0x12 }, buffer[0..4]);
    }

    // u64 little-endian
    {
        const written = try serialize(u64, 0x123456789ABCDEF0, &buffer);
        try std.testing.expectEqual(@as(usize, 8), written);
        try std.testing.expectEqualSlices(u8, &[_]u8{ 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12 }, buffer[0..8]);
    }

    // i32 (signed)
    {
        const written = try serialize(i32, -1, &buffer);
        try std.testing.expectEqual(@as(usize, 4), written);
        try std.testing.expectEqualSlices(u8, &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF }, buffer[0..4]);
    }
}

// Rust test: test bool serialization
test "borsh: serialize bool" {
    var buffer: [10]u8 = undefined;

    {
        const written = try serialize(bool, false, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 0), buffer[0]);
    }

    {
        const written = try serialize(bool, true, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 1), buffer[0]);
    }
}

// Rust test: test Option serialization
test "borsh: serialize optional" {
    var buffer: [10]u8 = undefined;

    // None
    {
        const value: ?u32 = null;
        const written = try serialize(?u32, value, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 0), buffer[0]);
    }

    // Some
    {
        const value: ?u32 = 42;
        const written = try serialize(?u32, value, &buffer);
        try std.testing.expectEqual(@as(usize, 5), written);
        try std.testing.expectEqual(@as(u8, 1), buffer[0]);
        try std.testing.expectEqualSlices(u8, &[_]u8{ 42, 0, 0, 0 }, buffer[1..5]);
    }
}

// Rust test: test array serialization (no length prefix)
test "borsh: serialize array" {
    var buffer: [10]u8 = undefined;

    const arr = [_]u8{ 1, 2, 3, 4 };
    const written = try serialize([4]u8, arr, &buffer);
    try std.testing.expectEqual(@as(usize, 4), written);
    try std.testing.expectEqualSlices(u8, &arr, buffer[0..4]);
}

// Rust test: test slice serialization (with length prefix)
test "borsh: serialize slice" {
    var buffer: [20]u8 = undefined;

    const slice: []const u8 = &[_]u8{ 1, 2, 3, 4 };
    const written = try serialize([]const u8, slice, &buffer);
    try std.testing.expectEqual(@as(usize, 8), written); // 4 bytes length + 4 bytes data

    // Length prefix (u32 little-endian)
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 0, 0, 0 }, buffer[0..4]);
    // Data
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4 }, buffer[4..8]);
}

// Rust test: test struct serialization
test "borsh: serialize struct" {
    var buffer: [20]u8 = undefined;

    const value = TestStruct{
        .a = 0x12345678,
        .b = 42,
        .c = true,
    };

    const written = try serialize(TestStruct, value, &buffer);
    try std.testing.expectEqual(@as(usize, 6), written); // 4 + 1 + 1

    // a: u32 little-endian
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x78, 0x56, 0x34, 0x12 }, buffer[0..4]);
    // b: u8
    try std.testing.expectEqual(@as(u8, 42), buffer[4]);
    // c: bool
    try std.testing.expectEqual(@as(u8, 1), buffer[5]);
}

// Rust test: test enum serialization
test "borsh: serialize enum" {
    var buffer: [10]u8 = undefined;

    {
        const written = try serialize(TestEnum, .variant_a, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 0), buffer[0]);
    }

    {
        const written = try serialize(TestEnum, .variant_b, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 1), buffer[0]);
    }

    {
        const written = try serialize(TestEnum, .variant_c, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 2), buffer[0]);
    }
}

// Rust test: test tagged union serialization
test "borsh: serialize tagged union" {
    var buffer: [10]u8 = undefined;

    // void variant
    {
        const value = TestUnion{ .none = {} };
        const written = try serialize(TestUnion, value, &buffer);
        try std.testing.expectEqual(@as(usize, 1), written);
        try std.testing.expectEqual(@as(u8, 0), buffer[0]);
    }

    // u32 variant
    {
        const value = TestUnion{ .some_u32 = 0x12345678 };
        const written = try serialize(TestUnion, value, &buffer);
        try std.testing.expectEqual(@as(usize, 5), written);
        try std.testing.expectEqual(@as(u8, 1), buffer[0]);
        try std.testing.expectEqualSlices(u8, &[_]u8{ 0x78, 0x56, 0x34, 0x12 }, buffer[1..5]);
    }

    // bool variant
    {
        const value = TestUnion{ .some_bool = true };
        const written = try serialize(TestUnion, value, &buffer);
        try std.testing.expectEqual(@as(usize, 2), written);
        try std.testing.expectEqual(@as(u8, 2), buffer[0]);
        try std.testing.expectEqual(@as(u8, 1), buffer[1]);
    }
}

// Rust test: test deserialization
test "borsh: deserialize integers" {
    // u8
    {
        const result = try deserialize(u8, &[_]u8{42});
        try std.testing.expectEqual(@as(u8, 42), result.value);
        try std.testing.expectEqual(@as(usize, 1), result.bytes_read);
    }

    // u16
    {
        const result = try deserialize(u16, &[_]u8{ 0x34, 0x12 });
        try std.testing.expectEqual(@as(u16, 0x1234), result.value);
    }

    // u32
    {
        const result = try deserialize(u32, &[_]u8{ 0x78, 0x56, 0x34, 0x12 });
        try std.testing.expectEqual(@as(u32, 0x12345678), result.value);
    }

    // i32 negative
    {
        const result = try deserialize(i32, &[_]u8{ 0xFF, 0xFF, 0xFF, 0xFF });
        try std.testing.expectEqual(@as(i32, -1), result.value);
    }
}

test "borsh: deserialize bool" {
    {
        const result = try deserialize(bool, &[_]u8{0});
        try std.testing.expectEqual(false, result.value);
    }

    {
        const result = try deserialize(bool, &[_]u8{1});
        try std.testing.expectEqual(true, result.value);
    }

    // Invalid bool value
    {
        const result = deserialize(bool, &[_]u8{2});
        try std.testing.expectError(BorshError.InvalidBool, result);
    }
}

test "borsh: deserialize optional" {
    // None
    {
        const result = try deserialize(?u32, &[_]u8{0});
        try std.testing.expectEqual(@as(?u32, null), result.value);
    }

    // Some
    {
        const result = try deserialize(?u32, &[_]u8{ 1, 42, 0, 0, 0 });
        try std.testing.expectEqual(@as(?u32, 42), result.value);
    }

    // Invalid tag
    {
        const result = deserialize(?u32, &[_]u8{2});
        try std.testing.expectError(BorshError.InvalidOptionTag, result);
    }
}

test "borsh: deserialize array" {
    const result = try deserialize([4]u8, &[_]u8{ 1, 2, 3, 4 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4 }, &result.value);
}

test "borsh: deserialize struct" {
    const data = [_]u8{
        0x78, 0x56, 0x34, 0x12, // a: u32
        42, // b: u8
        1, // c: bool
    };

    const result = try deserialize(TestStruct, &data);
    try std.testing.expectEqual(@as(u32, 0x12345678), result.value.a);
    try std.testing.expectEqual(@as(u8, 42), result.value.b);
    try std.testing.expectEqual(true, result.value.c);
}

test "borsh: deserialize enum" {
    {
        const result = try deserialize(TestEnum, &[_]u8{0});
        try std.testing.expectEqual(TestEnum.variant_a, result.value);
    }

    {
        const result = try deserialize(TestEnum, &[_]u8{1});
        try std.testing.expectEqual(TestEnum.variant_b, result.value);
    }

    // Invalid tag
    {
        const result = deserialize(TestEnum, &[_]u8{10});
        try std.testing.expectError(BorshError.InvalidEnumTag, result);
    }
}

test "borsh: deserialize tagged union" {
    // void variant
    {
        const result = try deserialize(TestUnion, &[_]u8{0});
        try std.testing.expectEqual(std.meta.Tag(TestUnion).none, std.meta.activeTag(result.value));
    }

    // u32 variant
    {
        const result = try deserialize(TestUnion, &[_]u8{ 1, 0x78, 0x56, 0x34, 0x12 });
        try std.testing.expectEqual(std.meta.Tag(TestUnion).some_u32, std.meta.activeTag(result.value));
        try std.testing.expectEqual(@as(u32, 0x12345678), result.value.some_u32);
    }

    // bool variant
    {
        const result = try deserialize(TestUnion, &[_]u8{ 2, 1 });
        try std.testing.expectEqual(std.meta.Tag(TestUnion).some_bool, std.meta.activeTag(result.value));
        try std.testing.expectEqual(true, result.value.some_bool);
    }
}

test "borsh: round-trip serialization" {
    const original = TestStruct{
        .a = 12345,
        .b = 200,
        .c = true,
    };

    var buffer: [100]u8 = undefined;
    const written = try serialize(TestStruct, original, &buffer);
    const result = try deserialize(TestStruct, buffer[0..written]);

    try std.testing.expectEqual(original.a, result.value.a);
    try std.testing.expectEqual(original.b, result.value.b);
    try std.testing.expectEqual(original.c, result.value.c);
}

test "borsh: serialized size calculation" {
    // Primitives
    try std.testing.expectEqual(@as(usize, 1), serializedSize(u8, 0));
    try std.testing.expectEqual(@as(usize, 4), serializedSize(u32, 0));
    try std.testing.expectEqual(@as(usize, 8), serializedSize(u64, 0));
    try std.testing.expectEqual(@as(usize, 1), serializedSize(bool, false));

    // Optional
    try std.testing.expectEqual(@as(usize, 1), serializedSize(?u32, null));
    try std.testing.expectEqual(@as(usize, 5), serializedSize(?u32, @as(?u32, 42)));

    // Array
    try std.testing.expectEqual(@as(usize, 4), serializedSize([4]u8, [_]u8{ 1, 2, 3, 4 }));

    // Struct
    const s = TestStruct{ .a = 0, .b = 0, .c = false };
    try std.testing.expectEqual(@as(usize, 6), serializedSize(TestStruct, s));
}

test "borsh: error handling" {
    // Buffer too small
    {
        var small_buffer: [2]u8 = undefined;
        const result = serialize(u32, 42, &small_buffer);
        try std.testing.expectError(BorshError.BufferTooSmall, result);
    }

    // Unexpected end of input
    {
        const result = deserialize(u32, &[_]u8{ 1, 2 });
        try std.testing.expectError(BorshError.UnexpectedEndOfInput, result);
    }

    // Extra data after deserialize
    {
        const result = deserializeExact(u8, &[_]u8{ 42, 99 });
        try std.testing.expectError(BorshError.ExtraDataAfterDeserialize, result);
    }
}

test "borsh: float serialization" {
    var buffer: [10]u8 = undefined;

    // f32
    {
        const value: f32 = 1.5;
        const written = try serialize(f32, value, &buffer);
        try std.testing.expectEqual(@as(usize, 4), written);

        const result = try deserialize(f32, buffer[0..4]);
        try std.testing.expectEqual(value, result.value);
    }

    // f64
    {
        const value: f64 = 3.14159265358979;
        const written = try serialize(f64, value, &buffer);
        try std.testing.expectEqual(@as(usize, 8), written);

        const result = try deserialize(f64, buffer[0..8]);
        try std.testing.expectEqual(value, result.value);
    }
}

test "borsh: NaN rejection" {
    var buffer: [10]u8 = undefined;

    // f32 NaN
    {
        const result = serialize(f32, std.math.nan(f32), &buffer);
        try std.testing.expectError(BorshError.NanNotAllowed, result);
    }

    // f64 NaN
    {
        const result = serialize(f64, std.math.nan(f64), &buffer);
        try std.testing.expectError(BorshError.NanNotAllowed, result);
    }
}

test "borsh: nested struct" {
    const Inner = struct {
        x: u16,
        y: u16,
    };

    const Outer = struct {
        inner: Inner,
        flag: bool,
    };

    const original = Outer{
        .inner = .{ .x = 100, .y = 200 },
        .flag = true,
    };

    var buffer: [100]u8 = undefined;
    const written = try serialize(Outer, original, &buffer);
    try std.testing.expectEqual(@as(usize, 5), written); // 2 + 2 + 1

    const result = try deserialize(Outer, buffer[0..written]);
    try std.testing.expectEqual(original.inner.x, result.value.inner.x);
    try std.testing.expectEqual(original.inner.y, result.value.inner.y);
    try std.testing.expectEqual(original.flag, result.value.flag);
}

test "borsh: allocating serialization" {
    const allocator = std.testing.allocator;

    const value = TestStruct{
        .a = 12345,
        .b = 200,
        .c = true,
    };

    const buffer = try serializeAlloc(allocator, TestStruct, value);
    defer allocator.free(buffer);

    try std.testing.expectEqual(@as(usize, 6), buffer.len);

    const result = try deserialize(TestStruct, buffer);
    try std.testing.expectEqual(value.a, result.value.a);
    try std.testing.expectEqual(value.b, result.value.b);
    try std.testing.expectEqual(value.c, result.value.c);
}
