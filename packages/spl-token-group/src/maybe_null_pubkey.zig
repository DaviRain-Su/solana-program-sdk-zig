const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;
const ZERO_PUBKEY: Pubkey = .{0} ** @sizeOf(Pubkey);

pub const MaybeNullPubkey = struct {
    pub const LEN: usize = @sizeOf(Pubkey);
    pub const ParseError = error{InvalidLength};
    pub const WriteError = error{BufferTooSmall};

    present: bool = false,
    bytes: Pubkey = .{0} ** 32,

    pub fn initNull() MaybeNullPubkey {
        return .{};
    }

    pub fn fromPubkey(pubkey: *const Pubkey) MaybeNullPubkey {
        if (std.mem.eql(u8, pubkey[0..], ZERO_PUBKEY[0..])) return initNull();
        return .{
            .present = true,
            .bytes = pubkey.*,
        };
    }

    pub fn fromOptional(pubkey: ?*const Pubkey) MaybeNullPubkey {
        return if (pubkey) |key| fromPubkey(key) else initNull();
    }

    pub fn fromBytes(bytes: []const u8) ParseError!MaybeNullPubkey {
        if (bytes.len != LEN) return error.InvalidLength;

        var pubkey: Pubkey = undefined;
        @memcpy(pubkey[0..], bytes[0..LEN]);
        return fromPubkey(&pubkey);
    }

    pub fn parse(bytes: []const u8) ParseError!MaybeNullPubkey {
        return fromBytes(bytes);
    }

    pub fn isNull(self: MaybeNullPubkey) bool {
        return !self.present;
    }

    pub fn isPresent(self: MaybeNullPubkey) bool {
        return self.present;
    }

    pub fn presentKey(self: *const MaybeNullPubkey) ?*const Pubkey {
        return if (self.present) &self.bytes else null;
    }

    pub fn write(self: *const MaybeNullPubkey, out: []u8) WriteError![]u8 {
        if (out.len < LEN) return error.BufferTooSmall;
        if (self.present) {
            @memcpy(out[0..LEN], self.bytes[0..]);
        } else {
            @memset(out[0..LEN], 0);
        }
        return out[0..LEN];
    }

    pub fn encode(self: *const MaybeNullPubkey, out: []u8) WriteError![]const u8 {
        return try self.write(out);
    }

    pub fn allocBytes(self: *const MaybeNullPubkey, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
        const out = try allocator.alloc(u8, LEN);
        _ = self.write(out) catch unreachable;
        return out;
    }
};

test "MaybeNullPubkey decodes and encodes canonical null bytes" {
    const maybe_null = try MaybeNullPubkey.fromBytes(&ZERO_PUBKEY);

    try std.testing.expect(maybe_null.isNull());
    try std.testing.expect(!maybe_null.isPresent());
    try std.testing.expectEqual(@as(?*const Pubkey, null), maybe_null.presentKey());

    var out = [_]u8{0xbb} ** (MaybeNullPubkey.LEN + 1);
    const written = try maybe_null.write(out[0..]);
    try std.testing.expectEqual(@as(usize, MaybeNullPubkey.LEN), written.len);
    try std.testing.expectEqualSlices(u8, ZERO_PUBKEY[0..], written);
    try std.testing.expectEqual(@as(u8, 0xbb), out[MaybeNullPubkey.LEN]);
}

test "MaybeNullPubkey preserves exact nonzero 32-byte encoding" {
    const raw: Pubkey = .{
        0x6e, 0x4d, 0x2c, 0x0b, 0xfa, 0xd9, 0xb8, 0x97,
        0x13, 0x26, 0x39, 0x4c, 0x5f, 0x72, 0x85, 0x98,
        0x9f, 0x8e, 0x7d, 0x6c, 0x5b, 0x4a, 0x39, 0x28,
        0x17, 0x06, 0xf5, 0xe4, 0xd3, 0xc2, 0xb1, 0xa0,
    };
    const maybe_null = try MaybeNullPubkey.parse(&raw);

    try std.testing.expect(maybe_null.isPresent());
    try std.testing.expect(!maybe_null.isNull());
    try std.testing.expectEqualSlices(u8, raw[0..], maybe_null.presentKey().?[0..]);

    var out = [_]u8{0} ** MaybeNullPubkey.LEN;
    try std.testing.expectEqualSlices(u8, raw[0..], try maybe_null.encode(out[0..]));

    const from_constructor = MaybeNullPubkey.fromPubkey(&raw);
    try std.testing.expectEqualSlices(u8, raw[0..], from_constructor.presentKey().?[0..]);
}

test "MaybeNullPubkey rejects malformed short inputs" {
    var buf = [_]u8{0xee} ** MaybeNullPubkey.LEN;
    for (0..MaybeNullPubkey.LEN) |len| {
        try std.testing.expectError(error.InvalidLength, MaybeNullPubkey.fromBytes(buf[0..len]));
    }
}

test "MaybeNullPubkey caller-buffer and allocator boundaries are exact" {
    const raw: Pubkey = .{
        0xc1, 0xb2, 0xa3, 0x94, 0x85, 0x76, 0x67, 0x58,
        0x49, 0x3a, 0x2b, 0x1c, 0x0d, 0xfe, 0xef, 0xd0,
        0xc2, 0xb4, 0xa6, 0x98, 0x8a, 0x7c, 0x6e, 0x50,
        0x41, 0x32, 0x23, 0x14, 0x05, 0xf6, 0xe7, 0xd8,
    };
    const maybe_null = MaybeNullPubkey.fromOptional(&raw);

    var short: [MaybeNullPubkey.LEN - 1]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, maybe_null.write(short[0..]));

    var exact_storage: [MaybeNullPubkey.LEN]u8 = undefined;
    var exact_fba = std.heap.FixedBufferAllocator.init(&exact_storage);
    const owned = try maybe_null.allocBytes(exact_fba.allocator());
    try std.testing.expectEqual(@as(usize, MaybeNullPubkey.LEN), owned.len);
    try std.testing.expectEqualSlices(u8, raw[0..], owned);

    var undersized_storage: [MaybeNullPubkey.LEN - 1]u8 = undefined;
    var undersized_fba = std.heap.FixedBufferAllocator.init(&undersized_storage);
    try std.testing.expectError(error.OutOfMemory, maybe_null.allocBytes(undersized_fba.allocator()));
}

test "MaybeNullPubkey public API stays borrowed and caller-buffer based" {
    const from_bytes_info = @typeInfo(@TypeOf(MaybeNullPubkey.fromBytes)).@"fn";
    try std.testing.expectEqual(@as(usize, 1), from_bytes_info.params.len);
    try std.testing.expect(from_bytes_info.params[0].type.? == []const u8);

    const write_info = @typeInfo(@TypeOf(MaybeNullPubkey.write)).@"fn";
    try std.testing.expectEqual(@as(usize, 2), write_info.params.len);
    try std.testing.expect(write_info.params[1].type.? == []u8);
}

test {
    std.testing.refAllDecls(@This());
}
