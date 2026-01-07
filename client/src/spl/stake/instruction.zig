//! SPL Stake program instruction builders (Client)
//!
//! Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
//!
//! This module provides instruction builders for the Stake program (18 instructions).
//! Types (StakeInstruction, Authorized, Lockup, etc.) are imported from the SDK.
//!
//! ## Instructions
//! - Initialize, InitializeChecked - Initialize stake accounts
//! - Authorize, AuthorizeChecked, AuthorizeWithSeed, AuthorizeCheckedWithSeed - Change authorities
//! - DelegateStake - Delegate stake to a validator
//! - Split - Split stake between accounts
//! - Withdraw - Withdraw unstaked lamports
//! - Deactivate, DeactivateDelinquent - Deactivate stake
//! - SetLockup, SetLockupChecked - Set lockup parameters
//! - Merge - Merge stake accounts
//! - GetMinimumDelegation - Query minimum delegation
//! - Redelegate (deprecated) - Redelegate stake
//! - MoveStake, MoveLamports - Move stake/lamports between accounts

const std = @import("std");
const sdk = @import("solana_sdk");
const PublicKey = sdk.PublicKey;
const AccountMeta = sdk.AccountMeta;

// Re-export types from SDK
const sdk_stake = sdk.spl.stake;
pub const StakeInstruction = sdk_stake.StakeInstruction;
pub const Authorized = sdk_stake.Authorized;
pub const Lockup = sdk_stake.Lockup;
pub const LockupArgs = sdk_stake.LockupArgs;
pub const LockupCheckedArgs = sdk_stake.LockupCheckedArgs;
pub const StakeAuthorize = sdk_stake.StakeAuthorize;
pub const STAKE_PROGRAM_ID = sdk_stake.STAKE_PROGRAM_ID;
pub const STAKE_CONFIG_PROGRAM_ID = sdk_stake.STAKE_CONFIG_PROGRAM_ID;

// ============================================================================
// Sysvar Program IDs
// ============================================================================

/// Clock sysvar
pub const CLOCK_SYSVAR = PublicKey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");

/// Rent sysvar
pub const RENT_SYSVAR = PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");

/// Stake History sysvar
pub const STAKE_HISTORY_SYSVAR = PublicKey.comptimeFromBase58("SysvarStakeHistory1111111111111111111111111");

// ============================================================================
// Helper Functions
// ============================================================================

fn writeU32LE(buffer: []u8, value: u32) void {
    std.mem.writeInt(u32, buffer[0..4], value, .little);
}

fn writeU64LE(buffer: []u8, value: u64) void {
    std.mem.writeInt(u64, buffer[0..8], value, .little);
}

fn writeI64LE(buffer: []u8, value: i64) void {
    std.mem.writeInt(i64, buffer[0..8], value, .little);
}

// ============================================================================
// Initialize (ID=0)
// ============================================================================

/// Maximum size of instruction data for stake instructions
/// = 4 (discriminant) + 64 (Authorized) + 48 (Lockup) = 116
pub const MAX_INITIALIZE_DATA_SIZE: usize = 116;

/// Creates an Initialize instruction.
///
/// Initializes a stake account with authorized staker and withdrawer.
///
/// # Account references
///   0. `[WRITE]` Uninitialized stake account
///   1. `[]` Rent sysvar
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn initialize(
    stake_account: PublicKey,
    authorized: Authorized,
    lockup: Lockup,
) struct { accounts: [2]AccountMeta, data: [MAX_INITIALIZE_DATA_SIZE]u8 } {
    var data: [MAX_INITIALIZE_DATA_SIZE]u8 = undefined;

    // Discriminant (4 bytes, little-endian)
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.Initialize));

    // Authorized (64 bytes): staker (32) + withdrawer (32)
    @memcpy(data[4..36], &authorized.staker.bytes);
    @memcpy(data[36..68], &authorized.withdrawer.bytes);

    // Lockup (48 bytes): unix_timestamp (8) + epoch (8) + custodian (32)
    writeI64LE(data[68..76], lockup.unix_timestamp);
    writeU64LE(data[76..84], lockup.epoch);
    @memcpy(data[84..116], &lockup.custodian.bytes);

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newReadonly(RENT_SYSVAR),
        },
        .data = data,
    };
}

// ============================================================================
// Authorize (ID=1)
// ============================================================================

/// Data size for Authorize instruction
/// = 4 (discriminant) + 32 (pubkey) + 4 (stake_authorize enum)
pub const AUTHORIZE_DATA_SIZE: usize = 40;

/// Creates an Authorize instruction.
///
/// Authorize a key to manage stake or withdrawal.
///
/// # Account references
///   0. `[WRITE]` Stake account to be updated
///   1. `[]` Clock sysvar
///   2. `[SIGNER]` The stake or withdraw authority
///   3. Optional: `[SIGNER]` Lockup authority (if updating Withdrawer before lockup expiration)
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn authorize(
    stake_account: PublicKey,
    authority: PublicKey,
    new_authority: PublicKey,
    stake_authorize: StakeAuthorize,
    custodian: ?PublicKey,
) struct { accounts: [4]AccountMeta, num_accounts: usize, data: [AUTHORIZE_DATA_SIZE]u8 } {
    var data: [AUTHORIZE_DATA_SIZE]u8 = undefined;

    // Discriminant
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.Authorize));

    // New authority pubkey (32 bytes)
    @memcpy(data[4..36], &new_authority.bytes);

    // StakeAuthorize enum (4 bytes)
    writeU32LE(data[36..40], @intFromEnum(stake_authorize));

    var accounts: [4]AccountMeta = undefined;
    accounts[0] = AccountMeta.newWritable(stake_account);
    accounts[1] = AccountMeta.newReadonly(CLOCK_SYSVAR);
    accounts[2] = AccountMeta.newReadonlySigner(authority);

    var num_accounts: usize = 3;
    if (custodian) |c| {
        accounts[3] = AccountMeta.newReadonlySigner(c);
        num_accounts = 4;
    }

    return .{
        .accounts = accounts,
        .num_accounts = num_accounts,
        .data = data,
    };
}

// ============================================================================
// DelegateStake (ID=2)
// ============================================================================

/// Data size for DelegateStake instruction (only discriminant)
pub const DELEGATE_STAKE_DATA_SIZE: usize = 4;

/// Creates a DelegateStake instruction.
///
/// Delegate a stake to a particular vote account.
///
/// # Account references
///   0. `[WRITE]` Initialized stake account to be delegated
///   1. `[]` Vote account to which this stake will be delegated
///   2. `[]` Clock sysvar
///   3. `[]` Stake history sysvar
///   4. `[]` Stake config account (deprecated but still required)
///   5. `[SIGNER]` Stake authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn delegateStake(
    stake_account: PublicKey,
    vote_account: PublicKey,
    authority: PublicKey,
) struct { accounts: [6]AccountMeta, data: [DELEGATE_STAKE_DATA_SIZE]u8 } {
    var data: [DELEGATE_STAKE_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.DelegateStake));

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newReadonly(vote_account),
            AccountMeta.newReadonly(CLOCK_SYSVAR),
            AccountMeta.newReadonly(STAKE_HISTORY_SYSVAR),
            AccountMeta.newReadonly(STAKE_CONFIG_PROGRAM_ID),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
    };
}

// ============================================================================
// Split (ID=3)
// ============================================================================

/// Data size for Split instruction
/// = 4 (discriminant) + 8 (lamports)
pub const SPLIT_DATA_SIZE: usize = 12;

/// Creates a Split instruction.
///
/// Split lamports from a stake account into another stake account.
///
/// # Account references
///   0. `[WRITE]` Stake account to be split (must be in Initialized or Stake state)
///   1. `[WRITE]` Uninitialized stake account that will take the split-off amount
///   2. `[SIGNER]` Stake authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn split(
    stake_account: PublicKey,
    split_stake_account: PublicKey,
    authority: PublicKey,
    lamports: u64,
) struct { accounts: [3]AccountMeta, data: [SPLIT_DATA_SIZE]u8 } {
    var data: [SPLIT_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.Split));
    writeU64LE(data[4..12], lamports);

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newWritable(split_stake_account),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
    };
}

// ============================================================================
// Withdraw (ID=4)
// ============================================================================

/// Data size for Withdraw instruction
/// = 4 (discriminant) + 8 (lamports)
pub const WITHDRAW_DATA_SIZE: usize = 12;

/// Creates a Withdraw instruction.
///
/// Withdraw unstaked lamports from the stake account.
///
/// # Account references
///   0. `[WRITE]` Stake account from which to withdraw
///   1. `[WRITE]` Recipient account
///   2. `[]` Clock sysvar
///   3. `[]` Stake history sysvar
///   4. `[SIGNER]` Withdraw authority
///   5. Optional: `[SIGNER]` Lockup authority (if before lockup expiration)
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn withdraw(
    stake_account: PublicKey,
    recipient: PublicKey,
    authority: PublicKey,
    lamports: u64,
    custodian: ?PublicKey,
) struct { accounts: [6]AccountMeta, num_accounts: usize, data: [WITHDRAW_DATA_SIZE]u8 } {
    var data: [WITHDRAW_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.Withdraw));
    writeU64LE(data[4..12], lamports);

    var accounts: [6]AccountMeta = undefined;
    accounts[0] = AccountMeta.newWritable(stake_account);
    accounts[1] = AccountMeta.newWritable(recipient);
    accounts[2] = AccountMeta.newReadonly(CLOCK_SYSVAR);
    accounts[3] = AccountMeta.newReadonly(STAKE_HISTORY_SYSVAR);
    accounts[4] = AccountMeta.newReadonlySigner(authority);

    var num_accounts: usize = 5;
    if (custodian) |c| {
        accounts[5] = AccountMeta.newReadonlySigner(c);
        num_accounts = 6;
    }

    return .{
        .accounts = accounts,
        .num_accounts = num_accounts,
        .data = data,
    };
}

// ============================================================================
// Deactivate (ID=5)
// ============================================================================

/// Data size for Deactivate instruction (only discriminant)
pub const DEACTIVATE_DATA_SIZE: usize = 4;

/// Creates a Deactivate instruction.
///
/// Deactivate the stake. The stake will go through a cooldown period.
///
/// # Account references
///   0. `[WRITE]` Delegated stake account
///   1. `[]` Clock sysvar
///   2. `[SIGNER]` Stake authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn deactivate(
    stake_account: PublicKey,
    authority: PublicKey,
) struct { accounts: [3]AccountMeta, data: [DEACTIVATE_DATA_SIZE]u8 } {
    var data: [DEACTIVATE_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.Deactivate));

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newReadonly(CLOCK_SYSVAR),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
    };
}

// ============================================================================
// SetLockup (ID=6)
// ============================================================================

/// Maximum data size for SetLockup instruction
/// = 4 (discriminant) + 1 + 8 (optional unix_timestamp) + 1 + 8 (optional epoch) + 1 + 32 (optional custodian)
pub const MAX_SET_LOCKUP_DATA_SIZE: usize = 55;

/// Creates a SetLockup instruction.
///
/// Set lockup on a stake account.
///
/// # Account references
///   0. `[WRITE]` Initialized stake account
///   1. `[SIGNER]` Lockup authority or withdraw authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn setLockup(
    stake_account: PublicKey,
    authority: PublicKey,
    lockup_args: LockupArgs,
) struct { accounts: [2]AccountMeta, data: [MAX_SET_LOCKUP_DATA_SIZE]u8, data_len: usize } {
    var data: [MAX_SET_LOCKUP_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.SetLockup));

    var offset: usize = 4;

    // Optional unix_timestamp
    if (lockup_args.unix_timestamp) |ts| {
        data[offset] = 1; // Some
        offset += 1;
        writeI64LE(data[offset..][0..8], ts);
        offset += 8;
    } else {
        data[offset] = 0; // None
        offset += 1;
    }

    // Optional epoch
    if (lockup_args.epoch) |e| {
        data[offset] = 1; // Some
        offset += 1;
        writeU64LE(data[offset..][0..8], e);
        offset += 8;
    } else {
        data[offset] = 0; // None
        offset += 1;
    }

    // Optional custodian
    if (lockup_args.custodian) |c| {
        data[offset] = 1; // Some
        offset += 1;
        @memcpy(data[offset..][0..32], &c.bytes);
        offset += 32;
    } else {
        data[offset] = 0; // None
        offset += 1;
    }

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
        .data_len = offset,
    };
}

// ============================================================================
// Merge (ID=7)
// ============================================================================

/// Data size for Merge instruction (only discriminant)
pub const MERGE_DATA_SIZE: usize = 4;

/// Creates a Merge instruction.
///
/// Merge two stake accounts.
///
/// # Account references
///   0. `[WRITE]` Destination stake account
///   1. `[WRITE]` Source stake account (will be drained)
///   2. `[]` Clock sysvar
///   3. `[]` Stake history sysvar
///   4. `[SIGNER]` Stake authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn merge(
    destination_stake: PublicKey,
    source_stake: PublicKey,
    authority: PublicKey,
) struct { accounts: [5]AccountMeta, data: [MERGE_DATA_SIZE]u8 } {
    var data: [MERGE_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.Merge));

    return .{
        .accounts = .{
            AccountMeta.newWritable(destination_stake),
            AccountMeta.newWritable(source_stake),
            AccountMeta.newReadonly(CLOCK_SYSVAR),
            AccountMeta.newReadonly(STAKE_HISTORY_SYSVAR),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
    };
}

// ============================================================================
// InitializeChecked (ID=9)
// ============================================================================

/// Data size for InitializeChecked instruction (only discriminant)
pub const INITIALIZE_CHECKED_DATA_SIZE: usize = 4;

/// Creates an InitializeChecked instruction.
///
/// Initialize a stake with authorization checked (staker and withdrawer must sign).
///
/// # Account references
///   0. `[WRITE]` Uninitialized stake account
///   1. `[]` Rent sysvar
///   2. `[SIGNER]` Staker authority
///   3. `[SIGNER]` Withdrawer authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn initializeChecked(
    stake_account: PublicKey,
    staker: PublicKey,
    withdrawer: PublicKey,
) struct { accounts: [4]AccountMeta, data: [INITIALIZE_CHECKED_DATA_SIZE]u8 } {
    var data: [INITIALIZE_CHECKED_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.InitializeChecked));

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newReadonly(RENT_SYSVAR),
            AccountMeta.newReadonlySigner(staker),
            AccountMeta.newReadonlySigner(withdrawer),
        },
        .data = data,
    };
}

// ============================================================================
// AuthorizeChecked (ID=10)
// ============================================================================

/// Data size for AuthorizeChecked instruction
/// = 4 (discriminant) + 4 (stake_authorize enum)
pub const AUTHORIZE_CHECKED_DATA_SIZE: usize = 8;

/// Creates an AuthorizeChecked instruction.
///
/// Authorize a key with authorization checked (new authority must sign).
///
/// # Account references
///   0. `[WRITE]` Stake account to be updated
///   1. `[]` Clock sysvar
///   2. `[SIGNER]` The stake or withdraw authority
///   3. `[SIGNER]` The new stake or withdraw authority
///   4. Optional: `[SIGNER]` Lockup authority (if updating Withdrawer before lockup expiration)
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn authorizeChecked(
    stake_account: PublicKey,
    authority: PublicKey,
    new_authority: PublicKey,
    stake_authorize: StakeAuthorize,
    custodian: ?PublicKey,
) struct { accounts: [5]AccountMeta, num_accounts: usize, data: [AUTHORIZE_CHECKED_DATA_SIZE]u8 } {
    var data: [AUTHORIZE_CHECKED_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.AuthorizeChecked));
    writeU32LE(data[4..8], @intFromEnum(stake_authorize));

    var accounts: [5]AccountMeta = undefined;
    accounts[0] = AccountMeta.newWritable(stake_account);
    accounts[1] = AccountMeta.newReadonly(CLOCK_SYSVAR);
    accounts[2] = AccountMeta.newReadonlySigner(authority);
    accounts[3] = AccountMeta.newReadonlySigner(new_authority);

    var num_accounts: usize = 4;
    if (custodian) |c| {
        accounts[4] = AccountMeta.newReadonlySigner(c);
        num_accounts = 5;
    }

    return .{
        .accounts = accounts,
        .num_accounts = num_accounts,
        .data = data,
    };
}

// ============================================================================
// SetLockupChecked (ID=12)
// ============================================================================

/// Maximum data size for SetLockupChecked instruction
/// = 4 (discriminant) + 1 + 8 (optional unix_timestamp) + 1 + 8 (optional epoch)
pub const MAX_SET_LOCKUP_CHECKED_DATA_SIZE: usize = 22;

/// Creates a SetLockupChecked instruction.
///
/// Set lockup with lockup checked (new custodian must sign).
///
/// # Account references
///   0. `[WRITE]` Initialized stake account
///   1. `[SIGNER]` Lockup authority or withdraw authority
///   2. Optional: `[SIGNER]` New lockup authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn setLockupChecked(
    stake_account: PublicKey,
    authority: PublicKey,
    lockup_args: LockupCheckedArgs,
    new_custodian: ?PublicKey,
) struct { accounts: [3]AccountMeta, num_accounts: usize, data: [MAX_SET_LOCKUP_CHECKED_DATA_SIZE]u8, data_len: usize } {
    var data: [MAX_SET_LOCKUP_CHECKED_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.SetLockupChecked));

    var offset: usize = 4;

    // Optional unix_timestamp
    if (lockup_args.unix_timestamp) |ts| {
        data[offset] = 1;
        offset += 1;
        writeI64LE(data[offset..][0..8], ts);
        offset += 8;
    } else {
        data[offset] = 0;
        offset += 1;
    }

    // Optional epoch
    if (lockup_args.epoch) |e| {
        data[offset] = 1;
        offset += 1;
        writeU64LE(data[offset..][0..8], e);
        offset += 8;
    } else {
        data[offset] = 0;
        offset += 1;
    }

    var accounts: [3]AccountMeta = undefined;
    accounts[0] = AccountMeta.newWritable(stake_account);
    accounts[1] = AccountMeta.newReadonlySigner(authority);

    var num_accounts: usize = 2;
    if (new_custodian) |c| {
        accounts[2] = AccountMeta.newReadonlySigner(c);
        num_accounts = 3;
    }

    return .{
        .accounts = accounts,
        .num_accounts = num_accounts,
        .data = data,
        .data_len = offset,
    };
}

// ============================================================================
// GetMinimumDelegation (ID=13)
// ============================================================================

/// Data size for GetMinimumDelegation instruction (only discriminant)
pub const GET_MINIMUM_DELEGATION_DATA_SIZE: usize = 4;

/// Creates a GetMinimumDelegation instruction.
///
/// Return the minimum delegation amount.
///
/// # Account references
///   None
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn getMinimumDelegation() struct { data: [GET_MINIMUM_DELEGATION_DATA_SIZE]u8 } {
    var data: [GET_MINIMUM_DELEGATION_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.GetMinimumDelegation));

    return .{
        .data = data,
    };
}

// ============================================================================
// DeactivateDelinquent (ID=14)
// ============================================================================

/// Data size for DeactivateDelinquent instruction (only discriminant)
pub const DEACTIVATE_DELINQUENT_DATA_SIZE: usize = 4;

/// Creates a DeactivateDelinquent instruction.
///
/// Deactivate stake delegated to a delinquent vote account.
///
/// # Account references
///   0. `[WRITE]` Stake account
///   1. `[]` Delinquent vote account
///   2. `[]` Reference vote account (with sufficient voting activity)
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn deactivateDelinquent(
    stake_account: PublicKey,
    delinquent_vote_account: PublicKey,
    reference_vote_account: PublicKey,
) struct { accounts: [3]AccountMeta, data: [DEACTIVATE_DELINQUENT_DATA_SIZE]u8 } {
    var data: [DEACTIVATE_DELINQUENT_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.DeactivateDelinquent));

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newReadonly(delinquent_vote_account),
            AccountMeta.newReadonly(reference_vote_account),
        },
        .data = data,
    };
}

// ============================================================================
// Redelegate (ID=15) - DEPRECATED
// ============================================================================

/// Data size for Redelegate instruction (only discriminant)
pub const REDELEGATE_DATA_SIZE: usize = 4;

/// Creates a Redelegate instruction.
///
/// Redelegate activated stake to another vote account.
///
/// NOTE: This instruction is deprecated and will not be enabled.
///
/// # Account references
///   0. `[WRITE]` Delegated stake account to be redelegated
///   1. `[WRITE]` Uninitialized stake account to hold redelegated stake
///   2. `[]` New vote account
///   3. `[]` Stake config account (deprecated)
///   4. `[SIGNER]` Stake authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn redelegate(
    stake_account: PublicKey,
    uninitialized_stake_account: PublicKey,
    vote_account: PublicKey,
    authority: PublicKey,
) struct { accounts: [5]AccountMeta, data: [REDELEGATE_DATA_SIZE]u8 } {
    var data: [REDELEGATE_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.Redelegate));

    return .{
        .accounts = .{
            AccountMeta.newWritable(stake_account),
            AccountMeta.newWritable(uninitialized_stake_account),
            AccountMeta.newReadonly(vote_account),
            AccountMeta.newReadonly(STAKE_CONFIG_PROGRAM_ID),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
    };
}

// ============================================================================
// MoveStake (ID=16)
// ============================================================================

/// Data size for MoveStake instruction
/// = 4 (discriminant) + 8 (lamports)
pub const MOVE_STAKE_DATA_SIZE: usize = 12;

/// Creates a MoveStake instruction.
///
/// Move stake between accounts with the same authorities and lockups.
///
/// # Account references
///   0. `[WRITE]` Source stake account
///   1. `[WRITE]` Destination stake account
///   2. `[SIGNER]` Stake authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn moveStake(
    source_stake: PublicKey,
    destination_stake: PublicKey,
    authority: PublicKey,
    lamports: u64,
) struct { accounts: [3]AccountMeta, data: [MOVE_STAKE_DATA_SIZE]u8 } {
    var data: [MOVE_STAKE_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.MoveStake));
    writeU64LE(data[4..12], lamports);

    return .{
        .accounts = .{
            AccountMeta.newWritable(source_stake),
            AccountMeta.newWritable(destination_stake),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
    };
}

// ============================================================================
// MoveLamports (ID=17)
// ============================================================================

/// Data size for MoveLamports instruction
/// = 4 (discriminant) + 8 (lamports)
pub const MOVE_LAMPORTS_DATA_SIZE: usize = 12;

/// Creates a MoveLamports instruction.
///
/// Move unstaked lamports between accounts with the same authorities and lockups.
///
/// # Account references
///   0. `[WRITE]` Source stake account
///   1. `[WRITE]` Destination stake account
///   2. `[SIGNER]` Stake authority
///
/// Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
pub fn moveLamports(
    source_stake: PublicKey,
    destination_stake: PublicKey,
    authority: PublicKey,
    lamports: u64,
) struct { accounts: [3]AccountMeta, data: [MOVE_LAMPORTS_DATA_SIZE]u8 } {
    var data: [MOVE_LAMPORTS_DATA_SIZE]u8 = undefined;
    writeU32LE(data[0..4], @intFromEnum(StakeInstruction.Discriminant.MoveLamports));
    writeU64LE(data[4..12], lamports);

    return .{
        .accounts = .{
            AccountMeta.newWritable(source_stake),
            AccountMeta.newWritable(destination_stake),
            AccountMeta.newReadonlySigner(authority),
        },
        .data = data,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "initialize: creates correct instruction data" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const staker = PublicKey.from([_]u8{2} ** 32);
    const withdrawer = PublicKey.from([_]u8{3} ** 32);

    const authorized = Authorized{
        .staker = staker,
        .withdrawer = withdrawer,
    };
    const lockup = Lockup.DEFAULT;

    const result = initialize(stake_account, authorized, lockup);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 0), discriminant); // Initialize = 0

    // Check accounts
    try std.testing.expectEqual(@as(usize, 2), result.accounts.len);
    try std.testing.expect(result.accounts[0].is_writable);
    try std.testing.expect(!result.accounts[0].is_signer);
    try std.testing.expect(!result.accounts[1].is_writable);
}

test "authorize: creates correct instruction with custodian" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);
    const new_authority = PublicKey.from([_]u8{3} ** 32);
    const custodian = PublicKey.from([_]u8{4} ** 32);

    const result = authorize(stake_account, authority, new_authority, .Staker, custodian);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 1), discriminant); // Authorize = 1

    // Check StakeAuthorize
    const stake_auth = std.mem.readInt(u32, result.data[36..40], .little);
    try std.testing.expectEqual(@as(u32, 0), stake_auth); // Staker = 0

    // Check accounts count
    try std.testing.expectEqual(@as(usize, 4), result.num_accounts);
}

test "authorize: creates correct instruction without custodian" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);
    const new_authority = PublicKey.from([_]u8{3} ** 32);

    const result = authorize(stake_account, authority, new_authority, .Withdrawer, null);

    // Check StakeAuthorize
    const stake_auth = std.mem.readInt(u32, result.data[36..40], .little);
    try std.testing.expectEqual(@as(u32, 1), stake_auth); // Withdrawer = 1

    // Check accounts count (no custodian)
    try std.testing.expectEqual(@as(usize, 3), result.num_accounts);
}

test "delegateStake: creates correct instruction" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const vote_account = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const result = delegateStake(stake_account, vote_account, authority);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 2), discriminant); // DelegateStake = 2

    // Check accounts
    try std.testing.expectEqual(@as(usize, 6), result.accounts.len);
}

test "split: creates correct instruction" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const split_stake = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const result = split(stake_account, split_stake, authority, 1_000_000);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 3), discriminant); // Split = 3

    // Check lamports
    const lamports = std.mem.readInt(u64, result.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 1_000_000), lamports);
}

test "withdraw: creates correct instruction" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const recipient = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const result = withdraw(stake_account, recipient, authority, 500_000, null);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 4), discriminant); // Withdraw = 4

    // Check lamports
    const lamports = std.mem.readInt(u64, result.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 500_000), lamports);

    // Check accounts count
    try std.testing.expectEqual(@as(usize, 5), result.num_accounts);
}

test "deactivate: creates correct instruction" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);

    const result = deactivate(stake_account, authority);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 5), discriminant); // Deactivate = 5

    // Check accounts
    try std.testing.expectEqual(@as(usize, 3), result.accounts.len);
}

test "setLockup: creates correct instruction with all args" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);
    const new_custodian = PublicKey.from([_]u8{3} ** 32);

    const lockup_args = LockupArgs{
        .unix_timestamp = 1234567890,
        .epoch = 100,
        .custodian = new_custodian,
    };

    const result = setLockup(stake_account, authority, lockup_args);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 6), discriminant); // SetLockup = 6

    // Check data length (4 + 1 + 8 + 1 + 8 + 1 + 32 = 55)
    try std.testing.expectEqual(@as(usize, 55), result.data_len);
}

test "setLockup: creates correct instruction with no args" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);

    const lockup_args = LockupArgs{};

    const result = setLockup(stake_account, authority, lockup_args);

    // Check data length (4 + 1 + 1 + 1 = 7)
    try std.testing.expectEqual(@as(usize, 7), result.data_len);
}

test "merge: creates correct instruction" {
    const dest = PublicKey.from([_]u8{1} ** 32);
    const source = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const result = merge(dest, source, authority);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 7), discriminant); // Merge = 7

    // Check accounts
    try std.testing.expectEqual(@as(usize, 5), result.accounts.len);
}

test "initializeChecked: creates correct instruction" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const staker = PublicKey.from([_]u8{2} ** 32);
    const withdrawer = PublicKey.from([_]u8{3} ** 32);

    const result = initializeChecked(stake_account, staker, withdrawer);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 9), discriminant); // InitializeChecked = 9

    // Check accounts (should have signers for staker and withdrawer)
    try std.testing.expectEqual(@as(usize, 4), result.accounts.len);
    try std.testing.expect(result.accounts[2].is_signer);
    try std.testing.expect(result.accounts[3].is_signer);
}

test "authorizeChecked: creates correct instruction" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const authority = PublicKey.from([_]u8{2} ** 32);
    const new_authority = PublicKey.from([_]u8{3} ** 32);

    const result = authorizeChecked(stake_account, authority, new_authority, .Staker, null);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 10), discriminant); // AuthorizeChecked = 10

    // Check accounts count
    try std.testing.expectEqual(@as(usize, 4), result.num_accounts);
}

test "getMinimumDelegation: creates correct instruction" {
    const result = getMinimumDelegation();

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 13), discriminant); // GetMinimumDelegation = 13
}

test "deactivateDelinquent: creates correct instruction" {
    const stake_account = PublicKey.from([_]u8{1} ** 32);
    const delinquent_vote = PublicKey.from([_]u8{2} ** 32);
    const reference_vote = PublicKey.from([_]u8{3} ** 32);

    const result = deactivateDelinquent(stake_account, delinquent_vote, reference_vote);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 14), discriminant); // DeactivateDelinquent = 14

    // Check accounts
    try std.testing.expectEqual(@as(usize, 3), result.accounts.len);
}

test "moveStake: creates correct instruction" {
    const source = PublicKey.from([_]u8{1} ** 32);
    const dest = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const result = moveStake(source, dest, authority, 2_000_000);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 16), discriminant); // MoveStake = 16

    // Check lamports
    const lamports = std.mem.readInt(u64, result.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 2_000_000), lamports);
}

test "moveLamports: creates correct instruction" {
    const source = PublicKey.from([_]u8{1} ** 32);
    const dest = PublicKey.from([_]u8{2} ** 32);
    const authority = PublicKey.from([_]u8{3} ** 32);

    const result = moveLamports(source, dest, authority, 3_000_000);

    // Check discriminant
    const discriminant = std.mem.readInt(u32, result.data[0..4], .little);
    try std.testing.expectEqual(@as(u32, 17), discriminant); // MoveLamports = 17

    // Check lamports
    const lamports = std.mem.readInt(u64, result.data[4..12], .little);
    try std.testing.expectEqual(@as(u64, 3_000_000), lamports);
}

test "sysvar constants: correct addresses" {
    var buffer: [44]u8 = undefined;

    const clock = CLOCK_SYSVAR.toBase58(&buffer);
    try std.testing.expectEqualStrings("SysvarC1ock11111111111111111111111111111111", clock);

    const rent = RENT_SYSVAR.toBase58(&buffer);
    try std.testing.expectEqualStrings("SysvarRent111111111111111111111111111111111", rent);

    const stake_history = STAKE_HISTORY_SYSVAR.toBase58(&buffer);
    try std.testing.expectEqualStrings("SysvarStakeHistory1111111111111111111111111", stake_history);
}
