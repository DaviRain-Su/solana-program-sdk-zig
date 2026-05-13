//! `ExtraAccountMeta` raw record helpers for transfer-hook instruction
//! payloads.

const std = @import("std");
const sol = @import("solana_program_sdk");
const seed = @import("seed.zig");
const pubkey_data = @import("pubkey_data.zig");

const Pubkey = sol.Pubkey;
const AccountMeta = sol.cpi.AccountMeta;
const ProgramError = sol.ProgramError;

pub const EXTRA_ACCOUNT_META_LEN: usize = 35;
pub const ACCOUNT_META_DISCRIMINATOR: u8 = 0;
pub const HOOK_PROGRAM_PDA_DISCRIMINATOR: u8 = 1;
pub const PUBKEY_DATA_DISCRIMINATOR: u8 = 2;
pub const EXTERNAL_PDA_DISCRIMINATOR_MIN: u8 = 1 << 7;

fn isCanonicalBool(byte: u8) bool {
    return byte == 0 or byte == 1;
}

fn isSupportedDiscriminator(discriminator: u8) bool {
    return discriminator <= PUBKEY_DATA_DISCRIMINATOR or discriminator >= EXTERNAL_PDA_DISCRIMINATOR_MIN;
}

pub const ExtraAccountMeta = extern struct {
    discriminator: u8,
    address_config: [32]u8,
    is_signer: u8,
    is_writable: u8,

    pub fn fixed(pubkey: *const Pubkey, is_signer: bool, is_writable: bool) ExtraAccountMeta {
        return .{
            .discriminator = ACCOUNT_META_DISCRIMINATOR,
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

    pub fn hookProgramDerived(
        seeds: []const seed.Seed,
        is_signer: bool,
        is_writable: bool,
    ) ProgramError!ExtraAccountMeta {
        return .{
            .discriminator = HOOK_PROGRAM_PDA_DISCRIMINATOR,
            .address_config = try seed.packIntoAddressConfig(seeds),
            .is_signer = @intFromBool(is_signer),
            .is_writable = @intFromBool(is_writable),
        };
    }

    pub fn externalProgramDerived(
        program_index: u8,
        seeds: []const seed.Seed,
        is_signer: bool,
        is_writable: bool,
    ) ProgramError!ExtraAccountMeta {
        if (program_index > 127) return ProgramError.InvalidAccountData;
        return .{
            .discriminator = std.math.add(u8, EXTERNAL_PDA_DISCRIMINATOR_MIN, program_index)
                catch return ProgramError.InvalidAccountData,
            .address_config = try seed.packIntoAddressConfig(seeds),
            .is_signer = @intFromBool(is_signer),
            .is_writable = @intFromBool(is_writable),
        };
    }

    pub fn pubkeyData(
        key_data: pubkey_data.PubkeyData,
        is_signer: bool,
        is_writable: bool,
    ) ProgramError!ExtraAccountMeta {
        return .{
            .discriminator = PUBKEY_DATA_DISCRIMINATOR,
            .address_config = try pubkey_data.packIntoAddressConfig(key_data),
            .is_signer = @intFromBool(is_signer),
            .is_writable = @intFromBool(is_writable),
        };
    }

    pub fn parse(bytes: []const u8) ProgramError!ExtraAccountMeta {
        if (bytes.len != EXTRA_ACCOUNT_META_LEN) return ProgramError.InvalidInstructionData;

        var address_config: [32]u8 = undefined;
        @memcpy(&address_config, bytes[1..33]);
        const parsed: ExtraAccountMeta = .{
            .discriminator = bytes[0],
            .address_config = address_config,
            .is_signer = bytes[33],
            .is_writable = bytes[34],
        };
        try parsed.validate();
        return parsed;
    }

    pub fn write(self: ExtraAccountMeta, dst: []u8) void {
        dst[0] = self.discriminator;
        @memcpy(dst[1..33], &self.address_config);
        dst[33] = self.is_signer;
        dst[34] = self.is_writable;
    }

    pub fn validate(self: ExtraAccountMeta) ProgramError!void {
        if (!isSupportedDiscriminator(self.discriminator)) return ProgramError.InvalidAccountData;
        if (!isCanonicalBool(self.is_signer)) return ProgramError.InvalidAccountData;
        if (!isCanonicalBool(self.is_writable)) return ProgramError.InvalidAccountData;
    }

    pub fn resolveFixedPubkey(self: *const ExtraAccountMeta) ProgramError!AccountMeta {
        try self.validate();
        if (self.discriminator != ACCOUNT_META_DISCRIMINATOR) return ProgramError.InvalidAccountData;
        return .{
            .pubkey = @ptrCast(&self.address_config),
            .is_signer = self.is_signer,
            .is_writable = self.is_writable,
        };
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

    pub fn validateAll(self: ExtraAccountMetaSlice) ProgramError!void {
        for (0..self.len()) |i| {
            _ = try self.get(i);
        }
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

test "ExtraAccountMeta parser rejects reserved discriminators and invalid boolean bytes" {
    const pubkey: Pubkey = .{
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe,
        0x55, 0x44, 0x33, 0x22, 0x11, 0x99, 0x88, 0x77,
        0x66, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xf0, 0x0f,
    };
    const fixed = ExtraAccountMeta.fixed(&pubkey, true, false);

    var reserved_bytes: [EXTRA_ACCOUNT_META_LEN]u8 = undefined;
    fixed.write(reserved_bytes[0..]);
    reserved_bytes[0] = 3;
    try std.testing.expectError(ProgramError.InvalidAccountData, ExtraAccountMeta.parse(reserved_bytes[0..]));

    reserved_bytes[0] = 127;
    try std.testing.expectError(ProgramError.InvalidAccountData, ExtraAccountMeta.parse(reserved_bytes[0..]));

    reserved_bytes[0] = 2;
    const parsed_pubkey_data = try ExtraAccountMeta.parse(reserved_bytes[0..]);
    try std.testing.expectEqual(@as(u8, 2), parsed_pubkey_data.discriminator);

    var bad_signer_bytes = reserved_bytes;
    bad_signer_bytes[0] = 0;
    bad_signer_bytes[33] = 2;
    try std.testing.expectError(ProgramError.InvalidAccountData, ExtraAccountMeta.parse(bad_signer_bytes[0..]));

    var bad_writable_bytes = reserved_bytes;
    bad_writable_bytes[0] = 1;
    bad_writable_bytes[34] = 0xff;
    try std.testing.expectError(ProgramError.InvalidAccountData, ExtraAccountMeta.parse(bad_writable_bytes[0..]));
}

test "ExtraAccountMeta fixed records resolve to canonical AccountMeta without mutation" {
    const pubkey: Pubkey = .{
        0xde, 0xad, 0xfa, 0xce, 0x01, 0x02, 0x03, 0x04,
        0x05, 0x06, 0x07, 0x08, 0x55, 0xaa, 0x99, 0x77,
        0x42, 0x24, 0x13, 0x31, 0x80, 0x70, 0x60, 0x50,
        0x40, 0x30, 0x20, 0x10, 0xef, 0xcd, 0xab, 0x89,
    };

    const cases = [_]struct {
        is_signer: bool,
        is_writable: bool,
    }{
        .{ .is_signer = false, .is_writable = false },
        .{ .is_signer = false, .is_writable = true },
        .{ .is_signer = true, .is_writable = false },
        .{ .is_signer = true, .is_writable = true },
    };

    inline for (cases) |case| {
        var record = ExtraAccountMeta.fixed(&pubkey, case.is_signer, case.is_writable);
        const resolved = try record.resolveFixedPubkey();
        try std.testing.expectEqual(@intFromPtr(@as(*const Pubkey, @ptrCast(&record.address_config))), @intFromPtr(resolved.pubkey));
        try std.testing.expectEqualSlices(u8, &pubkey, resolved.pubkey[0..]);
        try std.testing.expectEqual(@as(u8, @intFromBool(case.is_signer)), resolved.is_signer);
        try std.testing.expectEqual(@as(u8, @intFromBool(case.is_writable)), resolved.is_writable);
    }
}

test "ExtraAccountMeta dynamic constructors preserve discriminators and packed configs" {
    const seeds = [_]seed.Seed{
        .{ .literal = "vault" },
        .{ .instruction_data = .{ .index = 7, .length = 4 } },
    };
    const internal = try ExtraAccountMeta.hookProgramDerived(&seeds, false, true);
    try std.testing.expectEqual(HOOK_PROGRAM_PDA_DISCRIMINATOR, internal.discriminator);
    try std.testing.expectEqual(@as(u8, 0), internal.is_signer);
    try std.testing.expectEqual(@as(u8, 1), internal.is_writable);

    const external = try ExtraAccountMeta.externalProgramDerived(5, &seeds, true, false);
    try std.testing.expectEqual(@as(u8, EXTERNAL_PDA_DISCRIMINATOR_MIN + 5), external.discriminator);
    try std.testing.expectEqual(@as(u8, 1), external.is_signer);
    try std.testing.expectEqual(@as(u8, 0), external.is_writable);

    const key_data = pubkey_data.PubkeyData{
        .account_data = .{
            .account_index = 3,
            .data_index = 9,
        },
    };
    const pubkey_data_meta = try ExtraAccountMeta.pubkeyData(key_data, true, true);
    try std.testing.expectEqual(PUBKEY_DATA_DISCRIMINATOR, pubkey_data_meta.discriminator);
    try std.testing.expectEqual(@as(u8, 1), pubkey_data_meta.is_signer);
    try std.testing.expectEqual(@as(u8, 1), pubkey_data_meta.is_writable);
}
