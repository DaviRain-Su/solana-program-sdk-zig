const std = @import("std");
const sol = @import("solana_program_sdk");

const ProgramError = sol.ProgramError;

pub const max_seed_config_len: usize = 32;
pub const max_seed_configs_per_address_config: usize = 16;

pub const Seed = union(enum) {
    literal: []const u8,
    instruction_data: InstructionData,
    account_key: AccountKey,
    account_data: AccountData,

    pub const InstructionData = struct {
        index: u8,
        length: u8,
    };

    pub const AccountKey = struct {
        index: u8,
    };

    pub const AccountData = struct {
        account_index: u8,
        data_index: u8,
        length: u8,
    };

    pub fn tlvSize(self: Seed) ProgramError!usize {
        return switch (self) {
            .literal => |bytes| blk: {
                if (bytes.len > sol.pda.MAX_SEED_LEN) return ProgramError.InvalidAccountData;
                break :blk 2 + bytes.len;
            },
            .instruction_data => |source| blk: {
                if (source.length > sol.pda.MAX_SEED_LEN) return ProgramError.InvalidAccountData;
                break :blk 3;
            },
            .account_key => 2,
            .account_data => |source| blk: {
                if (source.length > sol.pda.MAX_SEED_LEN) return ProgramError.InvalidAccountData;
                break :blk 4;
            },
        };
    }

    pub fn pack(self: Seed, dst: []u8) ProgramError!void {
        const expected_len = try self.tlvSize();
        if (dst.len != expected_len) return ProgramError.InvalidAccountData;

        switch (self) {
            .literal => |bytes| {
                dst[0] = 1;
                dst[1] = @intCast(bytes.len);
                @memcpy(dst[2..], bytes);
            },
            .instruction_data => |source| {
                dst[0] = 2;
                dst[1] = source.index;
                dst[2] = source.length;
            },
            .account_key => |source| {
                dst[0] = 3;
                dst[1] = source.index;
            },
            .account_data => |source| {
                dst[0] = 4;
                dst[1] = source.account_index;
                dst[2] = source.data_index;
                dst[3] = source.length;
            },
        }
    }
};

pub const Iterator = struct {
    address_config: *const [32]u8,
    offset: usize = 0,

    pub fn next(self: *Iterator) ProgramError!?Seed {
        if (self.offset >= self.address_config.len) return null;

        const discrim = self.address_config[self.offset];
        if (discrim == 0) {
            self.offset = self.address_config.len;
            return null;
        }

        const remaining = self.address_config[self.offset..];
        const parsed = try unpackOne(remaining);
        self.offset += parsed.size;
        return parsed.seed;
    }
};

pub fn iterator(address_config: *const [32]u8) Iterator {
    return .{ .address_config = address_config };
}

pub fn packIntoAddressConfig(seeds: []const Seed) ProgramError![32]u8 {
    var buffer: [32]u8 = .{0} ** 32;
    var offset: usize = 0;
    for (seeds) |seed| {
        const seed_len = try seed.tlvSize();
        const next_offset = std.math.add(usize, offset, seed_len) catch return ProgramError.InvalidAccountData;
        if (next_offset > buffer.len) return ProgramError.InvalidAccountData;
        try seed.pack(buffer[offset..next_offset]);
        offset = next_offset;
    }
    return buffer;
}

const ParsedSeed = struct {
    seed: Seed,
    size: usize,
};

fn unpackOne(bytes: []const u8) ProgramError!ParsedSeed {
    if (bytes.len == 0) return ProgramError.InvalidAccountData;

    return switch (bytes[0]) {
        1 => unpackLiteral(bytes[1..]),
        2 => unpackInstructionData(bytes[1..]),
        3 => unpackAccountKey(bytes[1..]),
        4 => unpackAccountData(bytes[1..]),
        else => ProgramError.InvalidAccountData,
    };
}

fn unpackLiteral(bytes: []const u8) ProgramError!ParsedSeed {
    if (bytes.len == 0) return ProgramError.InvalidAccountData;
    const literal_len: usize = bytes[0];
    if (literal_len > sol.pda.MAX_SEED_LEN) return ProgramError.InvalidAccountData;
    if (bytes.len - 1 < literal_len) return ProgramError.InvalidAccountData;
    return .{
        .seed = .{ .literal = bytes[1 .. 1 + literal_len] },
        .size = 2 + literal_len,
    };
}

fn unpackInstructionData(bytes: []const u8) ProgramError!ParsedSeed {
    if (bytes.len < 2) return ProgramError.InvalidAccountData;
    if (bytes[1] > sol.pda.MAX_SEED_LEN) return ProgramError.InvalidAccountData;
    return .{
        .seed = .{
            .instruction_data = .{
                .index = bytes[0],
                .length = bytes[1],
            },
        },
        .size = 3,
    };
}

fn unpackAccountKey(bytes: []const u8) ProgramError!ParsedSeed {
    if (bytes.len == 0) return ProgramError.InvalidAccountData;
    return .{
        .seed = .{ .account_key = .{ .index = bytes[0] } },
        .size = 2,
    };
}

fn unpackAccountData(bytes: []const u8) ProgramError!ParsedSeed {
    if (bytes.len < 3) return ProgramError.InvalidAccountData;
    if (bytes[2] > sol.pda.MAX_SEED_LEN) return ProgramError.InvalidAccountData;
    return .{
        .seed = .{
            .account_data = .{
                .account_index = bytes[0],
                .data_index = bytes[1],
                .length = bytes[2],
            },
        },
        .size = 4,
    };
}

test "seed configs pack and unpack within the 32-byte address config grammar" {
    const seeds = [_]Seed{
        .{ .literal = "vault" },
        .{ .instruction_data = .{ .index = 5, .length = 4 } },
        .{ .account_key = .{ .index = 9 } },
        .{ .account_data = .{ .account_index = 2, .data_index = 7, .length = 3 } },
    };

    const encoded = try packIntoAddressConfig(&seeds);
    var it = iterator(&encoded);

    try std.testing.expectEqualSlices(u8, "vault", (try it.next()).?.literal);
    try std.testing.expectEqualDeep(seeds[1].instruction_data, (try it.next()).?.instruction_data);
    try std.testing.expectEqualDeep(seeds[2].account_key, (try it.next()).?.account_key);
    try std.testing.expectEqualDeep(seeds[3].account_data, (try it.next()).?.account_data);
    try std.testing.expectEqual(@as(?Seed, null), try it.next());
}

test "seed config parsing rejects malformed and oversized encodings" {
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        packIntoAddressConfig(&.{.{ .literal = ([_]u8{0xaa} ** 33)[0..] }}),
    );
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        packIntoAddressConfig(&.{
            .{ .literal = ([_]u8{0xbb} ** 30)[0..] },
            .{ .instruction_data = .{ .index = 0, .length = 4 } },
        }),
    );

    var malformed_literal: [32]u8 = .{0} ** 32;
    malformed_literal[0] = 1;
    malformed_literal[1] = 31;
    var malformed_it = iterator(&malformed_literal);
    try std.testing.expectError(ProgramError.InvalidAccountData, malformed_it.next());

    var malformed_account_data: [32]u8 = .{0} ** 32;
    malformed_account_data[0] = 4;
    malformed_account_data[1] = 0;
    malformed_account_data[2] = 0;
    malformed_account_data[3] = 33;
    var malformed_account_data_it = iterator(&malformed_account_data);
    try std.testing.expectError(ProgramError.InvalidAccountData, malformed_account_data_it.next());
}
