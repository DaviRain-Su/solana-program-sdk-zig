//! Shared Borsh `string` (u32 little-endian length prefix + UTF-8 payload) helpers
//! for `spl_token_metadata` instruction and state encoding.

const std = @import("std");

pub const WriteError = error{
    LengthOverflow,
    OutputTooSmall,
};

pub fn checkedAddLen(base: usize, addend: usize) error{LengthOverflow}!usize {
    return std.math.add(usize, base, addend) catch error.LengthOverflow;
}

/// Length of a Borsh-encoded string without any application-level max length cap.
pub fn borshStringLenUnbounded(value: []const u8) error{LengthOverflow}!usize {
    if (value.len > std.math.maxInt(u32)) return error.LengthOverflow;
    return try checkedAddLen(@sizeOf(u32), value.len);
}

pub fn writeBorshStringCore(out: []u8, value: []const u8) WriteError!usize {
    const expected_len = try borshStringLenUnbounded(value);
    if (out.len < expected_len) return error.OutputTooSmall;
    std.mem.writeInt(u32, out[0..@sizeOf(u32)], @intCast(value.len), .little);
    @memcpy(out[@sizeOf(u32)..expected_len], value);
    return expected_len;
}
