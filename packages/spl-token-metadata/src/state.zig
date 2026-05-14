//! Interface-state constants, field helpers, and bounded Borsh
//! TokenMetadata parsing/serialization for `spl_token_metadata`.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");
const borsh_string = @import("borsh_string.zig");
const parity_fixture = @import("parity_fixture.zig");

pub const INTERFACE_NAMESPACE = id.INTERFACE_NAMESPACE;
pub const INTERFACE_DISCRIMINATOR_LEN: usize = sol.DISCRIMINATOR_LEN;
pub const MaybeNullPubkey = @import("maybe_null_pubkey.zig").MaybeNullPubkey;
pub const SURFACE = "interface-only";
pub const TOKEN_METADATA_DISCRIMINATOR = [_]u8{ 112, 132, 90, 90, 11, 88, 157, 87 };
pub const MAX_STRING_LEN: usize = 1024;
pub const MAX_ADDITIONAL_METADATA_PAIRS: usize = 64;
pub const MAX_SERIALIZED_METADATA_BODY_LEN: usize = 16 * 1024;

pub const StateError = error{
    InvalidAccountData,
    BufferTooSmall,
    BoundsExceeded,
    LengthOverflow,
};

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

pub const AdditionalMetadata = struct {
    key: []const u8,
    value: []const u8,

    pub fn packedLen(self: AdditionalMetadata) error{ BoundsExceeded, LengthOverflow }!usize {
        return checkedAddLen(
            try borshStringLen(self.key),
            try borshStringLen(self.value),
        );
    }

    pub fn write(self: AdditionalMetadata, out: []u8) error{ BufferTooSmall, BoundsExceeded, LengthOverflow }![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len < expected_len) return error.BufferTooSmall;

        var offset: usize = 0;
        offset += try writeBorshString(out[offset..], self.key);
        offset += try writeBorshString(out[offset..], self.value);
        return out[0..offset];
    }
};

pub const TokenMetadata = struct {
    update_authority: MaybeNullPubkey,
    mint: sol.Pubkey,
    name: []const u8,
    symbol: []const u8,
    uri: []const u8,
    additional_metadata: []const AdditionalMetadata,

    pub const ParseError = StateError;
    pub const WriteError = error{
        BufferTooSmall,
        BoundsExceeded,
        LengthOverflow,
    };

    pub fn fromBytes(bytes: []const u8, additional_metadata_out: []AdditionalMetadata) ParseError!TokenMetadata {
        return parse(bytes, additional_metadata_out);
    }

    pub fn parse(bytes: []const u8, additional_metadata_out: []AdditionalMetadata) ParseError!TokenMetadata {
        if (bytes.len < INTERFACE_DISCRIMINATOR_LEN) return error.InvalidAccountData;
        if (!std.mem.eql(u8, bytes[0..INTERFACE_DISCRIMINATOR_LEN], TOKEN_METADATA_DISCRIMINATOR[0..])) {
            return error.InvalidAccountData;
        }
        return parseBody(bytes[INTERFACE_DISCRIMINATOR_LEN..], additional_metadata_out);
    }

    pub fn parseBody(bytes: []const u8, additional_metadata_out: []AdditionalMetadata) ParseError!TokenMetadata {
        if (bytes.len > MAX_SERIALIZED_METADATA_BODY_LEN) return error.BoundsExceeded;

        var offset: usize = 0;
        const update_authority = try readMaybeNullPubkey(bytes, &offset);
        const mint = try readPubkey(bytes, &offset);
        const name = try readBoundedString(bytes, &offset);
        const symbol = try readBoundedString(bytes, &offset);
        const uri = try readBoundedString(bytes, &offset);
        const pair_count = try readBoundedPairCount(bytes, &offset);

        if (pair_count > additional_metadata_out.len) return error.BufferTooSmall;

        for (0..pair_count) |i| {
            additional_metadata_out[i] = .{
                .key = try readBoundedString(bytes, &offset),
                .value = try readBoundedString(bytes, &offset),
            };
        }

        if (offset != bytes.len) return error.InvalidAccountData;

        return .{
            .update_authority = update_authority,
            .mint = mint,
            .name = name,
            .symbol = symbol,
            .uri = uri,
            .additional_metadata = additional_metadata_out[0..pair_count],
        };
    }

    pub fn bodyLen(self: TokenMetadata) error{ BoundsExceeded, LengthOverflow }!usize {
        if (self.additional_metadata.len > MAX_ADDITIONAL_METADATA_PAIRS) return error.BoundsExceeded;

        var len = MaybeNullPubkey.LEN + @sizeOf(sol.Pubkey);
        len = try checkedAddLen(len, try borshStringLen(self.name));
        len = try checkedAddLen(len, try borshStringLen(self.symbol));
        len = try checkedAddLen(len, try borshStringLen(self.uri));
        len = try checkedAddLen(len, @sizeOf(u32));

        for (self.additional_metadata) |entry| {
            len = try checkedAddLen(len, try entry.packedLen());
        }

        if (len > MAX_SERIALIZED_METADATA_BODY_LEN) return error.BoundsExceeded;
        return len;
    }

    pub fn packedLen(self: TokenMetadata) error{ BoundsExceeded, LengthOverflow }!usize {
        return checkedAddLen(INTERFACE_DISCRIMINATOR_LEN, try self.bodyLen());
    }

    pub fn writeBody(self: TokenMetadata, out: []u8) WriteError![]const u8 {
        const expected_len = try self.bodyLen();
        if (out.len < expected_len) return error.BufferTooSmall;

        var offset: usize = 0;
        _ = try self.update_authority.write(out[offset..][0..MaybeNullPubkey.LEN]);
        offset += MaybeNullPubkey.LEN;

        @memcpy(out[offset..][0..@sizeOf(sol.Pubkey)], self.mint[0..]);
        offset += @sizeOf(sol.Pubkey);

        offset += try writeBorshString(out[offset..], self.name);
        offset += try writeBorshString(out[offset..], self.symbol);
        offset += try writeBorshString(out[offset..], self.uri);

        std.mem.writeInt(u32, out[offset..][0..@sizeOf(u32)], @intCast(self.additional_metadata.len), .little);
        offset += @sizeOf(u32);

        for (self.additional_metadata) |entry| {
            const written = try entry.write(out[offset..]);
            offset += written.len;
        }

        return out[0..offset];
    }

    pub fn write(self: TokenMetadata, out: []u8) WriteError![]const u8 {
        const expected_len = try self.packedLen();
        if (out.len < expected_len) return error.BufferTooSmall;

        @memcpy(out[0..INTERFACE_DISCRIMINATOR_LEN], TOKEN_METADATA_DISCRIMINATOR[0..]);
        _ = try self.writeBody(out[INTERFACE_DISCRIMINATOR_LEN..][0 .. expected_len - INTERFACE_DISCRIMINATOR_LEN]);
        return out[0..expected_len];
    }

    pub fn encode(self: TokenMetadata, out: []u8) WriteError![]const u8 {
        return write(self, out);
    }
};

fn checkedAddLen(base: usize, addend: usize) error{LengthOverflow}!usize {
    return borsh_string.checkedAddLen(base, addend);
}

fn borshStringLen(value: []const u8) error{ BoundsExceeded, LengthOverflow }!usize {
    if (value.len > MAX_STRING_LEN) return error.BoundsExceeded;
    return borsh_string.borshStringLenUnbounded(value);
}

fn writeBorshString(out: []u8, value: []const u8) error{ BufferTooSmall, BoundsExceeded, LengthOverflow }!usize {
    return borsh_string.writeBorshStringCore(out, value) catch |err| switch (err) {
        error.LengthOverflow => return error.LengthOverflow,
        error.OutputTooSmall => return error.BufferTooSmall,
    };
}

fn readMaybeNullPubkey(bytes: []const u8, offset: *usize) StateError!MaybeNullPubkey {
    const end = checkedAddLen(offset.*, MaybeNullPubkey.LEN) catch return error.LengthOverflow;
    if (end > bytes.len) return error.InvalidAccountData;
    const parsed = MaybeNullPubkey.parse(bytes[offset.*..end]) catch return error.InvalidAccountData;
    offset.* = end;
    return parsed;
}

fn readPubkey(bytes: []const u8, offset: *usize) StateError!sol.Pubkey {
    const end = checkedAddLen(offset.*, @sizeOf(sol.Pubkey)) catch return error.LengthOverflow;
    if (end > bytes.len) return error.InvalidAccountData;

    var pubkey: sol.Pubkey = undefined;
    @memcpy(pubkey[0..], bytes[offset.*..end]);
    offset.* = end;
    return pubkey;
}

fn readBoundedPairCount(bytes: []const u8, offset: *usize) StateError!usize {
    const count = try readLenU32(bytes, offset);
    if (count > MAX_ADDITIONAL_METADATA_PAIRS) return error.BoundsExceeded;
    return count;
}

fn readBoundedString(bytes: []const u8, offset: *usize) StateError![]const u8 {
    const string_len = try readLenU32(bytes, offset);
    if (string_len > MAX_STRING_LEN) return error.BoundsExceeded;

    const end = checkedAddLen(offset.*, string_len) catch return error.LengthOverflow;
    if (end > bytes.len) return error.InvalidAccountData;

    const value = bytes[offset.*..end];
    offset.* = end;
    return value;
}

fn readLenU32(bytes: []const u8, offset: *usize) StateError!usize {
    const end = checkedAddLen(offset.*, @sizeOf(u32)) catch return error.LengthOverflow;
    if (end > bytes.len) return error.InvalidAccountData;
    const value = std.mem.readInt(u32, bytes[offset.*..][0..@sizeOf(u32)], .little);
    offset.* = end;
    return @intCast(value);
}

test "state scaffold exposes canonical namespace discriminator width and interface-only surface" {
    try std.testing.expectEqualStrings("spl_token_metadata_interface", INTERFACE_NAMESPACE);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expectEqual(@as(usize, 8), INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expect(@hasDecl(@This(), "MaybeNullPubkey"));
    try std.testing.expect(@hasDecl(@This(), "TokenMetadata"));
    try std.testing.expect(@hasDecl(@This(), "AdditionalMetadata"));
    try std.testing.expectEqualStrings("interface-only", SURFACE);
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 112, 132, 90, 90, 11, 88, 157, 87 },
        &TOKEN_METADATA_DISCRIMINATOR,
    );
}

test "state surface exposes bounded TokenMetadata parser/serializer types" {
    const metadata: TokenMetadata = .{
        .update_authority = MaybeNullPubkey.initNull(),
        .mint = [_]u8{0} ** 32,
        .name = "",
        .symbol = "",
        .uri = "",
        .additional_metadata = &.{},
    };
    _ = metadata;

    try std.testing.expect(!@hasDecl(@This(), "processor"));
    try std.testing.expect(!@hasDecl(@This(), "mutate"));
    try std.testing.expect(!@hasDecl(@This(), "realloc"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}

test "Field layout and parsing are canonical" {
    const expectField = @import("field_test_assert.zig").expectField;
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

fn testPubkey(base: u8) sol.Pubkey {
    var pubkey: sol.Pubkey = undefined;
    for (pubkey[0..], 0..) |*byte, i| byte.* = base +% @as(u8, @intCast(i * 3));
    return pubkey;
}

fn writeExpectedString(out: []u8, value: []const u8) usize {
    std.mem.writeInt(u32, out[0..4], @intCast(value.len), .little);
    @memcpy(out[4 .. 4 + value.len], value);
    return 4 + value.len;
}

fn expectMaybeNullPubkeyEqual(actual: MaybeNullPubkey, expected: MaybeNullPubkey) !void {
    try std.testing.expectEqual(expected.isPresent(), actual.isPresent());
    if (expected.presentKey()) |expected_key| {
        try std.testing.expectEqualSlices(u8, expected_key[0..], actual.presentKey().?[0..]);
    } else {
        try std.testing.expect(actual.presentKey() == null);
    }
}

fn expectTokenMetadataEqual(actual: TokenMetadata, expected: TokenMetadata) !void {
    try expectMaybeNullPubkeyEqual(actual.update_authority, expected.update_authority);
    try std.testing.expectEqualSlices(u8, expected.mint[0..], actual.mint[0..]);
    try std.testing.expectEqualStrings(expected.name, actual.name);
    try std.testing.expectEqualStrings(expected.symbol, actual.symbol);
    try std.testing.expectEqualStrings(expected.uri, actual.uri);
    try std.testing.expectEqual(expected.additional_metadata.len, actual.additional_metadata.len);
    for (expected.additional_metadata, actual.additional_metadata) |expected_entry, actual_entry| {
        try std.testing.expectEqualStrings(expected_entry.key, actual_entry.key);
        try std.testing.expectEqualStrings(expected_entry.value, actual_entry.value);
    }
}

test "TokenMetadata state field order is canonical and additional metadata order is preserved" {
    const update_authority_key = testPubkey(0x11);
    const mint_key = testPubkey(0x90);
    const expected_pairs = [_]AdditionalMetadata{
        .{ .key = "alpha", .value = "1" },
        .{ .key = "dup", .value = "first" },
        .{ .key = "dup", .value = "second" },
    };
    const expected_metadata = TokenMetadata{
        .update_authority = MaybeNullPubkey.fromPubkey(&update_authority_key),
        .mint = mint_key,
        .name = "Token",
        .symbol = "TOK",
        .uri = "uri",
        .additional_metadata = expected_pairs[0..],
    };

    const expected_body_len = 32 + 32 + (4 + 5) + (4 + 3) + (4 + 3) + 4 +
        ((4 + 5) + (4 + 1)) +
        ((4 + 3) + (4 + 5)) +
        ((4 + 3) + (4 + 6));
    var expected_body: [expected_body_len]u8 = undefined;
    var offset: usize = 0;
    _ = try expected_metadata.update_authority.write(expected_body[offset..][0..32]);
    offset += 32;
    @memcpy(expected_body[offset..][0..32], mint_key[0..]);
    offset += 32;
    offset += writeExpectedString(expected_body[offset..], "Token");
    offset += writeExpectedString(expected_body[offset..], "TOK");
    offset += writeExpectedString(expected_body[offset..], "uri");
    std.mem.writeInt(u32, expected_body[offset..][0..4], 3, .little);
    offset += 4;
    offset += writeExpectedString(expected_body[offset..], "alpha");
    offset += writeExpectedString(expected_body[offset..], "1");
    offset += writeExpectedString(expected_body[offset..], "dup");
    offset += writeExpectedString(expected_body[offset..], "first");
    offset += writeExpectedString(expected_body[offset..], "dup");
    offset += writeExpectedString(expected_body[offset..], "second");
    try std.testing.expectEqual(expected_body.len, offset);

    var parsed_pairs: [expected_pairs.len]AdditionalMetadata = undefined;
    const parsed_body = try TokenMetadata.parseBody(expected_body[0..], parsed_pairs[0..]);
    try expectTokenMetadataEqual(parsed_body, expected_metadata);

    const expected_total_len = INTERFACE_DISCRIMINATOR_LEN + expected_body.len;
    var expected_bytes: [expected_total_len]u8 = undefined;
    @memcpy(expected_bytes[0..INTERFACE_DISCRIMINATOR_LEN], TOKEN_METADATA_DISCRIMINATOR[0..]);
    @memcpy(expected_bytes[INTERFACE_DISCRIMINATOR_LEN..], expected_body[0..]);

    var parsed_pairs_full: [expected_pairs.len]AdditionalMetadata = undefined;
    const parsed_full = try TokenMetadata.parse(expected_bytes[0..], parsed_pairs_full[0..]);
    try expectTokenMetadataEqual(parsed_full, expected_metadata);

    var body_out: [expected_body_len + 4]u8 = [_]u8{0xaa} ** (expected_body_len + 4);
    const written_body = try expected_metadata.writeBody(body_out[0..]);
    try std.testing.expectEqual(expected_body.len, written_body.len);
    try std.testing.expectEqualSlices(u8, expected_body[0..], written_body);
    try std.testing.expectEqual(@as(u8, 0xaa), body_out[expected_body_len]);

    var full_out: [expected_total_len + 4]u8 = [_]u8{0xbb} ** (expected_total_len + 4);
    const written_full = try expected_metadata.write(full_out[0..]);
    try std.testing.expectEqual(expected_total_len, written_full.len);
    try std.testing.expectEqualSlices(u8, expected_bytes[0..], written_full);
    try std.testing.expectEqual(@as(u8, 0xbb), full_out[expected_total_len]);
}

test "TokenMetadata parser rejects hostile lengths oversized bodies and truncated pairs" {
    const min_prefix_len = 32 + 32;

    var oversized_name_body: [min_prefix_len + 4]u8 = [_]u8{0} ** (min_prefix_len + 4);
    std.mem.writeInt(u32, oversized_name_body[min_prefix_len..][0..4], MAX_STRING_LEN + 1, .little);
    var pair_scratch: [1]AdditionalMetadata = undefined;
    try std.testing.expectError(
        error.BoundsExceeded,
        TokenMetadata.parseBody(oversized_name_body[0..], pair_scratch[0..]),
    );

    var hostile_name_body: [min_prefix_len + 4]u8 = [_]u8{0} ** (min_prefix_len + 4);
    std.mem.writeInt(u32, hostile_name_body[min_prefix_len..][0..4], std.math.maxInt(u32), .little);
    try std.testing.expectError(
        error.BoundsExceeded,
        TokenMetadata.parseBody(hostile_name_body[0..], pair_scratch[0..]),
    );

    const pair_count_body_len = min_prefix_len + 4 + 0 + 4 + 0 + 4 + 0 + 4;
    var oversized_pair_count_body: [pair_count_body_len]u8 = [_]u8{0} ** pair_count_body_len;
    std.mem.writeInt(u32, oversized_pair_count_body[pair_count_body_len - 4 ..][0..4], MAX_ADDITIONAL_METADATA_PAIRS + 1, .little);
    try std.testing.expectError(
        error.BoundsExceeded,
        TokenMetadata.parseBody(oversized_pair_count_body[0..], pair_scratch[0..]),
    );

    var too_large_body: [MAX_SERIALIZED_METADATA_BODY_LEN + 1]u8 = [_]u8{0} ** (MAX_SERIALIZED_METADATA_BODY_LEN + 1);
    try std.testing.expectError(
        error.BoundsExceeded,
        TokenMetadata.parseBody(too_large_body[0..], pair_scratch[0..]),
    );

    const truncated_pair_body_len = min_prefix_len + 4 + 0 + 4 + 0 + 4 + 0 + 4 + 4 + 3;
    var truncated_pair_body: [truncated_pair_body_len]u8 = [_]u8{0} ** truncated_pair_body_len;
    var truncated_offset: usize = min_prefix_len;
    truncated_offset += writeExpectedString(truncated_pair_body[truncated_offset..], "");
    truncated_offset += writeExpectedString(truncated_pair_body[truncated_offset..], "");
    truncated_offset += writeExpectedString(truncated_pair_body[truncated_offset..], "");
    std.mem.writeInt(u32, truncated_pair_body[truncated_offset..][0..4], 1, .little);
    truncated_offset += 4;
    std.mem.writeInt(u32, truncated_pair_body[truncated_offset..][0..4], 4, .little);
    truncated_offset += 4;
    @memcpy(truncated_pair_body[truncated_offset..][0..3], "key");
    try std.testing.expectError(
        error.InvalidAccountData,
        TokenMetadata.parseBody(truncated_pair_body[0..], pair_scratch[0..]),
    );
}

test "TokenMetadata serializer reports exact length and enforces caller buffers" {
    const update_authority_key = testPubkey(0x44);
    const mint_key = testPubkey(0xb0);
    const pairs = [_]AdditionalMetadata{
        .{ .key = "x", .value = "1" },
        .{ .key = "y", .value = "22" },
    };
    const metadata = TokenMetadata{
        .update_authority = MaybeNullPubkey.fromPubkey(&update_authority_key),
        .mint = mint_key,
        .name = "n",
        .symbol = "s",
        .uri = "u",
        .additional_metadata = pairs[0..],
    };

    const expected_body_len = 32 + 32 + (4 + 1) + (4 + 1) + (4 + 1) + 4 +
        ((4 + 1) + (4 + 1)) +
        ((4 + 1) + (4 + 2));
    try std.testing.expectEqual(expected_body_len, try metadata.bodyLen());
    try std.testing.expectEqual(INTERFACE_DISCRIMINATOR_LEN + expected_body_len, try metadata.packedLen());

    var body_short: [expected_body_len - 1]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, metadata.writeBody(body_short[0..]));

    var full_short: [INTERFACE_DISCRIMINATOR_LEN + expected_body_len - 1]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, metadata.write(full_short[0..]));

    var parsed_pairs: [pairs.len - 1]AdditionalMetadata = undefined;
    var enough_bytes: [INTERFACE_DISCRIMINATOR_LEN + expected_body_len]u8 = undefined;
    _ = try metadata.write(enough_bytes[0..]);
    try std.testing.expectError(
        error.BufferTooSmall,
        TokenMetadata.parse(enough_bytes[0..], parsed_pairs[0..]),
    );

    const oversized_name = [_]u8{'a'} ** (MAX_STRING_LEN + 1);
    const oversize_metadata = TokenMetadata{
        .update_authority = MaybeNullPubkey.initNull(),
        .mint = mint_key,
        .name = oversized_name[0..],
        .symbol = "",
        .uri = "",
        .additional_metadata = &.{},
    };
    try std.testing.expectError(error.BoundsExceeded, oversize_metadata.bodyLen());

    const too_many_pairs = [_]AdditionalMetadata{.{ .key = "", .value = "" }} ** (MAX_ADDITIONAL_METADATA_PAIRS + 1);
    const oversized_pairs_metadata = TokenMetadata{
        .update_authority = MaybeNullPubkey.initNull(),
        .mint = mint_key,
        .name = "",
        .symbol = "",
        .uri = "",
        .additional_metadata = too_many_pairs[0..],
    };
    try std.testing.expectError(error.BoundsExceeded, oversized_pairs_metadata.bodyLen());
}

test "TokenMetadata v0_1 keeps mutation and emit slice helpers absent" {
    try std.testing.expect(!@hasDecl(TokenMetadata, "setName"));
    try std.testing.expect(!@hasDecl(TokenMetadata, "setSymbol"));
    try std.testing.expect(!@hasDecl(TokenMetadata, "setUri"));
    try std.testing.expect(!@hasDecl(TokenMetadata, "update"));
    try std.testing.expect(!@hasDecl(TokenMetadata, "remove"));
    try std.testing.expect(!@hasDecl(@This(), "emitSlice"));
    try std.testing.expect(!@hasDecl(@This(), "extractEmitState"));
}

fn parityExpectedMetadata(
    case: parity_fixture.StateCase,
    additional_metadata_out: []AdditionalMetadata,
) TokenMetadata {
    for (case.additional_metadata, 0..) |entry, i| {
        additional_metadata_out[i] = .{
            .key = entry.key,
            .value = entry.value,
        };
    }

    return .{
        .update_authority = MaybeNullPubkey.fromBytes(case.update_authority[0..]) catch unreachable,
        .mint = case.mint,
        .name = case.name,
        .symbol = case.symbol,
        .uri = case.uri,
        .additional_metadata = additional_metadata_out[0..case.additional_metadata.len],
    };
}

test "official Rust parity fixture matches TokenMetadata state bytes" {
    const loaded = try parity_fixture.load(std.testing.allocator);
    defer loaded.deinit();

    for (loaded.value.states) |case| {
        const original = try std.testing.allocator.dupe(u8, case.data);
        defer std.testing.allocator.free(original);

        const parsed_storage = try std.testing.allocator.alloc(AdditionalMetadata, case.additional_metadata.len);
        defer std.testing.allocator.free(parsed_storage);
        const expected_storage = try std.testing.allocator.alloc(AdditionalMetadata, case.additional_metadata.len);
        defer std.testing.allocator.free(expected_storage);

        const expected = parityExpectedMetadata(case, expected_storage);
        const parsed = try TokenMetadata.parse(case.data, parsed_storage);
        try expectTokenMetadataEqual(parsed, expected);
        try std.testing.expectEqualSlices(u8, original, case.data);

        const body_bytes = case.data[INTERFACE_DISCRIMINATOR_LEN..];
        const parsed_body_storage = try std.testing.allocator.alloc(AdditionalMetadata, case.additional_metadata.len);
        defer std.testing.allocator.free(parsed_body_storage);
        const parsed_body = try TokenMetadata.parseBody(body_bytes, parsed_body_storage);
        try expectTokenMetadataEqual(parsed_body, expected);
        try std.testing.expectEqualSlices(u8, original[INTERFACE_DISCRIMINATOR_LEN..], body_bytes);

        const encoded = try std.testing.allocator.alloc(u8, case.data.len);
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqualSlices(u8, case.data, try expected.write(encoded));
    }
}

test {
    std.testing.refAllDecls(@This());
}
