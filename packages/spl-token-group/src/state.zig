//! Fixed-layout state parsing for `spl_token_group`.

const std = @import("std");
const sol = @import("solana_program_sdk");
const id = @import("id.zig");

pub const INTERFACE_NAMESPACE = id.INTERFACE_NAMESPACE;
pub const INTERFACE_DISCRIMINATOR_LEN: usize = sol.DISCRIMINATOR_LEN;
pub const MaybeNullPubkey = @import("maybe_null_pubkey.zig").MaybeNullPubkey;
pub const SURFACE = "interface-only";
pub const TOKEN_GROUP_DISCRIMINATOR = [_]u8{ 0xd6, 0x0f, 0x3f, 0x84, 0x31, 0x77, 0xd1, 0x28 };
pub const TOKEN_GROUP_MEMBER_DISCRIMINATOR = [_]u8{ 0xfe, 0x32, 0xa8, 0x86, 0x58, 0x7e, 0x64, 0xba };

pub const StateError = error{InvalidAccountData};

pub const TokenGroup = struct {
    pub const BODY_LEN: usize = MaybeNullPubkey.LEN + @sizeOf(sol.Pubkey) + @sizeOf(u64) + @sizeOf(u64);
    pub const PACKED_LEN: usize = INTERFACE_DISCRIMINATOR_LEN + BODY_LEN;
    pub const ParseError = StateError;

    update_authority: MaybeNullPubkey,
    mint: sol.Pubkey,
    size: u64,
    max_size: u64,

    pub fn fromBytes(bytes: []const u8) ParseError!TokenGroup {
        return parse(bytes);
    }

    pub fn parse(bytes: []const u8) ParseError!TokenGroup {
        if (bytes.len != PACKED_LEN) return error.InvalidAccountData;
        if (!std.mem.eql(u8, bytes[0..INTERFACE_DISCRIMINATOR_LEN], TOKEN_GROUP_DISCRIMINATOR[0..])) {
            return error.InvalidAccountData;
        }
        return parseBody(bytes[INTERFACE_DISCRIMINATOR_LEN..]);
    }

    pub fn parseBody(bytes: []const u8) ParseError!TokenGroup {
        if (bytes.len != BODY_LEN) return error.InvalidAccountData;

        var offset: usize = 0;
        return .{
            .update_authority = try readMaybeNullPubkey(bytes, &offset),
            .mint = try readPubkey(bytes, &offset),
            .size = try readLeU64(bytes, &offset),
            .max_size = try readLeU64(bytes, &offset),
        };
    }
};

pub const TokenGroupMember = struct {
    pub const BODY_LEN: usize = @sizeOf(sol.Pubkey) + @sizeOf(sol.Pubkey) + @sizeOf(u64);
    pub const PACKED_LEN: usize = INTERFACE_DISCRIMINATOR_LEN + BODY_LEN;
    pub const ParseError = StateError;

    mint: sol.Pubkey,
    group: sol.Pubkey,
    member_number: u64,

    pub fn fromBytes(bytes: []const u8) ParseError!TokenGroupMember {
        return parse(bytes);
    }

    pub fn parse(bytes: []const u8) ParseError!TokenGroupMember {
        if (bytes.len != PACKED_LEN) return error.InvalidAccountData;
        if (!std.mem.eql(u8, bytes[0..INTERFACE_DISCRIMINATOR_LEN], TOKEN_GROUP_MEMBER_DISCRIMINATOR[0..])) {
            return error.InvalidAccountData;
        }
        return parseBody(bytes[INTERFACE_DISCRIMINATOR_LEN..]);
    }

    pub fn parseBody(bytes: []const u8) ParseError!TokenGroupMember {
        if (bytes.len != BODY_LEN) return error.InvalidAccountData;

        var offset: usize = 0;
        return .{
            .mint = try readPubkey(bytes, &offset),
            .group = try readPubkey(bytes, &offset),
            .member_number = try readLeU64(bytes, &offset),
        };
    }
};

fn readMaybeNullPubkey(bytes: []const u8, offset: *usize) StateError!MaybeNullPubkey {
    const end = std.math.add(usize, offset.*, MaybeNullPubkey.LEN) catch return error.InvalidAccountData;
    if (end > bytes.len) return error.InvalidAccountData;
    const parsed = MaybeNullPubkey.parse(bytes[offset.*..end]) catch return error.InvalidAccountData;
    offset.* = end;
    return parsed;
}

fn readPubkey(bytes: []const u8, offset: *usize) StateError!sol.Pubkey {
    const end = std.math.add(usize, offset.*, @sizeOf(sol.Pubkey)) catch return error.InvalidAccountData;
    if (end > bytes.len) return error.InvalidAccountData;

    var pubkey: sol.Pubkey = undefined;
    @memcpy(pubkey[0..], bytes[offset.*..end]);
    offset.* = end;
    return pubkey;
}

fn readLeU64(bytes: []const u8, offset: *usize) StateError!u64 {
    const end = std.math.add(usize, offset.*, @sizeOf(u64)) catch return error.InvalidAccountData;
    if (end > bytes.len) return error.InvalidAccountData;
    const value = std.mem.readInt(u64, bytes[offset.*..][0..@sizeOf(u64)], .little);
    offset.* = end;
    return value;
}

test "state scaffold exposes canonical namespace and discriminator width" {
    try std.testing.expectEqualStrings("spl_token_group_interface", INTERFACE_NAMESPACE);
    try std.testing.expectEqual(sol.DISCRIMINATOR_LEN, INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expectEqual(@as(usize, 8), INTERFACE_DISCRIMINATOR_LEN);
    try std.testing.expect(@hasDecl(@This(), "MaybeNullPubkey"));
    try std.testing.expectEqualStrings("interface-only", SURFACE);
}

test "state surface stays parser-only and interface scoped" {
    try std.testing.expect(!@hasDecl(@This(), "processor"));
    try std.testing.expect(!@hasDecl(@This(), "mutate"));
    try std.testing.expect(!@hasDecl(@This(), "realloc"));
    try std.testing.expect(!@hasDecl(@This(), "transaction"));
}

fn testPubkey(base: u8) sol.Pubkey {
    var pubkey: sol.Pubkey = undefined;
    for (pubkey[0..], 0..) |*byte, i| byte.* = base +% @as(u8, @intCast(i * 5));
    return pubkey;
}

fn expectMaybeNullPubkeyEqual(actual: MaybeNullPubkey, expected: MaybeNullPubkey) !void {
    try std.testing.expectEqual(expected.isPresent(), actual.isPresent());
    if (expected.presentKey()) |expected_key| {
        try std.testing.expectEqualSlices(u8, expected_key[0..], actual.presentKey().?[0..]);
    } else {
        try std.testing.expect(actual.presentKey() == null);
    }
}

test "TokenGroup and TokenGroupMember state discriminators are canonical" {
    try std.testing.expect(@hasDecl(@This(), "TOKEN_GROUP_DISCRIMINATOR"));
    try std.testing.expect(@hasDecl(@This(), "TOKEN_GROUP_MEMBER_DISCRIMINATOR"));
    try std.testing.expect(@hasDecl(@This(), "TokenGroup"));
    try std.testing.expect(@hasDecl(@This(), "TokenGroupMember"));
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xd6, 0x0f, 0x3f, 0x84, 0x31, 0x77, 0xd1, 0x28 },
        &TOKEN_GROUP_DISCRIMINATOR,
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xfe, 0x32, 0xa8, 0x86, 0x58, 0x7e, 0x64, 0xba },
        &TOKEN_GROUP_MEMBER_DISCRIMINATOR,
    );
}

test "TokenGroup parser accepts body-only and discriminator-prefixed layouts with exact lengths" {
    const update_authority_key = testPubkey(0x14);
    const mint_key = testPubkey(0x80);

    var body: [80]u8 = undefined;
    _ = try MaybeNullPubkey.fromPubkey(&update_authority_key).write(body[0..32]);
    @memcpy(body[32..64], mint_key[0..]);
    std.mem.writeInt(u64, body[64..72], 0x0123_4567_89ab_cdef, .little);
    std.mem.writeInt(u64, body[72..80], 0xfedc_ba98_7654_3210, .little);

    const parsed_body = try TokenGroup.parseBody(body[0..]);
    try expectMaybeNullPubkeyEqual(parsed_body.update_authority, MaybeNullPubkey.fromPubkey(&update_authority_key));
    try std.testing.expectEqualSlices(u8, mint_key[0..], parsed_body.mint[0..]);
    try std.testing.expectEqual(@as(u64, 0x0123_4567_89ab_cdef), parsed_body.size);
    try std.testing.expectEqual(@as(u64, 0xfedc_ba98_7654_3210), parsed_body.max_size);

    var prefixed: [INTERFACE_DISCRIMINATOR_LEN + body.len]u8 = undefined;
    @memcpy(prefixed[0..INTERFACE_DISCRIMINATOR_LEN], &TOKEN_GROUP_DISCRIMINATOR);
    @memcpy(prefixed[INTERFACE_DISCRIMINATOR_LEN..], body[0..]);

    const parsed_prefixed = try TokenGroup.parse(prefixed[0..]);
    try expectMaybeNullPubkeyEqual(parsed_prefixed.update_authority, MaybeNullPubkey.fromPubkey(&update_authority_key));
    try std.testing.expectEqualSlices(u8, mint_key[0..], parsed_prefixed.mint[0..]);
    try std.testing.expectEqual(@as(u64, 0x0123_4567_89ab_cdef), parsed_prefixed.size);
    try std.testing.expectEqual(@as(u64, 0xfedc_ba98_7654_3210), parsed_prefixed.max_size);

    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parseBody(body[0 .. body.len - 1]));
    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parseBody(prefixed[0..]));
    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parse(prefixed[0 .. prefixed.len - 1]));
}

test "TokenGroup parser rejects wrong discriminator and malformed lengths" {
    const update_authority_key = testPubkey(0x33);
    const mint_key = testPubkey(0x91);

    var body: [80]u8 = undefined;
    _ = try MaybeNullPubkey.fromPubkey(&update_authority_key).write(body[0..32]);
    @memcpy(body[32..64], mint_key[0..]);
    std.mem.writeInt(u64, body[64..72], 7, .little);
    std.mem.writeInt(u64, body[72..80], 11, .little);

    var wrong_prefixed: [INTERFACE_DISCRIMINATOR_LEN + body.len]u8 = undefined;
    @memcpy(wrong_prefixed[0..INTERFACE_DISCRIMINATOR_LEN], &TOKEN_GROUP_MEMBER_DISCRIMINATOR);
    @memcpy(wrong_prefixed[INTERFACE_DISCRIMINATOR_LEN..], body[0..]);

    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parse(&[_]u8{}));
    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parse(wrong_prefixed[0..]));
    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parse(wrong_prefixed[0 .. wrong_prefixed.len - 1]));

    var plus_one_body: [81]u8 = undefined;
    @memcpy(plus_one_body[0..80], body[0..]);
    plus_one_body[80] = 0xaa;
    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parseBody(plus_one_body[0..]));

    var plus_one_prefixed: [INTERFACE_DISCRIMINATOR_LEN + plus_one_body.len]u8 = undefined;
    @memcpy(plus_one_prefixed[0..INTERFACE_DISCRIMINATOR_LEN], &TOKEN_GROUP_DISCRIMINATOR);
    @memcpy(plus_one_prefixed[INTERFACE_DISCRIMINATOR_LEN..], plus_one_body[0..]);
    try std.testing.expectError(error.InvalidAccountData, TokenGroup.parse(plus_one_prefixed[0..]));
}

test "TokenGroupMember parser accepts body-only and discriminator-prefixed layouts with exact lengths" {
    const mint_key = testPubkey(0x44);
    const group_key = testPubkey(0xa0);

    var body: [72]u8 = undefined;
    @memcpy(body[0..32], mint_key[0..]);
    @memcpy(body[32..64], group_key[0..]);
    std.mem.writeInt(u64, body[64..72], 0x8877_6655_4433_2211, .little);

    const parsed_body = try TokenGroupMember.parseBody(body[0..]);
    try std.testing.expectEqualSlices(u8, mint_key[0..], parsed_body.mint[0..]);
    try std.testing.expectEqualSlices(u8, group_key[0..], parsed_body.group[0..]);
    try std.testing.expectEqual(@as(u64, 0x8877_6655_4433_2211), parsed_body.member_number);

    var prefixed: [INTERFACE_DISCRIMINATOR_LEN + body.len]u8 = undefined;
    @memcpy(prefixed[0..INTERFACE_DISCRIMINATOR_LEN], &TOKEN_GROUP_MEMBER_DISCRIMINATOR);
    @memcpy(prefixed[INTERFACE_DISCRIMINATOR_LEN..], body[0..]);

    const parsed_prefixed = try TokenGroupMember.parse(prefixed[0..]);
    try std.testing.expectEqualSlices(u8, mint_key[0..], parsed_prefixed.mint[0..]);
    try std.testing.expectEqualSlices(u8, group_key[0..], parsed_prefixed.group[0..]);
    try std.testing.expectEqual(@as(u64, 0x8877_6655_4433_2211), parsed_prefixed.member_number);

    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parseBody(body[0 .. body.len - 1]));
    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parseBody(prefixed[0..]));
    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parse(prefixed[0 .. prefixed.len - 1]));
}

test "TokenGroupMember parser rejects wrong discriminator and malformed lengths" {
    const mint_key = testPubkey(0x52);
    const group_key = testPubkey(0xb4);

    var body: [72]u8 = undefined;
    @memcpy(body[0..32], mint_key[0..]);
    @memcpy(body[32..64], group_key[0..]);
    std.mem.writeInt(u64, body[64..72], 42, .little);

    var wrong_prefixed: [INTERFACE_DISCRIMINATOR_LEN + body.len]u8 = undefined;
    @memcpy(wrong_prefixed[0..INTERFACE_DISCRIMINATOR_LEN], &TOKEN_GROUP_DISCRIMINATOR);
    @memcpy(wrong_prefixed[INTERFACE_DISCRIMINATOR_LEN..], body[0..]);

    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parse(&[_]u8{}));
    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parse(wrong_prefixed[0..]));
    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parse(wrong_prefixed[0 .. wrong_prefixed.len - 1]));

    var plus_one_body: [73]u8 = undefined;
    @memcpy(plus_one_body[0..72], body[0..]);
    plus_one_body[72] = 0xbb;
    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parseBody(plus_one_body[0..]));

    var plus_one_prefixed: [INTERFACE_DISCRIMINATOR_LEN + plus_one_body.len]u8 = undefined;
    @memcpy(plus_one_prefixed[0..INTERFACE_DISCRIMINATOR_LEN], &TOKEN_GROUP_MEMBER_DISCRIMINATOR);
    @memcpy(plus_one_prefixed[INTERFACE_DISCRIMINATOR_LEN..], plus_one_body[0..]);
    try std.testing.expectError(error.InvalidAccountData, TokenGroupMember.parse(plus_one_prefixed[0..]));
}

test {
    std.testing.refAllDecls(@This());
}
