//! Zig implementation of Solana Stake program instruction types
//!
//! Rust source: https://github.com/solana-program/stake/blob/master/interface/src/instruction.rs
//!
//! This module provides instruction TYPE DEFINITIONS for the Stake program.
//! For instruction BUILDERS that create complete instructions with accounts and data,
//! see `client/src/spl/stake/instruction.zig`.

const std = @import("std");
const PublicKey = @import("../../public_key.zig").PublicKey;
const state = @import("state.zig");

// Re-export commonly used types
pub const Authorized = state.Authorized;
pub const Lockup = state.Lockup;
pub const LockupArgs = state.LockupArgs;
pub const LockupCheckedArgs = state.LockupCheckedArgs;
pub const StakeAuthorize = state.StakeAuthorize;
pub const STAKE_PROGRAM_ID = state.STAKE_PROGRAM_ID;

// ============================================================================
// Instruction Argument Structures
// ============================================================================

/// Arguments for AuthorizeWithSeed instruction
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/instruction.rs#L565-L570
pub const AuthorizeWithSeedArgs = struct {
    /// New authority pubkey
    new_authorized_pubkey: PublicKey,
    /// Type of stake authorization
    stake_authorize: StakeAuthorize,
    /// Authority seed (for PDA derivation)
    authority_seed: []const u8,
    /// Authority owner program
    authority_owner: PublicKey,
};

/// Arguments for AuthorizeCheckedWithSeed instruction
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/instruction.rs#L582-L586
pub const AuthorizeCheckedWithSeedArgs = struct {
    /// Type of stake authorization
    stake_authorize: StakeAuthorize,
    /// Authority seed (for PDA derivation)
    authority_seed: []const u8,
    /// Authority owner program
    authority_owner: PublicKey,
};

// ============================================================================
// StakeInstruction Enum
// ============================================================================

/// Stake program instructions
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/instruction.rs#L44-L526
///
/// Total: 18 instruction variants (0-17)
///
/// Note: This is the TYPE DEFINITION only. For instruction builders that
/// create complete instructions with accounts and serialized data,
/// see `client/src/spl/stake/instruction.zig`.
pub const StakeInstruction = union(enum) {
    /// Initialize a stake account with authorized staker and withdrawer
    ///
    /// # Account references
    ///   0. `[WRITE]` Uninitialized stake account
    ///   1. `[]` Rent sysvar
    ///
    /// Authorized: Authorized staker and withdrawer pubkeys
    /// Lockup: Optional lockup configuration
    Initialize: struct {
        authorized: Authorized,
        lockup: Lockup,
    },

    /// Authorize a key to manage stake or withdrawal
    ///
    /// # Account references
    ///   0. `[WRITE]` Stake account to be updated
    ///   1. `[]` Clock sysvar
    ///   2. `[SIGNER]` The stake or withdraw authority
    ///   3. Optional: `[SIGNER]` Lockup authority, if updating StakeAuthorize::Withdrawer before
    ///      lockup expiration
    Authorize: struct {
        pubkey: PublicKey,
        stake_authorize: StakeAuthorize,
    },

    /// Delegate a stake to a particular vote account
    ///
    /// # Account references
    ///   0. `[WRITE]` Initialized stake account to be delegated
    ///   1. `[]` Vote account to which this stake will be delegated
    ///   2. `[]` Clock sysvar
    ///   3. `[]` Stake history sysvar
    ///   4. `[]` Stake config account (deprecated)
    ///   5. `[SIGNER]` Stake authority
    DelegateStake: void,

    /// Split lamports from a stake account into another stake account
    ///
    /// # Account references
    ///   0. `[WRITE]` Stake account to be split; must be in Initialized or Stake state
    ///   1. `[WRITE]` Uninitialized stake account that will take the split-off amount
    ///   2. `[SIGNER]` Stake authority
    Split: u64,

    /// Withdraw unstaked lamports from the stake account
    ///
    /// # Account references
    ///   0. `[WRITE]` Stake account from which to withdraw
    ///   1. `[WRITE]` Recipient account
    ///   2. `[]` Clock sysvar
    ///   3. `[]` Stake history sysvar
    ///   4. `[SIGNER]` Withdraw authority
    ///   5. Optional: `[SIGNER]` Lockup authority, if before lockup expiration
    Withdraw: u64,

    /// Deactivate the stake
    ///
    /// # Account references
    ///   0. `[WRITE]` Delegated stake account
    ///   1. `[]` Clock sysvar
    ///   2. `[SIGNER]` Stake authority
    Deactivate: void,

    /// Set lockup on a stake account
    ///
    /// # Account references
    ///   0. `[WRITE]` Initialized stake account
    ///   1. `[SIGNER]` Lockup authority or withdraw authority
    SetLockup: LockupArgs,

    /// Merge two stake accounts
    ///
    /// # Account references
    ///   0. `[WRITE]` Destination stake account
    ///   1. `[WRITE]` Source stake account (will be drained)
    ///   2. `[]` Clock sysvar
    ///   3. `[]` Stake history sysvar
    ///   4. `[SIGNER]` Stake authority
    Merge: void,

    /// Authorize a key with a derived key
    ///
    /// # Account references
    ///   0. `[WRITE]` Stake account to be updated
    ///   1. `[SIGNER]` Base key of stake or withdraw authority
    ///   2. `[]` Clock sysvar
    ///   3. Optional: `[SIGNER]` Lockup authority, if updating StakeAuthorize::Withdrawer before
    ///      lockup expiration
    AuthorizeWithSeed: AuthorizeWithSeedArgs,

    /// Initialize a stake with authorization checked
    ///
    /// # Account references
    ///   0. `[WRITE]` Uninitialized stake account
    ///   1. `[]` Rent sysvar
    ///   2. `[SIGNER]` Staker authority
    ///   3. `[SIGNER]` Withdrawer authority
    InitializeChecked: void,

    /// Authorize a key with authorization checked
    ///
    /// # Account references
    ///   0. `[WRITE]` Stake account to be updated
    ///   1. `[]` Clock sysvar
    ///   2. `[SIGNER]` The stake or withdraw authority
    ///   3. `[SIGNER]` The new stake or withdraw authority
    ///   4. Optional: `[SIGNER]` Lockup authority, if updating StakeAuthorize::Withdrawer before
    ///      lockup expiration
    AuthorizeChecked: StakeAuthorize,

    /// Authorize with seed with authorization checked
    ///
    /// # Account references
    ///   0. `[WRITE]` Stake account to be updated
    ///   1. `[SIGNER]` Base key of stake or withdraw authority
    ///   2. `[]` Clock sysvar
    ///   3. `[SIGNER]` The new stake or withdraw authority
    ///   4. Optional: `[SIGNER]` Lockup authority, if updating StakeAuthorize::Withdrawer before
    ///      lockup expiration
    AuthorizeCheckedWithSeed: AuthorizeCheckedWithSeedArgs,

    /// Set lockup with lockup checked
    ///
    /// # Account references
    ///   0. `[WRITE]` Initialized stake account
    ///   1. `[SIGNER]` Lockup authority or withdraw authority
    ///   2. Optional: `[SIGNER]` New lockup authority
    SetLockupChecked: LockupCheckedArgs,

    /// Return the minimum delegation amount
    ///
    /// # Account references
    ///   None
    GetMinimumDelegation: void,

    /// Deactivate stake delegated to a delinquent vote account
    ///
    /// # Account references
    ///   0. `[WRITE]` Stake account
    ///   1. `[]` Delinquent vote account
    ///   2. `[]` Reference vote account with sufficient voting activity
    DeactivateDelinquent: void,

    /// Redelegate activated stake to another vote account (DEPRECATED)
    ///
    /// # Account references
    ///   0. `[WRITE]` Delegated stake account to be redelegated
    ///   1. `[WRITE]` Uninitialized stake account to hold redelegated stake
    ///   2. `[]` New vote account
    ///   3. `[]` Stake config account (deprecated)
    ///   4. `[SIGNER]` Stake authority
    ///
    /// Note: This instruction is deprecated and will not be enabled
    Redelegate: void,

    /// Move stake between accounts with the same authorities and lockups
    ///
    /// # Account references
    ///   0. `[WRITE]` Source stake account
    ///   1. `[WRITE]` Destination stake account
    ///   2. `[SIGNER]` Stake authority
    MoveStake: u64,

    /// Move unstaked lamports between accounts with the same authorities and lockups
    ///
    /// # Account references
    ///   0. `[WRITE]` Source stake account
    ///   1. `[WRITE]` Destination stake account
    ///   2. `[SIGNER]` Stake authority
    MoveLamports: u64,

    /// Discriminant values for instruction serialization
    pub const Discriminant = enum(u32) {
        Initialize = 0,
        Authorize = 1,
        DelegateStake = 2,
        Split = 3,
        Withdraw = 4,
        Deactivate = 5,
        SetLockup = 6,
        Merge = 7,
        AuthorizeWithSeed = 8,
        InitializeChecked = 9,
        AuthorizeChecked = 10,
        AuthorizeCheckedWithSeed = 11,
        SetLockupChecked = 12,
        GetMinimumDelegation = 13,
        DeactivateDelinquent = 14,
        Redelegate = 15,
        MoveStake = 16,
        MoveLamports = 17,
    };

    /// Get the discriminant value for this instruction
    pub fn discriminant(self: StakeInstruction) Discriminant {
        return switch (self) {
            .Initialize => .Initialize,
            .Authorize => .Authorize,
            .DelegateStake => .DelegateStake,
            .Split => .Split,
            .Withdraw => .Withdraw,
            .Deactivate => .Deactivate,
            .SetLockup => .SetLockup,
            .Merge => .Merge,
            .AuthorizeWithSeed => .AuthorizeWithSeed,
            .InitializeChecked => .InitializeChecked,
            .AuthorizeChecked => .AuthorizeChecked,
            .AuthorizeCheckedWithSeed => .AuthorizeCheckedWithSeed,
            .SetLockupChecked => .SetLockupChecked,
            .GetMinimumDelegation => .GetMinimumDelegation,
            .DeactivateDelinquent => .DeactivateDelinquent,
            .Redelegate => .Redelegate,
            .MoveStake => .MoveStake,
            .MoveLamports => .MoveLamports,
        };
    }

    /// Get the program ID for stake instructions
    pub fn getProgramId() PublicKey {
        return STAKE_PROGRAM_ID;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StakeInstruction.Discriminant: enum values match Rust SDK" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(StakeInstruction.Discriminant.Initialize));
    try std.testing.expectEqual(@as(u32, 1), @intFromEnum(StakeInstruction.Discriminant.Authorize));
    try std.testing.expectEqual(@as(u32, 2), @intFromEnum(StakeInstruction.Discriminant.DelegateStake));
    try std.testing.expectEqual(@as(u32, 3), @intFromEnum(StakeInstruction.Discriminant.Split));
    try std.testing.expectEqual(@as(u32, 4), @intFromEnum(StakeInstruction.Discriminant.Withdraw));
    try std.testing.expectEqual(@as(u32, 5), @intFromEnum(StakeInstruction.Discriminant.Deactivate));
    try std.testing.expectEqual(@as(u32, 6), @intFromEnum(StakeInstruction.Discriminant.SetLockup));
    try std.testing.expectEqual(@as(u32, 7), @intFromEnum(StakeInstruction.Discriminant.Merge));
    try std.testing.expectEqual(@as(u32, 8), @intFromEnum(StakeInstruction.Discriminant.AuthorizeWithSeed));
    try std.testing.expectEqual(@as(u32, 9), @intFromEnum(StakeInstruction.Discriminant.InitializeChecked));
    try std.testing.expectEqual(@as(u32, 10), @intFromEnum(StakeInstruction.Discriminant.AuthorizeChecked));
    try std.testing.expectEqual(@as(u32, 11), @intFromEnum(StakeInstruction.Discriminant.AuthorizeCheckedWithSeed));
    try std.testing.expectEqual(@as(u32, 12), @intFromEnum(StakeInstruction.Discriminant.SetLockupChecked));
    try std.testing.expectEqual(@as(u32, 13), @intFromEnum(StakeInstruction.Discriminant.GetMinimumDelegation));
    try std.testing.expectEqual(@as(u32, 14), @intFromEnum(StakeInstruction.Discriminant.DeactivateDelinquent));
    try std.testing.expectEqual(@as(u32, 15), @intFromEnum(StakeInstruction.Discriminant.Redelegate));
    try std.testing.expectEqual(@as(u32, 16), @intFromEnum(StakeInstruction.Discriminant.MoveStake));
    try std.testing.expectEqual(@as(u32, 17), @intFromEnum(StakeInstruction.Discriminant.MoveLamports));
}

test "StakeInstruction: getProgramId" {
    const expected = "Stake11111111111111111111111111111111111111";
    var buffer: [44]u8 = undefined;
    const actual = StakeInstruction.getProgramId().toBase58(&buffer);
    try std.testing.expectEqualStrings(expected, actual);
}
