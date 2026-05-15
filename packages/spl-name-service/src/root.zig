//! `spl_name_service` - SPL Name Service account/header and instruction helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const codec = @import("solana_codec");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX");
pub const SYSTEM_PROGRAM_ID: Pubkey = sol.system_program_id;
pub const HASH_PREFIX = "SPL Name Service";
pub const HASH_BYTES = sol.hash.HASH_BYTES;
pub const NAME_RECORD_HEADER_LEN: usize = 96;
pub const MAX_HASHED_NAME_LEN: usize = (sol.pda.MAX_SEEDS - 2) * sol.PUBKEY_BYTES;
pub const DEFAULT_PUBKEY: Pubkey = .{0} ** sol.PUBKEY_BYTES;

pub const Error = codec.Error || sol.ProgramError || error{
    AccountDataTooSmall,
    AccountMetaBufferTooSmall,
    SeedScratchTooSmall,
    HashedNameTooLong,
};

pub const NameRecordHeader = extern struct {
    parent_name: Pubkey,
    owner: Pubkey,
    class: Pubkey,
};

pub const ProgramInstruction = enum(u8) {
    create = 0,
    update = 1,
    transfer = 2,
    delete = 3,
    realloc = 4,
};

pub fn hashName(name: []const u8) Error![HASH_BYTES]u8 {
    const hash = try sol.sha256(&.{ HASH_PREFIX, name });
    return hash.bytes;
}

pub fn nameSeedCount(hashed_name: []const u8) Error!usize {
    if (hashed_name.len > MAX_HASHED_NAME_LEN) return error.HashedNameTooLong;
    const hash_seed_count = (hashed_name.len + sol.PUBKEY_BYTES - 1) / sol.PUBKEY_BYTES;
    return hash_seed_count + 2;
}

pub fn fillNameSeeds(
    hashed_name: []const u8,
    name_class: ?*const Pubkey,
    parent_name: ?*const Pubkey,
    seed_scratch: [][]const u8,
) Error![]const []const u8 {
    const needed = try nameSeedCount(hashed_name);
    if (seed_scratch.len < needed) return error.SeedScratchTooSmall;

    var cursor: usize = 0;
    var seed_index: usize = 0;
    while (cursor < hashed_name.len) {
        const end = @min(cursor + sol.PUBKEY_BYTES, hashed_name.len);
        seed_scratch[seed_index] = hashed_name[cursor..end];
        seed_index += 1;
        cursor = end;
    }

    const class_key = name_class orelse &DEFAULT_PUBKEY;
    seed_scratch[seed_index] = class_key;
    seed_index += 1;

    const parent_key = parent_name orelse &DEFAULT_PUBKEY;
    seed_scratch[seed_index] = parent_key;
    seed_index += 1;

    return seed_scratch[0..seed_index];
}

pub fn deriveNameAccountAddress(
    hashed_name: []const u8,
    name_class: ?*const Pubkey,
    parent_name: ?*const Pubkey,
    seed_scratch: [][]const u8,
) Error!sol.pda.ProgramDerivedAddress {
    const seeds = try fillNameSeeds(hashed_name, name_class, parent_name, seed_scratch);
    return try sol.pda.findProgramAddress(seeds, &PROGRAM_ID);
}

pub fn parseHeader(data: []const u8) Error!NameRecordHeader {
    if (data.len < NAME_RECORD_HEADER_LEN) return error.AccountDataTooSmall;
    return .{
        .parent_name = data[0..32].*,
        .owner = data[32..64].*,
        .class = data[64..96].*,
    };
}

pub fn writeHeader(header: NameRecordHeader, out: []u8) Error![]const u8 {
    if (out.len < NAME_RECORD_HEADER_LEN) return error.BufferTooSmall;
    @memcpy(out[0..32], &header.parent_name);
    @memcpy(out[32..64], &header.owner);
    @memcpy(out[64..96], &header.class);
    return out[0..NAME_RECORD_HEADER_LEN];
}

pub fn createDataLen(hashed_name: []const u8) Error!usize {
    return 1 + (try codec.borshBytesLen(hashed_name)) + 8 + 4;
}

pub fn updateDataLen(payload: []const u8) Error!usize {
    return 1 + 4 + (try codec.borshBytesLen(payload));
}

pub fn writeCreateData(hashed_name: []const u8, lamports: u64, space: u32, out: []u8) Error![]const u8 {
    const needed = try createDataLen(hashed_name);
    if (out.len < needed) return error.BufferTooSmall;

    out[0] = @intFromEnum(ProgramInstruction.create);
    var cursor: usize = 1;
    cursor += try codec.writeBorshBytes(out[cursor..], hashed_name);
    cursor += try codec.writeBorshU64(out[cursor..], lamports);
    cursor += try codec.writeBorshU32(out[cursor..], space);
    return out[0..cursor];
}

pub fn writeUpdateData(offset: u32, payload: []const u8, out: []u8) Error![]const u8 {
    const needed = try updateDataLen(payload);
    if (out.len < needed) return error.BufferTooSmall;

    out[0] = @intFromEnum(ProgramInstruction.update);
    var cursor: usize = 1;
    cursor += try codec.writeBorshU32(out[cursor..], offset);
    cursor += try codec.writeBorshBytes(out[cursor..], payload);
    return out[0..cursor];
}

pub fn writeTransferData(new_owner: *const Pubkey, out: []u8) Error![]const u8 {
    if (out.len < 1 + sol.PUBKEY_BYTES) return error.BufferTooSmall;
    out[0] = @intFromEnum(ProgramInstruction.transfer);
    @memcpy(out[1..33], new_owner);
    return out[0..33];
}

pub fn writeDeleteData(out: []u8) Error![]const u8 {
    if (out.len < 1) return error.BufferTooSmall;
    out[0] = @intFromEnum(ProgramInstruction.delete);
    return out[0..1];
}

pub fn writeReallocData(space: u32, out: []u8) Error![]const u8 {
    if (out.len < 5) return error.BufferTooSmall;
    out[0] = @intFromEnum(ProgramInstruction.realloc);
    std.mem.writeInt(u32, out[1..5], space, .little);
    return out[0..5];
}

pub fn createForAddress(
    name_account: *const Pubkey,
    payer: *const Pubkey,
    name_owner: *const Pubkey,
    name_class: ?*const Pubkey,
    parent_name: ?*const Pubkey,
    parent_owner: ?*const Pubkey,
    hashed_name: []const u8,
    lamports: u64,
    space: u32,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len: usize = if (parent_owner == null) 6 else 7;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeCreateData(hashed_name, lamports, space, data);

    metas[0] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[1] = AccountMeta.signerWritable(payer);
    metas[2] = AccountMeta.writable(name_account);
    metas[3] = AccountMeta.readonly(name_owner);
    metas[4] = if (name_class) |key| AccountMeta.signer(key) else AccountMeta.readonly(&DEFAULT_PUBKEY);
    metas[5] = if (parent_name) |key| AccountMeta.readonly(key) else AccountMeta.readonly(&DEFAULT_PUBKEY);
    if (parent_owner) |key| metas[6] = AccountMeta.signer(key);

    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas[0..account_len],
        .data = written_data,
    };
}

pub fn createDerived(
    payer: *const Pubkey,
    name_owner: *const Pubkey,
    name_class: ?*const Pubkey,
    parent_name: ?*const Pubkey,
    parent_owner: ?*const Pubkey,
    hashed_name: []const u8,
    lamports: u64,
    space: u32,
    name_account_out: *Pubkey,
    seed_scratch: [][]const u8,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const derived = try deriveNameAccountAddress(hashed_name, name_class, parent_name, seed_scratch);
    name_account_out.* = derived.address;
    return createForAddress(
        name_account_out,
        payer,
        name_owner,
        name_class,
        parent_name,
        parent_owner,
        hashed_name,
        lamports,
        space,
        metas,
        data,
    );
}

pub fn update(
    name_account: *const Pubkey,
    update_signer: *const Pubkey,
    parent_name: ?*const Pubkey,
    offset: u32,
    payload: []const u8,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len: usize = if (parent_name == null) 2 else 3;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeUpdateData(offset, payload, data);

    metas[0] = AccountMeta.writable(name_account);
    metas[1] = AccountMeta.signer(update_signer);
    if (parent_name) |key| metas[2] = AccountMeta.writable(key);

    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas[0..account_len],
        .data = written_data,
    };
}

pub fn transfer(
    name_account: *const Pubkey,
    current_owner: *const Pubkey,
    new_owner: *const Pubkey,
    name_class: ?*const Pubkey,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len: usize = if (name_class == null) 2 else 3;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeTransferData(new_owner, data);

    metas[0] = AccountMeta.writable(name_account);
    metas[1] = AccountMeta.signer(current_owner);
    if (name_class) |key| metas[2] = AccountMeta.signer(key);

    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas[0..account_len],
        .data = written_data,
    };
}

pub fn delete(
    name_account: *const Pubkey,
    owner: *const Pubkey,
    refund_target: *const Pubkey,
    metas: *[3]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeDeleteData(data);
    metas[0] = AccountMeta.writable(name_account);
    metas[1] = AccountMeta.signer(owner);
    metas[2] = AccountMeta.writable(refund_target);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas[0..],
        .data = written_data,
    };
}

pub fn realloc(
    payer: *const Pubkey,
    name_account: *const Pubkey,
    owner: *const Pubkey,
    space: u32,
    metas: *[4]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeReallocData(space, data);
    metas[0] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[1] = AccountMeta.signerWritable(payer);
    metas[2] = AccountMeta.writable(name_account);
    metas[3] = AccountMeta.signer(owner);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas[0..],
        .data = written_data,
    };
}

test "NameRecordHeader parses and writes the 96-byte borsh layout" {
    const header: NameRecordHeader = .{
        .parent_name = .{1} ** 32,
        .owner = .{2} ** 32,
        .class = .{3} ** 32,
    };
    var data: [NAME_RECORD_HEADER_LEN]u8 = undefined;
    _ = try writeHeader(header, &data);

    try std.testing.expectEqualSlices(u8, &header.parent_name, data[0..32]);
    try std.testing.expectEqualSlices(u8, &header.owner, data[32..64]);
    try std.testing.expectEqualSlices(u8, &header.class, data[64..96]);

    const parsed = try parseHeader(&data);
    try std.testing.expectEqualSlices(u8, &header.parent_name, &parsed.parent_name);
    try std.testing.expectEqualSlices(u8, &header.owner, &parsed.owner);
    try std.testing.expectEqualSlices(u8, &header.class, &parsed.class);
    try std.testing.expectError(error.AccountDataTooSmall, parseHeader(data[0..95]));
}

test "hashName uses the official prefix" {
    const hash = try hashName("example");
    var expected = sol.sha256(&.{ HASH_PREFIX, "example" }) catch unreachable;
    try std.testing.expectEqualSlices(u8, &expected.bytes, &hash);
}

test "fillNameSeeds chunks hashed name then class and parent" {
    var hashed_name: [33]u8 = .{0xAA} ** 33;
    const class: Pubkey = .{1} ** 32;
    const parent: Pubkey = .{2} ** 32;
    var seeds: [4][]const u8 = undefined;

    const filled = try fillNameSeeds(&hashed_name, &class, &parent, &seeds);
    try std.testing.expectEqual(@as(usize, 4), filled.len);
    try std.testing.expectEqual(@as(usize, 32), filled[0].len);
    try std.testing.expectEqual(@as(usize, 1), filled[1].len);
    try std.testing.expectEqualSlices(u8, &class, filled[2]);
    try std.testing.expectEqualSlices(u8, &parent, filled[3]);
}

test "writeCreateData matches borsh enum layout" {
    const hash = [_]u8{ 1, 2, 3 };
    var data: [40]u8 = undefined;
    const written = try writeCreateData(&hash, 0x0102_0304_0506_0708, 64, &data);

    try std.testing.expectEqualSlices(u8, &.{
        0,
        3,
        0,
        0,
        0,
        1,
        2,
        3,
        8,
        7,
        6,
        5,
        4,
        3,
        2,
        1,
        64,
        0,
        0,
        0,
    }, written);
}

test "createForAddress builds official account order" {
    const name_account: Pubkey = .{9} ** 32;
    const payer: Pubkey = .{1} ** 32;
    const owner: Pubkey = .{2} ** 32;
    const class: Pubkey = .{3} ** 32;
    const parent: Pubkey = .{4} ** 32;
    const parent_owner: Pubkey = .{5} ** 32;
    const hash = [_]u8{ 1, 2, 3 };
    var metas: [7]AccountMeta = undefined;
    var data: [40]u8 = undefined;

    const ix = try createForAddress(
        &name_account,
        &payer,
        &owner,
        &class,
        &parent,
        &parent_owner,
        &hash,
        50,
        10,
        &metas,
        &data,
    );

    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, ix.program_id);
    try std.testing.expectEqual(@as(usize, 7), ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &SYSTEM_PROGRAM_ID, ix.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_writable);
    try std.testing.expectEqualSlices(u8, &name_account, ix.accounts[2].pubkey);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[4].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[6].is_signer);
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);
}

test "update transfer delete and realloc builders match borsh tags" {
    const name_account: Pubkey = .{9} ** 32;
    const owner: Pubkey = .{1} ** 32;
    const new_owner: Pubkey = .{2} ** 32;
    const class: Pubkey = .{3} ** 32;
    const parent: Pubkey = .{4} ** 32;
    const refund: Pubkey = .{5} ** 32;
    var dynamic_metas: [3]AccountMeta = undefined;
    var fixed3: [3]AccountMeta = undefined;
    var fixed4: [4]AccountMeta = undefined;
    var data: [40]u8 = undefined;

    const update_ix = try update(&name_account, &owner, &parent, 7, "abc", &dynamic_metas, &data);
    try std.testing.expectEqual(@as(usize, 3), update_ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), update_ix.data[0]);
    try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, update_ix.data[1..5], .little));
    try std.testing.expectEqual(@as(u8, 1), update_ix.accounts[2].is_writable);

    const transfer_ix = try transfer(&name_account, &owner, &new_owner, &class, &dynamic_metas, &data);
    try std.testing.expectEqual(@as(usize, 3), transfer_ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 2), transfer_ix.data[0]);
    try std.testing.expectEqualSlices(u8, &new_owner, transfer_ix.data[1..33]);

    const delete_ix = try delete(&name_account, &owner, &refund, &fixed3, &data);
    try std.testing.expectEqual(@as(u8, 3), delete_ix.data[0]);
    try std.testing.expectEqual(@as(u8, 1), delete_ix.accounts[2].is_writable);

    const realloc_ix = try realloc(&refund, &name_account, &owner, 99, &fixed4, &data);
    try std.testing.expectEqual(@as(u8, 4), realloc_ix.data[0]);
    try std.testing.expectEqual(@as(u32, 99), std.mem.readInt(u32, realloc_ix.data[1..5], .little));
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "hashName"));
    try std.testing.expect(@hasDecl(@This(), "deriveNameAccountAddress"));
    try std.testing.expect(@hasDecl(@This(), "createForAddress"));
    try std.testing.expect(@hasDecl(@This(), "update"));
    try std.testing.expect(@hasDecl(@This(), "transfer"));
    try std.testing.expect(@hasDecl(@This(), "delete"));
    try std.testing.expect(@hasDecl(@This(), "realloc"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
