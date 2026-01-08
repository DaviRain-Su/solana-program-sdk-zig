//! SPL Stake Program Client Module
//!
//! Rust source: https://github.com/solana-program/stake
//!
//! This module provides instruction builders and RPC client for the Stake program.
//! Types are re-exported from the SDK.
//!
//! ## Usage
//!
//! ```zig
//! const stake = @import("solana_client").spl.stake;
//!
//! // Low-level: Build instructions directly
//! const authorized = stake.Authorized{
//!     .staker = staker_pubkey,
//!     .withdrawer = withdrawer_pubkey,
//! };
//! const ix = stake.initialize(stake_account, authorized, stake.Lockup.DEFAULT);
//!
//! // High-level: Use StakeClient for RPC operations
//! var client = stake.StakeClient.init(allocator, rpc);
//! const sig = try client.delegate(stake_account, vote_account, authority, signers);
//! ```

const std = @import("std");

/// Instruction builders and types
pub const instruction = @import("instruction.zig");

/// RPC client wrapper for stake operations
pub const client = @import("client.zig");
pub const StakeClient = client.StakeClient;

// Re-export instruction builders for convenience
pub const initialize = instruction.initialize;
pub const authorize = instruction.authorize;
pub const delegateStake = instruction.delegateStake;
pub const split = instruction.split;
pub const withdraw = instruction.withdraw;
pub const deactivate = instruction.deactivate;
pub const setLockup = instruction.setLockup;
pub const merge = instruction.merge;
pub const initializeChecked = instruction.initializeChecked;
pub const authorizeChecked = instruction.authorizeChecked;
pub const setLockupChecked = instruction.setLockupChecked;
pub const getMinimumDelegation = instruction.getMinimumDelegation;
pub const deactivateDelinquent = instruction.deactivateDelinquent;
pub const redelegate = instruction.redelegate;
pub const moveStake = instruction.moveStake;
pub const moveLamports = instruction.moveLamports;

// Re-export types
pub const StakeInstruction = instruction.StakeInstruction;
pub const Authorized = instruction.Authorized;
pub const Lockup = instruction.Lockup;
pub const LockupArgs = instruction.LockupArgs;
pub const LockupCheckedArgs = instruction.LockupCheckedArgs;
pub const StakeAuthorize = instruction.StakeAuthorize;
pub const STAKE_PROGRAM_ID = instruction.STAKE_PROGRAM_ID;
pub const STAKE_CONFIG_PROGRAM_ID = instruction.STAKE_CONFIG_PROGRAM_ID;

// Re-export sysvar constants
pub const CLOCK_SYSVAR = instruction.CLOCK_SYSVAR;
pub const RENT_SYSVAR = instruction.RENT_SYSVAR;
pub const STAKE_HISTORY_SYSVAR = instruction.STAKE_HISTORY_SYSVAR;

test {
    std.testing.refAllDecls(@This());
}
