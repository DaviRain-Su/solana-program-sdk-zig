//! `solana_vote` — Vote Program instruction builders.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("Vote111111111111111111111111111111111111111");
pub const CLOCK_ID: Pubkey = sol.pubkey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");
pub const RENT_ID: Pubkey = sol.rent_id;
pub const MAX_SEED_LEN: usize = sol.pda.MAX_SEED_LEN;

pub const Error = error{
    BufferTooSmall,
    SeedTooLong,
};

pub const VoteAuthorize = enum(u32) {
    voter = 0,
    withdrawer = 1,
};

pub const VoteInit = struct {
    node_pubkey: Pubkey,
    authorized_voter: Pubkey,
    authorized_withdrawer: Pubkey,
    commission: u8,
};

pub const VoteInstruction = enum(u32) {
    initialize_account = 0,
    authorize = 1,
    vote = 2,
    withdraw = 3,
    update_validator_identity = 4,
    update_commission = 5,
    vote_switch = 6,
    authorize_checked = 7,
    update_vote_state = 8,
    update_vote_state_switch = 9,
    authorize_with_seed = 10,
    authorize_checked_with_seed = 11,
    compact_update_vote_state = 12,
    compact_update_vote_state_switch = 13,
    tower_sync = 14,
    tower_sync_switch = 15,
};

pub const INITIALIZE_ACCOUNT_DATA_LEN: usize = 4 + 32 + 32 + 32 + 1;
pub const AUTHORIZE_DATA_LEN: usize = 4 + 32 + 4;
pub const AUTHORIZE_CHECKED_DATA_LEN: usize = 4 + 4;
pub const WITHDRAW_DATA_LEN: usize = 4 + 8;
pub const UPDATE_COMMISSION_DATA_LEN: usize = 4 + 1;
pub const DISCRIMINANT_ONLY_DATA_LEN: usize = 4;
pub const AUTHORIZE_WITH_SEED_DATA_CAPACITY: usize = 4 + 4 + 32 + 8 + MAX_SEED_LEN + 32;
pub const AUTHORIZE_CHECKED_WITH_SEED_DATA_CAPACITY: usize = 4 + 4 + 32 + 8 + MAX_SEED_LEN;

pub const InitializeAccountData = [INITIALIZE_ACCOUNT_DATA_LEN]u8;
pub const AuthorizeData = [AUTHORIZE_DATA_LEN]u8;
pub const AuthorizeCheckedData = [AUTHORIZE_CHECKED_DATA_LEN]u8;
pub const WithdrawData = [WITHDRAW_DATA_LEN]u8;
pub const UpdateCommissionData = [UPDATE_COMMISSION_DATA_LEN]u8;
pub const DiscriminantOnlyData = [DISCRIMINANT_ONLY_DATA_LEN]u8;
pub const AuthorizeWithSeedData = [AUTHORIZE_WITH_SEED_DATA_CAPACITY]u8;
pub const AuthorizeCheckedWithSeedData = [AUTHORIZE_CHECKED_WITH_SEED_DATA_CAPACITY]u8;

pub fn initializeAccount(
    vote_account: *const Pubkey,
    vote_init: VoteInit,
    metas: *[4]AccountMeta,
    data: *InitializeAccountData,
) Instruction {
    writeInitializeAccountData(vote_init, data);
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.readonly(&RENT_ID);
    metas[2] = AccountMeta.readonly(&CLOCK_ID);
    metas[3] = AccountMeta.signer(&vote_init.node_pubkey);
    return instruction(metas[0..], data);
}

pub fn authorize(
    vote_account: *const Pubkey,
    authorized: *const Pubkey,
    new_authorized: *const Pubkey,
    vote_authorize: VoteAuthorize,
    metas: *[3]AccountMeta,
    data: *AuthorizeData,
) Instruction {
    writeAuthorizeData(new_authorized, vote_authorize, data);
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.readonly(&CLOCK_ID);
    metas[2] = AccountMeta.signer(authorized);
    return instruction(metas[0..], data);
}

pub fn authorizeChecked(
    vote_account: *const Pubkey,
    authorized: *const Pubkey,
    new_authorized: *const Pubkey,
    vote_authorize: VoteAuthorize,
    metas: *[4]AccountMeta,
    data: *AuthorizeCheckedData,
) Instruction {
    writeAuthorizeCheckedData(vote_authorize, data);
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.readonly(&CLOCK_ID);
    metas[2] = AccountMeta.signer(authorized);
    metas[3] = AccountMeta.signer(new_authorized);
    return instruction(metas[0..], data);
}

pub fn authorizeWithSeed(
    vote_account: *const Pubkey,
    current_authority_base: *const Pubkey,
    current_authority_owner: *const Pubkey,
    current_authority_seed: []const u8,
    new_authority: *const Pubkey,
    vote_authorize: VoteAuthorize,
    metas: *[3]AccountMeta,
    data: *AuthorizeWithSeedData,
) Error!Instruction {
    const written = try writeAuthorizeWithSeedData(
        vote_authorize,
        current_authority_owner,
        current_authority_seed,
        new_authority,
        data[0..],
    );
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.readonly(&CLOCK_ID);
    metas[2] = AccountMeta.signer(current_authority_base);
    return instruction(metas[0..], data[0..written]);
}

pub fn authorizeCheckedWithSeed(
    vote_account: *const Pubkey,
    current_authority_base: *const Pubkey,
    current_authority_owner: *const Pubkey,
    current_authority_seed: []const u8,
    new_authority: *const Pubkey,
    vote_authorize: VoteAuthorize,
    metas: *[4]AccountMeta,
    data: *AuthorizeCheckedWithSeedData,
) Error!Instruction {
    const written = try writeAuthorizeCheckedWithSeedData(
        vote_authorize,
        current_authority_owner,
        current_authority_seed,
        data[0..],
    );
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.readonly(&CLOCK_ID);
    metas[2] = AccountMeta.signer(current_authority_base);
    metas[3] = AccountMeta.signer(new_authority);
    return instruction(metas[0..], data[0..written]);
}

pub fn updateValidatorIdentity(
    vote_account: *const Pubkey,
    authorized_withdrawer: *const Pubkey,
    node_pubkey: *const Pubkey,
    metas: *[3]AccountMeta,
    data: *DiscriminantOnlyData,
) Instruction {
    writeDiscriminant(.update_validator_identity, data);
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.signer(node_pubkey);
    metas[2] = AccountMeta.signer(authorized_withdrawer);
    return instruction(metas[0..], data);
}

pub fn updateCommission(
    vote_account: *const Pubkey,
    authorized_withdrawer: *const Pubkey,
    commission: u8,
    metas: *[2]AccountMeta,
    data: *UpdateCommissionData,
) Instruction {
    writeDiscriminant(.update_commission, data[0..4]);
    data[4] = commission;
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.signer(authorized_withdrawer);
    return instruction(metas[0..], data);
}

pub fn withdraw(
    vote_account: *const Pubkey,
    to: *const Pubkey,
    authorized_withdrawer: *const Pubkey,
    lamports: u64,
    metas: *[3]AccountMeta,
    data: *WithdrawData,
) Instruction {
    writeDiscriminant(.withdraw, data[0..4]);
    std.mem.writeInt(u64, data[4..12], lamports, .little);
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.writable(to);
    metas[2] = AccountMeta.signer(authorized_withdrawer);
    return instruction(metas[0..], data);
}

fn instruction(accounts: []const AccountMeta, data: []const u8) Instruction {
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = accounts,
        .data = data,
    };
}

fn writeInitializeAccountData(vote_init: VoteInit, data: *InitializeAccountData) void {
    writeDiscriminant(.initialize_account, data[0..4]);
    @memcpy(data[4..36], &vote_init.node_pubkey);
    @memcpy(data[36..68], &vote_init.authorized_voter);
    @memcpy(data[68..100], &vote_init.authorized_withdrawer);
    data[100] = vote_init.commission;
}

fn writeAuthorizeData(
    new_authorized: *const Pubkey,
    vote_authorize: VoteAuthorize,
    data: *AuthorizeData,
) void {
    writeDiscriminant(.authorize, data[0..4]);
    @memcpy(data[4..36], new_authorized);
    std.mem.writeInt(u32, data[36..40], @intFromEnum(vote_authorize), .little);
}

fn writeAuthorizeCheckedData(vote_authorize: VoteAuthorize, data: *AuthorizeCheckedData) void {
    writeDiscriminant(.authorize_checked, data[0..4]);
    std.mem.writeInt(u32, data[4..8], @intFromEnum(vote_authorize), .little);
}

fn writeAuthorizeWithSeedData(
    vote_authorize: VoteAuthorize,
    current_authority_owner: *const Pubkey,
    current_authority_seed: []const u8,
    new_authority: *const Pubkey,
    data: []u8,
) Error!usize {
    if (current_authority_seed.len > MAX_SEED_LEN) return error.SeedTooLong;
    if (data.len < 4 + 4 + 32 + 8 + current_authority_seed.len + 32) return error.BufferTooSmall;
    writeDiscriminant(.authorize_with_seed, data[0..4]);
    std.mem.writeInt(u32, data[4..8], @intFromEnum(vote_authorize), .little);
    @memcpy(data[8..40], current_authority_owner);
    var cursor: usize = 40;
    cursor += try writeBincodeString(data[cursor..], current_authority_seed);
    @memcpy(data[cursor .. cursor + 32], new_authority);
    return cursor + 32;
}

fn writeAuthorizeCheckedWithSeedData(
    vote_authorize: VoteAuthorize,
    current_authority_owner: *const Pubkey,
    current_authority_seed: []const u8,
    data: []u8,
) Error!usize {
    if (current_authority_seed.len > MAX_SEED_LEN) return error.SeedTooLong;
    if (data.len < 4 + 4 + 32 + 8 + current_authority_seed.len) return error.BufferTooSmall;
    writeDiscriminant(.authorize_checked_with_seed, data[0..4]);
    std.mem.writeInt(u32, data[4..8], @intFromEnum(vote_authorize), .little);
    @memcpy(data[8..40], current_authority_owner);
    var cursor: usize = 40;
    cursor += try writeBincodeString(data[cursor..], current_authority_seed);
    return cursor;
}

fn writeBincodeString(data: []u8, value: []const u8) Error!usize {
    if (data.len < 8 + value.len) return error.BufferTooSmall;
    std.mem.writeInt(u64, data[0..8], @intCast(value.len), .little);
    @memcpy(data[8 .. 8 + value.len], value);
    return 8 + value.len;
}

fn writeDiscriminant(tag: VoteInstruction, data: []u8) void {
    std.debug.assert(data.len >= 4);
    std.mem.writeInt(u32, data[0..4], @intFromEnum(tag), .little);
}

test "initializeAccount encodes VoteInit and canonical accounts" {
    const vote_account: Pubkey = .{1} ** 32;
    const vote_init: VoteInit = .{
        .node_pubkey = .{2} ** 32,
        .authorized_voter = .{3} ** 32,
        .authorized_withdrawer = .{4} ** 32,
        .commission = 7,
    };
    var metas: [4]AccountMeta = undefined;
    var data: InitializeAccountData = undefined;

    const ix = initializeAccount(&vote_account, vote_init, &metas, &data);
    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, ix.program_id);
    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[0].is_writable);
    try std.testing.expectEqualSlices(u8, &RENT_ID, ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &CLOCK_ID, ix.accounts[2].pubkey);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[3].is_signer);
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &vote_init.node_pubkey, ix.data[4..36]);
    try std.testing.expectEqualSlices(u8, &vote_init.authorized_voter, ix.data[36..68]);
    try std.testing.expectEqualSlices(u8, &vote_init.authorized_withdrawer, ix.data[68..100]);
    try std.testing.expectEqual(@as(u8, 7), ix.data[100]);
}

test "authorize builders encode authority type and signer metas" {
    const vote_account: Pubkey = .{1} ** 32;
    const current: Pubkey = .{2} ** 32;
    const next: Pubkey = .{3} ** 32;
    var authorize_metas: [3]AccountMeta = undefined;
    var authorize_data: AuthorizeData = undefined;
    const authorize_ix = authorize(&vote_account, &current, &next, .withdrawer, &authorize_metas, &authorize_data);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, authorize_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &next, authorize_ix.data[4..36]);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, authorize_ix.data[36..40], .little));
    try std.testing.expectEqual(@as(u8, 1), authorize_ix.accounts[2].is_signer);

    var checked_metas: [4]AccountMeta = undefined;
    var checked_data: AuthorizeCheckedData = undefined;
    const checked_ix = authorizeChecked(&vote_account, &current, &next, .voter, &checked_metas, &checked_data);
    try std.testing.expectEqualSlices(u8, &.{ 7, 0, 0, 0, 0, 0, 0, 0 }, checked_ix.data);
    try std.testing.expectEqual(@as(u8, 1), checked_ix.accounts[3].is_signer);
}

test "seeded authorize builders encode seed string owner and signer metas" {
    const vote_account: Pubkey = .{1} ** 32;
    const base: Pubkey = .{2} ** 32;
    const owner: Pubkey = .{3} ** 32;
    const next: Pubkey = .{4} ** 32;

    var metas: [3]AccountMeta = undefined;
    var data: AuthorizeWithSeedData = undefined;
    const ix = try authorizeWithSeed(
        &vote_account,
        &base,
        &owner,
        "seed",
        &next,
        .withdrawer,
        &metas,
        &data,
    );
    try std.testing.expectEqual(@as(usize, 3), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[2].is_signer);
    try std.testing.expectEqual(@as(u32, 10), std.mem.readInt(u32, ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, ix.data[4..8], .little));
    try std.testing.expectEqualSlices(u8, &owner, ix.data[8..40]);
    try std.testing.expectEqual(@as(u64, 4), std.mem.readInt(u64, ix.data[40..48], .little));
    try std.testing.expectEqualSlices(u8, "seed", ix.data[48..52]);
    try std.testing.expectEqualSlices(u8, &next, ix.data[52..84]);

    var checked_metas: [4]AccountMeta = undefined;
    var checked_data: AuthorizeCheckedWithSeedData = undefined;
    const checked = try authorizeCheckedWithSeed(
        &vote_account,
        &base,
        &owner,
        "seed",
        &next,
        .voter,
        &checked_metas,
        &checked_data,
    );
    try std.testing.expectEqual(@as(usize, 4), checked.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), checked.accounts[2].is_signer);
    try std.testing.expectEqual(@as(u8, 1), checked.accounts[3].is_signer);
    try std.testing.expectEqual(@as(u32, 11), std.mem.readInt(u32, checked.data[0..4], .little));
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, checked.data[4..8], .little));
    try std.testing.expectEqualSlices(u8, &owner, checked.data[8..40]);
    try std.testing.expectEqual(@as(u64, 4), std.mem.readInt(u64, checked.data[40..48], .little));
    try std.testing.expectEqualSlices(u8, "seed", checked.data[48..52]);
}

test "account management builders encode canonical discriminants and metas" {
    const vote_account: Pubkey = .{1} ** 32;
    const withdrawer: Pubkey = .{2} ** 32;
    const node: Pubkey = .{3} ** 32;
    const to: Pubkey = .{4} ** 32;

    var identity_metas: [3]AccountMeta = undefined;
    var identity_data: DiscriminantOnlyData = undefined;
    const identity_ix = updateValidatorIdentity(&vote_account, &withdrawer, &node, &identity_metas, &identity_data);
    try std.testing.expectEqualSlices(u8, &.{ 4, 0, 0, 0 }, identity_ix.data);
    try std.testing.expectEqual(@as(u8, 1), identity_ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), identity_ix.accounts[2].is_signer);

    var commission_metas: [2]AccountMeta = undefined;
    var commission_data: UpdateCommissionData = undefined;
    const commission_ix = updateCommission(&vote_account, &withdrawer, 9, &commission_metas, &commission_data);
    try std.testing.expectEqualSlices(u8, &.{ 5, 0, 0, 0, 9 }, commission_ix.data);
    try std.testing.expectEqual(@as(u8, 1), commission_ix.accounts[1].is_signer);

    var withdraw_metas: [3]AccountMeta = undefined;
    var withdraw_data: WithdrawData = undefined;
    const withdraw_ix = withdraw(&vote_account, &to, &withdrawer, 500, &withdraw_metas, &withdraw_data);
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, withdraw_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, withdraw_ix.data[4..12], .little));
    try std.testing.expectEqual(@as(u8, 1), withdraw_ix.accounts[1].is_writable);
    try std.testing.expectEqual(@as(u8, 1), withdraw_ix.accounts[2].is_signer);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "initializeAccount"));
    try std.testing.expect(@hasDecl(@This(), "authorize"));
    try std.testing.expect(@hasDecl(@This(), "authorizeChecked"));
    try std.testing.expect(@hasDecl(@This(), "authorizeWithSeed"));
    try std.testing.expect(@hasDecl(@This(), "authorizeCheckedWithSeed"));
    try std.testing.expect(@hasDecl(@This(), "withdraw"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
