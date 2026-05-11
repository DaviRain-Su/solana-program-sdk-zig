//! Sysvar accessors for Solana programs
//!
//! Provides types and access patterns for Solana sysvars.

const std = @import("std");
const pubkey = @import("pubkey.zig");
const account_mod = @import("account.zig");
const program_error = @import("program_error.zig");

const Pubkey = pubkey.Pubkey;
const AccountInfo = account_mod.AccountInfo;
const ProgramError = program_error.ProgramError;

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
    const data = account.dataUnchecked();
    if (data.len < @sizeOf(T)) {
        return ProgramError.InvalidAccountData;
    }
    return std.mem.bytesToValue(T, data[0..@sizeOf(T)]);
}

/// Clock sysvar — network time
pub const Clock = extern struct {
    /// The current slot
    slot: u64,
    /// The bank timestamp for the current slot
    epoch_start_timestamp: i64,
    /// The current epoch
    epoch: u64,
    /// The leader schedule epoch for the current slot
    leader_schedule_epoch: u64,
    /// The real-world timestamp for the current slot
    unix_timestamp: i64,
};

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

/// Rent sysvar
pub const Rent = extern struct {
    /// Rental rate in lamports per byte-year
    lamports_per_byte_year: u64,
    /// Exemption threshold in years
    exemption_threshold: f64,
    /// Burn percentage
    burn_percent: u8,

    /// Calculate minimum balance for rent exemption
    pub fn minimumBalance(self: Rent, data_len: usize) u64 {
        const bytes = data_len + 128; // account overhead
        return @intFromFloat(@as(f64, @floatFromInt(self.lamports_per_byte_year)) *
            self.exemption_threshold *
            @as(f64, @floatFromInt(bytes)));
    }

    /// Check if balance is exempt from rent
    pub fn isExempt(self: Rent, balance: u64, data_len: usize) bool {
        return balance >= self.minimumBalance(data_len);
    }
};

/// Slot hash entry
pub const SlotHash = extern struct {
    slot: u64,
    hash: [32]u8,
};

// =============================================================================
// Tests
// =============================================================================

test "sysvar: Clock size" {
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(Clock));
}

test "sysvar: Rent minimumBalance" {
    const rent = Rent{
        .lamports_per_byte_year = 3480,
        .exemption_threshold = 2.0,
        .burn_percent = 50,
    };

    const min_balance = rent.minimumBalance(100);
    try std.testing.expect(min_balance > 0);
}

test "sysvar: Rent isExempt" {
    const rent = Rent{
        .lamports_per_byte_year = 3480,
        .exemption_threshold = 2.0,
        .burn_percent = 50,
    };

    const min_balance = rent.minimumBalance(100);
    try std.testing.expect(rent.isExempt(min_balance, 100));
    try std.testing.expect(!rent.isExempt(min_balance - 1, 100));
}
