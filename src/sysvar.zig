//! Sysvar accessors for Solana programs
//!
//! Provides types and access patterns for Solana sysvars.
//!
//! - `getSysvar(T, account)` deserializes data from a sysvar account the
//!   caller has passed into the program.
//! - For the most common sysvars (Clock, Rent) prefer the syscall-based
//!   wrappers in `clock.zig` / `rent.zig`, which do not require the
//!   sysvar account to be listed in the instruction's accounts.

const std = @import("std");
const pubkey = @import("pubkey.zig");
const account_mod = @import("account.zig");
const program_error = @import("program_error.zig");
const clock_mod = @import("clock.zig");
const rent_mod = @import("rent.zig");

const Pubkey = pubkey.Pubkey;
const AccountInfo = account_mod.AccountInfo;
const ProgramError = program_error.ProgramError;

/// Clock sysvar — re-exported from `clock.zig` so it is the single
/// canonical type in the SDK.
pub const Clock = clock_mod.Clock;

/// Rent sysvar data — re-exported from `rent.zig`.
pub const Rent = rent_mod.Rent.Data;

/// Clock sysvar ID
pub const CLOCK_ID: Pubkey = pubkey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");

/// Rent sysvar ID
pub const RENT_ID: Pubkey = pubkey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");

/// Epoch schedule sysvar ID
pub const EPOCH_SCHEDULE_ID: Pubkey = pubkey.comptimeFromBase58("SysvarEpochSchedu1e111111111111111111111111");

/// Slot hashes sysvar ID
pub const SLOT_HASHES_ID: Pubkey = pubkey.comptimeFromBase58("SysvarS1otHashes111111111111111111111111111");

/// Stake history sysvar ID
pub const STAKE_HISTORY_ID: Pubkey = pubkey.comptimeFromBase58("SysvarStakeHistory1111111111111111111111111");

/// Instructions sysvar ID
pub const INSTRUCTIONS_ID: Pubkey = pubkey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");

/// Get sysvar data from an account
///
/// The account must be the sysvar account. This function deserializes
/// the account data into the requested type.
pub fn getSysvar(comptime T: type, account: AccountInfo) ProgramError!T {
    const data = account.data();
    if (data.len < @sizeOf(T)) {
        return ProgramError.InvalidAccountData;
    }
    return std.mem.bytesToValue(T, data[0..@sizeOf(T)]);
}

/// Epoch schedule sysvar
pub const EpochSchedule = extern struct {
    /// The maximum number of slots in each epoch
    slots_per_epoch: u64,
    /// The number of slots before the first epoch
    leader_schedule_slot_offset: u64,
    /// Whether epochs are warm-up epochs
    warmup: bool,
    /// The first epoch after warm-up
    first_normal_epoch: u64,
    /// The first slot after warm-up
    first_normal_slot: u64,
};

/// Slot hash entry
pub const SlotHash = extern struct {
    slot: u64,
    hash: [32]u8,
};

// =============================================================================
// Tests
// =============================================================================

test "sysvar: Clock re-export points to clock.Clock" {
    try std.testing.expectEqual(@sizeOf(clock_mod.Clock), @sizeOf(Clock));
}

test "sysvar: Rent re-export points to rent.Rent.Data" {
    const r: Rent = .{};
    try std.testing.expect(r.lamports_per_byte_year > 0);
}
