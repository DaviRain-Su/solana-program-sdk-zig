//! Zig implementation of Solana SDK's sysvar module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/sysvar/src/lib.rs
//!
//! This module provides unified access to all Solana system variables (sysvars).
//! Sysvars contain network state information and are updated by the runtime.
//! This module offers convenient functions to read and validate sysvar data.
//!
//! ## Available Sysvars
//! - Clock: Timing information (slot, epoch, timestamp)
//! - Rent: Account rent parameters
//! - SlotHashes: Recent slot hash information
//! - SlotHistory: Recent slot status information
//! - Instructions: Current transaction instructions
//! - EpochRewards: Epoch reward distribution info
//! - LastRestartSlot: Last network restart slot

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Clock = @import("clock.zig").Clock;
const Rent = @import("rent.zig").Rent;
const SlotHashes = @import("slot_hashes.zig").SlotHashes;
const SlotHistory = @import("slot_history.zig").SlotHistory;
// Instructions sysvar has a different API - no Instructions type
const EpochRewards = @import("epoch_rewards.zig").EpochRewards;
const LastRestartSlot = @import("last_restart_slot.zig").LastRestartSlot;
const SysvarId = @import("sysvar_id.zig");

// ============================================================================
// Sysvar Access Functions
// ============================================================================

/// Note: Sysvar data access
///
/// In Solana programs, sysvar data is typically accessed by passing
/// the sysvar account as a parameter to the program. The account data
/// can then be cast directly to the sysvar struct since they have
/// stable layouts.
///
/// Example:
/// ```zig
/// fn processInstruction(
///     program_id: *sdk.PublicKey,
///     accounts: []sdk.Account,
///     instruction_data: []const u8,
/// ) sdk.ProgramResult {
///     // accounts[0] should be the Clock sysvar account
///     const clock_data = @as(*const sdk.Clock, @ptrCast(accounts[0].data.ptr));
///     const current_slot = clock_data.slot;
///     // ...
/// }
/// ```
/// Get the Clock sysvar data
///
/// # Arguments
/// * `account_data` - The raw account data from the Clock sysvar account
///
/// # Returns
/// Parsed Clock data
///
/// # Errors
/// Returns error if account ID is invalid or data parsing fails
pub fn getClock(account_data: []const u8) !Clock {
    if (account_data.len < @sizeOf(Clock)) return error.InvalidData;
    return std.mem.bytesToValue(Clock, account_data[0..@sizeOf(Clock)]);
}

/// Get the Rent sysvar data
///
/// # Arguments
/// * `account_data` - The raw account data from the Rent sysvar account
///
/// # Returns
/// Parsed Rent data
///
/// # Errors
/// Returns error if account ID is invalid or data parsing fails
pub fn getRent(account_data: []const u8) !Rent.Data {
    if (account_data.len < @sizeOf(Rent.Data)) return error.InvalidData;
    return std.mem.bytesToValue(Rent.Data, account_data[0..@sizeOf(Rent.Data)]);
}

/// Get the SlotHashes sysvar data
///
/// # Arguments
/// * `account_data` - The raw account data from the SlotHashes sysvar account
///
/// # Returns
/// Parsed SlotHashes data
///
/// # Errors
/// Returns error if account ID is invalid or data parsing fails
pub fn getSlotHashes(account_data: []const u8) !SlotHashes {
    return SlotHashes.parse(account_data);
}

/// Get the SlotHistory sysvar data
///
/// # Arguments
/// * `account_data` - The raw account data from the SlotHistory sysvar account
///
/// # Returns
/// Parsed SlotHistory data
///
/// # Errors
/// Returns error if account ID is invalid or data parsing fails
pub fn getSlotHistory(account_data: []const u8) !SlotHistory {
    return SlotHistory.parse(account_data);
}

/// Note: Instructions sysvar has a different API
///
/// The Instructions sysvar is special and doesn't have a simple parse function.
/// Use the functions in instructions_sysvar.zig directly:
/// - `loadCurrentIndex()`
/// - `loadInstructionAt()`
/// - `getInstructionRelative()`
/// Get the EpochRewards sysvar data
///
/// # Arguments
/// * `account_data` - The raw account data from the EpochRewards sysvar account
///
/// # Returns
/// Parsed EpochRewards data
///
/// # Errors
/// Returns error if account ID is invalid or data parsing fails
pub fn getEpochRewards(account_data: []const u8) !EpochRewards {
    return EpochRewards.parse(account_data);
}

/// Get the LastRestartSlot sysvar data
///
/// # Arguments
/// * `account_data` - The raw account data from the LastRestartSlot sysvar account
///
/// # Returns
/// Parsed LastRestartSlot data
///
/// # Errors
/// Returns error if account ID is invalid or data parsing fails
pub fn getLastRestartSlot(account_data: []const u8) !LastRestartSlot {
    return LastRestartSlot.parse(account_data);
}

// ============================================================================
// Sysvar ID Validation Functions
// ============================================================================

/// Check if the given public key is the Clock sysvar ID
pub fn isClockId(pubkey: PublicKey) bool {
    return pubkey.equals(Clock.id);
}

/// Check if the given public key is the Rent sysvar ID
pub fn isRentId(pubkey: PublicKey) bool {
    return pubkey.equals(Rent.id);
}

/// Check if the given public key is the SlotHashes sysvar ID
pub fn isSlotHashesId(pubkey: PublicKey) bool {
    return pubkey.equals(SlotHashes.id);
}

/// Check if the given public key is the SlotHistory sysvar ID
pub fn isSlotHistoryId(pubkey: PublicKey) bool {
    return pubkey.equals(SlotHistory.id);
}

/// Check if the given public key is the Instructions sysvar ID
pub fn isInstructionsId(pubkey: PublicKey) bool {
    const instructions_mod = @import("instructions_sysvar.zig");
    return pubkey.equals(instructions_mod.ID);
}

/// Check if the given public key is the EpochRewards sysvar ID
pub fn isEpochRewardsId(pubkey: PublicKey) bool {
    return pubkey.equals(SysvarId.EPOCH_REWARDS);
}

/// Check if the given public key is the LastRestartSlot sysvar ID
pub fn isLastRestartSlotId(pubkey: PublicKey) bool {
    return pubkey.equals(SysvarId.LAST_RESTART_SLOT);
}

/// Check if the given public key is any known sysvar ID
pub fn isSysvarId(pubkey: PublicKey) bool {
    return isClockId(pubkey) or
        isRentId(pubkey) or
        isSlotHashesId(pubkey) or
        isSlotHistoryId(pubkey) or
        isInstructionsId(pubkey) or
        isEpochRewardsId(pubkey) or
        isLastRestartSlotId(pubkey);
}

// ============================================================================
// Tests
// ============================================================================

test "sysvar: direct data access example" {
    // Demonstrate how to access sysvar data directly
    // (This is how sysvars are typically used in Solana programs)

    // Clock data access example
    var clock_data: [40]u8 = undefined;
    std.mem.writeInt(u64, clock_data[0..8], 12345, .little); // slot

    // Cast to Clock struct
    const clock = std.mem.bytesToValue(Clock, &clock_data);
    try std.testing.expectEqual(@as(u64, 12345), clock.slot);

    // Rent data access example
    var rent_data: [17]u8 = undefined;
    std.mem.writeInt(u64, rent_data[0..8], 1000, .little); // lamports_per_byte_year
    @memcpy(rent_data[8..16], std.mem.asBytes(&@as(f64, 2.0))); // exemption_threshold
    rent_data[16] = 2; // burn_percent

    // Cast to Rent struct
    const rent = std.mem.bytesToValue(Rent.Data, &rent_data);
    try std.testing.expectEqual(@as(u64, 1000), rent.lamports_per_byte_year);
    try std.testing.expectEqual(@as(f64, 2.0), rent.exemption_threshold);
    try std.testing.expectEqual(@as(u8, 2), rent.burn_percent);
}

test "sysvar: isSysvarId checks" {
    try std.testing.expect(isClockId(Clock.id));
    try std.testing.expect(isRentId(Rent.id));
    try std.testing.expect(isSlotHashesId(SlotHashes.id));
    try std.testing.expect(isSlotHistoryId(SlotHistory.id));
    try std.testing.expect(isInstructionsId(@import("instructions_sysvar.zig").ID));
    try std.testing.expect(isEpochRewardsId(@import("sysvar_id.zig").EPOCH_REWARDS));
    try std.testing.expect(isLastRestartSlotId(@import("sysvar_id.zig").LAST_RESTART_SLOT));
}

test "sysvar: isSysvarId with non-sysvar key" {
    const fake_key = PublicKey.from([_]u8{0xFF} ** 32);
    try std.testing.expect(!isSysvarId(fake_key));
}

test "sysvar: getClock" {
    var data: [@sizeOf(Clock)]u8 = undefined;

    // Fill with test data
    std.mem.writeInt(u64, data[0..8], 12345, .little); // slot
    std.mem.writeInt(i64, data[8..16], 1609459200, .little); // epoch_start_timestamp
    std.mem.writeInt(u64, data[16..24], 42, .little); // epoch
    std.mem.writeInt(u64, data[24..32], 43, .little); // leader_schedule_epoch
    std.mem.writeInt(i64, data[32..40], 1609459200 + 3600, .little); // unix_timestamp

    const clock = try getClock(&data);
    try std.testing.expectEqual(@as(u64, 12345), clock.slot);
    try std.testing.expectEqual(@as(i64, 1609459200), clock.epoch_start_timestamp);
    try std.testing.expectEqual(@as(u64, 42), clock.epoch);
    try std.testing.expectEqual(@as(u64, 43), clock.leader_schedule_epoch);
    try std.testing.expectEqual(@as(i64, 1609459200 + 3600), clock.unix_timestamp);
}

test "sysvar: getRent" {
    var data: [@sizeOf(Rent.Data)]u8 = undefined;

    // Fill with test data
    std.mem.writeInt(u64, data[0..8], 1000, .little); // lamports_per_byte_year
    @memcpy(data[8..16], std.mem.asBytes(&@as(f64, 2.0))); // exemption_threshold
    data[16] = 50; // burn_percent

    const rent = try getRent(&data);
    try std.testing.expectEqual(@as(u64, 1000), rent.lamports_per_byte_year);
    try std.testing.expectEqual(@as(f64, 2.0), rent.exemption_threshold);
    try std.testing.expectEqual(@as(u8, 50), rent.burn_percent);
}

test "sysvar: getLastRestartSlot" {
    var data: [8]u8 = undefined;
    std.mem.writeInt(u64, &data, 999999, .little);

    const restart_slot = try getLastRestartSlot(&data);
    try std.testing.expectEqual(@as(u64, 999999), restart_slot.getSlot());
}

test "sysvar: getEpochRewards" {
    var data: [77]u8 = undefined;

    // Fill with test data
    std.mem.writeInt(u64, data[0..8], 1000000, .little); // distribution_starting_block_height
    std.mem.writeInt(u64, data[8..16], 10, .little); // num_partitions
    @memset(data[16..48], 0xAA); // parent_blockhash
    std.mem.writeInt(u64, data[48..56], 1000000, .little); // total_points
    std.mem.writeInt(u64, data[56..64], 5000000000, .little); // total_rewards
    std.mem.writeInt(u64, data[64..72], 2000000000, .little); // distributed_rewards
    data[72] = 1; // active

    const rewards = try getEpochRewards(&data);
    try std.testing.expectEqual(@as(u64, 5000000000), rewards.getTotalRewards());
    try std.testing.expect(rewards.isActive());
}
