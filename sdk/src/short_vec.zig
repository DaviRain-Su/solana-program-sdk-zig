//! Zig implementation of Solana SDK's short-vec module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/short-vec/src/lib.rs
//!
//! Compact encoding of vectors with small length. ShortU16 serializes u16 values
//! using 1 to 3 bytes, saving space for small values while still supporting the
//! full u16 range.
//!
//! Encoding scheme:
//! - 0-127:       1 byte  (0xxxxxxx)
//! - 128-16383:   2 bytes (1xxxxxxx 0yyyyyyy)
//! - 16384-65535: 3 bytes (1xxxxxxx 1yyyyyyy 000000zz)

const std = @import("std");

/// Maximum number of bytes needed to encode a ShortU16
pub const MAX_ENCODING_LENGTH: usize = 3;

/// Errors that can occur during ShortU16 decoding
pub const DecodeError = error{
    /// Input too long (more than 3 bytes with continue bits set)
    TooLong,
    /// Input too short (continue bit set but no more bytes)
    TooShort,
    /// Decoded value overflows u16 (> 65535)
    Overflow,
    /// Alias encoding detected (non-canonical form)
    Alias,
    /// Third byte has continue bit set (invalid)
    ByteThreeContinues,
};

/// Result of visiting a single byte during decoding
const VisitStatus = union(enum) {
    /// Decoding complete, contains final value
    done: u16,
    /// More bytes needed, contains partial value
    more: u16,
};

/// Same as u16, but serialized with 1 to 3 bytes.
///
/// If the value is above 0x7f, the top bit is set and the remaining value
/// is stored in the next bytes. Each byte follows the same pattern until
/// the 3rd byte. The 3rd byte may only have the 2 least-significant bits set,
/// otherwise the encoded value will overflow the u16.
///
/// Rust equivalent: `solana_short_vec::ShortU16`
pub const ShortU16 = struct {
    value: u16,

    const Self = @This();

    pub fn init(value: u16) Self {
        return .{ .value = value };
    }

    /// Encode the ShortU16 value to bytes.
    /// Returns the number of bytes written (1-3).
    pub fn encode(self: Self, buffer: *[MAX_ENCODING_LENGTH]u8) usize {
        return encodeU16(self.value, buffer);
    }

    /// Decode a ShortU16 from bytes.
    /// Returns the decoded value and how many bytes were consumed.
    pub fn decode(bytes: []const u8) DecodeError!struct { value: Self, bytes_read: usize } {
        const result = try decodeU16Len(bytes);
        return .{
            .value = .{ .value = @intCast(result.value) },
            .bytes_read = result.bytes_read,
        };
    }
};

/// Encode a u16 value using ShortU16 encoding.
/// Returns the number of bytes written (1-3).
///
/// Rust equivalent: Part of `ShortU16::serialize`
pub fn encodeU16(value: u16, buffer: *[MAX_ENCODING_LENGTH]u8) usize {
    var rem_val = value;
    var i: usize = 0;

    while (true) {
        var elem: u8 = @intCast(rem_val & 0x7f);
        rem_val >>= 7;
        if (rem_val == 0) {
            buffer[i] = elem;
            return i + 1;
        } else {
            elem |= 0x80;
            buffer[i] = elem;
            i += 1;
        }
    }
}

/// Process a single byte during decoding.
/// Returns either a complete value or indicates more bytes are needed.
///
/// Rust equivalent: `visit_byte`
fn visitByte(elem: u8, val: u16, nth_byte: usize) DecodeError!VisitStatus {
    // Detect alias encoding (non-canonical form)
    // A zero byte after the first byte is always an alias
    if (elem == 0 and nth_byte != 0) {
        return DecodeError.Alias;
    }

    const val32: u32 = val;
    const elem32: u32 = elem;
    const elem_val: u32 = elem32 & 0x7f;
    const elem_done = (elem32 & 0x80) == 0;

    // Check for too many bytes
    if (nth_byte >= MAX_ENCODING_LENGTH) {
        return DecodeError.TooLong;
    }

    // Third byte cannot have continue bit set
    if (nth_byte == MAX_ENCODING_LENGTH - 1 and !elem_done) {
        return DecodeError.ByteThreeContinues;
    }

    // Calculate shift amount (0, 7, or 14)
    const shift: u5 = @intCast(nth_byte * 7);
    const shifted_val = elem_val << shift;

    // Combine with existing value
    const new_val = val32 | shifted_val;

    // Check for overflow
    if (new_val > std.math.maxInt(u16)) {
        return DecodeError.Overflow;
    }

    const result: u16 = @intCast(new_val);

    if (elem_done) {
        return VisitStatus{ .done = result };
    } else {
        return VisitStatus{ .more = result };
    }
}

/// Decode a ShortU16 length from bytes.
/// Returns the decoded value and how many bytes were consumed.
///
/// Rust equivalent: `decode_shortu16_len`
pub fn decodeU16Len(bytes: []const u8) DecodeError!struct { value: usize, bytes_read: usize } {
    var val: u16 = 0;

    const max_bytes = @min(bytes.len, MAX_ENCODING_LENGTH);

    for (0..max_bytes) |nth_byte| {
        const byte = bytes[nth_byte];
        switch (try visitByte(byte, val, nth_byte)) {
            .more => |new_val| {
                val = new_val;
            },
            .done => |new_val| {
                return .{
                    .value = new_val,
                    .bytes_read = nth_byte + 1,
                };
            },
        }
    }

    // If we're here, we ran out of bytes while continue bit was set
    if (bytes.len < MAX_ENCODING_LENGTH) {
        return DecodeError.TooShort;
    }

    // We processed MAX_ENCODING_LENGTH bytes but never got a done signal
    return DecodeError.ByteThreeContinues;
}

/// ShortVec is a vector type that uses ShortU16 encoding for its length.
/// This allows efficient encoding of vectors with up to 65535 elements.
///
/// Rust equivalent: `solana_short_vec::ShortVec<T>`
pub fn ShortVec(comptime T: type) type {
    return struct {
        items: []const T,

        const Self = @This();

        pub fn init(items: []const T) Self {
            return .{ .items = items };
        }

        /// Calculate the encoded size of this ShortVec
        pub fn encodedSize(self: Self) usize {
            var len_buf: [MAX_ENCODING_LENGTH]u8 = undefined;
            const len_bytes = encodeU16(@intCast(self.items.len), &len_buf);
            return len_bytes + self.items.len * @sizeOf(T);
        }

        /// Encode the length prefix to the buffer.
        /// Returns the number of bytes written for the length.
        pub fn encodeLength(self: Self, buffer: *[MAX_ENCODING_LENGTH]u8) usize {
            if (self.items.len > std.math.maxInt(u16)) {
                @panic("ShortVec length exceeds u16 max");
            }
            return encodeU16(@intCast(self.items.len), buffer);
        }
    };
}

// ============================================================================
// Tests - Matching Rust source tests
// ============================================================================

/// Helper to encode a u16 value and return the bytes as a slice
fn encodeLen(value: u16) struct { data: [MAX_ENCODING_LENGTH]u8, len: usize } {
    var buffer: [MAX_ENCODING_LENGTH]u8 = undefined;
    const len = encodeU16(value, &buffer);
    return .{ .data = buffer, .len = len };
}

/// Helper to assert encoding and decoding round-trip correctly
fn assertLenEncoding(len: u16, expected_bytes: []const u8) !void {
    const encoded = encodeLen(len);

    // Check encoding
    try std.testing.expectEqualSlices(u8, expected_bytes, encoded.data[0..encoded.len]);

    // Check decoding
    const decoded = try decodeU16Len(expected_bytes);
    try std.testing.expectEqual(@as(usize, len), decoded.value);
    try std.testing.expectEqual(expected_bytes.len, decoded.bytes_read);
}

// Rust test: test_short_vec_encode_len
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/short-vec/src/lib.rs
test "short_vec: encode length" {
    try assertLenEncoding(0x0, &[_]u8{0x0});
    try assertLenEncoding(0x7f, &[_]u8{0x7f});
    try assertLenEncoding(0x80, &[_]u8{ 0x80, 0x01 });
    try assertLenEncoding(0xff, &[_]u8{ 0xff, 0x01 });
    try assertLenEncoding(0x100, &[_]u8{ 0x80, 0x02 });
    try assertLenEncoding(0x7fff, &[_]u8{ 0xff, 0xff, 0x01 });
    try assertLenEncoding(0xffff, &[_]u8{ 0xff, 0xff, 0x03 });
}

/// Helper to assert good deserialization
fn assertGoodDeserializedValue(expected: u16, bytes: []const u8) !void {
    const result = try decodeU16Len(bytes);
    try std.testing.expectEqual(@as(usize, expected), result.value);
}

/// Helper to assert bad deserialization (should error)
fn assertBadDeserializedValue(bytes: []const u8) !void {
    const result = decodeU16Len(bytes);
    try std.testing.expect(result == error.Alias or
        result == error.TooShort or
        result == error.TooLong or
        result == error.Overflow or
        result == error.ByteThreeContinues);
}

// Rust test: test_deserialize
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/short-vec/src/lib.rs
test "short_vec: deserialize" {
    // Good values
    try assertGoodDeserializedValue(0x0000, &[_]u8{0x00});
    try assertGoodDeserializedValue(0x007f, &[_]u8{0x7f});
    try assertGoodDeserializedValue(0x0080, &[_]u8{ 0x80, 0x01 });
    try assertGoodDeserializedValue(0x00ff, &[_]u8{ 0xff, 0x01 });
    try assertGoodDeserializedValue(0x0100, &[_]u8{ 0x80, 0x02 });
    try assertGoodDeserializedValue(0x07ff, &[_]u8{ 0xff, 0x0f });
    try assertGoodDeserializedValue(0x3fff, &[_]u8{ 0xff, 0x7f });
    try assertGoodDeserializedValue(0x4000, &[_]u8{ 0x80, 0x80, 0x01 });
    try assertGoodDeserializedValue(0xffff, &[_]u8{ 0xff, 0xff, 0x03 });

    // Aliases - non-canonical encodings that should be rejected
    // 0x0000 aliases
    try assertBadDeserializedValue(&[_]u8{ 0x80, 0x00 });
    try assertBadDeserializedValue(&[_]u8{ 0x80, 0x80, 0x00 });
    // 0x007f aliases
    try assertBadDeserializedValue(&[_]u8{ 0xff, 0x00 });
    try assertBadDeserializedValue(&[_]u8{ 0xff, 0x80, 0x00 });
    // 0x0080 alias
    try assertBadDeserializedValue(&[_]u8{ 0x80, 0x81, 0x00 });
    // 0x00ff alias
    try assertBadDeserializedValue(&[_]u8{ 0xff, 0x81, 0x00 });
    // 0x0100 alias
    try assertBadDeserializedValue(&[_]u8{ 0x80, 0x82, 0x00 });
    // 0x07ff alias
    try assertBadDeserializedValue(&[_]u8{ 0xff, 0x8f, 0x00 });
    // 0x3fff alias
    try assertBadDeserializedValue(&[_]u8{ 0xff, 0xff, 0x00 });

    // Too short
    try assertBadDeserializedValue(&[_]u8{});
    try assertBadDeserializedValue(&[_]u8{0x80});

    // Too long (continue bit set on byte 3)
    try assertBadDeserializedValue(&[_]u8{ 0x80, 0x80, 0x80, 0x00 });

    // Too large (overflow u16)
    // 0x0001_0000
    try assertBadDeserializedValue(&[_]u8{ 0x80, 0x80, 0x04 });
    // 0x0001_8000
    try assertBadDeserializedValue(&[_]u8{ 0x80, 0x80, 0x06 });
}

// Rust test: test_short_vec_u8
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/short-vec/src/lib.rs
test "short_vec: u8 vector" {
    const data = [_]u8{4} ** 32;
    const vec = ShortVec(u8).init(&data);

    // Encoded size should be 1 (length) + 32 (data)
    try std.testing.expectEqual(@as(usize, 33), vec.encodedSize());

    var len_buf: [MAX_ENCODING_LENGTH]u8 = undefined;
    const len_bytes = vec.encodeLength(&len_buf);
    try std.testing.expectEqual(@as(usize, 1), len_bytes);
    try std.testing.expectEqual(@as(u8, 32), len_buf[0]);
}

// Rust test: test_short_vec_u8_too_long
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/short-vec/src/lib.rs
test "short_vec: length limit" {
    // Max valid length (u16::MAX)
    const max_len: u16 = std.math.maxInt(u16);
    const encoded = encodeLen(max_len);
    try std.testing.expectEqual(@as(usize, 3), encoded.len);

    // Decode should work
    const decoded = try decodeU16Len(encoded.data[0..encoded.len]);
    try std.testing.expectEqual(@as(usize, max_len), decoded.value);
}

// Rust test: test_short_vec_aliased_length
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/short-vec/src/lib.rs
test "short_vec: aliased length rejected" {
    // 3-byte alias of 1: 0x81, 0x80, 0x00
    const bytes = [_]u8{ 0x81, 0x80, 0x00, 0x00 };
    const result = decodeU16Len(&bytes);
    try std.testing.expect(result == error.Alias);
}

// Additional test: round-trip encoding/decoding for all boundary values
test "short_vec: boundary values round-trip" {
    const test_values = [_]u16{
        0,     1,     126,   127,   128,   129,
        254,   255,   256,   16382, 16383, 16384,
        16385, 65534, 65535,
    };

    for (test_values) |value| {
        var buffer: [MAX_ENCODING_LENGTH]u8 = undefined;
        const encoded_len = encodeU16(value, &buffer);
        const decoded = try decodeU16Len(buffer[0..encoded_len]);
        try std.testing.expectEqual(@as(usize, value), decoded.value);
        try std.testing.expectEqual(encoded_len, decoded.bytes_read);
    }
}

// Additional test: ShortU16 struct interface
test "short_vec: ShortU16 struct" {
    const short = ShortU16.init(12345);
    var buffer: [MAX_ENCODING_LENGTH]u8 = undefined;
    const len = short.encode(&buffer);

    const decoded = try ShortU16.decode(buffer[0..len]);
    try std.testing.expectEqual(short.value, decoded.value.value);
    try std.testing.expectEqual(len, decoded.bytes_read);
}
