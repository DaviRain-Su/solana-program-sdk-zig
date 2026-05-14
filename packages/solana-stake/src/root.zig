//! `solana_stake` — Stake Program instruction builders.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("Stake11111111111111111111111111111111111111");
pub const CLOCK_ID: Pubkey = sol.pubkey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");
pub const RENT_ID: Pubkey = sol.rent_id;
pub const STAKE_HISTORY_ID: Pubkey = sol.pubkey.comptimeFromBase58("SysvarStakeHistory1111111111111111111111111");
pub const CONFIG_ID: Pubkey = sol.pubkey.comptimeFromBase58("StakeConfig11111111111111111111111111111111");
pub const STAKE_STATE_SIZE: u64 = 200;
pub const MAX_SEED_LEN: usize = sol.pda.MAX_SEED_LEN;

pub const Error = error{
    BufferTooSmall,
    SeedTooLong,
};

pub const StakeAuthorize = enum(u32) {
    staker = 0,
    withdrawer = 1,
};

pub const Authorized = struct {
    staker: Pubkey,
    withdrawer: Pubkey,
};

pub const Lockup = struct {
    unix_timestamp: i64,
    epoch: u64,
    custodian: Pubkey,
};

pub const LockupArgs = struct {
    unix_timestamp: ?i64 = null,
    epoch: ?u64 = null,
    custodian: ?Pubkey = null,
};

pub const LockupCheckedArgs = struct {
    unix_timestamp: ?i64 = null,
    epoch: ?u64 = null,
    new_custodian: ?*const Pubkey = null,
};

pub const StakeInstruction = enum(u32) {
    initialize = 0,
    authorize = 1,
    delegate_stake = 2,
    split = 3,
    withdraw = 4,
    deactivate = 5,
    set_lockup = 6,
    merge = 7,
    authorize_with_seed = 8,
    initialize_checked = 9,
    authorize_checked = 10,
    authorize_checked_with_seed = 11,
    set_lockup_checked = 12,
    get_minimum_delegation = 13,
    deactivate_delinquent = 14,
    redelegate = 15,
    move_stake = 16,
    move_lamports = 17,
};

pub const INITIALIZE_DATA_LEN: usize = 4 + 32 + 32 + 8 + 8 + 32;
pub const AUTHORIZE_DATA_LEN: usize = 4 + 32 + 4;
pub const AUTHORIZE_CHECKED_DATA_LEN: usize = 4 + 4;
pub const U64_DATA_LEN: usize = 4 + 8;
pub const DISCRIMINANT_ONLY_DATA_LEN: usize = 4;
pub const AUTHORIZE_WITH_SEED_DATA_CAPACITY: usize = 4 + 32 + 4 + 8 + MAX_SEED_LEN + 32;
pub const AUTHORIZE_CHECKED_WITH_SEED_DATA_CAPACITY: usize = 4 + 4 + 8 + MAX_SEED_LEN + 32;
pub const SET_LOCKUP_DATA_CAPACITY: usize = 4 + 1 + 8 + 1 + 8 + 1 + 32;
pub const SET_LOCKUP_CHECKED_DATA_CAPACITY: usize = 4 + 1 + 8 + 1 + 8;

pub const InitializeData = [INITIALIZE_DATA_LEN]u8;
pub const AuthorizeData = [AUTHORIZE_DATA_LEN]u8;
pub const AuthorizeCheckedData = [AUTHORIZE_CHECKED_DATA_LEN]u8;
pub const U64Data = [U64_DATA_LEN]u8;
pub const DiscriminantOnlyData = [DISCRIMINANT_ONLY_DATA_LEN]u8;
pub const AuthorizeWithSeedData = [AUTHORIZE_WITH_SEED_DATA_CAPACITY]u8;
pub const AuthorizeCheckedWithSeedData = [AUTHORIZE_CHECKED_WITH_SEED_DATA_CAPACITY]u8;
pub const SetLockupData = [SET_LOCKUP_DATA_CAPACITY]u8;
pub const SetLockupCheckedData = [SET_LOCKUP_CHECKED_DATA_CAPACITY]u8;

pub fn initialize(
    stake: *const Pubkey,
    authorized: Authorized,
    lockup: Lockup,
    metas: *[2]AccountMeta,
    data: *InitializeData,
) Instruction {
    writeInitializeData(authorized, lockup, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.readonly(&RENT_ID);
    return instruction(metas[0..], data);
}

pub fn initializeChecked(
    stake: *const Pubkey,
    authorized: Authorized,
    metas: *[4]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.initialize_checked, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.readonly(&RENT_ID);
    metas[2] = AccountMeta.readonly(&authorized.staker);
    metas[3] = AccountMeta.signer(&authorized.withdrawer);
    return instruction(metas[0..], data);
}

pub fn authorize(
    stake: *const Pubkey,
    authorized: *const Pubkey,
    new_authorized: *const Pubkey,
    stake_authorize: StakeAuthorize,
    custodian: ?*const Pubkey,
    metas: *[4]AccountMeta,
    data: *AuthorizeData,
) Instruction {
    writeAuthorizeData(.authorize, new_authorized, stake_authorize, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.readonly(&CLOCK_ID);
    metas[2] = AccountMeta.signer(authorized);
    if (custodian) |key| {
        metas[3] = AccountMeta.signer(key);
        return instruction(metas[0..4], data);
    }
    return instruction(metas[0..3], data);
}

pub fn authorizeChecked(
    stake: *const Pubkey,
    authorized: *const Pubkey,
    new_authorized: *const Pubkey,
    stake_authorize: StakeAuthorize,
    custodian: ?*const Pubkey,
    metas: *[5]AccountMeta,
    data: *AuthorizeCheckedData,
) Instruction {
    writeAuthorizeCheckedData(stake_authorize, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.readonly(&CLOCK_ID);
    metas[2] = AccountMeta.signer(authorized);
    metas[3] = AccountMeta.signer(new_authorized);
    if (custodian) |key| {
        metas[4] = AccountMeta.signer(key);
        return instruction(metas[0..5], data);
    }
    return instruction(metas[0..4], data);
}

pub fn authorizeWithSeed(
    stake: *const Pubkey,
    authority_base: *const Pubkey,
    authority_seed: []const u8,
    authority_owner: *const Pubkey,
    new_authorized: *const Pubkey,
    stake_authorize: StakeAuthorize,
    custodian: ?*const Pubkey,
    metas: *[4]AccountMeta,
    data: *AuthorizeWithSeedData,
) Error!Instruction {
    const written = try writeAuthorizeWithSeedData(
        .authorize_with_seed,
        new_authorized,
        stake_authorize,
        authority_seed,
        authority_owner,
        data[0..],
    );
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.signer(authority_base);
    metas[2] = AccountMeta.readonly(&CLOCK_ID);
    if (custodian) |key| {
        metas[3] = AccountMeta.signer(key);
        return instruction(metas[0..4], data[0..written]);
    }
    return instruction(metas[0..3], data[0..written]);
}

pub fn authorizeCheckedWithSeed(
    stake: *const Pubkey,
    authority_base: *const Pubkey,
    authority_seed: []const u8,
    authority_owner: *const Pubkey,
    new_authorized: *const Pubkey,
    stake_authorize: StakeAuthorize,
    custodian: ?*const Pubkey,
    metas: *[5]AccountMeta,
    data: *AuthorizeCheckedWithSeedData,
) Error!Instruction {
    const written = try writeAuthorizeCheckedWithSeedData(
        stake_authorize,
        authority_seed,
        authority_owner,
        data[0..],
    );
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.signer(authority_base);
    metas[2] = AccountMeta.readonly(&CLOCK_ID);
    metas[3] = AccountMeta.signer(new_authorized);
    if (custodian) |key| {
        metas[4] = AccountMeta.signer(key);
        return instruction(metas[0..5], data[0..written]);
    }
    return instruction(metas[0..4], data[0..written]);
}

pub fn delegateStake(
    stake: *const Pubkey,
    authorized: *const Pubkey,
    vote: *const Pubkey,
    metas: *[6]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.delegate_stake, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.readonly(vote);
    metas[2] = AccountMeta.readonly(&CLOCK_ID);
    metas[3] = AccountMeta.readonly(&STAKE_HISTORY_ID);
    metas[4] = AccountMeta.readonly(&CONFIG_ID);
    metas[5] = AccountMeta.signer(authorized);
    return instruction(metas[0..], data);
}

pub fn split(
    stake: *const Pubkey,
    split_stake: *const Pubkey,
    authorized: *const Pubkey,
    lamports: u64,
    metas: *[3]AccountMeta,
    data: *U64Data,
) Instruction {
    writeU64(.split, lamports, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.writable(split_stake);
    metas[2] = AccountMeta.signer(authorized);
    return instruction(metas[0..], data);
}

pub fn withdraw(
    stake: *const Pubkey,
    to: *const Pubkey,
    withdrawer: *const Pubkey,
    lamports: u64,
    custodian: ?*const Pubkey,
    metas: *[6]AccountMeta,
    data: *U64Data,
) Instruction {
    writeU64(.withdraw, lamports, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.writable(to);
    metas[2] = AccountMeta.readonly(&CLOCK_ID);
    metas[3] = AccountMeta.readonly(&STAKE_HISTORY_ID);
    metas[4] = AccountMeta.signer(withdrawer);
    if (custodian) |key| {
        metas[5] = AccountMeta.signer(key);
        return instruction(metas[0..6], data);
    }
    return instruction(metas[0..5], data);
}

pub fn deactivateStake(
    stake: *const Pubkey,
    authorized: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.deactivate, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.readonly(&CLOCK_ID);
    metas[2] = AccountMeta.signer(authorized);
    return instruction(metas[0..], data);
}

pub fn setLockup(
    stake: *const Pubkey,
    lockup: LockupArgs,
    custodian: *const Pubkey,
    metas: *[2]AccountMeta,
    data: *SetLockupData,
) Error!Instruction {
    const written = try writeSetLockupData(.set_lockup, lockup, data[0..]);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.signer(custodian);
    return instruction(metas[0..], data[0..written]);
}

pub fn setLockupChecked(
    stake: *const Pubkey,
    lockup: LockupCheckedArgs,
    custodian: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *SetLockupCheckedData,
) Error!Instruction {
    const written = try writeSetLockupCheckedData(lockup, data[0..]);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.signer(custodian);
    if (lockup.new_custodian) |new_custodian| {
        metas[2] = AccountMeta.signer(new_custodian);
        return instruction(metas[0..3], data[0..written]);
    }
    return instruction(metas[0..2], data[0..written]);
}

pub fn merge(
    destination_stake: *const Pubkey,
    source_stake: *const Pubkey,
    authorized: *const Pubkey,
    metas: *[5]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.merge, data);
    metas[0] = AccountMeta.writable(destination_stake);
    metas[1] = AccountMeta.writable(source_stake);
    metas[2] = AccountMeta.readonly(&CLOCK_ID);
    metas[3] = AccountMeta.readonly(&STAKE_HISTORY_ID);
    metas[4] = AccountMeta.signer(authorized);
    return instruction(metas[0..], data);
}

pub fn getMinimumDelegation(data: *DiscriminantOnlyData) Instruction {
    writeDiscriminant(.get_minimum_delegation, data);
    return instruction(&.{}, data);
}

pub fn deactivateDelinquentStake(
    stake: *const Pubkey,
    delinquent_vote: *const Pubkey,
    reference_vote: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.deactivate_delinquent, data);
    metas[0] = AccountMeta.writable(stake);
    metas[1] = AccountMeta.readonly(delinquent_vote);
    metas[2] = AccountMeta.readonly(reference_vote);
    return instruction(metas[0..], data);
}

pub fn moveStake(
    source_stake: *const Pubkey,
    destination_stake: *const Pubkey,
    authorized: *const Pubkey,
    lamports: u64,
    metas: *[3]AccountMeta,
    data: *U64Data,
) Instruction {
    writeU64(.move_stake, lamports, data);
    metas[0] = AccountMeta.writable(source_stake);
    metas[1] = AccountMeta.writable(destination_stake);
    metas[2] = AccountMeta.signer(authorized);
    return instruction(metas[0..], data);
}

pub fn moveLamports(
    source_stake: *const Pubkey,
    destination_stake: *const Pubkey,
    authorized: *const Pubkey,
    lamports: u64,
    metas: *[3]AccountMeta,
    data: *U64Data,
) Instruction {
    writeU64(.move_lamports, lamports, data);
    metas[0] = AccountMeta.writable(source_stake);
    metas[1] = AccountMeta.writable(destination_stake);
    metas[2] = AccountMeta.signer(authorized);
    return instruction(metas[0..], data);
}

fn instruction(accounts: []const AccountMeta, data: []const u8) Instruction {
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = accounts,
        .data = data,
    };
}

fn writeInitializeData(authorized: Authorized, lockup: Lockup, data: *InitializeData) void {
    writeDiscriminant(.initialize, data[0..4]);
    @memcpy(data[4..36], &authorized.staker);
    @memcpy(data[36..68], &authorized.withdrawer);
    std.mem.writeInt(i64, data[68..76], lockup.unix_timestamp, .little);
    std.mem.writeInt(u64, data[76..84], lockup.epoch, .little);
    @memcpy(data[84..116], &lockup.custodian);
}

fn writeAuthorizeData(
    tag: StakeInstruction,
    new_authorized: *const Pubkey,
    stake_authorize: StakeAuthorize,
    data: *AuthorizeData,
) void {
    writeDiscriminant(tag, data[0..4]);
    @memcpy(data[4..36], new_authorized);
    std.mem.writeInt(u32, data[36..40], @intFromEnum(stake_authorize), .little);
}

fn writeAuthorizeCheckedData(stake_authorize: StakeAuthorize, data: *AuthorizeCheckedData) void {
    writeDiscriminant(.authorize_checked, data[0..4]);
    std.mem.writeInt(u32, data[4..8], @intFromEnum(stake_authorize), .little);
}

fn writeAuthorizeWithSeedData(
    tag: StakeInstruction,
    new_authorized: *const Pubkey,
    stake_authorize: StakeAuthorize,
    authority_seed: []const u8,
    authority_owner: *const Pubkey,
    data: []u8,
) Error!usize {
    if (authority_seed.len > MAX_SEED_LEN) return error.SeedTooLong;
    if (data.len < 4 + 32 + 4 + 8 + authority_seed.len + 32) return error.BufferTooSmall;
    writeDiscriminant(tag, data[0..4]);
    @memcpy(data[4..36], new_authorized);
    std.mem.writeInt(u32, data[36..40], @intFromEnum(stake_authorize), .little);
    var cursor: usize = 40;
    cursor += try writeBincodeString(data[cursor..], authority_seed);
    @memcpy(data[cursor .. cursor + 32], authority_owner);
    return cursor + 32;
}

fn writeAuthorizeCheckedWithSeedData(
    stake_authorize: StakeAuthorize,
    authority_seed: []const u8,
    authority_owner: *const Pubkey,
    data: []u8,
) Error!usize {
    if (authority_seed.len > MAX_SEED_LEN) return error.SeedTooLong;
    if (data.len < 4 + 4 + 8 + authority_seed.len + 32) return error.BufferTooSmall;
    writeDiscriminant(.authorize_checked_with_seed, data[0..4]);
    std.mem.writeInt(u32, data[4..8], @intFromEnum(stake_authorize), .little);
    var cursor: usize = 8;
    cursor += try writeBincodeString(data[cursor..], authority_seed);
    @memcpy(data[cursor .. cursor + 32], authority_owner);
    return cursor + 32;
}

fn writeSetLockupData(tag: StakeInstruction, lockup: LockupArgs, data: []u8) Error!usize {
    if (data.len < 4) return error.BufferTooSmall;
    writeDiscriminant(tag, data[0..4]);
    var cursor: usize = 4;
    cursor += try writeOptionI64(data[cursor..], lockup.unix_timestamp);
    cursor += try writeOptionU64(data[cursor..], lockup.epoch);
    cursor += try writeOptionPubkey(data[cursor..], lockup.custodian);
    return cursor;
}

fn writeSetLockupCheckedData(lockup: LockupCheckedArgs, data: []u8) Error!usize {
    if (data.len < 4) return error.BufferTooSmall;
    writeDiscriminant(.set_lockup_checked, data[0..4]);
    var cursor: usize = 4;
    cursor += try writeOptionI64(data[cursor..], lockup.unix_timestamp);
    cursor += try writeOptionU64(data[cursor..], lockup.epoch);
    return cursor;
}

fn writeBincodeString(data: []u8, value: []const u8) Error!usize {
    if (data.len < 8 + value.len) return error.BufferTooSmall;
    std.mem.writeInt(u64, data[0..8], @intCast(value.len), .little);
    @memcpy(data[8 .. 8 + value.len], value);
    return 8 + value.len;
}

fn writeOptionI64(data: []u8, value: ?i64) Error!usize {
    if (data.len < 1) return error.BufferTooSmall;
    if (value) |inner| {
        if (data.len < 9) return error.BufferTooSmall;
        data[0] = 1;
        std.mem.writeInt(i64, data[1..9], inner, .little);
        return 9;
    }
    data[0] = 0;
    return 1;
}

fn writeOptionU64(data: []u8, value: ?u64) Error!usize {
    if (data.len < 1) return error.BufferTooSmall;
    if (value) |inner| {
        if (data.len < 9) return error.BufferTooSmall;
        data[0] = 1;
        std.mem.writeInt(u64, data[1..9], inner, .little);
        return 9;
    }
    data[0] = 0;
    return 1;
}

fn writeOptionPubkey(data: []u8, value: ?Pubkey) Error!usize {
    if (data.len < 1) return error.BufferTooSmall;
    if (value) |inner| {
        if (data.len < 33) return error.BufferTooSmall;
        data[0] = 1;
        @memcpy(data[1..33], &inner);
        return 33;
    }
    data[0] = 0;
    return 1;
}

fn writeU64(tag: StakeInstruction, value: u64, data: *U64Data) void {
    writeDiscriminant(tag, data[0..4]);
    std.mem.writeInt(u64, data[4..12], value, .little);
}

fn writeDiscriminant(tag: StakeInstruction, data: []u8) void {
    std.debug.assert(data.len >= 4);
    std.mem.writeInt(u32, data[0..4], @intFromEnum(tag), .little);
}

test "initialize encodes authorized and lockup data" {
    const stake: Pubkey = .{1} ** 32;
    const authorized: Authorized = .{
        .staker = .{2} ** 32,
        .withdrawer = .{3} ** 32,
    };
    const lockup: Lockup = .{
        .unix_timestamp = -5,
        .epoch = 9,
        .custodian = .{4} ** 32,
    };
    var metas: [2]AccountMeta = undefined;
    var data: InitializeData = undefined;

    const ix = initialize(&stake, authorized, lockup, &metas, &data);
    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, ix.program_id);
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[0].is_writable);
    try std.testing.expectEqualSlices(u8, &RENT_ID, ix.accounts[1].pubkey);
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &authorized.staker, ix.data[4..36]);
    try std.testing.expectEqualSlices(u8, &authorized.withdrawer, ix.data[36..68]);
    try std.testing.expectEqual(@as(i64, -5), std.mem.readInt(i64, ix.data[68..76], .little));
    try std.testing.expectEqual(@as(u64, 9), std.mem.readInt(u64, ix.data[76..84], .little));
    try std.testing.expectEqualSlices(u8, &lockup.custodian, ix.data[84..116]);
}

test "checked initialize encodes signer authorities" {
    const stake: Pubkey = .{1} ** 32;
    const authorized: Authorized = .{
        .staker = .{2} ** 32,
        .withdrawer = .{3} ** 32,
    };
    var metas: [4]AccountMeta = undefined;
    var data: DiscriminantOnlyData = undefined;

    const ix = initializeChecked(&stake, authorized, &metas, &data);
    try std.testing.expectEqualSlices(u8, &.{ 9, 0, 0, 0 }, ix.data);
    try std.testing.expectEqual(@as(u8, 0), ix.accounts[2].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[3].is_signer);
}

test "authorize builders include optional custodian" {
    const stake: Pubkey = .{1} ** 32;
    const current: Pubkey = .{2} ** 32;
    const next: Pubkey = .{3} ** 32;
    const custodian: Pubkey = .{4} ** 32;
    var metas: [4]AccountMeta = undefined;
    var data: AuthorizeData = undefined;

    const ix = authorize(&stake, &current, &next, .withdrawer, &custodian, &metas, &data);
    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[2].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[3].is_signer);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &next, ix.data[4..36]);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, ix.data[36..40], .little));
}

test "seeded authorize builders encode seed strings and owners" {
    const stake: Pubkey = .{1} ** 32;
    const authority_base: Pubkey = .{2} ** 32;
    const authority_owner: Pubkey = .{3} ** 32;
    const next: Pubkey = .{4} ** 32;
    const custodian: Pubkey = .{5} ** 32;

    var metas: [4]AccountMeta = undefined;
    var data: AuthorizeWithSeedData = undefined;
    const ix = try authorizeWithSeed(
        &stake,
        &authority_base,
        "seed",
        &authority_owner,
        &next,
        .withdrawer,
        &custodian,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[3].is_signer);
    try std.testing.expectEqual(@as(u32, 8), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &next, ix.data[4..36]);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, ix.data[36..40], .little));
    try std.testing.expectEqual(@as(u64, 4), std.mem.readInt(u64, ix.data[40..48], .little));
    try std.testing.expectEqualSlices(u8, "seed", ix.data[48..52]);
    try std.testing.expectEqualSlices(u8, &authority_owner, ix.data[52..84]);

    var checked_metas: [5]AccountMeta = undefined;
    var checked_data: AuthorizeCheckedWithSeedData = undefined;
    const checked = try authorizeCheckedWithSeed(
        &stake,
        &authority_base,
        "seed",
        &authority_owner,
        &next,
        .staker,
        null,
        &checked_metas,
        &checked_data,
    );
    try std.testing.expectEqual(@as(usize, 4), checked.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), checked.accounts[3].is_signer);
    try std.testing.expectEqual(@as(u32, 11), std.mem.readInt(u32, checked.data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, checked.data[4..8], .little));
    try std.testing.expectEqual(@as(u64, 4), std.mem.readInt(u64, checked.data[8..16], .little));
    try std.testing.expectEqualSlices(u8, "seed", checked.data[16..20]);
    try std.testing.expectEqualSlices(u8, &authority_owner, checked.data[20..52]);
}

test "lockup builders encode optional bincode fields" {
    const stake: Pubkey = .{1} ** 32;
    const custodian: Pubkey = .{2} ** 32;
    const new_custodian: Pubkey = .{3} ** 32;
    var metas: [2]AccountMeta = undefined;
    var data: SetLockupData = undefined;

    const ix = try setLockup(&stake, .{
        .unix_timestamp = -5,
        .epoch = 9,
        .custodian = new_custodian,
    }, &custodian, &metas, &data);
    try std.testing.expectEqual(@as(usize, 2), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u32, 6), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u8, 1), ix.data[4]);
    try std.testing.expectEqual(@as(i64, -5), std.mem.readInt(i64, ix.data[5..13], .little));
    try std.testing.expectEqual(@as(u8, 1), ix.data[13]);
    try std.testing.expectEqual(@as(u64, 9), std.mem.readInt(u64, ix.data[14..22], .little));
    try std.testing.expectEqual(@as(u8, 1), ix.data[22]);
    try std.testing.expectEqualSlices(u8, &new_custodian, ix.data[23..55]);

    var checked_metas: [3]AccountMeta = undefined;
    var checked_data: SetLockupCheckedData = undefined;
    const checked = try setLockupChecked(&stake, .{
        .unix_timestamp = -5,
        .epoch = null,
        .new_custodian = &new_custodian,
    }, &custodian, &checked_metas, &checked_data);
    try std.testing.expectEqual(@as(usize, 3), checked.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), checked.accounts[2].is_signer);
    try std.testing.expectEqual(@as(u32, 12), std.mem.readInt(u32, checked.data[0..4], .little));
    try std.testing.expectEqual(@as(u8, 1), checked.data[4]);
    try std.testing.expectEqual(@as(i64, -5), std.mem.readInt(i64, checked.data[5..13], .little));
    try std.testing.expectEqual(@as(u8, 0), checked.data[13]);
}

test "delegate withdraw merge and move builders encode canonical metas" {
    const stake: Pubkey = .{1} ** 32;
    const other_stake: Pubkey = .{2} ** 32;
    const authority: Pubkey = .{3} ** 32;
    const vote: Pubkey = .{4} ** 32;
    const to: Pubkey = .{5} ** 32;

    var delegate_metas: [6]AccountMeta = undefined;
    var delegate_data: DiscriminantOnlyData = undefined;
    const delegate_ix = delegateStake(&stake, &authority, &vote, &delegate_metas, &delegate_data);
    try std.testing.expectEqualSlices(u8, &.{ 2, 0, 0, 0 }, delegate_ix.data);
    try std.testing.expectEqualSlices(u8, &CONFIG_ID, delegate_ix.accounts[4].pubkey);
    try std.testing.expectEqual(@as(u8, 1), delegate_ix.accounts[5].is_signer);

    var withdraw_metas: [6]AccountMeta = undefined;
    var withdraw_data: U64Data = undefined;
    const withdraw_ix = withdraw(&stake, &to, &authority, 500, null, &withdraw_metas, &withdraw_data);
    try std.testing.expectEqual(@as(usize, 5), withdraw_ix.accounts.len);
    try std.testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, withdraw_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, withdraw_ix.data[4..12], .little));

    var merge_metas: [5]AccountMeta = undefined;
    var merge_data: DiscriminantOnlyData = undefined;
    const merge_ix = merge(&stake, &other_stake, &authority, &merge_metas, &merge_data);
    try std.testing.expectEqualSlices(u8, &.{ 7, 0, 0, 0 }, merge_ix.data);
    try std.testing.expectEqualSlices(u8, &STAKE_HISTORY_ID, merge_ix.accounts[3].pubkey);

    var move_metas: [3]AccountMeta = undefined;
    var move_data: U64Data = undefined;
    const move_ix = moveStake(&stake, &other_stake, &authority, 9, &move_metas, &move_data);
    try std.testing.expectEqual(@as(u32, 16), std.mem.readInt(u32, move_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 9), std.mem.readInt(u64, move_ix.data[4..12], .little));
}

test "remaining discriminant-only builders encode expected variants" {
    const stake: Pubkey = .{1} ** 32;
    const authority: Pubkey = .{2} ** 32;
    const vote_a: Pubkey = .{3} ** 32;
    const vote_b: Pubkey = .{4} ** 32;

    var deactivate_metas: [3]AccountMeta = undefined;
    var deactivate_data: DiscriminantOnlyData = undefined;
    const deactivate_ix = deactivateStake(&stake, &authority, &deactivate_metas, &deactivate_data);
    try std.testing.expectEqualSlices(u8, &.{ 5, 0, 0, 0 }, deactivate_ix.data);
    try std.testing.expectEqual(@as(u8, 1), deactivate_ix.accounts[2].is_signer);

    var delinquent_metas: [3]AccountMeta = undefined;
    var delinquent_data: DiscriminantOnlyData = undefined;
    const delinquent_ix = deactivateDelinquentStake(&stake, &vote_a, &vote_b, &delinquent_metas, &delinquent_data);
    try std.testing.expectEqualSlices(u8, &.{ 14, 0, 0, 0 }, delinquent_ix.data);
    try std.testing.expectEqual(@as(u8, 0), delinquent_ix.accounts[1].is_signer);

    var minimum_data: DiscriminantOnlyData = undefined;
    const minimum_ix = getMinimumDelegation(&minimum_data);
    try std.testing.expectEqual(@as(usize, 0), minimum_ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &.{ 13, 0, 0, 0 }, minimum_ix.data);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "initialize"));
    try std.testing.expect(@hasDecl(@This(), "authorizeWithSeed"));
    try std.testing.expect(@hasDecl(@This(), "setLockupChecked"));
    try std.testing.expect(@hasDecl(@This(), "delegateStake"));
    try std.testing.expect(@hasDecl(@This(), "withdraw"));
    try std.testing.expect(@hasDecl(@This(), "getMinimumDelegation"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
