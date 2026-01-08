//! SPL Stake program instruction builders (Client)
//!
//! Rust source: https://github.com/solana-program/stake/blob/master/program/src/instruction.rs
//!
//! This module re-exports instruction builders from the SDK.
//! All implementations are in `sdk/src/spl/stake/instruction.zig`.

const sdk = @import("solana_sdk");
const sdk_stake = sdk.spl.stake;

// Re-export types from SDK
pub const StakeInstruction = sdk_stake.StakeInstruction;
pub const Authorized = sdk_stake.Authorized;
pub const Lockup = sdk_stake.Lockup;
pub const LockupArgs = sdk_stake.LockupArgs;
pub const LockupCheckedArgs = sdk_stake.LockupCheckedArgs;
pub const StakeAuthorize = sdk_stake.StakeAuthorize;
pub const STAKE_PROGRAM_ID = sdk_stake.STAKE_PROGRAM_ID;
pub const STAKE_CONFIG_PROGRAM_ID = sdk_stake.STAKE_CONFIG_PROGRAM_ID;

// Re-export sysvar IDs
pub const CLOCK_SYSVAR = sdk_stake.CLOCK_SYSVAR;
pub const RENT_SYSVAR = sdk_stake.RENT_SYSVAR;
pub const STAKE_HISTORY_SYSVAR = sdk_stake.STAKE_HISTORY_SYSVAR;

// Re-export instruction builders
pub const initialize = sdk_stake.initialize;
pub const authorize = sdk_stake.authorize;
pub const delegateStake = sdk_stake.delegateStake;
pub const split = sdk_stake.split;
pub const withdraw = sdk_stake.withdraw;
pub const deactivate = sdk_stake.deactivate;
pub const setLockup = sdk_stake.setLockup;
pub const merge = sdk_stake.merge;
pub const initializeChecked = sdk_stake.initializeChecked;
pub const authorizeChecked = sdk_stake.authorizeChecked;
pub const setLockupChecked = sdk_stake.setLockupChecked;
pub const getMinimumDelegation = sdk_stake.getMinimumDelegation;
pub const deactivateDelinquent = sdk_stake.deactivateDelinquent;
pub const redelegate = sdk_stake.redelegate;
pub const moveStake = sdk_stake.moveStake;
pub const moveLamports = sdk_stake.moveLamports;

// Re-export data size constants
pub const MAX_INITIALIZE_DATA_SIZE = sdk_stake.instruction.MAX_INITIALIZE_DATA_SIZE;
pub const AUTHORIZE_DATA_SIZE = sdk_stake.instruction.AUTHORIZE_DATA_SIZE;
pub const DELEGATE_STAKE_DATA_SIZE = sdk_stake.instruction.DELEGATE_STAKE_DATA_SIZE;
pub const SPLIT_DATA_SIZE = sdk_stake.instruction.SPLIT_DATA_SIZE;
pub const WITHDRAW_DATA_SIZE = sdk_stake.instruction.WITHDRAW_DATA_SIZE;
pub const DEACTIVATE_DATA_SIZE = sdk_stake.instruction.DEACTIVATE_DATA_SIZE;
pub const MAX_SET_LOCKUP_DATA_SIZE = sdk_stake.instruction.MAX_SET_LOCKUP_DATA_SIZE;
pub const MERGE_DATA_SIZE = sdk_stake.instruction.MERGE_DATA_SIZE;
pub const INITIALIZE_CHECKED_DATA_SIZE = sdk_stake.instruction.INITIALIZE_CHECKED_DATA_SIZE;
pub const AUTHORIZE_CHECKED_DATA_SIZE = sdk_stake.instruction.AUTHORIZE_CHECKED_DATA_SIZE;
pub const MAX_SET_LOCKUP_CHECKED_DATA_SIZE = sdk_stake.instruction.MAX_SET_LOCKUP_CHECKED_DATA_SIZE;
pub const GET_MINIMUM_DELEGATION_DATA_SIZE = sdk_stake.instruction.GET_MINIMUM_DELEGATION_DATA_SIZE;
pub const DEACTIVATE_DELINQUENT_DATA_SIZE = sdk_stake.instruction.DEACTIVATE_DELINQUENT_DATA_SIZE;
pub const REDELEGATE_DATA_SIZE = sdk_stake.instruction.REDELEGATE_DATA_SIZE;
pub const MOVE_STAKE_DATA_SIZE = sdk_stake.instruction.MOVE_STAKE_DATA_SIZE;
pub const MOVE_LAMPORTS_DATA_SIZE = sdk_stake.instruction.MOVE_LAMPORTS_DATA_SIZE;

// Tests are in SDK - this module is just re-exports
