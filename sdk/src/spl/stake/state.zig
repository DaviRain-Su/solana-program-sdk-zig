//! Zig implementation of Solana Stake program state types
//!
//! Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
//!
//! This module provides state types for the Stake program:
//! - StakeStateV2: Main stake account state enum
//! - Meta: Metadata about a stake account
//! - Authorized: Authorized staker and withdrawer
//! - Lockup: Lockup restrictions
//! - Stake: Active stake with delegation
//! - Delegation: Stake delegation information
//! - StakeFlags: Bitflags for stake state

const std = @import("std");
const PublicKey = @import("../../public_key.zig").PublicKey;

// Import stake history types
const stake_history = @import("stake_history.zig");
pub const StakeHistoryEntry = stake_history.StakeHistoryEntry;
pub const StakeHistory = stake_history.StakeHistory;

/// Type alias for stake activation status (same as StakeHistoryEntry)
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L30
pub const StakeActivationStatus = StakeHistoryEntry;

// ============================================================================
// Program ID
// ============================================================================

/// Stake Program ID
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/lib.rs
pub const STAKE_PROGRAM_ID = PublicKey.comptimeFromBase58("Stake11111111111111111111111111111111111111");

/// Stake Config Program ID
pub const STAKE_CONFIG_PROGRAM_ID = PublicKey.comptimeFromBase58("StakeConfig11111111111111111111111111111111");

// ============================================================================
// Constants
// ============================================================================

/// Default warmup/cooldown rate for stake activation/deactivation
/// This represents the fraction of stake that can be activated/deactivated per epoch
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L14
pub const DEFAULT_WARMUP_COOLDOWN_RATE: f64 = 0.25;

/// New warmup/cooldown rate (post feature activation)
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L15
pub const NEW_WARMUP_COOLDOWN_RATE: f64 = 0.09;

/// Default slash penalty (5% of stake)
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L16
pub const DEFAULT_SLASH_PENALTY: u8 = @intCast((5 * @as(usize, 255)) / 100);

/// Maximum value for deactivation_epoch indicating the stake is not deactivating
pub const EPOCH_MAX: u64 = std.math.maxInt(u64);

/// The minimum number of epochs before stake account that is delegated to a delinquent vote
/// account may be unstaked with `StakeInstruction::DeactivateDelinquent`
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/lib.rs#L17
pub const MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION: usize = 5;

// ============================================================================
// Functions
// ============================================================================

/// Get the warmup/cooldown rate based on epoch and feature activation.
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L18-L28
///
/// # Arguments
/// * `current_epoch` - The current epoch
/// * `new_rate_activation_epoch` - The epoch when the new rate feature was activated (if any)
///
/// # Returns
/// The warmup/cooldown rate to use for stake calculations
pub fn warmupCooldownRate(current_epoch: u64, new_rate_activation_epoch: ?u64) f64 {
    if (new_rate_activation_epoch) |activation_epoch| {
        if (current_epoch >= activation_epoch) {
            return NEW_WARMUP_COOLDOWN_RATE;
        }
    }
    return DEFAULT_WARMUP_COOLDOWN_RATE;
}

// ============================================================================
// Size Constants
// ============================================================================

/// Size of Authorized structure in bytes (2 * 32 = 64)
pub const AUTHORIZED_SIZE: usize = 64;

/// Size of Lockup structure in bytes (8 + 8 + 32 = 48)
pub const LOCKUP_SIZE: usize = 48;

/// Size of Meta structure in bytes (8 + 64 + 48 = 120)
pub const META_SIZE: usize = 120;

/// Size of Delegation structure in bytes (32 + 8 + 8 + 8 + 8 = 64)
/// Note: warmup_cooldown_rate is deprecated and stored as 8 bytes
pub const DELEGATION_SIZE: usize = 64;

/// Size of Stake structure in bytes (64 + 8 = 72)
pub const STAKE_SIZE: usize = 72;

/// Size of StakeFlags in bytes
pub const STAKE_FLAGS_SIZE: usize = 1;

/// Size of StakeStateV2 discriminant
pub const STAKE_STATE_DISCRIMINANT_SIZE: usize = 4;

/// Total size of StakeStateV2::Stake variant
/// = discriminant(4) + meta(120) + stake(72) + flags(1) + padding
pub const STAKE_STATE_V2_SIZE: usize = 200;

// ============================================================================
// StakeFlags
// ============================================================================

/// Stake account flags
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
pub const StakeFlags = packed struct {
    /// Currently active and contributing to vote rewards
    must_fully_activate_before_deactivation_is_permitted: bool = false,
    _reserved: u7 = 0,

    pub const EMPTY: StakeFlags = .{};

    pub const MUST_FULLY_ACTIVATE_BEFORE_DEACTIVATION_IS_PERMITTED: StakeFlags = .{
        .must_fully_activate_before_deactivation_is_permitted = true,
    };

    /// Check if empty (no flags set)
    pub fn isEmpty(self: StakeFlags) bool {
        return !self.must_fully_activate_before_deactivation_is_permitted;
    }

    /// Check if must fully activate before deactivation is permitted
    pub fn mustFullyActivateBeforeDeactivation(self: StakeFlags) bool {
        return self.must_fully_activate_before_deactivation_is_permitted;
    }

    /// Convert to byte
    pub fn toByte(self: StakeFlags) u8 {
        return @bitCast(self);
    }

    /// Convert from byte
    pub fn fromByte(byte: u8) StakeFlags {
        return @bitCast(byte);
    }

    /// Union with another StakeFlags
    pub fn @"union"(self: StakeFlags, other: StakeFlags) StakeFlags {
        return .{
            .must_fully_activate_before_deactivation_is_permitted = self.must_fully_activate_before_deactivation_is_permitted or
                other.must_fully_activate_before_deactivation_is_permitted,
        };
    }

    /// Check if contains all flags from other
    pub fn contains(self: StakeFlags, other: StakeFlags) bool {
        if (other.must_fully_activate_before_deactivation_is_permitted and
            !self.must_fully_activate_before_deactivation_is_permitted)
        {
            return false;
        }
        return true;
    }

    /// Set flag for must fully activate
    pub fn setMustFullyActivate(self: *StakeFlags) void {
        self.must_fully_activate_before_deactivation_is_permitted = true;
    }

    /// Remove flag for must fully activate
    pub fn removeMustFullyActivate(self: *StakeFlags) void {
        self.must_fully_activate_before_deactivation_is_permitted = false;
    }
};

// ============================================================================
// Authorized
// ============================================================================

/// Authorized staker and withdrawer
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
///
/// Layout (64 bytes):
/// - bytes[0..32]: staker (Pubkey)
/// - bytes[32..64]: withdrawer (Pubkey)
pub const Authorized = struct {
    /// Public key that can stake the account
    staker: PublicKey,
    /// Public key that can withdraw from the account
    withdrawer: PublicKey,

    /// Size in bytes
    pub const SIZE: usize = AUTHORIZED_SIZE;

    /// Create a new Authorized with the same key for both staker and withdrawer
    pub fn auto(authorized_pubkey: PublicKey) Authorized {
        return .{
            .staker = authorized_pubkey,
            .withdrawer = authorized_pubkey,
        };
    }

    /// Check if a pubkey is authorized for the given stake authorize type
    pub fn check(self: Authorized, signers: []const PublicKey, stake_authorize: StakeAuthorize) bool {
        const authorized_key = switch (stake_authorize) {
            .Staker => self.staker,
            .Withdrawer => self.withdrawer,
        };
        for (signers) |signer| {
            if (signer.equals(authorized_key)) return true;
        }
        return false;
    }

    /// Unpack from bytes
    pub fn unpack(data: []const u8) !Authorized {
        if (data.len < SIZE) return error.InvalidAccountData;
        return .{
            .staker = PublicKey.from(data[0..32].*),
            .withdrawer = PublicKey.from(data[32..64].*),
        };
    }

    /// Pack into bytes
    ///
    /// Returns error.InvalidAccountData if dest buffer is too small.
    pub fn pack(self: Authorized, dest: []u8) !void {
        if (dest.len < SIZE) return error.InvalidAccountData;
        @memcpy(dest[0..32], &self.staker.bytes);
        @memcpy(dest[32..64], &self.withdrawer.bytes);
    }
};

/// Type of stake authorization
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
pub const StakeAuthorize = enum(u32) {
    /// Authority to stake
    Staker = 0,
    /// Authority to withdraw
    Withdrawer = 1,

    /// Convert from u32
    pub fn fromU32(value: u32) ?StakeAuthorize {
        return std.meta.intToEnum(StakeAuthorize, value) catch null;
    }

    /// Convert to u32
    pub fn toU32(self: StakeAuthorize) u32 {
        return @intFromEnum(self);
    }
};

// ============================================================================
// Lockup
// ============================================================================

/// Lockup restrictions on a stake account
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
///
/// Layout (48 bytes):
/// - bytes[0..8]: unix_timestamp (i64, little-endian)
/// - bytes[8..16]: epoch (u64, little-endian)
/// - bytes[16..48]: custodian (Pubkey)
pub const Lockup = struct {
    /// UnixTimestamp at which this stake will allow withdrawal,
    /// unless the transaction is signed by the custodian
    unix_timestamp: i64,
    /// Epoch height at which this stake will allow withdrawal,
    /// unless the transaction is signed by the custodian
    epoch: u64,
    /// Custodian signature on a transaction exempts the operation
    /// from lockup constraints
    custodian: PublicKey,

    /// Size in bytes
    pub const SIZE: usize = LOCKUP_SIZE;

    /// Default lockup (no restrictions)
    pub const DEFAULT: Lockup = .{
        .unix_timestamp = 0,
        .epoch = 0,
        .custodian = PublicKey.default(),
    };

    /// Check if lockup is in force at the given clock
    pub fn isInForce(self: Lockup, clock_unix_timestamp: i64, clock_epoch: u64) bool {
        return self.unix_timestamp > clock_unix_timestamp or self.epoch > clock_epoch;
    }

    /// Unpack from bytes
    pub fn unpack(data: []const u8) !Lockup {
        if (data.len < SIZE) return error.InvalidAccountData;
        return .{
            .unix_timestamp = std.mem.readInt(i64, data[0..8], .little),
            .epoch = std.mem.readInt(u64, data[8..16], .little),
            .custodian = PublicKey.from(data[16..48].*),
        };
    }

    /// Pack into bytes
    ///
    /// Returns error.InvalidAccountData if dest buffer is too small.
    pub fn pack(self: Lockup, dest: []u8) !void {
        if (dest.len < SIZE) return error.InvalidAccountData;
        std.mem.writeInt(i64, dest[0..8], self.unix_timestamp, .little);
        std.mem.writeInt(u64, dest[8..16], self.epoch, .little);
        @memcpy(dest[16..48], &self.custodian.bytes);
    }
};

// ============================================================================
// Meta
// ============================================================================

/// Meta contains information about a stake account
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
///
/// Layout (120 bytes):
/// - bytes[0..8]: rent_exempt_reserve (u64, little-endian)
/// - bytes[8..72]: authorized (Authorized, 64 bytes)
/// - bytes[72..120]: lockup (Lockup, 48 bytes)
pub const Meta = struct {
    /// Rent exempt reserve for the account
    rent_exempt_reserve: u64,
    /// Authorized staker and withdrawer
    authorized: Authorized,
    /// Lockup restrictions
    lockup: Lockup,

    /// Size in bytes
    pub const SIZE: usize = META_SIZE;

    /// Create a new Meta with auto-authorization
    pub fn auto(authorized_pubkey: *const PublicKey) Meta {
        return .{
            .rent_exempt_reserve = 0,
            .authorized = Authorized.auto(authorized_pubkey.*),
            .lockup = Lockup.DEFAULT,
        };
    }

    /// Set lockup
    pub fn setLockup(self: *Meta, lockup_args: LockupArgs, signers: []const PublicKey, clock: anytype) !void {
        // Check if custodian signed
        const custodian_signed = for (signers) |signer| {
            if (signer.equals(self.lockup.custodian)) break true;
        } else false;

        // Only custodian or withdrawer can change lockup
        if (!custodian_signed) {
            const withdrawer_signed = for (signers) |signer| {
                if (signer.equals(self.authorized.withdrawer)) break true;
            } else false;

            if (!withdrawer_signed) return error.CustodianMissing;

            // Withdrawer can only change lockup if it's not in force
            if (self.lockup.isInForce(clock.unix_timestamp, clock.epoch)) {
                return error.LockupInForce;
            }
        }

        if (lockup_args.unix_timestamp) |ts| self.lockup.unix_timestamp = ts;
        if (lockup_args.epoch) |e| self.lockup.epoch = e;
        if (lockup_args.custodian) |c| self.lockup.custodian = c;
    }

    /// Unpack from bytes
    pub fn unpack(data: []const u8) !Meta {
        if (data.len < SIZE) return error.InvalidAccountData;
        return .{
            .rent_exempt_reserve = std.mem.readInt(u64, data[0..8], .little),
            .authorized = try Authorized.unpack(data[8..72]),
            .lockup = try Lockup.unpack(data[72..120]),
        };
    }

    /// Pack into bytes
    ///
    /// Returns error.InvalidAccountData if dest buffer is too small.
    pub fn pack(self: Meta, dest: []u8) !void {
        if (dest.len < SIZE) return error.InvalidAccountData;
        std.mem.writeInt(u64, dest[0..8], self.rent_exempt_reserve, .little);
        try self.authorized.pack(dest[8..72]);
        try self.lockup.pack(dest[72..120]);
    }
};

/// Lockup arguments for SetLockup instruction
pub const LockupArgs = struct {
    unix_timestamp: ?i64 = null,
    epoch: ?u64 = null,
    custodian: ?PublicKey = null,
};

/// Lockup checked arguments (with custodian as signer)
pub const LockupCheckedArgs = struct {
    unix_timestamp: ?i64 = null,
    epoch: ?u64 = null,
};

// ============================================================================
// Delegation
// ============================================================================

/// Stake delegation information
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
///
/// Layout (64 bytes):
/// - bytes[0..32]: voter_pubkey (Pubkey)
/// - bytes[32..40]: stake (u64, little-endian)
/// - bytes[40..48]: activation_epoch (u64, little-endian)
/// - bytes[48..56]: deactivation_epoch (u64, little-endian)
/// - bytes[56..64]: warmup_cooldown_rate (f64, deprecated, always 0.0)
pub const Delegation = struct {
    /// To whom the stake is delegated
    voter_pubkey: PublicKey,
    /// Activated stake amount, set at delegate() time
    stake: u64,
    /// Epoch at which this stake was activated
    activation_epoch: u64,
    /// Epoch at which this stake was deactivated
    /// EPOCH_MAX if not deactivated
    deactivation_epoch: u64,

    /// Size in bytes
    pub const SIZE: usize = DELEGATION_SIZE;

    /// Create a new delegation
    pub fn new(voter_pubkey: *const PublicKey, stake: u64, activation_epoch: u64) Delegation {
        return .{
            .voter_pubkey = voter_pubkey.*,
            .stake = stake,
            .activation_epoch = activation_epoch,
            .deactivation_epoch = EPOCH_MAX,
        };
    }

    /// Check if stake is in the activating phase (activation epoch has arrived but not yet past)
    ///
    /// Returns true if we're at or after the activation epoch but before we're fully activated.
    /// Note: A stake is "activating" at activation_epoch, becomes "active" after warmup completes.
    pub fn isActivating(self: Delegation, current_epoch: u64) bool {
        // Bootstrap stakes are never "activating" - they're immediately effective
        if (self.isBootstrap()) return false;
        // Must be at or after activation epoch, not deactivated, and at the activation epoch itself
        return current_epoch == self.activation_epoch and
            self.deactivation_epoch == EPOCH_MAX;
    }

    /// Check if stake is deactivating
    ///
    /// Returns true if deactivation has started (current_epoch >= deactivation_epoch)
    /// and deactivation_epoch is not EPOCH_MAX.
    pub fn isDeactivating(self: Delegation, current_epoch: u64) bool {
        return self.deactivation_epoch != EPOCH_MAX and
            current_epoch >= self.deactivation_epoch;
    }

    /// Check if stake is active (past activation epoch and not deactivating)
    ///
    /// A stake is "active" when:
    /// - It's a bootstrap stake (activation_epoch == EPOCH_MAX), OR
    /// - Current epoch is past the activation epoch AND not deactivating
    pub fn isActive(self: Delegation, current_epoch: u64) bool {
        // Bootstrap stakes are always active (when not deactivating)
        if (self.isBootstrap()) {
            return self.deactivation_epoch == EPOCH_MAX or current_epoch < self.deactivation_epoch;
        }
        // Normal stakes: must be past activation epoch and not deactivating
        return current_epoch > self.activation_epoch and
            (self.deactivation_epoch == EPOCH_MAX or current_epoch < self.deactivation_epoch);
    }

    /// Deactivate the stake
    pub fn deactivate(self: *Delegation, epoch: u64) !void {
        if (self.deactivation_epoch != EPOCH_MAX) {
            return error.AlreadyDeactivated;
        }
        self.deactivation_epoch = epoch;
    }

    /// Unpack from bytes
    pub fn unpack(data: []const u8) !Delegation {
        if (data.len < SIZE) return error.InvalidAccountData;
        return .{
            .voter_pubkey = PublicKey.from(data[0..32].*),
            .stake = std.mem.readInt(u64, data[32..40], .little),
            .activation_epoch = std.mem.readInt(u64, data[40..48], .little),
            .deactivation_epoch = std.mem.readInt(u64, data[48..56], .little),
            // bytes[56..64] is warmup_cooldown_rate (deprecated f64, ignored)
        };
    }

    /// Pack into bytes
    ///
    /// Returns error.InvalidAccountData if dest buffer is too small.
    pub fn pack(self: Delegation, dest: []u8) !void {
        if (dest.len < SIZE) return error.InvalidAccountData;
        @memcpy(dest[0..32], &self.voter_pubkey.bytes);
        std.mem.writeInt(u64, dest[32..40], self.stake, .little);
        std.mem.writeInt(u64, dest[40..48], self.activation_epoch, .little);
        std.mem.writeInt(u64, dest[48..56], self.deactivation_epoch, .little);
        // Write deprecated warmup_cooldown_rate as 0.0
        std.mem.writeInt(u64, dest[56..64], 0, .little);
    }

    /// Check if this is a bootstrap stake (activation_epoch == u64::MAX)
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L319-L321
    ///
    /// Bootstrap stakes are special stakes that are immediately fully effective.
    pub fn isBootstrap(self: Delegation) bool {
        return self.activation_epoch == EPOCH_MAX;
    }

    /// Calculate the effective stake at a given epoch.
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L323-L340
    ///
    /// This accounts for warmup and cooldown periods. During activation,
    /// stake gradually becomes effective. During deactivation, effective
    /// stake gradually decreases.
    ///
    /// # Arguments
    /// * `target_epoch` - The epoch to calculate stake for
    /// * `history` - Stake history for warmup/cooldown calculations
    /// * `new_rate_activation_epoch` - Epoch when new rate was activated (if any)
    ///
    /// # Returns
    /// The effective stake amount at the target epoch
    pub fn getStake(
        self: Delegation,
        target_epoch: u64,
        history: ?StakeHistory,
        new_rate_activation_epoch: ?u64,
    ) u64 {
        const status = self.stakeActivatingAndDeactivating(target_epoch, history, new_rate_activation_epoch);
        return status.effective;
    }

    /// Calculate the stake activation status (effective, activating, deactivating).
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L342-L436
    ///
    /// This is the core function for stake warmup/cooldown calculations.
    ///
    /// # Arguments
    /// * `target_epoch` - The epoch to calculate status for
    /// * `history` - Stake history for warmup/cooldown calculations
    /// * `new_rate_activation_epoch` - Epoch when new rate was activated (if any)
    ///
    /// # Returns
    /// A StakeActivationStatus with effective, activating, and deactivating amounts
    pub fn stakeActivatingAndDeactivating(
        self: Delegation,
        target_epoch: u64,
        history: ?StakeHistory,
        new_rate_activation_epoch: ?u64,
    ) StakeActivationStatus {
        // First, calculate effective and activating stake
        const effective_and_activating = self.stakeAndActivating(target_epoch, history, new_rate_activation_epoch);
        const effective_stake = effective_and_activating[0];
        const activating_stake = effective_and_activating[1];

        // Then de-activate some portion if necessary
        if (target_epoch < self.deactivation_epoch) {
            // not deactivated
            if (activating_stake == 0) {
                return StakeActivationStatus.withEffective(effective_stake);
            } else {
                return StakeActivationStatus.withEffectiveAndActivating(effective_stake, activating_stake);
            }
        } else if (target_epoch == self.deactivation_epoch) {
            // can only deactivate what's activated
            return StakeActivationStatus.withDeactivating(effective_stake);
        } else {
            // target_epoch > self.deactivation_epoch
            // Calculate deactivation using history
            if (history) |h| {
                if (h.get(self.deactivation_epoch)) |cluster_stake_at_deactivation| {
                    return self.calculateDeactivation(
                        target_epoch,
                        effective_stake,
                        h,
                        cluster_stake_at_deactivation,
                        new_rate_activation_epoch,
                    );
                }
            }
            // no history or dropped out, assume fully deactivated
            return StakeActivationStatus.DEFAULT;
        }
    }

    /// Calculate effective and activating stake (returns tuple)
    fn stakeAndActivating(
        self: Delegation,
        target_epoch: u64,
        history: ?StakeHistory,
        new_rate_activation_epoch: ?u64,
    ) [2]u64 {
        const delegated_stake = self.stake;

        if (self.isBootstrap()) {
            // fully effective immediately
            return .{ delegated_stake, 0 };
        } else if (self.activation_epoch == self.deactivation_epoch) {
            // activated but instantly deactivated; no stake at all regardless of target_epoch
            return .{ 0, 0 };
        } else if (target_epoch == self.activation_epoch) {
            // all is activating
            return .{ 0, delegated_stake };
        } else if (target_epoch < self.activation_epoch) {
            // not yet enabled
            return .{ 0, 0 };
        } else {
            // target_epoch > self.activation_epoch
            // Calculate warmup using history
            if (history) |h| {
                if (h.get(self.activation_epoch)) |cluster_stake_at_activation| {
                    return self.calculateActivation(
                        target_epoch,
                        delegated_stake,
                        h,
                        cluster_stake_at_activation,
                        new_rate_activation_epoch,
                    );
                }
            }
            // no history or dropped out, assume fully effective
            return .{ delegated_stake, 0 };
        }
    }

    /// Calculate activation warmup
    fn calculateActivation(
        self: Delegation,
        target_epoch: u64,
        delegated_stake: u64,
        history: StakeHistory,
        initial_cluster_stake: StakeHistoryEntry,
        new_rate_activation_epoch: ?u64,
    ) [2]u64 {
        var prev_epoch = self.activation_epoch;
        var prev_cluster_stake = initial_cluster_stake;
        var current_effective_stake: u64 = 0;

        while (true) {
            const current_epoch = prev_epoch + 1;

            // if there is no activating stake at prev epoch, we should have been
            // fully effective at this moment
            if (prev_cluster_stake.activating == 0) {
                break;
            }

            // how much of the growth in stake this account is entitled to take
            const remaining_activating_stake = delegated_stake - current_effective_stake;
            const weight = @as(f64, @floatFromInt(remaining_activating_stake)) /
                @as(f64, @floatFromInt(prev_cluster_stake.activating));
            const rate = warmupCooldownRate(current_epoch, new_rate_activation_epoch);

            // portion of newly effective cluster stake I'm entitled to at current epoch
            const newly_effective_cluster_stake = @as(f64, @floatFromInt(prev_cluster_stake.effective)) * rate;
            // Rust: ((weight * newly_effective_cluster_stake) as u64).max(1)
            const newly_effective_stake = @max(@as(u64, @intFromFloat(weight * newly_effective_cluster_stake)), 1);

            current_effective_stake += newly_effective_stake;
            if (current_effective_stake >= delegated_stake) {
                current_effective_stake = delegated_stake;
                break;
            }

            if (current_epoch >= target_epoch or current_epoch >= self.deactivation_epoch) {
                break;
            }
            if (history.get(current_epoch)) |current_cluster_stake| {
                prev_epoch = current_epoch;
                prev_cluster_stake = current_cluster_stake;
            } else {
                break;
            }
        }

        return .{ current_effective_stake, delegated_stake - current_effective_stake };
    }

    /// Calculate deactivation cooldown
    fn calculateDeactivation(
        self: Delegation,
        target_epoch: u64,
        effective_stake: u64,
        history: StakeHistory,
        initial_cluster_stake: StakeHistoryEntry,
        new_rate_activation_epoch: ?u64,
    ) StakeActivationStatus {
        var prev_epoch = self.deactivation_epoch;
        var prev_cluster_stake = initial_cluster_stake;
        var current_effective_stake = effective_stake;

        while (true) {
            const current_epoch = prev_epoch + 1;

            // if there is no deactivating stake at prev epoch, we should have been
            // fully undelegated at this moment
            if (prev_cluster_stake.deactivating == 0) {
                break;
            }

            // I'm trying to get to zero, how much of the deactivation in stake
            // this account is entitled to take
            const weight = @as(f64, @floatFromInt(current_effective_stake)) /
                @as(f64, @floatFromInt(prev_cluster_stake.deactivating));
            const rate = warmupCooldownRate(current_epoch, new_rate_activation_epoch);

            // portion of newly not-effective cluster stake I'm entitled to at current epoch
            const newly_not_effective_cluster_stake = @as(f64, @floatFromInt(prev_cluster_stake.effective)) * rate;
            // Rust: ((weight * newly_not_effective_cluster_stake) as u64).max(1)
            const newly_not_effective_stake = @max(@as(u64, @intFromFloat(weight * newly_not_effective_cluster_stake)), 1);

            current_effective_stake = current_effective_stake -| newly_not_effective_stake;
            if (current_effective_stake == 0) {
                break;
            }

            if (current_epoch >= target_epoch) {
                break;
            }
            if (history.get(current_epoch)) |current_cluster_stake| {
                prev_epoch = current_epoch;
                prev_cluster_stake = current_cluster_stake;
            } else {
                break;
            }
        }

        // deactivating stake should equal to all of currently remaining effective stake
        return StakeActivationStatus.withDeactivating(current_effective_stake);
    }
};

// ============================================================================
// Stake
// ============================================================================

/// Active stake information
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
///
/// Layout (72 bytes):
/// - bytes[0..64]: delegation (Delegation)
/// - bytes[64..72]: credits_observed (u64, little-endian)
pub const Stake = struct {
    /// Delegation information
    delegation: Delegation,
    /// Credits observed for the validator this epoch
    credits_observed: u64,

    /// Size in bytes
    pub const SIZE: usize = STAKE_SIZE;

    /// Create a new Stake
    pub fn new(
        voter_pubkey: *const PublicKey,
        stake: u64,
        activation_epoch: u64,
        credits_observed: u64,
    ) Stake {
        return .{
            .delegation = Delegation.new(voter_pubkey, stake, activation_epoch),
            .credits_observed = credits_observed,
        };
    }

    /// Deactivate the stake
    pub fn deactivate(self: *Stake, epoch: u64) !void {
        try self.delegation.deactivate(epoch);
    }

    /// Get the effective stake at a given epoch
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L485-L492
    pub fn getStake(
        self: Stake,
        epoch: u64,
        history: ?StakeHistory,
        new_rate_activation_epoch: ?u64,
    ) u64 {
        return self.delegation.getStake(epoch, history, new_rate_activation_epoch);
    }

    /// Split stake from this account
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs#L494-L522
    ///
    /// # Arguments
    /// * `remaining_stake_delta` - Amount by which remaining stake will decrease
    /// * `split_stake_amount` - Amount of stake for the split account
    ///
    /// # Returns
    /// A new Stake for the split account, or error if insufficient stake
    pub fn split(self: *Stake, remaining_stake_delta: u64, split_stake_amount: u64) !Stake {
        if (remaining_stake_delta > self.delegation.stake) {
            return error.InsufficientStake;
        }

        self.delegation.stake -= remaining_stake_delta;

        return Stake{
            .delegation = Delegation{
                .voter_pubkey = self.delegation.voter_pubkey,
                .stake = split_stake_amount,
                .activation_epoch = self.delegation.activation_epoch,
                .deactivation_epoch = self.delegation.deactivation_epoch,
            },
            .credits_observed = self.credits_observed,
        };
    }

    /// Unpack from bytes
    pub fn unpack(data: []const u8) !Stake {
        if (data.len < SIZE) return error.InvalidAccountData;
        return .{
            .delegation = try Delegation.unpack(data[0..64]),
            .credits_observed = std.mem.readInt(u64, data[64..72], .little),
        };
    }

    /// Pack into bytes
    ///
    /// Returns error.InvalidAccountData if dest buffer is too small.
    pub fn pack(self: Stake, dest: []u8) !void {
        if (dest.len < SIZE) return error.InvalidAccountData;
        try self.delegation.pack(dest[0..64]);
        std.mem.writeInt(u64, dest[64..72], self.credits_observed, .little);
    }
};

// ============================================================================
// StakeStateV2
// ============================================================================

/// Stake account state (V2)
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/state.rs
///
/// The stake account state machine:
/// - Uninitialized: Account has been created but not initialized
/// - Initialized: Account has meta but no stake
/// - Stake: Account has active stake with meta
/// - RewardsPool: Deprecated rewards pool account
///
/// Discriminant values:
/// - 0: Uninitialized
/// - 1: Initialized(Meta)
/// - 2: Stake(Meta, Stake, StakeFlags)
/// - 3: RewardsPool
pub const StakeStateV2 = union(enum) {
    /// Account has not been initialized
    Uninitialized: void,
    /// Account has been initialized (has meta)
    Initialized: Meta,
    /// Account has active stake
    Stake: struct {
        meta: Meta,
        stake: Stake,
        stake_flags: StakeFlags,
    },
    /// Deprecated rewards pool
    RewardsPool: void,

    /// Size in bytes
    pub const SIZE: usize = STAKE_STATE_V2_SIZE;

    /// Discriminant values
    pub const Discriminant = enum(u32) {
        Uninitialized = 0,
        Initialized = 1,
        Stake = 2,
        RewardsPool = 3,
    };

    /// Get the discriminant value
    pub fn discriminant(self: StakeStateV2) Discriminant {
        return switch (self) {
            .Uninitialized => .Uninitialized,
            .Initialized => .Initialized,
            .Stake => .Stake,
            .RewardsPool => .RewardsPool,
        };
    }

    /// Get meta if available
    pub fn meta(self: StakeStateV2) ?Meta {
        return switch (self) {
            .Uninitialized, .RewardsPool => null,
            .Initialized => |m| m,
            .Stake => |s| s.meta,
        };
    }

    /// Get stake if available
    pub fn stake(self: StakeStateV2) ?Stake {
        return switch (self) {
            .Stake => |s| s.stake,
            else => null,
        };
    }

    /// Get stake flags if available
    pub fn stakeFlags(self: StakeStateV2) ?StakeFlags {
        return switch (self) {
            .Stake => |s| s.stake_flags,
            else => null,
        };
    }

    /// Get authorized info
    pub fn authorized(self: StakeStateV2) ?Authorized {
        const m = self.meta() orelse return null;
        return m.authorized;
    }

    /// Get lockup info
    pub fn lockup(self: StakeStateV2) ?Lockup {
        const m = self.meta() orelse return null;
        return m.lockup;
    }

    /// Unpack from bytes
    pub fn unpack(data: []const u8) !StakeStateV2 {
        if (data.len < STAKE_STATE_DISCRIMINANT_SIZE) return error.InvalidAccountData;

        const disc = std.mem.readInt(u32, data[0..4], .little);

        return switch (disc) {
            0 => .Uninitialized,
            1 => blk: {
                if (data.len < 4 + META_SIZE) return error.InvalidAccountData;
                break :blk .{ .Initialized = try Meta.unpack(data[4 .. 4 + META_SIZE]) };
            },
            2 => blk: {
                if (data.len < 4 + META_SIZE + STAKE_SIZE + STAKE_FLAGS_SIZE) return error.InvalidAccountData;
                break :blk .{
                    .Stake = .{
                        .meta = try Meta.unpack(data[4 .. 4 + META_SIZE]),
                        .stake = try Stake.unpack(data[4 + META_SIZE .. 4 + META_SIZE + STAKE_SIZE]),
                        .stake_flags = StakeFlags.fromByte(data[4 + META_SIZE + STAKE_SIZE]),
                    },
                };
            },
            3 => .RewardsPool,
            else => error.InvalidAccountData,
        };
    }

    /// Pack into bytes
    ///
    /// Returns error.InvalidAccountData if dest buffer is too small.
    pub fn pack(self: StakeStateV2, dest: []u8) !void {
        if (dest.len < SIZE) return error.InvalidAccountData;

        // Clear buffer first
        @memset(dest[0..SIZE], 0);

        switch (self) {
            .Uninitialized => {
                std.mem.writeInt(u32, dest[0..4], 0, .little);
            },
            .Initialized => |m| {
                std.mem.writeInt(u32, dest[0..4], 1, .little);
                try m.pack(dest[4 .. 4 + META_SIZE]);
            },
            .Stake => |s| {
                std.mem.writeInt(u32, dest[0..4], 2, .little);
                try s.meta.pack(dest[4 .. 4 + META_SIZE]);
                try s.stake.pack(dest[4 + META_SIZE .. 4 + META_SIZE + STAKE_SIZE]);
                dest[4 + META_SIZE + STAKE_SIZE] = s.stake_flags.toByte();
            },
            .RewardsPool => {
                std.mem.writeInt(u32, dest[0..4], 3, .little);
            },
        }
    }

    /// Check if initialized
    pub fn isInitialized(self: StakeStateV2) bool {
        return switch (self) {
            .Uninitialized => false,
            else => true,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StakeFlags: empty and constants" {
    const empty = StakeFlags.EMPTY;
    try std.testing.expect(empty.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), empty.toByte());

    const must_activate = StakeFlags.MUST_FULLY_ACTIVATE_BEFORE_DEACTIVATION_IS_PERMITTED;
    try std.testing.expect(!must_activate.isEmpty());
    try std.testing.expect(must_activate.mustFullyActivateBeforeDeactivation());
    try std.testing.expectEqual(@as(u8, 1), must_activate.toByte());
}

test "StakeFlags: byte roundtrip" {
    const flags = StakeFlags.MUST_FULLY_ACTIVATE_BEFORE_DEACTIVATION_IS_PERMITTED;
    const byte = flags.toByte();
    const recovered = StakeFlags.fromByte(byte);
    try std.testing.expectEqual(flags, recovered);
}

test "StakeFlags: union and contains" {
    const empty = StakeFlags.EMPTY;
    const must_activate = StakeFlags.MUST_FULLY_ACTIVATE_BEFORE_DEACTIVATION_IS_PERMITTED;

    const union_result = empty.@"union"(must_activate);
    try std.testing.expect(union_result.mustFullyActivateBeforeDeactivation());
    try std.testing.expect(union_result.contains(must_activate));
    try std.testing.expect(union_result.contains(empty));
    try std.testing.expect(!empty.contains(must_activate));
}

test "StakeAuthorize: enum values" {
    try std.testing.expectEqual(@as(u32, 0), StakeAuthorize.Staker.toU32());
    try std.testing.expectEqual(@as(u32, 1), StakeAuthorize.Withdrawer.toU32());
}

test "StakeAuthorize: fromU32" {
    try std.testing.expectEqual(StakeAuthorize.Staker, StakeAuthorize.fromU32(0).?);
    try std.testing.expectEqual(StakeAuthorize.Withdrawer, StakeAuthorize.fromU32(1).?);
    try std.testing.expect(StakeAuthorize.fromU32(2) == null);
    try std.testing.expect(StakeAuthorize.fromU32(100) == null);
}

test "Authorized: SIZE constant" {
    try std.testing.expectEqual(@as(usize, 64), Authorized.SIZE);
}

test "Authorized: auto" {
    const pubkey = PublicKey.from([_]u8{0xAB} ** 32);
    const auth = Authorized.auto(pubkey);
    try std.testing.expectEqual(pubkey, auth.staker);
    try std.testing.expectEqual(pubkey, auth.withdrawer);
}

test "Authorized: pack and unpack roundtrip" {
    const staker = PublicKey.from([_]u8{1} ** 32);
    const withdrawer = PublicKey.from([_]u8{2} ** 32);
    const auth = Authorized{
        .staker = staker,
        .withdrawer = withdrawer,
    };

    var buffer: [Authorized.SIZE]u8 = undefined;
    try auth.pack(&buffer);

    const unpacked = try Authorized.unpack(&buffer);
    try std.testing.expectEqual(staker, unpacked.staker);
    try std.testing.expectEqual(withdrawer, unpacked.withdrawer);
}

test "Lockup: SIZE constant" {
    try std.testing.expectEqual(@as(usize, 48), Lockup.SIZE);
}

test "Lockup: DEFAULT is not in force" {
    const lockup = Lockup.DEFAULT;
    try std.testing.expect(!lockup.isInForce(0, 0));
    try std.testing.expect(!lockup.isInForce(1000, 100));
}

test "Lockup: isInForce with unix_timestamp" {
    const lockup = Lockup{
        .unix_timestamp = 1000,
        .epoch = 0,
        .custodian = PublicKey.default(),
    };
    try std.testing.expect(lockup.isInForce(500, 0));
    try std.testing.expect(!lockup.isInForce(1000, 0));
    try std.testing.expect(!lockup.isInForce(1500, 0));
}

test "Lockup: isInForce with epoch" {
    const lockup = Lockup{
        .unix_timestamp = 0,
        .epoch = 100,
        .custodian = PublicKey.default(),
    };
    try std.testing.expect(lockup.isInForce(0, 50));
    try std.testing.expect(!lockup.isInForce(0, 100));
    try std.testing.expect(!lockup.isInForce(0, 150));
}

test "Lockup: pack and unpack roundtrip" {
    const custodian = PublicKey.from([_]u8{3} ** 32);
    const lockup = Lockup{
        .unix_timestamp = 1234567890,
        .epoch = 42,
        .custodian = custodian,
    };

    var buffer: [Lockup.SIZE]u8 = undefined;
    try lockup.pack(&buffer);

    const unpacked = try Lockup.unpack(&buffer);
    try std.testing.expectEqual(@as(i64, 1234567890), unpacked.unix_timestamp);
    try std.testing.expectEqual(@as(u64, 42), unpacked.epoch);
    try std.testing.expectEqual(custodian, unpacked.custodian);
}

test "Meta: SIZE constant" {
    try std.testing.expectEqual(@as(usize, 120), Meta.SIZE);
}

test "Meta: auto" {
    const pubkey = PublicKey.from([_]u8{0xCD} ** 32);
    const m = Meta.auto(&pubkey);
    try std.testing.expectEqual(@as(u64, 0), m.rent_exempt_reserve);
    try std.testing.expectEqual(pubkey, m.authorized.staker);
    try std.testing.expectEqual(pubkey, m.authorized.withdrawer);
    try std.testing.expectEqual(Lockup.DEFAULT.unix_timestamp, m.lockup.unix_timestamp);
}

test "Meta: pack and unpack roundtrip" {
    const staker = PublicKey.from([_]u8{1} ** 32);
    const withdrawer = PublicKey.from([_]u8{2} ** 32);
    const custodian = PublicKey.from([_]u8{3} ** 32);

    const m = Meta{
        .rent_exempt_reserve = 1_000_000,
        .authorized = .{
            .staker = staker,
            .withdrawer = withdrawer,
        },
        .lockup = .{
            .unix_timestamp = 1234567890,
            .epoch = 42,
            .custodian = custodian,
        },
    };

    var buffer: [Meta.SIZE]u8 = undefined;
    try m.pack(&buffer);

    const unpacked = try Meta.unpack(&buffer);
    try std.testing.expectEqual(@as(u64, 1_000_000), unpacked.rent_exempt_reserve);
    try std.testing.expectEqual(staker, unpacked.authorized.staker);
    try std.testing.expectEqual(withdrawer, unpacked.authorized.withdrawer);
    try std.testing.expectEqual(@as(i64, 1234567890), unpacked.lockup.unix_timestamp);
    try std.testing.expectEqual(@as(u64, 42), unpacked.lockup.epoch);
    try std.testing.expectEqual(custodian, unpacked.lockup.custodian);
}

test "Delegation: SIZE constant" {
    try std.testing.expectEqual(@as(usize, 64), Delegation.SIZE);
}

test "Delegation: new" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);
    const d = Delegation.new(&voter, 100_000_000, 10);
    try std.testing.expectEqual(voter, d.voter_pubkey);
    try std.testing.expectEqual(@as(u64, 100_000_000), d.stake);
    try std.testing.expectEqual(@as(u64, 10), d.activation_epoch);
    try std.testing.expectEqual(EPOCH_MAX, d.deactivation_epoch);
}

test "Delegation: isActivating, isActive, isDeactivating" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);
    var d = Delegation.new(&voter, 100_000_000, 10);

    // Epoch 10: activating
    try std.testing.expect(d.isActivating(10));
    try std.testing.expect(!d.isActive(10));
    try std.testing.expect(!d.isDeactivating(10));

    // Epoch 11: active
    try std.testing.expect(!d.isActivating(11));
    try std.testing.expect(d.isActive(11));
    try std.testing.expect(!d.isDeactivating(11));

    // Deactivate at epoch 20
    try d.deactivate(20);

    // Epoch 20: deactivating
    try std.testing.expect(!d.isActivating(20));
    try std.testing.expect(!d.isActive(20));
    try std.testing.expect(d.isDeactivating(20));

    // Epoch 21: still deactivating (cooldown period continues)
    try std.testing.expect(d.isDeactivating(21));
}

test "Delegation: deactivate error if already deactivated" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);
    var d = Delegation.new(&voter, 100_000_000, 10);
    try d.deactivate(20);
    try std.testing.expectError(error.AlreadyDeactivated, d.deactivate(25));
}

test "Delegation: pack and unpack roundtrip" {
    const voter = PublicKey.from([_]u8{0xCD} ** 32);
    const d = Delegation{
        .voter_pubkey = voter,
        .stake = 500_000_000,
        .activation_epoch = 100,
        .deactivation_epoch = 200,
    };

    var buffer: [Delegation.SIZE]u8 = undefined;
    try d.pack(&buffer);

    const unpacked = try Delegation.unpack(&buffer);
    try std.testing.expectEqual(voter, unpacked.voter_pubkey);
    try std.testing.expectEqual(@as(u64, 500_000_000), unpacked.stake);
    try std.testing.expectEqual(@as(u64, 100), unpacked.activation_epoch);
    try std.testing.expectEqual(@as(u64, 200), unpacked.deactivation_epoch);
}

test "Stake: SIZE constant" {
    try std.testing.expectEqual(@as(usize, 72), Stake.SIZE);
}

test "Stake: new" {
    const voter = PublicKey.from([_]u8{0xEF} ** 32);
    const s = Stake.new(&voter, 100_000_000, 10, 12345);
    try std.testing.expectEqual(voter, s.delegation.voter_pubkey);
    try std.testing.expectEqual(@as(u64, 100_000_000), s.delegation.stake);
    try std.testing.expectEqual(@as(u64, 10), s.delegation.activation_epoch);
    try std.testing.expectEqual(EPOCH_MAX, s.delegation.deactivation_epoch);
    try std.testing.expectEqual(@as(u64, 12345), s.credits_observed);
}

test "Stake: pack and unpack roundtrip" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);
    const s = Stake{
        .delegation = .{
            .voter_pubkey = voter,
            .stake = 200_000_000,
            .activation_epoch = 50,
            .deactivation_epoch = EPOCH_MAX,
        },
        .credits_observed = 999999,
    };

    var buffer: [Stake.SIZE]u8 = undefined;
    try s.pack(&buffer);

    const unpacked = try Stake.unpack(&buffer);
    try std.testing.expectEqual(voter, unpacked.delegation.voter_pubkey);
    try std.testing.expectEqual(@as(u64, 200_000_000), unpacked.delegation.stake);
    try std.testing.expectEqual(@as(u64, 50), unpacked.delegation.activation_epoch);
    try std.testing.expectEqual(EPOCH_MAX, unpacked.delegation.deactivation_epoch);
    try std.testing.expectEqual(@as(u64, 999999), unpacked.credits_observed);
}

test "StakeStateV2: SIZE constant" {
    try std.testing.expectEqual(@as(usize, 200), StakeStateV2.SIZE);
}

test "StakeStateV2: discriminant values" {
    const uninitialized = StakeStateV2{ .Uninitialized = {} };
    try std.testing.expectEqual(StakeStateV2.Discriminant.Uninitialized, uninitialized.discriminant());

    const pubkey = PublicKey.from([_]u8{1} ** 32);
    const initialized = StakeStateV2{ .Initialized = Meta.auto(&pubkey) };
    try std.testing.expectEqual(StakeStateV2.Discriminant.Initialized, initialized.discriminant());

    const rewards_pool = StakeStateV2{ .RewardsPool = {} };
    try std.testing.expectEqual(StakeStateV2.Discriminant.RewardsPool, rewards_pool.discriminant());
}

test "StakeStateV2: Uninitialized pack and unpack" {
    const state = StakeStateV2{ .Uninitialized = {} };
    var buffer: [StakeStateV2.SIZE]u8 = undefined;
    try state.pack(&buffer);

    // Check discriminant
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, buffer[0..4], .little));

    const unpacked = try StakeStateV2.unpack(&buffer);
    try std.testing.expectEqual(StakeStateV2.Discriminant.Uninitialized, unpacked.discriminant());
    try std.testing.expect(!unpacked.isInitialized());
}

test "StakeStateV2: Initialized pack and unpack" {
    const pubkey = PublicKey.from([_]u8{0xAB} ** 32);
    const m = Meta.auto(&pubkey);
    const state = StakeStateV2{ .Initialized = m };

    var buffer: [StakeStateV2.SIZE]u8 = undefined;
    try state.pack(&buffer);

    // Check discriminant
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, buffer[0..4], .little));

    const unpacked = try StakeStateV2.unpack(&buffer);
    try std.testing.expectEqual(StakeStateV2.Discriminant.Initialized, unpacked.discriminant());
    try std.testing.expect(unpacked.isInitialized());
    try std.testing.expect(unpacked.meta() != null);
    try std.testing.expect(unpacked.stake() == null);
    try std.testing.expectEqual(pubkey, unpacked.meta().?.authorized.staker);
}

test "StakeStateV2: Stake pack and unpack" {
    const staker = PublicKey.from([_]u8{1} ** 32);
    const withdrawer = PublicKey.from([_]u8{2} ** 32);
    const voter = PublicKey.from([_]u8{3} ** 32);

    const state = StakeStateV2{
        .Stake = .{
            .meta = .{
                .rent_exempt_reserve = 1_000_000,
                .authorized = .{
                    .staker = staker,
                    .withdrawer = withdrawer,
                },
                .lockup = Lockup.DEFAULT,
            },
            .stake = .{
                .delegation = .{
                    .voter_pubkey = voter,
                    .stake = 100_000_000,
                    .activation_epoch = 10,
                    .deactivation_epoch = EPOCH_MAX,
                },
                .credits_observed = 5000,
            },
            .stake_flags = StakeFlags.MUST_FULLY_ACTIVATE_BEFORE_DEACTIVATION_IS_PERMITTED,
        },
    };

    var buffer: [StakeStateV2.SIZE]u8 = undefined;
    try state.pack(&buffer);

    // Check discriminant
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, buffer[0..4], .little));

    const unpacked = try StakeStateV2.unpack(&buffer);
    try std.testing.expectEqual(StakeStateV2.Discriminant.Stake, unpacked.discriminant());
    try std.testing.expect(unpacked.isInitialized());

    const meta = unpacked.meta().?;
    try std.testing.expectEqual(@as(u64, 1_000_000), meta.rent_exempt_reserve);
    try std.testing.expectEqual(staker, meta.authorized.staker);
    try std.testing.expectEqual(withdrawer, meta.authorized.withdrawer);

    const stake = unpacked.stake().?;
    try std.testing.expectEqual(voter, stake.delegation.voter_pubkey);
    try std.testing.expectEqual(@as(u64, 100_000_000), stake.delegation.stake);
    try std.testing.expectEqual(@as(u64, 10), stake.delegation.activation_epoch);
    try std.testing.expectEqual(EPOCH_MAX, stake.delegation.deactivation_epoch);
    try std.testing.expectEqual(@as(u64, 5000), stake.credits_observed);

    const flags = unpacked.stakeFlags().?;
    try std.testing.expect(flags.mustFullyActivateBeforeDeactivation());
}

test "StakeStateV2: RewardsPool pack and unpack" {
    const state = StakeStateV2{ .RewardsPool = {} };
    var buffer: [StakeStateV2.SIZE]u8 = undefined;
    try state.pack(&buffer);

    // Check discriminant
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, buffer[0..4], .little));

    const unpacked = try StakeStateV2.unpack(&buffer);
    try std.testing.expectEqual(StakeStateV2.Discriminant.RewardsPool, unpacked.discriminant());
    try std.testing.expect(unpacked.isInitialized());
    try std.testing.expect(unpacked.meta() == null);
    try std.testing.expect(unpacked.stake() == null);
}

test "StakeStateV2: unpack invalid discriminant" {
    var buffer: [StakeStateV2.SIZE]u8 = [_]u8{0} ** StakeStateV2.SIZE;
    std.mem.writeInt(u32, buffer[0..4], 4, .little); // Invalid discriminant

    const result = StakeStateV2.unpack(&buffer);
    try std.testing.expectError(error.InvalidAccountData, result);
}

test "StakeStateV2: authorized and lockup helpers" {
    const staker = PublicKey.from([_]u8{1} ** 32);
    const state = StakeStateV2{ .Initialized = Meta.auto(&staker) };

    const auth = state.authorized().?;
    try std.testing.expectEqual(staker, auth.staker);
    try std.testing.expectEqual(staker, auth.withdrawer);

    const lock = state.lockup().?;
    try std.testing.expectEqual(@as(i64, 0), lock.unix_timestamp);
    try std.testing.expectEqual(@as(u64, 0), lock.epoch);

    const uninitialized = StakeStateV2{ .Uninitialized = {} };
    try std.testing.expect(uninitialized.authorized() == null);
    try std.testing.expect(uninitialized.lockup() == null);
}

test "STAKE_PROGRAM_ID: correct value" {
    const expected = "Stake11111111111111111111111111111111111111";
    var buffer: [44]u8 = undefined;
    const actual = STAKE_PROGRAM_ID.toBase58(&buffer);
    try std.testing.expectEqualStrings(expected, actual);
}

test "STAKE_CONFIG_PROGRAM_ID: correct value" {
    const expected = "StakeConfig11111111111111111111111111111111";
    var buffer: [44]u8 = undefined;
    const actual = STAKE_CONFIG_PROGRAM_ID.toBase58(&buffer);
    try std.testing.expectEqualStrings(expected, actual);
}

// ============================================================================
// Additional Edge Case Tests
// ============================================================================

test "Delegation: isActivating/isActive/isDeactivating boundary conditions" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);

    // Test 1: Bootstrap stake (activation_epoch == EPOCH_MAX) - never activating, always active
    {
        const bootstrap = Delegation{
            .voter_pubkey = voter,
            .stake = 100_000_000,
            .activation_epoch = EPOCH_MAX, // Bootstrap stake
            .deactivation_epoch = EPOCH_MAX,
        };
        // Bootstrap stakes are never "activating"
        try std.testing.expect(!bootstrap.isActivating(0));
        try std.testing.expect(!bootstrap.isActivating(100));
        try std.testing.expect(!bootstrap.isActivating(EPOCH_MAX - 1));
        // Bootstrap stakes are always "active" (when not deactivating)
        try std.testing.expect(bootstrap.isActive(0));
        try std.testing.expect(bootstrap.isActive(100));
        try std.testing.expect(bootstrap.isActive(EPOCH_MAX - 1));
        // Not deactivating
        try std.testing.expect(!bootstrap.isDeactivating(0));
    }

    // Test 2: Bootstrap stake that is deactivating
    {
        const bootstrap_deactivating = Delegation{
            .voter_pubkey = voter,
            .stake = 100_000_000,
            .activation_epoch = EPOCH_MAX, // Bootstrap
            .deactivation_epoch = 50, // Deactivated at epoch 50
        };
        // Before deactivation - still active
        try std.testing.expect(bootstrap_deactivating.isActive(49));
        try std.testing.expect(!bootstrap_deactivating.isDeactivating(49));
        // At and after deactivation - not active, deactivating
        try std.testing.expect(!bootstrap_deactivating.isActive(50));
        try std.testing.expect(bootstrap_deactivating.isDeactivating(50));
        try std.testing.expect(!bootstrap_deactivating.isActive(51));
        try std.testing.expect(bootstrap_deactivating.isDeactivating(51));
    }

    // Test 3: Normal stake - epoch before activation
    {
        var normal = Delegation.new(&voter, 100_000_000, 10);
        // Before activation epoch - not activating, not active
        try std.testing.expect(!normal.isActivating(9));
        try std.testing.expect(!normal.isActive(9));
        try std.testing.expect(!normal.isDeactivating(9));
    }

    // Test 4: Instant deactivation (activation_epoch == deactivation_epoch)
    {
        const instant_deactivate = Delegation{
            .voter_pubkey = voter,
            .stake = 100_000_000,
            .activation_epoch = 10,
            .deactivation_epoch = 10, // Instantly deactivated
        };
        // At the epoch - deactivating, not activating
        try std.testing.expect(!instant_deactivate.isActivating(10));
        try std.testing.expect(!instant_deactivate.isActive(10));
        try std.testing.expect(instant_deactivate.isDeactivating(10));
    }

    // Test 5: Stake with deactivation - transition from active to deactivating
    {
        var d = Delegation.new(&voter, 100_000_000, 10);
        try d.deactivate(20);

        // Epoch 19 - still active
        try std.testing.expect(d.isActive(19));
        try std.testing.expect(!d.isDeactivating(19));

        // Epoch 20 - deactivating starts
        try std.testing.expect(!d.isActive(20));
        try std.testing.expect(d.isDeactivating(20));

        // Epoch 100 - still deactivating
        try std.testing.expect(!d.isActive(100));
        try std.testing.expect(d.isDeactivating(100));
    }
}

test "Delegation: isBootstrap" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);

    // Bootstrap stake
    const bootstrap = Delegation{
        .voter_pubkey = voter,
        .stake = 100_000_000,
        .activation_epoch = EPOCH_MAX,
        .deactivation_epoch = EPOCH_MAX,
    };
    try std.testing.expect(bootstrap.isBootstrap());

    // Normal stake (activation_epoch = 0 is NOT bootstrap)
    const normal_epoch_0 = Delegation{
        .voter_pubkey = voter,
        .stake = 100_000_000,
        .activation_epoch = 0,
        .deactivation_epoch = EPOCH_MAX,
    };
    try std.testing.expect(!normal_epoch_0.isBootstrap());

    // Normal stake (activation_epoch = 100)
    const normal = Delegation.new(&voter, 100_000_000, 100);
    try std.testing.expect(!normal.isBootstrap());
}

// ============================================================================
// Pack Error Tests
// ============================================================================

test "Authorized: pack rejects buffer too small" {
    const auth = Authorized{
        .staker = PublicKey.from([_]u8{1} ** 32),
        .withdrawer = PublicKey.from([_]u8{2} ** 32),
    };
    var small_buffer: [Authorized.SIZE - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, auth.pack(&small_buffer));
}

test "Lockup: pack rejects buffer too small" {
    const lockup = Lockup{
        .unix_timestamp = 12345,
        .epoch = 42,
        .custodian = PublicKey.from([_]u8{3} ** 32),
    };
    var small_buffer: [Lockup.SIZE - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, lockup.pack(&small_buffer));
}

test "Meta: pack rejects buffer too small" {
    const pubkey = PublicKey.from([_]u8{1} ** 32);
    const m = Meta.auto(&pubkey);
    var small_buffer: [Meta.SIZE - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, m.pack(&small_buffer));
}

test "Delegation: pack rejects buffer too small" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);
    const d = Delegation.new(&voter, 100_000_000, 10);
    var small_buffer: [Delegation.SIZE - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, d.pack(&small_buffer));
}

test "Stake: pack rejects buffer too small" {
    const voter = PublicKey.from([_]u8{0xAB} ** 32);
    const s = Stake{
        .delegation = Delegation.new(&voter, 100_000_000, 10),
        .credits_observed = 5000,
    };
    var small_buffer: [Stake.SIZE - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, s.pack(&small_buffer));
}

test "StakeStateV2: pack rejects buffer too small" {
    const pubkey = PublicKey.from([_]u8{1} ** 32);
    const state = StakeStateV2{ .Initialized = Meta.auto(&pubkey) };
    var small_buffer: [StakeStateV2.SIZE - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, state.pack(&small_buffer));
}
