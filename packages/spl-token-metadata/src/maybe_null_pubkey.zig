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

    var out = [_]u8{0xaa} ** (MaybeNullPubkey.LEN + 1);
    const written = try maybe_null.write(out[0..]);
    try std.testing.expectEqual(@as(usize, MaybeNullPubkey.LEN), written.len);
    try std.testing.expectEqualSlices(u8, ZERO_PUBKEY[0..], written);
    try std.testing.expectEqual(@as(u8, 0xaa), out[MaybeNullPubkey.LEN]);
}

test "MaybeNullPubkey preserves exact nonzero 32-byte encoding" {
    const raw: Pubkey = .{
        0x83, 0x01, 0x42, 0x27, 0x9a, 0xb7, 0x5c, 0xe1,
        0x11, 0x29, 0x38, 0x47, 0x56, 0x65, 0x74, 0x8f,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x0f, 0x1e, 0x2d, 0x3c, 0x4b, 0x5a, 0x69, 0x78,
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
    var buf = [_]u8{0xff} ** MaybeNullPubkey.LEN;
    for (0..MaybeNullPubkey.LEN) |len| {
        try std.testing.expectError(error.InvalidLength, MaybeNullPubkey.fromBytes(buf[0..len]));
    }
}

test "MaybeNullPubkey caller-buffer and allocator boundaries are exact" {
    const raw: Pubkey = .{
        0x01, 0x03, 0x05, 0x07, 0x09, 0x0b, 0x0d, 0x0f,
        0x10, 0x12, 0x14, 0x16, 0x18, 0x1a, 0x1c, 0x1e,
        0x21, 0x23, 0x25, 0x27, 0x29, 0x2b, 0x2d, 0x2f,
        0x31, 0x33, 0x35, 0x37, 0x39, 0x3b, 0x3d, 0x3f,
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
