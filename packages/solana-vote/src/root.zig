//! `solana_vote` — Vote Program instruction builders.

const std = @import("std");
const sol = @import("solana_program_sdk");
const codec = @import("solana_codec");

pub const Pubkey = sol.Pubkey;
pub const Hash = [32]u8;
pub const Slot = u64;
pub const UnixTimestamp = i64;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("Vote111111111111111111111111111111111111111");
pub const CLOCK_ID: Pubkey = sol.pubkey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");
pub const SLOT_HASHES_ID: Pubkey = sol.slot_hashes_id;
pub const RENT_ID: Pubkey = sol.rent_id;
pub const MAX_SEED_LEN: usize = sol.pda.MAX_SEED_LEN;

pub const Error = codec.Error || error{
    BufferTooSmall,
    SeedTooLong,
    InvalidVoteLockout,
    ConfirmationCountTooLarge,
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

pub const Vote = struct {
    slots: []const Slot,
    hash: Hash,
    timestamp: ?UnixTimestamp = null,
};

pub const Lockout = struct {
    slot: Slot,
    confirmation_count: u32,
};

pub const VoteStateUpdate = struct {
    lockouts: []const Lockout,
    root: ?Slot = null,
    hash: Hash,
    timestamp: ?UnixTimestamp = null,
};

pub const TowerSync = struct {
    lockouts: []const Lockout,
    root: ?Slot = null,
    hash: Hash,
    timestamp: ?UnixTimestamp = null,
    block_id: Hash,
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

pub fn voteRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_payload: []const u8,
    metas: *[4]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadData(.vote, vote_payload, data);
    setVoteSubmitMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn vote(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_payload: Vote,
    metas: *[4]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeVoteInstructionData(.vote, vote_payload, data);
    setVoteSubmitMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn voteSwitch(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_payload: Vote,
    proof_hash: *const Hash,
    metas: *[4]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeVoteInstructionWithHashData(.vote_switch, vote_payload, proof_hash, data);
    setVoteSubmitMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn voteSwitchRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_payload: []const u8,
    proof_hash: *const Hash,
    metas: *[4]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadWithHashData(.vote_switch, vote_payload, proof_hash, data);
    setVoteSubmitMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn updateVoteStateRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_state_update_payload: []const u8,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadData(.update_vote_state, vote_state_update_payload, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn updateVoteState(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_state_update: VoteStateUpdate,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeVoteStateUpdateInstructionData(.update_vote_state, vote_state_update, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn updateVoteStateSwitch(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_state_update: VoteStateUpdate,
    proof_hash: *const Hash,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeVoteStateUpdateInstructionWithHashData(.update_vote_state_switch, vote_state_update, proof_hash, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn updateVoteStateSwitchRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_state_update_payload: []const u8,
    proof_hash: *const Hash,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadWithHashData(.update_vote_state_switch, vote_state_update_payload, proof_hash, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn compactUpdateVoteStateRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    compact_vote_state_update_payload: []const u8,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadData(.compact_update_vote_state, compact_vote_state_update_payload, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn compactUpdateVoteState(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_state_update: VoteStateUpdate,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeCompactVoteStateUpdateInstructionData(.compact_update_vote_state, vote_state_update, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn compactUpdateVoteStateSwitch(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    vote_state_update: VoteStateUpdate,
    proof_hash: *const Hash,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeCompactVoteStateUpdateInstructionWithHashData(.compact_update_vote_state_switch, vote_state_update, proof_hash, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn compactUpdateVoteStateSwitchRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    compact_vote_state_update_payload: []const u8,
    proof_hash: *const Hash,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadWithHashData(.compact_update_vote_state_switch, compact_vote_state_update_payload, proof_hash, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn towerSyncRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    tower_sync_payload: []const u8,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadData(.tower_sync, tower_sync_payload, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn towerSync(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    tower_sync: TowerSync,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeTowerSyncInstructionData(.tower_sync, tower_sync, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn towerSyncSwitch(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    tower_sync: TowerSync,
    proof_hash: *const Hash,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writeTowerSyncInstructionWithHashData(.tower_sync_switch, tower_sync, proof_hash, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

pub fn towerSyncSwitchRaw(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    tower_sync_payload: []const u8,
    proof_hash: *const Hash,
    metas: *[2]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written = try writePayloadWithHashData(.tower_sync_switch, tower_sync_payload, proof_hash, data);
    setVoteStateUpdateMetas(vote_account, authorized_voter, metas);
    return instruction(metas[0..], data[0..written]);
}

fn instruction(accounts: []const AccountMeta, data: []const u8) Instruction {
    return .{
        .program_id = &PROGRAM_ID,
        .accounts = accounts,
        .data = data,
    };
}

fn setVoteSubmitMetas(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    metas: *[4]AccountMeta,
) void {
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.readonly(&SLOT_HASHES_ID);
    metas[2] = AccountMeta.readonly(&CLOCK_ID);
    metas[3] = AccountMeta.signer(authorized_voter);
}

fn setVoteStateUpdateMetas(
    vote_account: *const Pubkey,
    authorized_voter: *const Pubkey,
    metas: *[2]AccountMeta,
) void {
    metas[0] = AccountMeta.writable(vote_account);
    metas[1] = AccountMeta.signer(authorized_voter);
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
    cursor += try codec.writeBincodeString(data[cursor..], current_authority_seed);
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
    cursor += try codec.writeBincodeString(data[cursor..], current_authority_seed);
    return cursor;
}

fn writePayloadData(tag: VoteInstruction, payload: []const u8, data: []u8) Error!usize {
    if (data.len < 4 + payload.len) return error.BufferTooSmall;
    writeDiscriminant(tag, data[0..4]);
    @memcpy(data[4..][0..payload.len], payload);
    return 4 + payload.len;
}

fn writePayloadWithHashData(
    tag: VoteInstruction,
    payload: []const u8,
    proof_hash: *const Hash,
    data: []u8,
) Error!usize {
    const payload_end = try writePayloadData(tag, payload, data);
    if (data.len < payload_end + proof_hash.len) return error.BufferTooSmall;
    @memcpy(data[payload_end..][0..proof_hash.len], proof_hash);
    return payload_end + proof_hash.len;
}

pub fn writeVotePayload(vote_payload: Vote, data: []u8) Error!usize {
    var cursor: usize = 0;
    cursor += try codec.writeBincodeLen(data[cursor..], vote_payload.slots.len);
    for (vote_payload.slots) |slot| {
        cursor += try codec.writeBincodeU64(data[cursor..], slot);
    }
    cursor += try writeHash(data[cursor..], &vote_payload.hash);
    cursor += try codec.writeBincodeOptionI64(data[cursor..], vote_payload.timestamp);
    return cursor;
}

pub fn writeVoteStateUpdatePayload(vote_state_update: VoteStateUpdate, data: []u8) Error!usize {
    var cursor = try writeLockouts(vote_state_update.lockouts, data);
    cursor += try codec.writeBincodeOptionU64(data[cursor..], vote_state_update.root);
    cursor += try writeHash(data[cursor..], &vote_state_update.hash);
    cursor += try codec.writeBincodeOptionI64(data[cursor..], vote_state_update.timestamp);
    return cursor;
}

pub fn writeCompactVoteStateUpdatePayload(vote_state_update: VoteStateUpdate, data: []u8) Error!usize {
    var cursor: usize = 0;
    cursor += try codec.writeBincodeU64(data[cursor..], vote_state_update.root orelse std.math.maxInt(Slot));
    cursor += try writeCompactLockoutOffsets(vote_state_update.lockouts, vote_state_update.root, data[cursor..]);
    cursor += try writeHash(data[cursor..], &vote_state_update.hash);
    cursor += try codec.writeBincodeOptionI64(data[cursor..], vote_state_update.timestamp);
    return cursor;
}

pub fn writeTowerSyncPayload(tower_sync: TowerSync, data: []u8) Error!usize {
    var cursor: usize = 0;
    cursor += try codec.writeBincodeU64(data[cursor..], tower_sync.root orelse std.math.maxInt(Slot));
    cursor += try writeCompactLockoutOffsets(tower_sync.lockouts, tower_sync.root, data[cursor..]);
    cursor += try writeHash(data[cursor..], &tower_sync.hash);
    cursor += try codec.writeBincodeOptionI64(data[cursor..], tower_sync.timestamp);
    cursor += try writeHash(data[cursor..], &tower_sync.block_id);
    return cursor;
}

fn writeVoteInstructionData(tag: VoteInstruction, vote_payload: Vote, data: []u8) Error!usize {
    if (data.len < 4) return error.BufferTooSmall;
    writeDiscriminant(tag, data[0..4]);
    return 4 + try writeVotePayload(vote_payload, data[4..]);
}

fn writeVoteInstructionWithHashData(
    tag: VoteInstruction,
    vote_payload: Vote,
    proof_hash: *const Hash,
    data: []u8,
) Error!usize {
    const payload_end = try writeVoteInstructionData(tag, vote_payload, data);
    if (data.len < payload_end + proof_hash.len) return error.BufferTooSmall;
    @memcpy(data[payload_end..][0..proof_hash.len], proof_hash);
    return payload_end + proof_hash.len;
}

fn writeVoteStateUpdateInstructionData(
    tag: VoteInstruction,
    vote_state_update: VoteStateUpdate,
    data: []u8,
) Error!usize {
    if (data.len < 4) return error.BufferTooSmall;
    writeDiscriminant(tag, data[0..4]);
    return 4 + try writeVoteStateUpdatePayload(vote_state_update, data[4..]);
}

fn writeVoteStateUpdateInstructionWithHashData(
    tag: VoteInstruction,
    vote_state_update: VoteStateUpdate,
    proof_hash: *const Hash,
    data: []u8,
) Error!usize {
    const payload_end = try writeVoteStateUpdateInstructionData(tag, vote_state_update, data);
    if (data.len < payload_end + proof_hash.len) return error.BufferTooSmall;
    @memcpy(data[payload_end..][0..proof_hash.len], proof_hash);
    return payload_end + proof_hash.len;
}

fn writeCompactVoteStateUpdateInstructionData(
    tag: VoteInstruction,
    vote_state_update: VoteStateUpdate,
    data: []u8,
) Error!usize {
    if (data.len < 4) return error.BufferTooSmall;
    writeDiscriminant(tag, data[0..4]);
    return 4 + try writeCompactVoteStateUpdatePayload(vote_state_update, data[4..]);
}

fn writeCompactVoteStateUpdateInstructionWithHashData(
    tag: VoteInstruction,
    vote_state_update: VoteStateUpdate,
    proof_hash: *const Hash,
    data: []u8,
) Error!usize {
    const payload_end = try writeCompactVoteStateUpdateInstructionData(tag, vote_state_update, data);
    if (data.len < payload_end + proof_hash.len) return error.BufferTooSmall;
    @memcpy(data[payload_end..][0..proof_hash.len], proof_hash);
    return payload_end + proof_hash.len;
}

fn writeTowerSyncInstructionData(tag: VoteInstruction, tower_sync: TowerSync, data: []u8) Error!usize {
    if (data.len < 4) return error.BufferTooSmall;
    writeDiscriminant(tag, data[0..4]);
    return 4 + try writeTowerSyncPayload(tower_sync, data[4..]);
}

fn writeTowerSyncInstructionWithHashData(
    tag: VoteInstruction,
    tower_sync: TowerSync,
    proof_hash: *const Hash,
    data: []u8,
) Error!usize {
    const payload_end = try writeTowerSyncInstructionData(tag, tower_sync, data);
    if (data.len < payload_end + proof_hash.len) return error.BufferTooSmall;
    @memcpy(data[payload_end..][0..proof_hash.len], proof_hash);
    return payload_end + proof_hash.len;
}

fn writeLockouts(lockouts: []const Lockout, data: []u8) Error!usize {
    var cursor: usize = 0;
    cursor += try codec.writeBincodeLen(data[cursor..], lockouts.len);
    for (lockouts) |lockout| {
        cursor += try codec.writeBincodeU64(data[cursor..], lockout.slot);
        cursor += try codec.writeBincodeU32(data[cursor..], lockout.confirmation_count);
    }
    return cursor;
}

fn writeCompactLockoutOffsets(lockouts: []const Lockout, root: ?Slot, data: []u8) Error!usize {
    var cursor: usize = 0;
    cursor += try codec.writeShortVec(lockouts.len, data[cursor..]);

    var previous_slot: Slot = root orelse 0;
    for (lockouts) |lockout| {
        if (lockout.slot < previous_slot) return error.InvalidVoteLockout;
        if (lockout.confirmation_count > std.math.maxInt(u8)) return error.ConfirmationCountTooLarge;

        cursor += try codec.writeVarintU64(data[cursor..], lockout.slot - previous_slot);
        if (data.len < cursor + 1) return error.BufferTooSmall;
        data[cursor] = @intCast(lockout.confirmation_count);
        cursor += 1;
        previous_slot = lockout.slot;
    }
    return cursor;
}

fn writeHash(data: []u8, hash: *const Hash) Error!usize {
    if (data.len < hash.len) return error.BufferTooSmall;
    @memcpy(data[0..hash.len], hash);
    return hash.len;
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

test "runtime vote raw builders encode discriminants payloads and canonical metas" {
    const vote_account: Pubkey = .{1} ** 32;
    const voter: Pubkey = .{2} ** 32;
    const payload = [_]u8{ 0xaa, 0xbb, 0xcc };
    const proof_hash: Hash = .{9} ** 32;
    var metas: [4]AccountMeta = undefined;
    var data: [64]u8 = undefined;

    const vote_ix = try voteRaw(&vote_account, &voter, &payload, &metas, &data);
    try std.testing.expectEqual(@as(usize, 4), vote_ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &vote_account, vote_ix.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u8, 1), vote_ix.accounts[0].is_writable);
    try std.testing.expectEqualSlices(u8, &SLOT_HASHES_ID, vote_ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &CLOCK_ID, vote_ix.accounts[2].pubkey);
    try std.testing.expectEqualSlices(u8, &voter, vote_ix.accounts[3].pubkey);
    try std.testing.expectEqual(@as(u8, 1), vote_ix.accounts[3].is_signer);
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, vote_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &payload, vote_ix.data[4..7]);

    const switch_ix = try voteSwitchRaw(&vote_account, &voter, &payload, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 6), std.mem.readInt(u32, switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &payload, switch_ix.data[4..7]);
    try std.testing.expectEqualSlices(u8, &proof_hash, switch_ix.data[7..39]);
    try std.testing.expectError(error.BufferTooSmall, voteSwitchRaw(&vote_account, &voter, &payload, &proof_hash, &metas, data[0..38]));
}

test "typed vote builders encode bincode Vote payloads" {
    const vote_account: Pubkey = .{1} ** 32;
    const voter: Pubkey = .{2} ** 32;
    const slots = [_]Slot{ 10, 11 };
    const hash: Hash = .{9} ** 32;
    const proof_hash: Hash = .{7} ** 32;
    const vote_payload: Vote = .{ .slots = &slots, .hash = hash, .timestamp = -5 };
    var metas: [4]AccountMeta = undefined;
    var data: [128]u8 = undefined;

    const vote_ix = try vote(&vote_account, &voter, vote_payload, &metas, &data);
    try std.testing.expectEqual(@as(usize, 69), vote_ix.data.len);
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, vote_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 2), std.mem.readInt(u64, vote_ix.data[4..12], .little));
    try std.testing.expectEqual(@as(u64, 10), std.mem.readInt(u64, vote_ix.data[12..20], .little));
    try std.testing.expectEqual(@as(u64, 11), std.mem.readInt(u64, vote_ix.data[20..28], .little));
    try std.testing.expectEqualSlices(u8, &hash, vote_ix.data[28..60]);
    try std.testing.expectEqual(@as(u8, 1), vote_ix.data[60]);
    try std.testing.expectEqual(@as(i64, -5), std.mem.readInt(i64, vote_ix.data[61..69], .little));
    try std.testing.expectEqualSlices(u8, &SLOT_HASHES_ID, vote_ix.accounts[1].pubkey);
    try std.testing.expectEqualSlices(u8, &CLOCK_ID, vote_ix.accounts[2].pubkey);

    const switch_ix = try voteSwitch(&vote_account, &voter, vote_payload, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 6), std.mem.readInt(u32, switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &proof_hash, switch_ix.data[69..101]);
    try std.testing.expectError(error.BufferTooSmall, vote(&vote_account, &voter, vote_payload, &metas, data[0..68]));
}

test "vote-state and tower raw builders encode discriminants and two-account metas" {
    const vote_account: Pubkey = .{1} ** 32;
    const voter: Pubkey = .{2} ** 32;
    const payload = [_]u8{ 0x11, 0x22 };
    const proof_hash: Hash = .{7} ** 32;
    var metas: [2]AccountMeta = undefined;
    var data: [64]u8 = undefined;

    const update_ix = try updateVoteStateRaw(&vote_account, &voter, &payload, &metas, &data);
    try std.testing.expectEqual(@as(usize, 2), update_ix.accounts.len);
    try std.testing.expectEqualSlices(u8, &vote_account, update_ix.accounts[0].pubkey);
    try std.testing.expectEqual(@as(u8, 1), update_ix.accounts[0].is_writable);
    try std.testing.expectEqualSlices(u8, &voter, update_ix.accounts[1].pubkey);
    try std.testing.expectEqual(@as(u8, 1), update_ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u32, 8), std.mem.readInt(u32, update_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &payload, update_ix.data[4..6]);

    const update_switch_ix = try updateVoteStateSwitchRaw(&vote_account, &voter, &payload, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 9), std.mem.readInt(u32, update_switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &proof_hash, update_switch_ix.data[6..38]);

    const compact_ix = try compactUpdateVoteStateRaw(&vote_account, &voter, &payload, &metas, &data);
    try std.testing.expectEqual(@as(u32, 12), std.mem.readInt(u32, compact_ix.data[0..4], .little));

    const compact_switch_ix = try compactUpdateVoteStateSwitchRaw(&vote_account, &voter, &payload, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 13), std.mem.readInt(u32, compact_switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &proof_hash, compact_switch_ix.data[6..38]);

    const tower_ix = try towerSyncRaw(&vote_account, &voter, &payload, &metas, &data);
    try std.testing.expectEqual(@as(u32, 14), std.mem.readInt(u32, tower_ix.data[0..4], .little));

    const tower_switch_ix = try towerSyncSwitchRaw(&vote_account, &voter, &payload, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 15), std.mem.readInt(u32, tower_switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &proof_hash, tower_switch_ix.data[6..38]);
}

test "typed vote-state builders encode bincode and compact payloads" {
    const vote_account: Pubkey = .{1} ** 32;
    const voter: Pubkey = .{2} ** 32;
    const hash: Hash = .{8} ** 32;
    const proof_hash: Hash = .{7} ** 32;
    const lockouts = [_]Lockout{
        .{ .slot = 100, .confirmation_count = 3 },
        .{ .slot = 105, .confirmation_count = 4 },
    };
    const update: VoteStateUpdate = .{ .lockouts = &lockouts, .root = 90, .hash = hash };
    var metas: [2]AccountMeta = undefined;
    var data: [128]u8 = undefined;

    const update_ix = try updateVoteState(&vote_account, &voter, update, &metas, &data);
    try std.testing.expectEqual(@as(usize, 78), update_ix.data.len);
    try std.testing.expectEqual(@as(u32, 8), std.mem.readInt(u32, update_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 2), std.mem.readInt(u64, update_ix.data[4..12], .little));
    try std.testing.expectEqual(@as(u64, 100), std.mem.readInt(u64, update_ix.data[12..20], .little));
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, update_ix.data[20..24], .little));
    try std.testing.expectEqual(@as(u64, 105), std.mem.readInt(u64, update_ix.data[24..32], .little));
    try std.testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, update_ix.data[32..36], .little));
    try std.testing.expectEqual(@as(u8, 1), update_ix.data[36]);
    try std.testing.expectEqual(@as(u64, 90), std.mem.readInt(u64, update_ix.data[37..45], .little));
    try std.testing.expectEqualSlices(u8, &hash, update_ix.data[45..77]);
    try std.testing.expectEqual(@as(u8, 0), update_ix.data[77]);

    const switch_ix = try updateVoteStateSwitch(&vote_account, &voter, update, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 9), std.mem.readInt(u32, switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &proof_hash, switch_ix.data[78..110]);

    const compact_ix = try compactUpdateVoteState(&vote_account, &voter, update, &metas, &data);
    try std.testing.expectEqual(@as(usize, 50), compact_ix.data.len);
    try std.testing.expectEqual(@as(u32, 12), std.mem.readInt(u32, compact_ix.data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 90), std.mem.readInt(u64, compact_ix.data[4..12], .little));
    try std.testing.expectEqualSlices(u8, &.{ 2, 10, 3, 5, 4 }, compact_ix.data[12..17]);
    try std.testing.expectEqualSlices(u8, &hash, compact_ix.data[17..49]);
    try std.testing.expectEqual(@as(u8, 0), compact_ix.data[49]);

    const compact_switch_ix = try compactUpdateVoteStateSwitch(&vote_account, &voter, update, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 13), std.mem.readInt(u32, compact_switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &proof_hash, compact_switch_ix.data[50..82]);

    const bad_order = [_]Lockout{.{ .slot = 80, .confirmation_count = 1 }};
    try std.testing.expectError(
        error.InvalidVoteLockout,
        writeCompactVoteStateUpdatePayload(.{ .lockouts = &bad_order, .root = 90, .hash = hash }, &data),
    );
    const bad_count = [_]Lockout{.{ .slot = 100, .confirmation_count = 256 }};
    try std.testing.expectError(
        error.ConfirmationCountTooLarge,
        writeCompactVoteStateUpdatePayload(.{ .lockouts = &bad_count, .hash = hash }, &data),
    );
}

test "typed tower-sync builders encode compact tower payloads" {
    const vote_account: Pubkey = .{1} ** 32;
    const voter: Pubkey = .{2} ** 32;
    const hash: Hash = .{8} ** 32;
    const block_id: Hash = .{6} ** 32;
    const proof_hash: Hash = .{7} ** 32;
    const lockouts = [_]Lockout{
        .{ .slot = 100, .confirmation_count = 3 },
        .{ .slot = 105, .confirmation_count = 4 },
    };
    const tower: TowerSync = .{
        .lockouts = &lockouts,
        .hash = hash,
        .timestamp = 22,
        .block_id = block_id,
    };
    var metas: [2]AccountMeta = undefined;
    var data: [160]u8 = undefined;

    const tower_ix = try towerSync(&vote_account, &voter, tower, &metas, &data);
    try std.testing.expectEqual(@as(usize, 90), tower_ix.data.len);
    try std.testing.expectEqual(@as(u32, 14), std.mem.readInt(u32, tower_ix.data[0..4], .little));
    try std.testing.expectEqual(std.math.maxInt(u64), std.mem.readInt(u64, tower_ix.data[4..12], .little));
    try std.testing.expectEqualSlices(u8, &.{ 2, 100, 3, 5, 4 }, tower_ix.data[12..17]);
    try std.testing.expectEqualSlices(u8, &hash, tower_ix.data[17..49]);
    try std.testing.expectEqual(@as(u8, 1), tower_ix.data[49]);
    try std.testing.expectEqual(@as(i64, 22), std.mem.readInt(i64, tower_ix.data[50..58], .little));
    try std.testing.expectEqualSlices(u8, &block_id, tower_ix.data[58..90]);

    const switch_ix = try towerSyncSwitch(&vote_account, &voter, tower, &proof_hash, &metas, &data);
    try std.testing.expectEqual(@as(u32, 15), std.mem.readInt(u32, switch_ix.data[0..4], .little));
    try std.testing.expectEqualSlices(u8, &proof_hash, switch_ix.data[90..122]);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "initializeAccount"));
    try std.testing.expect(@hasDecl(@This(), "authorize"));
    try std.testing.expect(@hasDecl(@This(), "authorizeChecked"));
    try std.testing.expect(@hasDecl(@This(), "authorizeWithSeed"));
    try std.testing.expect(@hasDecl(@This(), "authorizeCheckedWithSeed"));
    try std.testing.expect(@hasDecl(@This(), "withdraw"));
    try std.testing.expect(@hasDecl(@This(), "voteRaw"));
    try std.testing.expect(@hasDecl(@This(), "voteSwitchRaw"));
    try std.testing.expect(@hasDecl(@This(), "vote"));
    try std.testing.expect(@hasDecl(@This(), "voteSwitch"));
    try std.testing.expect(@hasDecl(@This(), "updateVoteStateRaw"));
    try std.testing.expect(@hasDecl(@This(), "compactUpdateVoteStateRaw"));
    try std.testing.expect(@hasDecl(@This(), "towerSyncRaw"));
    try std.testing.expect(@hasDecl(@This(), "updateVoteState"));
    try std.testing.expect(@hasDecl(@This(), "compactUpdateVoteState"));
    try std.testing.expect(@hasDecl(@This(), "towerSync"));
    try std.testing.expect(@hasDecl(@This(), "writeVotePayload"));
    try std.testing.expect(@hasDecl(@This(), "writeVoteStateUpdatePayload"));
    try std.testing.expect(@hasDecl(@This(), "writeTowerSyncPayload"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
