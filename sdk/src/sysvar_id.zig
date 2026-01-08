//! Zig implementation of Solana SDK's sysvar-ids module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/sysvar-ids/src/lib.rs
//!
//! This module provides the fixed public key constants for all Solana system
//! variable accounts. These are special accounts that contain network state
//! information and are updated by the runtime.
//!
//! All sysvar accounts have fixed, well-known public keys that never change.

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

/// Clock sysvar public key
///
/// The Clock sysvar contains timing information about the current slot,
/// epoch, and unix timestamp.
pub const CLOCK = PublicKey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");

/// Rent sysvar public key
///
/// The Rent sysvar contains the current rent parameters for accounts.
pub const RENT = PublicKey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");

/// Slot hashes sysvar public key
///
/// The SlotHashes sysvar contains recent slot hash information.
pub const SLOT_HASHES = PublicKey.comptimeFromBase58("SysvarS1otHashes111111111111111111111111111");

/// Slot history sysvar public key
///
/// The SlotHistory sysvar contains information about recent slots.
pub const SLOT_HISTORY = PublicKey.comptimeFromBase58("SysvarS1otHistory11111111111111111111111111");

/// Stake history sysvar public key
///
/// The StakeHistory sysvar contains staking reward information.
pub const STAKE_HISTORY = PublicKey.comptimeFromBase58("SysvarStakeHistory1111111111111111111111111");

/// Instructions sysvar public key
///
/// The Instructions sysvar contains the current transaction's instruction data.
pub const INSTRUCTIONS = PublicKey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");

/// Epoch rewards sysvar public key
///
/// The EpochRewards sysvar contains information about epoch reward distribution.
pub const EPOCH_REWARDS = PublicKey.comptimeFromBase58("SysvarEpochRewards1111111111111111111111111");

/// Last restart slot sysvar public key
///
/// The LastRestartSlot sysvar contains the slot number of the last network restart.
pub const LAST_RESTART_SLOT = PublicKey.comptimeFromBase58("SysvarLastRestartS1ot1111111111111111111111");

/// Recent blockhashes sysvar public key
///
/// The RecentBlockhashes sysvar contains recent block hashes.
/// Note: This sysvar is deprecated but still used by nonce operations.
pub const RECENT_BLOCKHASHES = PublicKey.comptimeFromBase58("SysvarRecentB1ockHashes11111111111111111111");

/// Epoch schedule sysvar public key
///
/// The EpochSchedule sysvar contains the epoch schedule parameters.
pub const EPOCH_SCHEDULE = PublicKey.comptimeFromBase58("SysvarEpochSchedu1e111111111111111111111111");

/// Fees sysvar public key (deprecated)
///
/// The Fees sysvar contained fee rate information. Now deprecated.
pub const FEES = PublicKey.comptimeFromBase58("SysvarFees111111111111111111111111111111111");

/// All sysvar IDs as an array
///
/// This array contains all the sysvar public keys for convenience.
pub const ALL_IDS = [_]PublicKey{
    CLOCK,
    RENT,
    SLOT_HASHES,
    SLOT_HISTORY,
    STAKE_HISTORY,
    INSTRUCTIONS,
    EPOCH_REWARDS,
    LAST_RESTART_SLOT,
    RECENT_BLOCKHASHES,
    EPOCH_SCHEDULE,
    FEES,
};

// ============================================================================
// Tests
// ============================================================================

test "sysvar-ids: CLOCK constant" {
    const expected = "SysvarC1ock11111111111111111111111111111111";
    var buffer: [44]u8 = undefined;
    const result = CLOCK.toBase58(&buffer);
    try std.testing.expectEqualStrings(expected, result);
}

test "sysvar-ids: RENT constant" {
    const expected = "SysvarRent111111111111111111111111111111111";
    var buffer: [44]u8 = undefined;
    const result = RENT.toBase58(&buffer);
    try std.testing.expectEqualStrings(expected, result);
}

test "sysvar-ids: STAKE_HISTORY constant" {
    const expected = "SysvarStakeHistory1111111111111111111111111";
    var buffer: [44]u8 = undefined;
    const result = STAKE_HISTORY.toBase58(&buffer);
    try std.testing.expectEqualStrings(expected, result);
}

test "sysvar-ids: ALL_IDS array" {
    try std.testing.expectEqual(@as(usize, 11), ALL_IDS.len);

    // Verify all IDs are present
    try std.testing.expect(CLOCK.equals(ALL_IDS[0]));
    try std.testing.expect(RENT.equals(ALL_IDS[1]));
    try std.testing.expect(STAKE_HISTORY.equals(ALL_IDS[4]));
}
