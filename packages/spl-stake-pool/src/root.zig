//! `spl_stake_pool` - SPL Stake Pool state and instruction helpers.

const std = @import("std");
const sol = @import("solana_program_sdk");

pub const Pubkey = sol.Pubkey;
pub const AccountMeta = sol.cpi.AccountMeta;
pub const Instruction = sol.cpi.Instruction;

pub const PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("SPoo1Ku8WFXoNDMHPsrGSTSG1Y47rzgn41SLUNakuHy");
pub const DEVNET_PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("DPoo15wWDqpPJJtS2MUZ49aRxqz5ZaaJCJP4z8bLuib");
pub const SYSTEM_PROGRAM_ID: Pubkey = sol.system_program_id;
pub const STAKE_PROGRAM_ID: Pubkey = sol.pubkey.comptimeFromBase58("Stake11111111111111111111111111111111111111");
pub const STAKE_CONFIG_ID: Pubkey = sol.pubkey.comptimeFromBase58("StakeConfig11111111111111111111111111111111");
pub const CLOCK_ID: Pubkey = sol.clock_id;
pub const RENT_ID: Pubkey = sol.rent_id;
pub const STAKE_HISTORY_ID: Pubkey = sol.stake_history_id;

pub const AUTHORITY_DEPOSIT = "deposit";
pub const AUTHORITY_WITHDRAW = "withdraw";
pub const TRANSIENT_STAKE_SEED_PREFIX = "transient";
pub const EPHEMERAL_STAKE_SEED_PREFIX = "ephemeral";

pub const MINIMUM_ACTIVE_STAKE: u64 = 1_000_000;
pub const MINIMUM_RESERVE_LAMPORTS: u64 = 0;
pub const MAX_VALIDATORS_TO_UPDATE: usize = 4;
pub const MAX_TRANSIENT_STAKE_ACCOUNTS: usize = 10;

pub const VALIDATOR_LIST_HEADER_LEN: usize = 5;
pub const VALIDATOR_STAKE_INFO_LEN: usize = 73;
pub const STAKE_POOL_HEADER_MIN_LEN: usize = 338;

pub const Error = sol.ProgramError || error{
    AccountDataTooSmall,
    AccountMetaBufferTooSmall,
    BufferTooSmall,
    InvalidAccountType,
    InvalidSeed,
};

pub const AccountType = enum(u8) {
    uninitialized = 0,
    stake_pool = 1,
    validator_list = 2,
};

pub const StakeStatus = enum(u8) {
    active = 0,
    deactivating_transient = 1,
    ready_for_removal = 2,
    deactivating_validator = 3,
    deactivating_all = 4,
};

pub const ProgramInstruction = enum(u8) {
    initialize = 0,
    add_validator_to_pool = 1,
    remove_validator_from_pool = 2,
    decrease_validator_stake = 3,
    increase_validator_stake = 4,
    set_preferred_validator = 5,
    update_validator_list_balance = 6,
    update_stake_pool_balance = 7,
    cleanup_removed_validator_entries = 8,
    deposit_stake = 9,
    withdraw_stake = 10,
    set_manager = 11,
    set_fee = 12,
    set_staker = 13,
    deposit_sol = 14,
    set_funding_authority = 15,
    withdraw_sol = 16,
    create_token_metadata = 17,
    update_token_metadata = 18,
    increase_additional_validator_stake = 19,
    decrease_additional_validator_stake = 20,
    decrease_validator_stake_with_reserve = 21,
    redelegate = 22,
    deposit_stake_with_slippage = 23,
    withdraw_stake_with_slippage = 24,
    deposit_sol_with_slippage = 25,
    withdraw_sol_with_slippage = 26,
};

pub const PreferredValidatorType = enum(u8) {
    deposit = 0,
    withdraw = 1,
};

pub const FundingType = enum(u8) {
    stake_deposit = 0,
    sol_deposit = 1,
    sol_withdraw = 2,
};

pub const Fee = struct {
    denominator: u64,
    numerator: u64,
};

pub const Lockup = struct {
    unix_timestamp: i64,
    epoch: u64,
    custodian: Pubkey,
};

pub const ValidatorListHeader = struct {
    account_type: AccountType,
    max_validators: u32,
};

pub const ValidatorStakeInfo = struct {
    active_stake_lamports: u64,
    transient_stake_lamports: u64,
    last_update_epoch: u64,
    transient_seed_suffix: u64,
    unused: u32,
    validator_seed_suffix: u32,
    status: StakeStatus,
    vote_account_address: Pubkey,
};

pub const StakePoolHeader = struct {
    manager: Pubkey,
    staker: Pubkey,
    stake_deposit_authority: Pubkey,
    stake_withdraw_bump_seed: u8,
    validator_list: Pubkey,
    reserve_stake: Pubkey,
    pool_mint: Pubkey,
    manager_fee_account: Pubkey,
    token_program_id: Pubkey,
    total_lamports: u64,
    pool_token_supply: u64,
    last_update_epoch: u64,
    lockup: Lockup,
    epoch_fee: Fee,
};

pub const InitializeAccounts = struct {
    stake_pool: *const Pubkey,
    manager: *const Pubkey,
    staker: *const Pubkey,
    withdraw_authority: *const Pubkey,
    validator_list: *const Pubkey,
    reserve_stake: *const Pubkey,
    pool_mint: *const Pubkey,
    manager_pool_account: *const Pubkey,
    token_program_id: *const Pubkey,
    deposit_authority: ?*const Pubkey = null,
};

pub const AddValidatorAccounts = struct {
    stake_pool: *const Pubkey,
    staker: *const Pubkey,
    reserve_stake: *const Pubkey,
    withdraw_authority: *const Pubkey,
    validator_list: *const Pubkey,
    validator_stake: *const Pubkey,
    validator_vote: *const Pubkey,
};

pub const DepositStakeAccounts = struct {
    stake_pool: *const Pubkey,
    validator_list: *const Pubkey,
    deposit_authority: *const Pubkey,
    deposit_authority_is_signer: bool = false,
    withdraw_authority: *const Pubkey,
    deposit_stake: *const Pubkey,
    validator_stake: *const Pubkey,
    reserve_stake: *const Pubkey,
    pool_tokens_to: *const Pubkey,
    manager_fee_account: *const Pubkey,
    referrer_pool_tokens_account: *const Pubkey,
    pool_mint: *const Pubkey,
    token_program_id: *const Pubkey,
};

pub const DepositSolAccounts = struct {
    stake_pool: *const Pubkey,
    withdraw_authority: *const Pubkey,
    reserve_stake: *const Pubkey,
    lamports_from: *const Pubkey,
    pool_tokens_to: *const Pubkey,
    manager_fee_account: *const Pubkey,
    referrer_pool_tokens_account: *const Pubkey,
    pool_mint: *const Pubkey,
    token_program_id: *const Pubkey,
    sol_deposit_authority: ?*const Pubkey = null,
};

pub const WithdrawStakeAccounts = struct {
    stake_pool: *const Pubkey,
    validator_list: *const Pubkey,
    withdraw_authority: *const Pubkey,
    stake_to_split: *const Pubkey,
    stake_to_receive: *const Pubkey,
    user_stake_authority: *const Pubkey,
    user_transfer_authority: *const Pubkey,
    user_pool_token_account: *const Pubkey,
    manager_fee_account: *const Pubkey,
    pool_mint: *const Pubkey,
    token_program_id: *const Pubkey,
};

pub const WithdrawSolAccounts = struct {
    stake_pool: *const Pubkey,
    withdraw_authority: *const Pubkey,
    user_transfer_authority: *const Pubkey,
    pool_tokens_from: *const Pubkey,
    reserve_stake: *const Pubkey,
    lamports_to: *const Pubkey,
    manager_fee_account: *const Pubkey,
    pool_mint: *const Pubkey,
    token_program_id: *const Pubkey,
    sol_withdraw_authority: ?*const Pubkey = null,
};

pub fn findDepositAuthority(stake_pool: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ stake_pool, AUTHORITY_DEPOSIT }, &PROGRAM_ID) catch unreachable;
}

pub fn findWithdrawAuthority(stake_pool: *const Pubkey) sol.pda.ProgramDerivedAddress {
    return sol.pda.findProgramAddress(&.{ stake_pool, AUTHORITY_WITHDRAW }, &PROGRAM_ID) catch unreachable;
}

pub fn findValidatorStakeAddress(
    validator_vote: *const Pubkey,
    stake_pool: *const Pubkey,
    seed: ?u32,
) Error!sol.pda.ProgramDerivedAddress {
    if (seed) |s| {
        if (s == 0) return error.InvalidSeed;
        const seed_bytes = std.mem.toBytes(s);
        return try sol.pda.findProgramAddress(&.{ validator_vote, stake_pool, &seed_bytes }, &PROGRAM_ID);
    }
    return try sol.pda.findProgramAddress(&.{ validator_vote, stake_pool }, &PROGRAM_ID);
}

pub fn findTransientStakeAddress(
    validator_vote: *const Pubkey,
    stake_pool: *const Pubkey,
    seed: u64,
) sol.pda.ProgramDerivedAddress {
    const seed_bytes = std.mem.toBytes(seed);
    return sol.pda.findProgramAddress(&.{
        TRANSIENT_STAKE_SEED_PREFIX,
        validator_vote,
        stake_pool,
        &seed_bytes,
    }, &PROGRAM_ID) catch unreachable;
}

pub fn findEphemeralStakeAddress(stake_pool: *const Pubkey, seed: u64) sol.pda.ProgramDerivedAddress {
    const seed_bytes = std.mem.toBytes(seed);
    return sol.pda.findProgramAddress(&.{ EPHEMERAL_STAKE_SEED_PREFIX, stake_pool, &seed_bytes }, &PROGRAM_ID) catch unreachable;
}

pub fn parseValidatorListHeader(data: []const u8) Error!ValidatorListHeader {
    if (data.len < VALIDATOR_LIST_HEADER_LEN) return error.AccountDataTooSmall;
    const account_type = try parseAccountType(data[0]);
    return .{
        .account_type = account_type,
        .max_validators = std.mem.readInt(u32, data[1..5], .little),
    };
}

pub fn parseValidatorStakeInfo(data: []const u8) Error!ValidatorStakeInfo {
    if (data.len < VALIDATOR_STAKE_INFO_LEN) return error.AccountDataTooSmall;
    return .{
        .active_stake_lamports = std.mem.readInt(u64, data[0..8], .little),
        .transient_stake_lamports = std.mem.readInt(u64, data[8..16], .little),
        .last_update_epoch = std.mem.readInt(u64, data[16..24], .little),
        .transient_seed_suffix = std.mem.readInt(u64, data[24..32], .little),
        .unused = std.mem.readInt(u32, data[32..36], .little),
        .validator_seed_suffix = std.mem.readInt(u32, data[36..40], .little),
        .status = try parseStakeStatus(data[40]),
        .vote_account_address = data[41..73].*,
    };
}

pub fn parseStakePoolHeader(data: []const u8) Error!StakePoolHeader {
    if (data.len < STAKE_POOL_HEADER_MIN_LEN) return error.AccountDataTooSmall;
    const account_type = try parseAccountType(data[0]);
    if (account_type != .stake_pool) return error.InvalidAccountType;
    return .{
        .manager = data[1..33].*,
        .staker = data[33..65].*,
        .stake_deposit_authority = data[65..97].*,
        .stake_withdraw_bump_seed = data[97],
        .validator_list = data[98..130].*,
        .reserve_stake = data[130..162].*,
        .pool_mint = data[162..194].*,
        .manager_fee_account = data[194..226].*,
        .token_program_id = data[226..258].*,
        .total_lamports = std.mem.readInt(u64, data[258..266], .little),
        .pool_token_supply = std.mem.readInt(u64, data[266..274], .little),
        .last_update_epoch = std.mem.readInt(u64, data[274..282], .little),
        .lockup = .{
            .unix_timestamp = std.mem.readInt(i64, data[282..290], .little),
            .epoch = std.mem.readInt(u64, data[290..298], .little),
            .custodian = data[298..330].*,
        },
        .epoch_fee = readFee(data[330..346]),
    };
}

pub fn writeInitializeData(
    epoch_fee: Fee,
    withdrawal_fee: Fee,
    deposit_fee: Fee,
    referral_fee: u8,
    max_validators: u32,
    out: []u8,
) Error![]const u8 {
    if (out.len < 54) return error.BufferTooSmall;
    out[0] = @intFromEnum(ProgramInstruction.initialize);
    var cursor: usize = 1;
    cursor += writeFee(epoch_fee, out[cursor..][0..16]);
    cursor += writeFee(withdrawal_fee, out[cursor..][0..16]);
    cursor += writeFee(deposit_fee, out[cursor..][0..16]);
    out[cursor] = referral_fee;
    cursor += 1;
    std.mem.writeInt(u32, out[cursor..][0..4], max_validators, .little);
    cursor += 4;
    return out[0..cursor];
}

pub fn writeTag(tag: ProgramInstruction, out: []u8) Error![]const u8 {
    if (out.len < 1) return error.BufferTooSmall;
    out[0] = @intFromEnum(tag);
    return out[0..1];
}

pub fn writeAddValidatorData(seed: ?u32, out: []u8) Error![]const u8 {
    if (out.len < 5) return error.BufferTooSmall;
    out[0] = @intFromEnum(ProgramInstruction.add_validator_to_pool);
    std.mem.writeInt(u32, out[1..5], seed orelse 0, .little);
    return out[0..5];
}

pub fn writeU64InstructionData(tag: ProgramInstruction, amount: u64, out: []u8) Error![]const u8 {
    if (out.len < 9) return error.BufferTooSmall;
    out[0] = @intFromEnum(tag);
    std.mem.writeInt(u64, out[1..9], amount, .little);
    return out[0..9];
}

pub fn writeSlippageData(tag: ProgramInstruction, amount: u64, minimum_out: u64, out: []u8) Error![]const u8 {
    if (out.len < 17) return error.BufferTooSmall;
    out[0] = @intFromEnum(tag);
    std.mem.writeInt(u64, out[1..9], amount, .little);
    std.mem.writeInt(u64, out[9..17], minimum_out, .little);
    return out[0..17];
}

pub fn initialize(
    accounts: InitializeAccounts,
    epoch_fee: Fee,
    withdrawal_fee: Fee,
    deposit_fee: Fee,
    referral_fee: u8,
    max_validators: u32,
    metas: []AccountMeta,
    data: []u8,
) Error!Instruction {
    const account_len: usize = if (accounts.deposit_authority == null) 9 else 10;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = try writeInitializeData(epoch_fee, withdrawal_fee, deposit_fee, referral_fee, max_validators, data);

    metas[0] = AccountMeta.writable(accounts.stake_pool);
    metas[1] = AccountMeta.signer(accounts.manager);
    metas[2] = AccountMeta.readonly(accounts.staker);
    metas[3] = AccountMeta.readonly(accounts.withdraw_authority);
    metas[4] = AccountMeta.writable(accounts.validator_list);
    metas[5] = AccountMeta.readonly(accounts.reserve_stake);
    metas[6] = AccountMeta.writable(accounts.pool_mint);
    metas[7] = AccountMeta.writable(accounts.manager_pool_account);
    metas[8] = AccountMeta.readonly(accounts.token_program_id);
    if (accounts.deposit_authority) |authority| metas[9] = AccountMeta.signer(authority);

    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

pub fn addValidatorToPool(accounts: AddValidatorAccounts, seed: ?u32, metas: *[13]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeAddValidatorData(seed, data);
    metas[0] = AccountMeta.writable(accounts.stake_pool);
    metas[1] = AccountMeta.signer(accounts.staker);
    metas[2] = AccountMeta.writable(accounts.reserve_stake);
    metas[3] = AccountMeta.readonly(accounts.withdraw_authority);
    metas[4] = AccountMeta.writable(accounts.validator_list);
    metas[5] = AccountMeta.writable(accounts.validator_stake);
    metas[6] = AccountMeta.readonly(accounts.validator_vote);
    metas[7] = AccountMeta.readonly(&RENT_ID);
    metas[8] = AccountMeta.readonly(&CLOCK_ID);
    metas[9] = AccountMeta.readonly(&STAKE_HISTORY_ID);
    metas[10] = AccountMeta.readonly(&STAKE_CONFIG_ID);
    metas[11] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[12] = AccountMeta.readonly(&STAKE_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn removeValidatorFromPool(
    stake_pool: *const Pubkey,
    staker: *const Pubkey,
    withdraw_authority: *const Pubkey,
    validator_list: *const Pubkey,
    validator_stake: *const Pubkey,
    transient_stake: *const Pubkey,
    metas: *[8]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeTag(.remove_validator_from_pool, data);
    metas[0] = AccountMeta.writable(stake_pool);
    metas[1] = AccountMeta.signer(staker);
    metas[2] = AccountMeta.readonly(withdraw_authority);
    metas[3] = AccountMeta.writable(validator_list);
    metas[4] = AccountMeta.writable(validator_stake);
    metas[5] = AccountMeta.writable(transient_stake);
    metas[6] = AccountMeta.readonly(&CLOCK_ID);
    metas[7] = AccountMeta.readonly(&STAKE_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn updateStakePoolBalance(
    stake_pool: *const Pubkey,
    withdraw_authority: *const Pubkey,
    validator_list: *const Pubkey,
    reserve_stake: *const Pubkey,
    manager_fee_account: *const Pubkey,
    pool_mint: *const Pubkey,
    token_program_id: *const Pubkey,
    metas: *[7]AccountMeta,
    data: []u8,
) Error!Instruction {
    const written_data = try writeTag(.update_stake_pool_balance, data);
    metas[0] = AccountMeta.readonly(stake_pool);
    metas[1] = AccountMeta.readonly(withdraw_authority);
    metas[2] = AccountMeta.writable(validator_list);
    metas[3] = AccountMeta.readonly(reserve_stake);
    metas[4] = AccountMeta.writable(manager_fee_account);
    metas[5] = AccountMeta.writable(pool_mint);
    metas[6] = AccountMeta.readonly(token_program_id);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn cleanupRemovedValidatorEntries(stake_pool: *const Pubkey, validator_list: *const Pubkey, metas: *[2]AccountMeta, data: []u8) Error!Instruction {
    const written_data = try writeTag(.cleanup_removed_validator_entries, data);
    metas[0] = AccountMeta.readonly(stake_pool);
    metas[1] = AccountMeta.writable(validator_list);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn depositStakeFinal(accounts: DepositStakeAccounts, minimum_pool_tokens_out: ?u64, metas: *[15]AccountMeta, data: []u8) Error!Instruction {
    const written_data = if (minimum_pool_tokens_out) |min_out|
        try writeU64InstructionData(.deposit_stake_with_slippage, min_out, data)
    else
        try writeTag(.deposit_stake, data);
    metas[0] = AccountMeta.writable(accounts.stake_pool);
    metas[1] = AccountMeta.writable(accounts.validator_list);
    metas[2] = AccountMeta.init(accounts.deposit_authority, false, accounts.deposit_authority_is_signer);
    metas[3] = AccountMeta.readonly(accounts.withdraw_authority);
    metas[4] = AccountMeta.writable(accounts.deposit_stake);
    metas[5] = AccountMeta.writable(accounts.validator_stake);
    metas[6] = AccountMeta.writable(accounts.reserve_stake);
    metas[7] = AccountMeta.writable(accounts.pool_tokens_to);
    metas[8] = AccountMeta.writable(accounts.manager_fee_account);
    metas[9] = AccountMeta.writable(accounts.referrer_pool_tokens_account);
    metas[10] = AccountMeta.writable(accounts.pool_mint);
    metas[11] = AccountMeta.readonly(&CLOCK_ID);
    metas[12] = AccountMeta.readonly(&STAKE_HISTORY_ID);
    metas[13] = AccountMeta.readonly(accounts.token_program_id);
    metas[14] = AccountMeta.readonly(&STAKE_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn depositSol(accounts: DepositSolAccounts, lamports_in: u64, minimum_pool_tokens_out: ?u64, metas: []AccountMeta, data: []u8) Error!Instruction {
    const account_len: usize = if (accounts.sol_deposit_authority == null) 10 else 11;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = if (minimum_pool_tokens_out) |min_out|
        try writeSlippageData(.deposit_sol_with_slippage, lamports_in, min_out, data)
    else
        try writeU64InstructionData(.deposit_sol, lamports_in, data);
    metas[0] = AccountMeta.writable(accounts.stake_pool);
    metas[1] = AccountMeta.readonly(accounts.withdraw_authority);
    metas[2] = AccountMeta.writable(accounts.reserve_stake);
    metas[3] = AccountMeta.signerWritable(accounts.lamports_from);
    metas[4] = AccountMeta.writable(accounts.pool_tokens_to);
    metas[5] = AccountMeta.writable(accounts.manager_fee_account);
    metas[6] = AccountMeta.writable(accounts.referrer_pool_tokens_account);
    metas[7] = AccountMeta.writable(accounts.pool_mint);
    metas[8] = AccountMeta.readonly(&SYSTEM_PROGRAM_ID);
    metas[9] = AccountMeta.readonly(accounts.token_program_id);
    if (accounts.sol_deposit_authority) |authority| metas[10] = AccountMeta.signer(authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

pub fn withdrawStake(accounts: WithdrawStakeAccounts, pool_tokens_in: u64, minimum_lamports_out: ?u64, metas: *[13]AccountMeta, data: []u8) Error!Instruction {
    const written_data = if (minimum_lamports_out) |min_out|
        try writeSlippageData(.withdraw_stake_with_slippage, pool_tokens_in, min_out, data)
    else
        try writeU64InstructionData(.withdraw_stake, pool_tokens_in, data);
    metas[0] = AccountMeta.writable(accounts.stake_pool);
    metas[1] = AccountMeta.writable(accounts.validator_list);
    metas[2] = AccountMeta.readonly(accounts.withdraw_authority);
    metas[3] = AccountMeta.writable(accounts.stake_to_split);
    metas[4] = AccountMeta.writable(accounts.stake_to_receive);
    metas[5] = AccountMeta.readonly(accounts.user_stake_authority);
    metas[6] = AccountMeta.signer(accounts.user_transfer_authority);
    metas[7] = AccountMeta.writable(accounts.user_pool_token_account);
    metas[8] = AccountMeta.writable(accounts.manager_fee_account);
    metas[9] = AccountMeta.writable(accounts.pool_mint);
    metas[10] = AccountMeta.readonly(&CLOCK_ID);
    metas[11] = AccountMeta.readonly(accounts.token_program_id);
    metas[12] = AccountMeta.readonly(&STAKE_PROGRAM_ID);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..], .data = written_data };
}

pub fn withdrawSol(accounts: WithdrawSolAccounts, pool_tokens_in: u64, minimum_lamports_out: ?u64, metas: []AccountMeta, data: []u8) Error!Instruction {
    const account_len: usize = if (accounts.sol_withdraw_authority == null) 12 else 13;
    if (metas.len < account_len) return error.AccountMetaBufferTooSmall;
    const written_data = if (minimum_lamports_out) |min_out|
        try writeSlippageData(.withdraw_sol_with_slippage, pool_tokens_in, min_out, data)
    else
        try writeU64InstructionData(.withdraw_sol, pool_tokens_in, data);
    metas[0] = AccountMeta.writable(accounts.stake_pool);
    metas[1] = AccountMeta.readonly(accounts.withdraw_authority);
    metas[2] = AccountMeta.signer(accounts.user_transfer_authority);
    metas[3] = AccountMeta.writable(accounts.pool_tokens_from);
    metas[4] = AccountMeta.writable(accounts.reserve_stake);
    metas[5] = AccountMeta.writable(accounts.lamports_to);
    metas[6] = AccountMeta.writable(accounts.manager_fee_account);
    metas[7] = AccountMeta.writable(accounts.pool_mint);
    metas[8] = AccountMeta.readonly(&CLOCK_ID);
    metas[9] = AccountMeta.readonly(&STAKE_HISTORY_ID);
    metas[10] = AccountMeta.readonly(&STAKE_PROGRAM_ID);
    metas[11] = AccountMeta.readonly(accounts.token_program_id);
    if (accounts.sol_withdraw_authority) |authority| metas[12] = AccountMeta.signer(authority);
    return .{ .program_id = &PROGRAM_ID, .accounts = metas[0..account_len], .data = written_data };
}

fn parseAccountType(value: u8) Error!AccountType {
    return switch (value) {
        0 => .uninitialized,
        1 => .stake_pool,
        2 => .validator_list,
        else => error.InvalidAccountType,
    };
}

fn parseStakeStatus(value: u8) Error!StakeStatus {
    return switch (value) {
        0 => .active,
        1 => .deactivating_transient,
        2 => .ready_for_removal,
        3 => .deactivating_validator,
        4 => .deactivating_all,
        else => error.InvalidAccountType,
    };
}

fn readFee(input: []const u8) Fee {
    return .{
        .denominator = std.mem.readInt(u64, input[0..8], .little),
        .numerator = std.mem.readInt(u64, input[8..16], .little),
    };
}

fn writeFee(fee: Fee, out: []u8) usize {
    std.mem.writeInt(u64, out[0..8], fee.denominator, .little);
    std.mem.writeInt(u64, out[8..16], fee.numerator, .little);
    return 16;
}

test "PDA helpers match official seed order" {
    const stake_pool: Pubkey = .{1} ** 32;
    const vote: Pubkey = .{2} ** 32;

    const deposit = findDepositAuthority(&stake_pool);
    const deposit_expected = try sol.pda.findProgramAddress(&.{ &stake_pool, AUTHORITY_DEPOSIT }, &PROGRAM_ID);
    try std.testing.expectEqualSlices(u8, &deposit_expected.address, &deposit.address);

    const withdraw = findWithdrawAuthority(&stake_pool);
    const withdraw_expected = try sol.pda.findProgramAddress(&.{ &stake_pool, AUTHORITY_WITHDRAW }, &PROGRAM_ID);
    try std.testing.expectEqualSlices(u8, &withdraw_expected.address, &withdraw.address);

    const stake = try findValidatorStakeAddress(&vote, &stake_pool, 7);
    const seed = std.mem.toBytes(@as(u32, 7));
    const stake_expected = try sol.pda.findProgramAddress(&.{ &vote, &stake_pool, &seed }, &PROGRAM_ID);
    try std.testing.expectEqualSlices(u8, &stake_expected.address, &stake.address);
}

test "validator list and stake info parsers read borsh/pod layout" {
    var data: [VALIDATOR_LIST_HEADER_LEN + VALIDATOR_STAKE_INFO_LEN]u8 = .{0} ** (VALIDATOR_LIST_HEADER_LEN + VALIDATOR_STAKE_INFO_LEN);
    data[0] = @intFromEnum(AccountType.validator_list);
    std.mem.writeInt(u32, data[1..5], 12, .little);
    const header = try parseValidatorListHeader(&data);
    try std.testing.expectEqual(AccountType.validator_list, header.account_type);
    try std.testing.expectEqual(@as(u32, 12), header.max_validators);

    const info_data = data[5..];
    std.mem.writeInt(u64, info_data[0..8], 100, .little);
    std.mem.writeInt(u64, info_data[8..16], 25, .little);
    std.mem.writeInt(u64, info_data[16..24], 9, .little);
    std.mem.writeInt(u64, info_data[24..32], 8, .little);
    std.mem.writeInt(u32, info_data[36..40], 7, .little);
    info_data[40] = @intFromEnum(StakeStatus.active);
    @memset(info_data[41..73], 0xAB);
    const parsed = try parseValidatorStakeInfo(info_data);
    try std.testing.expectEqual(@as(u64, 125), parsed.active_stake_lamports + parsed.transient_stake_lamports);
    try std.testing.expectEqual(@as(u32, 7), parsed.validator_seed_suffix);
    try std.testing.expectEqual(StakeStatus.active, parsed.status);
    try std.testing.expectEqualSlices(u8, &(.{0xAB} ** 32), &parsed.vote_account_address);
}

test "initialize data and account metas match official layout" {
    const keys = [_]Pubkey{
        .{0} ** 32, .{1} ** 32, .{2} ** 32, .{3} ** 32, .{4} ** 32,
        .{5} ** 32, .{6} ** 32, .{7} ** 32, .{8} ** 32, .{9} ** 32,
    };
    var metas: [10]AccountMeta = undefined;
    var data: [64]u8 = undefined;
    const ix = try initialize(.{
        .stake_pool = &keys[0],
        .manager = &keys[1],
        .staker = &keys[2],
        .withdraw_authority = &keys[3],
        .validator_list = &keys[4],
        .reserve_stake = &keys[5],
        .pool_mint = &keys[6],
        .manager_pool_account = &keys[7],
        .token_program_id = &keys[8],
        .deposit_authority = &keys[9],
    }, .{ .denominator = 100, .numerator = 1 }, .{ .denominator = 200, .numerator = 2 }, .{ .denominator = 300, .numerator = 3 }, 4, 5, &metas, &data);

    try std.testing.expectEqualSlices(u8, &PROGRAM_ID, ix.program_id);
    try std.testing.expectEqual(@as(usize, 10), ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 0), ix.data[0]);
    try std.testing.expectEqual(@as(u64, 100), std.mem.readInt(u64, ix.data[1..9], .little));
    try std.testing.expectEqual(@as(u64, 1), std.mem.readInt(u64, ix.data[9..17], .little));
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[1].is_signer);
    try std.testing.expectEqual(@as(u8, 1), ix.accounts[9].is_signer);
}

test "common instruction builders encode official tags and metas" {
    const keys = [_]Pubkey{
        .{0} ** 32,  .{1} ** 32,  .{2} ** 32,  .{3} ** 32, .{4} ** 32,
        .{5} ** 32,  .{6} ** 32,  .{7} ** 32,  .{8} ** 32, .{9} ** 32,
        .{10} ** 32, .{11} ** 32, .{12} ** 32,
    };
    var data: [24]u8 = undefined;
    var add_metas: [13]AccountMeta = undefined;
    var sol_metas: [13]AccountMeta = undefined;
    var stake_metas: [15]AccountMeta = undefined;

    const add_ix = try addValidatorToPool(.{
        .stake_pool = &keys[0],
        .staker = &keys[1],
        .reserve_stake = &keys[2],
        .withdraw_authority = &keys[3],
        .validator_list = &keys[4],
        .validator_stake = &keys[5],
        .validator_vote = &keys[6],
    }, 7, &add_metas, &data);
    try std.testing.expectEqual(@as(u8, 1), add_ix.data[0]);
    try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, add_ix.data[1..5], .little));
    try std.testing.expectEqual(@as(usize, 13), add_ix.accounts.len);

    const deposit_ix = try depositSol(.{
        .stake_pool = &keys[0],
        .withdraw_authority = &keys[1],
        .reserve_stake = &keys[2],
        .lamports_from = &keys[3],
        .pool_tokens_to = &keys[4],
        .manager_fee_account = &keys[5],
        .referrer_pool_tokens_account = &keys[6],
        .pool_mint = &keys[7],
        .token_program_id = &keys[8],
        .sol_deposit_authority = &keys[9],
    }, 123, 100, &sol_metas, &data);
    try std.testing.expectEqual(@as(u8, 25), deposit_ix.data[0]);
    try std.testing.expectEqual(@as(usize, 11), deposit_ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), deposit_ix.accounts[10].is_signer);

    const stake_ix = try depositStakeFinal(.{
        .stake_pool = &keys[0],
        .validator_list = &keys[1],
        .deposit_authority = &keys[2],
        .deposit_authority_is_signer = true,
        .withdraw_authority = &keys[3],
        .deposit_stake = &keys[4],
        .validator_stake = &keys[5],
        .reserve_stake = &keys[6],
        .pool_tokens_to = &keys[7],
        .manager_fee_account = &keys[8],
        .referrer_pool_tokens_account = &keys[9],
        .pool_mint = &keys[10],
        .token_program_id = &keys[11],
    }, null, &stake_metas, &data);
    try std.testing.expectEqual(@as(u8, 9), stake_ix.data[0]);
    try std.testing.expectEqual(@as(usize, 15), stake_ix.accounts.len);
    try std.testing.expectEqual(@as(u8, 1), stake_ix.accounts[2].is_signer);
}

test "public surface guards" {
    try std.testing.expect(@hasDecl(@This(), "findDepositAuthority"));
    try std.testing.expect(@hasDecl(@This(), "findValidatorStakeAddress"));
    try std.testing.expect(@hasDecl(@This(), "parseValidatorStakeInfo"));
    try std.testing.expect(@hasDecl(@This(), "initialize"));
    try std.testing.expect(@hasDecl(@This(), "depositSol"));
    try std.testing.expect(@hasDecl(@This(), "withdrawSol"));
    try std.testing.expect(!@hasDecl(@This(), "rpc"));
    try std.testing.expect(!@hasDecl(@This(), "wallet"));
}
