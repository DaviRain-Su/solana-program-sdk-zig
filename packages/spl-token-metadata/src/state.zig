//! Interface-state constants and field helpers for `spl_token_metadata`.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");

pub const INTERFACE_NAMESPACE = id.INTERFACE_NAMESPACE;
pub const INTERFACE_DISCRIMINATOR_LEN: usize = sol.DISCRIMINATOR_LEN;
pub const MaybeNullPubkey = @import("maybe_null_pubkey.zig").MaybeNullPubkey;
pub const SURFACE = "interface-only";
pub const TOKEN_METADATA_DISCRIMINATOR = [_]u8{ 112, 132, 90, 90, 11, 88, 157, 87 };

pub const FieldTag = enum(u8) {
    name = 0,
    symbol = 1,
    uri = 2,
    key = 3,
};

pub const Field = union(FieldTag) {
    name: void,
    symbol: void,
    uri: void,
    key: []const u8,

    pub const EncodeError = error{
        InvalidInstructionDataSliceLength,
        LengthOverflow,
    };

    pub const ParseResult = struct {
        field: Field,
        consumed: usize,
    };

    pub fn packedLen(self: Field) EncodeError!usize {
        return switch (self) {
            .name, .symbol, .uri => 1,
            .key => |key| blk: {
                if (key.len > std.math.maxInt(u32)) return error.LengthOverflow;
                break :blk std.math.add(usize, 1 + @sizeOf(u32), key.len) catch error.LengthOverflow;
            },
        };
    }

    pub fn pack(self: Field, out: []u8) EncodeError![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len != expected_len) return error.InvalidInstructionDataSliceLength;

        switch (self) {
            .name => out[0] = @intFromEnum(FieldTag.name),
            .symbol => out[0] = @intFromEnum(FieldTag.symbol),
            .uri => out[0] = @intFromEnum(FieldTag.uri),
            .key => |key| {
                out[0] = @intFromEnum(FieldTag.key);
                std.mem.writeInt(u32, out[1..][0..@sizeOf(u32)], @intCast(key.len), .little);
                @memcpy(out[1 + @sizeOf(u32) ..], key);
            },
        }

        return out[0..expected_len];
    }

    pub fn parse(input: []const u8) sol.ProgramError!ParseResult {
        if (input.len == 0) return sol.ProgramError.InvalidInstructionData;

        return switch (input[0]) {
            @intFromEnum(FieldTag.name) => .{
                .field = .{ .name = {} },
                .consumed = 1,
            },
            @intFromEnum(FieldTag.symbol) => .{
                .field = .{ .symbol = {} },
                .consumed = 1,
            },
            @intFromEnum(FieldTag.uri) => .{
                .field = .{ .uri = {} },
                .consumed = 1,
            },
            @intFromEnum(FieldTag.key) => blk: {
                if (input.len < 1 + @sizeOf(u32)) return sol.ProgramError.InvalidInstructionData;
                const key_len = sol.instruction.tryReadUnaligned(u32, input, 1) orelse
                    return sol.ProgramError.InvalidInstructionData;
                const end = std.math.add(usize, 1 + @sizeOf(u32), @as(usize, key_len))
                    catch return sol.ProgramError.InvalidInstructionData;
                if (input.len < end) return sol.ProgramError.InvalidInstructionData;
                break :blk .{
                    .field = .{ .key = input[1 + @sizeOf(u32) .. end] },
                    .consumed = end,
                };
            },
            else => sol.ProgramError.InvalidInstructionData,
        };
    }
};

fn expectField(actual: Field, expected: Field) !void {
    switch (expected) {
        .name => try std.testing.expect(switch (actual) {
            .name => true,
            else => false,
        }),
        .symbol => try std.testing.expect(switch (actual) {
            .symbol => true,
            else => false,
        }),
        .uri => try std.testing.expect(switch (actual) {
            .uri => true,
            else => false,
        }),
        .key => |expected_key| switch (actual) {
            .key => |actual_key| try std.testing.expectEqualStrings(expected_key, actual_key),
            else => return error.TestUnexpectedResult,
        },
    }
}

test "state scaffold exposes canonical namespace discriminator width and interface-only surface" {
    try std.testing.expectEqualStrings("spl_token_metadata_interface", INTERFACE_NAMESPACE);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expectEqual(@as(usize, 8), INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expect(@hasDecl(@This(), "MaybeNullPubkey"));
    try std.testing.expectEqualStrings("interface-only", SURFACE);
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 112, 132, 90, 90, 11, 88, 157, 87 },
        &TOKEN_METADATA_DISCRIMINATOR,
    );
}

test "state surface stays parser-only and interface scoped" {
    try std.testing.expect(!@hasDecl(@This(), "TokenMetadata"));
    try std.testing.expect(!@hasDecl(@This(), "processor"));
    try std.testing.expect(!@hasDecl(@This(), "mutate"));
    try std.testing.expect(!@hasDecl(@This(), "realloc"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}

test "Field layout and parsing are canonical" {
    var name_bytes: [1]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{0},
        try (Field{ .name = {} }).pack(name_bytes[0..]),
    );
    try expectField((try Field.parse(name_bytes[0..])).field, .{ .name = {} });

    var symbol_bytes: [1]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{1},
        try (Field{ .symbol = {} }).pack(symbol_bytes[0..]),
    );
    try expectField((try Field.parse(symbol_bytes[0..])).field, .{ .symbol = {} });

    var uri_bytes: [1]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{2},
        try (Field{ .uri = {} }).pack(uri_bytes[0..]),
    );
    try expectField((try Field.parse(uri_bytes[0..])).field, .{ .uri = {} });

    var key_bytes: [1 + 4 + 6]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 3, 6, 0, 0, 0, 'c', 'u', 's', 't', 'o', 'm' },
        try (Field{ .key = "custom" }).pack(key_bytes[0..]),
    );

    const parsed = try Field.parse(key_bytes[0..]);
    try std.testing.expectEqual(key_bytes.len, parsed.consumed);
    try expectField(parsed.field, .{ .key = "custom" });
}

test "Field parser rejects unknown tags and malformed key payloads" {
    try std.testing.expectError(sol.ProgramError.InvalidInstructionData, Field.parse(&[_]u8{}));
    try std.testing.expectError(sol.ProgramError.InvalidInstructionData, Field.parse(&[_]u8{9}));
    try std.testing.expectError(
        sol.ProgramError.InvalidInstructionData,
        Field.parse(&[_]u8{ 3, 1, 0, 0, 0 }),
    );
}

test {
    std.testing.refAllDecls(@This());
}
