//! `solana_address_lookup_table` — ALT account parsing and resolution.

const std = @import("std");
const sol = @import("solana_program_sdk");
const tx = @import("solana_tx");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;
pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("AddressLookupTab1e1111111111111111111111111");
pub const SYSTEM_PROGRAM_ID: Pubkey = sol.system_program_id;
pub const LOOKUP_TABLE_META_SIZE: usize = 56;
pub const LOOKUP_TABLE_MAX_ADDRESSES: usize = 256;

pub const Error = error{
    AccountDataTooSmall,
    InvalidState,
    InvalidAuthorityOption,
    InvalidAddressData,
    AddressIndexOutOfRange,
    OutputTooSmall,
    TooManyAddresses,
};

pub const ProgramState = enum(u32) {
    uninitialized = 0,
    lookup_table = 1,
};

pub const LookupTableMeta = struct {
    deactivation_slot: u64,
    last_extended_slot: u64,
    last_extended_slot_start_index: u8,
    authority: ?Pubkey,
};

pub const LookupTableAccount = struct {
    meta: LookupTableMeta,
    addresses: []const Pubkey,
};

pub const ResolvedAddresses = struct {
    writable: []const Pubkey,
    readonly: []const Pubkey,
};

pub const ProgramInstruction = enum(u32) {
    create_lookup_table = 0,
    freeze_lookup_table = 1,
    extend_lookup_table = 2,
    deactivate_lookup_table = 3,
    close_lookup_table = 4,
};

pub const CREATE_LOOKUP_TABLE_DATA_LEN: usize = 4 + 8 + 1;
pub const DISCRIMINANT_ONLY_DATA_LEN: usize = 4;
pub const EXTEND_LOOKUP_TABLE_DATA_CAPACITY: usize = 4 + 8 + LOOKUP_TABLE_MAX_ADDRESSES * sol.PUBKEY_BYTES;

pub const CreateLookupTableData = [CREATE_LOOKUP_TABLE_DATA_LEN]u8;
pub const DiscriminantOnlyData = [DISCRIMINANT_ONLY_DATA_LEN]u8;
pub const ExtendLookupTableData = [EXTEND_LOOKUP_TABLE_DATA_CAPACITY]u8;

pub fn parse(data: []const u8) Error!LookupTableAccount {
    if (data.len < LOOKUP_TABLE_META_SIZE) return error.AccountDataTooSmall;
    if ((data.len - LOOKUP_TABLE_META_SIZE) % sol.PUBKEY_BYTES != 0) {
        return error.InvalidAddressData;
    }

    const state_raw = std.mem.readInt(u32, data[0..4], .little);
    const state: ProgramState = switch (state_raw) {
        @intFromEnum(ProgramState.lookup_table) => .lookup_table,
        else => return error.InvalidState,
    };
    _ = state;

    const authority_tag = data[21];
    const authority: ?Pubkey = switch (authority_tag) {
        0 => null,
        1 => data[22..54].*,
        else => return error.InvalidAuthorityOption,
    };

    const address_bytes = data[LOOKUP_TABLE_META_SIZE..];
    const addresses = std.mem.bytesAsSlice(Pubkey, address_bytes);
    if (addresses.len > LOOKUP_TABLE_MAX_ADDRESSES) return error.InvalidAddressData;

    return .{
        .meta = .{
            .deactivation_slot = std.mem.readInt(u64, data[4..12], .little),
            .last_extended_slot = std.mem.readInt(u64, data[12..20], .little),
            .last_extended_slot_start_index = data[20],
            .authority = authority,
        },
        .addresses = addresses,
    };
}

pub fn deriveLookupTableAddress(
    authority: *const Pubkey,
    recent_slot: u64,
) sol.pda.ProgramDerivedAddress {
    const slot_bytes = std.mem.asBytes(&recent_slot);
    return sol.pda.findProgramAddress(&.{ authority, slot_bytes }, &PROGRAM_ID) catch unreachable;
}

pub fn writeCreateLookupTableData(
    recent_slot: u64,
    bump_seed: u8,
    out: *CreateLookupTableData,
) []const u8 {
    writeDiscriminant(.create_lookup_table, out[0..4]);
    std.mem.writeInt(u64, out[4..12], recent_slot, .little);
    out[12] = bump_seed;
    return out;
}

pub fn createLookupTable(
    authority: *const Pubkey,
    payer: *const Pubkey,
    recent_slot: u64,
    authority_is_signer: bool,
    lookup_table_out: *Pubkey,
    metas: *[4]AccountMeta,
    data: *CreateLookupTableData,
) Instruction {
    const derived = deriveLookupTableAddress(authority, recent_slot);
    lookup_table_out.* = derived.address;
    return createLookupTableForAddress(
        lookup_table_out,
        authority,
        payer,
        recent_slot,
        derived.bump_seed,
        authority_is_signer,
        metas,
        data,
    );
}

pub fn createLookupTableForAddress(
    lookup_table: *const Pubkey,
    authority: *const Pubkey,
    payer: *const Pubkey,
    recent_slot: u64,
    bump_seed: u8,
    authority_is_signer: bool,
    metas: *[4]AccountMeta,
    data: *CreateLookupTableData,
) Instruction {
    metas[0] = AccountMeta.writable(lookup_table);
    metas[1] = AccountMeta.init(authority, false, authority_is_signer);
    metas[2] = AccountMeta.signerWritable(payer);
    metas[3] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = metas,
        .data = writeCreateLookupTableData(recent_slot, bump_seed, data),
    };
}

pub fn freezeLookupTable(
    lookup_table: *const Pubkey,
    authority: *const Pubkey,
    metas: *[2]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.freeze_lookup_table, data[0..]);
    metas[0] = AccountMeta.writable(lookup_table);
    metas[1] = AccountMeta.signer(authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn deactivateLookupTable(
    lookup_table: *const Pubkey,
    authority: *const Pubkey,
    metas: *[2]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.deactivate_lookup_table, data[0..]);
    metas[0] = AccountMeta.writable(lookup_table);
    metas[1] = AccountMeta.signer(authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn closeLookupTable(
    lookup_table: *const Pubkey,
    authority: *const Pubkey,
    recipient: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.close_lookup_table, data[0..]);
    metas[0] = AccountMeta.writable(lookup_table);
    metas[1] = AccountMeta.signer(authority);
    metas[2] = AccountMeta.writable(recipient);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = data };
}

pub fn extendLookupTable(
    lookup_table: *const Pubkey,
    authority: *const Pubkey,
    new_addresses: []const Pubkey,
    metas: *[2]AccountMeta,
    data: *ExtendLookupTableData,
) Error!Instruction {
    const written = try writeExtendLookupTableData(new_addresses, data);
    metas[0] = AccountMeta.writable(lookup_table);
    metas[1] = AccountMeta.signer(authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = written };
}

pub fn extendLookupTableFunded(
    lookup_table: *const Pubkey,
    authority: *const Pubkey,
    payer: *const Pubkey,
    new_addresses: []const Pubkey,
    metas: *[4]AccountMeta,
    data: *ExtendLookupTableData,
) Error!Instruction {
    const written = try writeExtendLookupTableData(new_addresses, data);
    metas[0] = AccountMeta.writable(lookup_table);
    metas[1] = AccountMeta.signer(authority);
    metas[2] = AccountMeta.signerWritable(payer);
    metas[3] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas, .data = written };
}

pub fn writeExtendLookupTableData(
    new_addresses: []const Pubkey,
    out: *ExtendLookupTableData,
) Error![]const u8 {
    if (new_addresses.len > LOOKUP_TABLE_MAX_ADDRESSES) return error.TooManyAddresses;
    writeDiscriminant(.extend_lookup_table, out[0..4]);
    std.mem.writeInt(u64, out[4..12], new_addresses.len, .little);
    var cursor: usize = 12;
    for (new_addresses) |*address| {
        @memcpy(out[cursor..][0..sol.PUBKEY_BYTES], address);
        cursor += sol.PUBKEY_BYTES;
    }
    return out[0..cursor];
}

pub fn resolveAddresses(
    table: LookupTableAccount,
    writable_indexes: []const u8,
    readonly_indexes: []const u8,
    writable_out: []Pubkey,
    readonly_out: []Pubkey,
) Error!ResolvedAddresses {
    if (writable_out.len < writable_indexes.len or readonly_out.len < readonly_indexes.len) {
        return error.OutputTooSmall;
    }

    for (writable_indexes, 0..) |index, i| {
        writable_out[i] = try addressAt(table, index);
    }
    for (readonly_indexes, 0..) |index, i| {
        readonly_out[i] = try addressAt(table, index);
    }

    return .{
        .writable = writable_out[0..writable_indexes.len],
        .readonly = readonly_out[0..readonly_indexes.len],
    };
}

pub fn messageAddressTableLookup(
    account_key: *const Pubkey,
    writable_indexes: []const u8,
    readonly_indexes: []const u8,
) tx.MessageAddressTableLookup {
    return .{
        .account_key = account_key,
        .writable_indexes = writable_indexes,
        .readonly_indexes = readonly_indexes,
    };
}

fn addressAt(table: LookupTableAccount, index: u8) Error!Pubkey {
    if (index >= table.addresses.len) return error.AddressIndexOutOfRange;
    return table.addresses[index];
}

fn writeDiscriminant(tag: ProgramInstruction, out: []u8) void {
    std.mem.writeInt(u32, out[0..4], @intFromEnum(tag), .little);
}

fn writeLookupTableFixture(
    out: []u8,
    authority: ?*const Pubkey,
    addresses: []const Pubkey,
) []u8 {
    std.debug.assert(out.len >= LOOKUP_TABLE_META_SIZE + addresses.len * sol.PUBKEY_BYTES);
    @memset(out[0..LOOKUP_TABLE_META_SIZE], 0);
    std.mem.writeInt(u32, out[0..4], @intFromEnum(ProgramState.lookup_table), .little);
    std.mem.writeInt(u64, out[4..12], std.math.maxInt(u64), .little);
    std.mem.writeInt(u64, out[12..20], 77, .little);
    out[20] = 2;
    if (authority) |key| {
        out[21] = 1;
        @memcpy(out[22..54], key);
    } else {
        out[21] = 0;
    }
    var cursor: usize = LOOKUP_TABLE_META_SIZE;
    for (addresses) |*address| {
        @memcpy(out[cursor..][0..sol.PUBKEY_BYTES], address);
        cursor += sol.PUBKEY_BYTES;
    }
    return out[0..cursor];
}

test "parse reads lookup table metadata and addresses" {
    const authority: Pubkey = .{9} ** sol.PUBKEY_BYTES;
    const addresses = [_]Pubkey{
        .{1} ** sol.PUBKEY_BYTES,
        .{2} ** sol.PUBKEY_BYTES,
        .{3} ** sol.PUBKEY_BYTES,
    };
    var data: [LOOKUP_TABLE_META_SIZE + addresses.len * sol.PUBKEY_BYTES]u8 = undefined;
    const account_data = writeLookupTableFixture(&data, &authority, &addresses);

    const table = try parse(account_data);
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), table.meta.deactivation_slot);
    try std.testing.expectEqual(@as(u64, 77), table.meta.last_extended_slot);
    try std.testing.expectEqual(@as(u8, 2), table.meta.last_extended_slot_start_index);
    try std.testing.expect(table.meta.authority != null);
    try std.testing.expectEqualSlices(u8, &authority, &table.meta.authority.?);
    try std.testing.expectEqual(@as(usize, addresses.len), table.addresses.len);
    try std.testing.expectEqualSlices(u8, &addresses[2], &table.addresses[2]);
}

test "parse accepts frozen lookup tables with no authority" {
    const addresses = [_]Pubkey{.{1} ** sol.PUBKEY_BYTES};
    var data: [LOOKUP_TABLE_META_SIZE + addresses.len * sol.PUBKEY_BYTES]u8 = undefined;
    const account_data = writeLookupTableFixture(&data, null, &addresses);

    const table = try parse(account_data);
    try std.testing.expect(table.meta.authority == null);
    try std.testing.expectEqual(@as(usize, 1), table.addresses.len);
}

test "resolveAddresses copies selected writable and readonly addresses" {
    const addresses = [_]Pubkey{
        .{1} ** sol.PUBKEY_BYTES,
        .{2} ** sol.PUBKEY_BYTES,
        .{3} ** sol.PUBKEY_BYTES,
    };
    var data: [LOOKUP_TABLE_META_SIZE + addresses.len * sol.PUBKEY_BYTES]u8 = undefined;
    const table = try parse(writeLookupTableFixture(&data, null, &addresses));

    var writable: [2]Pubkey = undefined;
    var readonly: [1]Pubkey = undefined;
    const resolved = try resolveAddresses(table, &.{ 2, 0 }, &.{1}, &writable, &readonly);

    try std.testing.expectEqualSlices(u8, &addresses[2], &resolved.writable[0]);
    try std.testing.expectEqualSlices(u8, &addresses[0], &resolved.writable[1]);
    try std.testing.expectEqualSlices(u8, &addresses[1], &resolved.readonly[0]);
}

test "lookup parser and resolver report malformed input" {
    const too_small: [8]u8 = .{0} ** 8;
    try std.testing.expectError(error.AccountDataTooSmall, parse(&too_small));

    var invalid_state: [LOOKUP_TABLE_META_SIZE]u8 = .{0} ** LOOKUP_TABLE_META_SIZE;
    std.mem.writeInt(u32, invalid_state[0..4], 2, .little);
    try std.testing.expectError(error.InvalidState, parse(&invalid_state));

    var invalid_authority: [LOOKUP_TABLE_META_SIZE]u8 = .{0} ** LOOKUP_TABLE_META_SIZE;
    std.mem.writeInt(u32, invalid_authority[0..4], @intFromEnum(ProgramState.lookup_table), .little);
    invalid_authority[21] = 2;
    try std.testing.expectError(error.InvalidAuthorityOption, parse(&invalid_authority));

    var invalid_addresses: [LOOKUP_TABLE_META_SIZE + 1]u8 = .{0} ** (LOOKUP_TABLE_META_SIZE + 1);
    std.mem.writeInt(u32, invalid_addresses[0..4], @intFromEnum(ProgramState.lookup_table), .little);
    try std.testing.expectError(error.InvalidAddressData, parse(&invalid_addresses));

    const addresses = [_]Pubkey{.{1} ** sol.PUBKEY_BYTES};
    var data: [LOOKUP_TABLE_META_SIZE + addresses.len * sol.PUBKEY_BYTES]u8 = undefined;
    const table = try parse(writeLookupTableFixture(&data, null, &addresses));
    var writable: [1]Pubkey = undefined;
    var readonly: [1]Pubkey = undefined;
    try std.testing.expectError(
        error.AddressIndexOutOfRange,
        resolveAddresses(table, &.{2}, &.{}, &writable, &readonly),
    );
    try std.testing.expectError(
        error.OutputTooSmall,
        resolveAddresses(table, &.{0}, &.{0}, writable[0..0], &readonly),
    );
}

test "messageAddressTableLookup builds solana_tx lookup records" {
    const table_key: Pubkey = .{7} ** sol.PUBKEY_BYTES;
    const lookup = messageAddressTableLookup(&table_key, &.{ 1, 2 }, &.{3});
    try std.testing.expectEqualSlices(u8, &table_key, lookup.account_key);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, lookup.writable_indexes);
    try std.testing.expectEqualSlices(u8, &.{3}, lookup.readonly_indexes);
}

test "create lookup table builder derives canonical PDA and bincode data" {
    const authority: Pubkey = .{1} ** sol.PUBKEY_BYTES;
    const payer: Pubkey = .{2} ** sol.PUBKEY_BYTES;
    const recent_slot: u64 = 12345;
    const derived = deriveLookupTableAddress(&authority, recent_slot);
    var lookup_table: Pubkey = undefined;
    var metas: [4]AccountMeta = undefined;
    var data: CreateLookupTableData = undefined;

    const ix = createLookupTable(&authority, &payer, recent_slot, false, &lookup_table, &metas, &data);

    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, ix.program_id);
    try std.testing.expectEqualSlices(u8, &derived.address, &lookup_table);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, ix.data[0..4]);
    try std.testing.expectEqual(recent_slot, std.mem.readInt(u64, ix.data[4..12], .little));
    try std.testing.expectEqual(derived.bump_seed, ix.data[12]);
    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &lookup_table, ix.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[0].is_writable);
    try std.testing.expectEqual(@as(u8, 0), ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[2].is_signer);
    try std.testing.expectEqualSlices(u8, &SYSTEM_PROGRAM_ID, ix.accounts[3].pubkey);
}

test "lookup table management builders encode official discriminants" {
    const table: Pubkey = .{3} ** sol.PUBKEY_BYTES;
    const authority: Pubkey = .{4} ** sol.PUBKEY_BYTES;
    const recipient: Pubkey = .{5} ** sol.PUBKEY_BYTES;
    const addresses = [_]Pubkey{ .{6} ** sol.PUBKEY_BYTES, .{7} ** sol.PUBKEY_BYTES };
    var two_metas: [2]AccountMeta = undefined;
    var three_metas: [3]AccountMeta = undefined;
    var four_metas: [4]AccountMeta = undefined;
    var disc_data: DiscriminantOnlyData = undefined;
    var extend_data: ExtendLookupTableData = undefined;

    const freeze = freezeLookupTable(&table, &authority, &two_metas, &disc_data);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0 }, freeze.data);

    const extend = try extendLookupTableFunded(&table, &authority, &recipient, &addresses, &four_metas, &extend_data);
    try std.testing.expectEqualSlices(u8, &.{ 2, 0, 0, 0 }, extend.data[0..4]);
    try std.testing.expectEqual(@as(u64, 2), std.mem.readInt(u64, extend.data[4..12], .little));
    try std.testing.expectEqualSlices(u8, &addresses[0], extend.data[12..44]);
    try std.testing.expectEqual(@as(usize, 4), extend.accounts.len);
    try std.testing.expectEqualSlices(u8, &SYSTEM_PROGRAM_ID, extend.accounts[3].pubkey);

    const deactivate = deactivateLookupTable(&table, &authority, &two_metas, &disc_data);
    try std.testing.expectEqualSlices(u8, &.{ 3, 0, 0, 0 }, deactivate.data);

    const close = closeLookupTable(&table, &authority, &recipient, &three_metas, &disc_data);
    try std.testing.expectEqualSlices(u8, &.{ 4, 0, 0, 0 }, close.data);
    try std.testing.expectEqualSlices(u8, &recipient, close.accounts[2].pubkey);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "parse"));
    try std.testing.expect(@hasDecl(@This(), "resolveAddresses"));
    try std.testing.expect(@hasDecl(@This(), "messageAddressTableLookup"));
    try std.testing.expect(@hasDecl(@This(), "createLookupTableForAddress"));
    try std.testing.expect(@hasDecl(@This(), "extendLookupTableFunded"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
