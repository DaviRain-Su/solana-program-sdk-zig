//! `solana_config` — Config Program instruction builders.

const std = @import("std");
const sol = @import("solana_program_sdk");
const codec = @import("solana_codec");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("Config1111111111111111111111111111111111111");

pub const Key = struct {
    pubkey: Pubkey,
    is_signer: bool,
};

pub const Error = codec.Error || error{
    AccountMetaBufferTooSmall,
    InvalidConfigKeySignerFlag,
};

pub const ConfigStateView = struct {
    keys: []const Key,
    state_data: []const u8,
    len: usize,
};

pub fn serializedKeysLen(keys: []const Key) Error!usize {
    return (try codec.shortVecLen(keys.len)) + keys.len * (sol.PUBKEY_BYTES + 1);
}

pub fn serializedStoreDataLen(keys: []const Key, state_data: []const u8) Error!usize {
    return (try serializedKeysLen(keys)) + state_data.len;
}

pub fn writeKeys(keys: []const Key, out: []u8) Error!usize {
    const needed = try serializedKeysLen(keys);
    if (out.len < needed) return error.BufferTooSmall;

    var cursor = try codec.writeShortVec(keys.len, out);
    for (keys) |key| {
        @memcpy(out[cursor..][0..sol.PUBKEY_BYTES], &key.pubkey);
        cursor += sol.PUBKEY_BYTES;
        out[cursor] = @intFromBool(key.is_signer);
        cursor += 1;
    }
    return cursor;
}

pub fn parseConfigState(input: []const u8, keys_out: []Key) Error!ConfigStateView {
    const key_count = try codec.readShortVec(input);
    if (keys_out.len < key_count.value) return error.BufferTooSmall;

    var cursor = key_count.len;
    for (keys_out[0..key_count.value]) |*key| {
        if (input.len < cursor + sol.PUBKEY_BYTES + 1) return error.InputTooShort;
        key.pubkey = input[cursor..][0..sol.PUBKEY_BYTES].*;
        cursor += sol.PUBKEY_BYTES;
        key.is_signer = switch (input[cursor]) {
            0 => false,
            1 => true,
            else => return error.InvalidConfigKeySignerFlag,
        };
        cursor += 1;
    }

    return .{
        .keys = keys_out[0..key_count.value],
        .state_data = input[cursor..],
        .len = input.len,
    };
}

pub fn configStatePayload(input: []const u8, keys_out: []Key) Error![]const u8 {
    return (try parseConfigState(input, keys_out)).state_data;
}

pub fn writeStoreData(keys: []const Key, state_data: []const u8, out: []u8) Error![]const u8 {
    const keys_len = try writeKeys(keys, out);
    if (out.len < keys_len + state_data.len) return error.BufferTooSmall;
    @memcpy(out[keys_len..][0..state_data.len], state_data);
    return out[0 .. keys_len + state_data.len];
}

pub fn storeRaw(
    config_account: *const Pubkey,
    is_config_signer: bool,
    keys: []const Key,
    state_data: []const u8,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    if (metas.len < storeAccountMetaLen(config_account, keys)) return error.AccountMetaBufferTooSmall;
    const written_data = try writeStoreData(keys, state_data, data);

    var cursor: usize = 0;
    metas[cursor] = AccountMeta.init(config_account, true, is_config_signer);
    cursor += 1;
    for (keys) |*key| {
        if (key.is_signer and !std.mem.eql(u8, &key.pubkey, config_account)) {
            metas[cursor] = AccountMeta.signerWritable(&key.pubkey);
            cursor += 1;
        }
    }

    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas[0..cursor],
        .data = written_data,
    };
}

pub fn initializeRaw(
    config_account: *const Pubkey,
    default_state_data: []const u8,
    metas: *[1]AccountMeta,
    data: []u8,
) Error!Instruction {
    return storeRaw(config_account, true, &.{}, default_state_data, metas[0..], data);
}

pub fn storeAccountMetaLen(config_account: *const Pubkey, keys: []const Key) usize {
    var len: usize = 1;
    for (keys) |*key| {
        if (key.is_signer and !std.mem.eql(u8, &key.pubkey, config_account)) len += 1;
    }
    return len;
}

test "writeKeys encodes bincode ConfigKeys shortvec layout" {
    const keys = [_]Key{
        .{ .pubkey = .{1} ** 32, .is_signer = true },
        .{ .pubkey = .{2} ** 32, .is_signer = false },
    };
    var buf: [80]u8 = undefined;
    const len = try writeKeys(&keys, &buf);

    try std.testing.expectEqual(@as(usize, 67), len);
    try std.testing.expectEqual(@as(u8, 2), buf[0]);
    try std.testing.expectEqualSlices(u8, &keys[0].pubkey, buf[1..33]);
    try std.testing.expectEqual(@as(u8, 1), buf[33]);
    try std.testing.expectEqualSlices(u8, &keys[1].pubkey, buf[34..66]);
    try std.testing.expectEqual(@as(u8, 0), buf[66]);
}

test "storeRaw appends state data and signer metas" {
    const config: Pubkey = .{9} ** 32;
    const signer: Pubkey = .{1} ** 32;
    const readonly: Pubkey = .{2} ** 32;
    const keys = [_]Key{
        .{ .pubkey = signer, .is_signer = true },
        .{ .pubkey = readonly, .is_signer = false },
    };
    const state_data = [_]u8{ 0x88, 0x77, 0x66, 0x55, 1 };
    var metas: [3]AccountMeta = undefined;
    var data: [96]u8 = undefined;

    const ix = try storeRaw(&config, false, &keys, &state_data, &metas, &data);
    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, ix.program_id);
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &config, ix.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 0), ix.accounts[0].is_signer);
    try std.testing.expectEqualSlices(u8, &signer, ix.accounts[1].pubkey);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_writable);
    try std.testing.expectEqual(@as(usize, 72), ix.data.len);
    try std.testing.expectEqualSlices(u8, &state_data, ix.data[67..72]);
}

test "parseConfigState returns typed key view and raw payload" {
    const signer: Pubkey = .{1} ** 32;
    const readonly: Pubkey = .{2} ** 32;
    const keys = [_]Key{
        .{ .pubkey = signer, .is_signer = true },
        .{ .pubkey = readonly, .is_signer = false },
    };
    const state_data = [_]u8{ 0xaa, 0xbb, 0xcc };
    var data: [80]u8 = undefined;

    const written = try writeStoreData(&keys, &state_data, &data);
    var parsed_keys: [2]Key = undefined;
    const parsed = try parseConfigState(written, &parsed_keys);

    try std.testing.expectEqual(@as(usize, written.len), parsed.len);
    try std.testing.expectEqual(@as(usize, 2), parsed.keys.len);
    try std.testing.expectEqualSlices(u8, &signer, &parsed.keys[0].pubkey);
    try std.testing.expect(parsed.keys[0].is_signer);
    try std.testing.expectEqualSlices(u8, &readonly, &parsed.keys[1].pubkey);
    try std.testing.expect(!parsed.keys[1].is_signer);
    try std.testing.expectEqualSlices(u8, &state_data, parsed.state_data);
    try std.testing.expectEqualSlices(u8, &state_data, try configStatePayload(written, &parsed_keys));

    var too_few_keys: [1]Key = undefined;
    try std.testing.expectError(error.BufferTooSmall, parseConfigState(written, &too_few_keys));

    data[33] = 2;
    try std.testing.expectError(error.InvalidConfigKeySignerFlag, parseConfigState(written, &parsed_keys));
}

test "initializeRaw writes empty keys and config signer" {
    const config: Pubkey = .{9} ** 32;
    const state_data = [_]u8{ 0, 0, 0, 0 };
    var metas: [1]AccountMeta = undefined;
    var data: [8]u8 = undefined;

    const ix = try initializeRaw(&config, &state_data, &metas, &data);
    try std.testing.expectEqual(@as(usize, 1), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[0].is_signer);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0 }, ix.data);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "storeRaw"));
    try std.testing.expect(@hasDecl(@This(), "initializeRaw"));
    try std.testing.expect(@hasDecl(@This(), "writeKeys"));
    try std.testing.expect(@hasDecl(@This(), "parseConfigState"));
    try std.testing.expect(@hasDecl(@This(), "ConfigStateView"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
