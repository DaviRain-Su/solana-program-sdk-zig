//! `ExtraAccountMeta` raw record helpers for transfer-hook instruction
//! payloads.

const std = @import("std");
const sol = @import("solana_program_sdk");

const Pubkey = sol.Pubkey;
const AccountMeta = sol.cpi.AccountMeta;
const ProgramError = sol.ProgramError;

pub const EXTRA_ACCOUNT_META_LEN: usize = 35;

pub const ExtraAccountMeta = extern struct {
    discriminator: u8,
    address_config: [32]u8,
    is_signer: u8,
    is_writable: u8,

    pub fn fixed(pubkey: *const Pubkey, is_signer: bool, is_writable: bool) ExtraAccountMeta {
        return .{
            .discriminator = 0,
            .address_config = pubkey.*,
            .is_signer = @intFromBool(is_signer),
            .is_writable = @intFromBool(is_writable),
        };
    }

    pub fn fromAccountMeta(account_meta: AccountMeta) ExtraAccountMeta {
        return fixed(
            account_meta.pubkey,
            account_meta.is_signer != 0,
            account_meta.is_writable != 0,
        );
    }

    pub fn parse(bytes: []const u8) ProgramError!ExtraAccountMeta {
        if (bytes.len != EXTRA_ACCOUNT_META_LEN) return ProgramError.InvalidInstructionData;

        var address_config: [32]u8 = undefined;
        @memcpy(&address_config, bytes[1..33]);
        return .{
            .discriminator = bytes[0],
            .address_config = address_config,
            .is_signer = bytes[33],
            .is_writable = bytes[34],
        };
    }

    pub fn write(self: ExtraAccountMeta, dst: []u8) void {
        dst[0] = self.discriminator;
        @memcpy(dst[1..33], &self.address_config);
        dst[33] = self.is_signer;
        dst[34] = self.is_writable;
    }
};

pub const ExtraAccountMetaSlice = struct {
    bytes: []const u8,

    pub fn init(bytes: []const u8) ProgramError!ExtraAccountMetaSlice {
        if (bytes.len % EXTRA_ACCOUNT_META_LEN != 0) return ProgramError.InvalidInstructionData;
        return .{ .bytes = bytes };
    }

    pub fn len(self: ExtraAccountMetaSlice) usize {
        return self.bytes.len / EXTRA_ACCOUNT_META_LEN;
    }

    pub fn get(self: ExtraAccountMetaSlice, index: usize) ProgramError!ExtraAccountMeta {
        if (index >= self.len()) return ProgramError.InvalidInstructionData;
        const start = index * EXTRA_ACCOUNT_META_LEN;
        return ExtraAccountMeta.parse(self.bytes[start..][0..EXTRA_ACCOUNT_META_LEN]);
    }

    pub fn asBytes(self: ExtraAccountMetaSlice) []const u8 {
        return self.bytes;
    }
};

fn expectExtraAccountMeta(actual: ExtraAccountMeta, expected: ExtraAccountMeta) !void {
    try std.testing.expectEqual(expected.discriminator, actual.discriminator);
    try std.testing.expectEqualSlices(u8, &expected.address_config, &actual.address_config);
    try std.testing.expectEqual(expected.is_signer, actual.is_signer);
    try std.testing.expectEqual(expected.is_writable, actual.is_writable);
}

test "ExtraAccountMeta fixed records preserve canonical 35-byte layout" {
    try std.testing.expectEqual(@as(usize, EXTRA_ACCOUNT_META_LEN), @sizeOf(ExtraAccountMeta));

    const pubkey: Pubkey = .{0xab} ** 32;
    const record = ExtraAccountMeta.fixed(&pubkey, true, false);

    var bytes: [EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    record.write(bytes[0..]);

    try std.testing.expectEqual(@as(u8, 0), bytes[0]);
    try std.testing.expectEqualSlices(u8, &pubkey, bytes[1..33]);
    try std.testing.expectEqual(@as(u8, 1), bytes[33]);
    try std.testing.expectEqual(@as(u8, 0), bytes[34]);

    try expectExtraAccountMeta(record, try ExtraAccountMeta.parse(bytes[0..]));
}

test "ExtraAccountMetaSlice requires whole 35-byte records" {
    const good = [_]u8{0} ** EXTRA_ACCOUNT_META_LEN;
    const slice = try ExtraAccountMetaSlice.init(good[0..]);
    try std.testing.expectEqual(@as(usize, 1), slice.len());

    const parsed = try slice.get(0);
    try std.testing.expectEqual(@as(u8, 0), parsed.discriminator);

    try std.testing.expectError(
        ProgramError.InvalidInstructionData,
        ExtraAccountMetaSlice.init(good[0 .. EXTRA_ACCOUNT_META_LEN - 1]),
    );
}
