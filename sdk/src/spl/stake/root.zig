//! Solana Stake Program Interface
//!
//! Rust source: https://github.com/solana-program/stake
//!
//! This module provides types for the Stake program that are shared between
//! on-chain programs and off-chain clients.
//!
//! ## Overview
//!
//! The Stake program is a core Solana native program for staking SOL to validators.
//! It implements a state machine for stake accounts:
//!
//! - Uninitialized: Account created but not initialized
//! - Initialized: Account has metadata but no stake delegation
//! - Stake: Account has active stake delegation to a validator
//! - RewardsPool: Deprecated rewards pool (not used in practice)
//!
//! ## Modules
//!
//! - `state`: Core state types (StakeStateV2, Meta, Stake, Delegation, etc.)
//! - `instruction`: Instruction enum and argument types
//! - `stake_history`: Stake history tracking types
//! - `tools`: Utility functions for delinquent vote detection
//! - `error`: StakeError enum
//!
//! ## Usage
//!
//! ```zig
//! const sdk = @import("solana_sdk");
//! const stake = sdk.spl.stake;
//!
//! // Parse stake account state
//! const state = try stake.StakeStateV2.unpack(account_data);
//! if (state.stake()) |s| {
//!     const voter = s.delegation.voter_pubkey;
//!     const amount = s.delegation.stake;
//! }
//!
//! // Calculate effective stake with warmup
//! const effective = delegation.getStake(current_epoch, history, null);
//!
//! // Check if vote account is delinquent
//! if (stake.tools.eligibleForDeactivateDelinquent(epoch_credits, current_epoch)) {
//!     // Can use DeactivateDelinquent instruction
//! }
//! ```

const std = @import("std");

// State types
pub const state = @import("state.zig");
pub const StakeStateV2 = state.StakeStateV2;
pub const Meta = state.Meta;
pub const Authorized = state.Authorized;
pub const Lockup = state.Lockup;
pub const Stake = state.Stake;
pub const Delegation = state.Delegation;
pub const StakeFlags = state.StakeFlags;
pub const StakeAuthorize = state.StakeAuthorize;
pub const LockupArgs = state.LockupArgs;
pub const LockupCheckedArgs = state.LockupCheckedArgs;
pub const StakeActivationStatus = state.StakeActivationStatus;

// Stake History types
pub const stake_history = @import("stake_history.zig");
pub const StakeHistory = stake_history.StakeHistory;
pub const StakeHistoryEntry = stake_history.StakeHistoryEntry;
pub const MAX_STAKE_HISTORY_ENTRIES = stake_history.MAX_ENTRIES;

// Tools/utilities
pub const tools = @import("tools.zig");
pub const acceptableReferenceEpochCredits = tools.acceptableReferenceEpochCredits;
pub const eligibleForDeactivateDelinquent = tools.eligibleForDeactivateDelinquent;
pub const EpochCredits = tools.EpochCredits;

// Instruction types
pub const instruction = @import("instruction.zig");
pub const StakeInstruction = instruction.StakeInstruction;
pub const AuthorizeWithSeedArgs = instruction.AuthorizeWithSeedArgs;
pub const AuthorizeCheckedWithSeedArgs = instruction.AuthorizeCheckedWithSeedArgs;

// Error types
pub const err = @import("error.zig");
pub const StakeError = err.StakeError;

// Program IDs
pub const STAKE_PROGRAM_ID = state.STAKE_PROGRAM_ID;
pub const STAKE_CONFIG_PROGRAM_ID = state.STAKE_CONFIG_PROGRAM_ID;

// Constants
pub const EPOCH_MAX = state.EPOCH_MAX;
pub const DEFAULT_WARMUP_COOLDOWN_RATE = state.DEFAULT_WARMUP_COOLDOWN_RATE;
pub const NEW_WARMUP_COOLDOWN_RATE = state.NEW_WARMUP_COOLDOWN_RATE;
pub const DEFAULT_SLASH_PENALTY = state.DEFAULT_SLASH_PENALTY;
pub const MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION = state.MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION;

// Functions
pub const warmupCooldownRate = state.warmupCooldownRate;

// Size constants
pub const STAKE_STATE_V2_SIZE = state.STAKE_STATE_V2_SIZE;
pub const META_SIZE = state.META_SIZE;
pub const STAKE_SIZE = state.STAKE_SIZE;
pub const DELEGATION_SIZE = state.DELEGATION_SIZE;
pub const AUTHORIZED_SIZE = state.AUTHORIZED_SIZE;
pub const LOCKUP_SIZE = state.LOCKUP_SIZE;
pub const STAKE_FLAGS_SIZE = state.STAKE_FLAGS_SIZE;
pub const STAKE_HISTORY_ENTRY_SIZE = stake_history.StakeHistoryEntry.SIZE;

test {
    std.testing.refAllDecls(@This());
}
