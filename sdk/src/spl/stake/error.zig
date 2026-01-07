//! Zig implementation of Solana Stake program error types
//!
//! Rust source: https://github.com/solana-program/stake/blob/master/interface/src/error.rs
//!
//! This module provides error types for the Stake program.

const std = @import("std");

// ============================================================================
// StakeError Enum
// ============================================================================

/// Errors that may be returned by the Stake program.
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/error.rs#L16-L161
pub const StakeError = enum(u32) {
    // 0
    /// Not enough credits to redeem
    NoCreditsToRedeem = 0,

    /// Lockup has not yet expired
    LockupInForce = 1,

    /// Stake already deactivated
    AlreadyDeactivated = 2,

    /// One re-delegation permitted per epoch
    TooSoonToRedelegate = 3,

    /// Split amount is more than is staked
    InsufficientStake = 4,

    // 5
    /// Stake account with transient stake cannot be merged
    MergeTransientStake = 5,

    /// Stake account merge failed due to different authority, lockups or state
    MergeMismatch = 6,

    /// Custodian address not present
    CustodianMissing = 7,

    /// Custodian signature not present
    CustodianSignatureMissing = 8,

    /// Insufficient voting activity in the reference vote account
    InsufficientReferenceVotes = 9,

    // 10
    /// Stake account is not delegated to the provided vote account
    VoteAddressMismatch = 10,

    /// Stake account has not been delinquent for the minimum epochs required for deactivation
    MinimumDelinquentEpochsForDeactivationNotMet = 11,

    /// Delegation amount is less than the minimum
    InsufficientDelegation = 12,

    /// Stake account with transient or inactive stake cannot be redelegated
    RedelegateTransientOrInactiveStake = 13,

    /// Stake redelegation to the same vote account is not permitted
    RedelegateToSameVoteAccount = 14,

    // 15
    /// Redelegated stake must be fully activated before deactivation
    RedelegatedStakeMustFullyActivateBeforeDeactivationIsPermitted = 15,

    /// Stake action is not permitted while the epoch rewards period is active
    EpochRewardsActive = 16,

    /// Convert from u32 error code
    pub fn fromCode(code: u32) ?StakeError {
        return std.meta.intToEnum(StakeError, code) catch null;
    }

    /// Convert to u32 error code
    pub fn toCode(self: StakeError) u32 {
        return @intFromEnum(self);
    }

    /// Get human-readable error message
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/error.rs
    pub fn message(self: StakeError) []const u8 {
        return switch (self) {
            .NoCreditsToRedeem => "Not enough credits to redeem",
            .LockupInForce => "Lockup has not yet expired",
            .AlreadyDeactivated => "Stake already deactivated",
            .TooSoonToRedelegate => "One re-delegation permitted per epoch",
            .InsufficientStake => "Split amount is more than is staked",
            .MergeTransientStake => "Stake account with transient stake cannot be merged",
            .MergeMismatch => "Stake account merge failed due to different authority, lockups or state",
            .CustodianMissing => "Custodian address not present",
            .CustodianSignatureMissing => "Custodian signature not present",
            .InsufficientReferenceVotes => "Insufficient voting activity in the reference vote account",
            .VoteAddressMismatch => "Stake account is not delegated to the provided vote account",
            .MinimumDelinquentEpochsForDeactivationNotMet => "Stake account has not been delinquent for the minimum epochs required for deactivation",
            .InsufficientDelegation => "Delegation amount is less than the minimum",
            .RedelegateTransientOrInactiveStake => "Stake account with transient or inactive stake cannot be redelegated",
            .RedelegateToSameVoteAccount => "Stake redelegation to the same vote account is not permitted",
            .RedelegatedStakeMustFullyActivateBeforeDeactivationIsPermitted => "Redelegated stake must be fully activated before deactivation",
            .EpochRewardsActive => "Stake action is not permitted while the epoch rewards period is active",
        };
    }

    /// Get the error string with "Error: " prefix (matches Rust Display implementation)
    pub fn toStr(self: StakeError) []const u8 {
        return switch (self) {
            .NoCreditsToRedeem => "Error: not enough credits to redeem",
            .LockupInForce => "Error: lockup has not yet expired",
            .AlreadyDeactivated => "Error: stake already deactivated",
            .TooSoonToRedelegate => "Error: one re-delegation permitted per epoch",
            .InsufficientStake => "Error: split amount is more than is staked",
            .MergeTransientStake => "Error: stake account with transient stake cannot be merged",
            .MergeMismatch => "Error: stake account merge failed due to different authority, lockups or state",
            .CustodianMissing => "Error: custodian address not present",
            .CustodianSignatureMissing => "Error: custodian signature not present",
            .InsufficientReferenceVotes => "Error: insufficient voting activity in the reference vote account",
            .VoteAddressMismatch => "Error: stake account is not delegated to the provided vote account",
            .MinimumDelinquentEpochsForDeactivationNotMet => "Error: stake account has not been delinquent for the minimum epochs required for deactivation",
            .InsufficientDelegation => "Error: delegation amount is less than the minimum",
            .RedelegateTransientOrInactiveStake => "Error: stake account with transient or inactive stake cannot be redelegated",
            .RedelegateToSameVoteAccount => "Error: stake redelegation to the same vote account is not permitted",
            .RedelegatedStakeMustFullyActivateBeforeDeactivationIsPermitted => "Error: redelegated stake must be fully activated before deactivation",
            .EpochRewardsActive => "Error: stake action is not permitted while the epoch rewards period is active",
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StakeError: enum values match Rust SDK" {
    try std.testing.expectEqual(@as(u32, 0), StakeError.NoCreditsToRedeem.toCode());
    try std.testing.expectEqual(@as(u32, 1), StakeError.LockupInForce.toCode());
    try std.testing.expectEqual(@as(u32, 2), StakeError.AlreadyDeactivated.toCode());
    try std.testing.expectEqual(@as(u32, 3), StakeError.TooSoonToRedelegate.toCode());
    try std.testing.expectEqual(@as(u32, 4), StakeError.InsufficientStake.toCode());
    try std.testing.expectEqual(@as(u32, 5), StakeError.MergeTransientStake.toCode());
    try std.testing.expectEqual(@as(u32, 6), StakeError.MergeMismatch.toCode());
    try std.testing.expectEqual(@as(u32, 7), StakeError.CustodianMissing.toCode());
    try std.testing.expectEqual(@as(u32, 8), StakeError.CustodianSignatureMissing.toCode());
    try std.testing.expectEqual(@as(u32, 9), StakeError.InsufficientReferenceVotes.toCode());
    try std.testing.expectEqual(@as(u32, 10), StakeError.VoteAddressMismatch.toCode());
    try std.testing.expectEqual(@as(u32, 11), StakeError.MinimumDelinquentEpochsForDeactivationNotMet.toCode());
    try std.testing.expectEqual(@as(u32, 12), StakeError.InsufficientDelegation.toCode());
    try std.testing.expectEqual(@as(u32, 13), StakeError.RedelegateTransientOrInactiveStake.toCode());
    try std.testing.expectEqual(@as(u32, 14), StakeError.RedelegateToSameVoteAccount.toCode());
    try std.testing.expectEqual(@as(u32, 15), StakeError.RedelegatedStakeMustFullyActivateBeforeDeactivationIsPermitted.toCode());
    try std.testing.expectEqual(@as(u32, 16), StakeError.EpochRewardsActive.toCode());
}

test "StakeError: fromCode" {
    try std.testing.expectEqual(StakeError.NoCreditsToRedeem, StakeError.fromCode(0).?);
    try std.testing.expectEqual(StakeError.LockupInForce, StakeError.fromCode(1).?);
    try std.testing.expectEqual(StakeError.AlreadyDeactivated, StakeError.fromCode(2).?);
    try std.testing.expectEqual(StakeError.EpochRewardsActive, StakeError.fromCode(16).?);

    // Invalid code should return null
    try std.testing.expect(StakeError.fromCode(17) == null);
    try std.testing.expect(StakeError.fromCode(100) == null);
    try std.testing.expect(StakeError.fromCode(0xFFFFFFFF) == null);
}

test "StakeError: message" {
    try std.testing.expectEqualStrings("Not enough credits to redeem", StakeError.NoCreditsToRedeem.message());
    try std.testing.expectEqualStrings("Lockup has not yet expired", StakeError.LockupInForce.message());
    try std.testing.expectEqualStrings("Stake already deactivated", StakeError.AlreadyDeactivated.message());
}

test "StakeError: toStr matches Rust Display" {
    try std.testing.expectEqualStrings("Error: not enough credits to redeem", StakeError.NoCreditsToRedeem.toStr());
    try std.testing.expectEqualStrings("Error: lockup has not yet expired", StakeError.LockupInForce.toStr());
    try std.testing.expectEqualStrings("Error: stake already deactivated", StakeError.AlreadyDeactivated.toStr());
}

// Rust test: test_stake_error_from_primitive_exhaustive
// Source: https://github.com/solana-program/stake/blob/master/interface/src/error.rs#L303
test "StakeError: exhaustive fromCode/toCode roundtrip" {
    // All 17 StakeError variants (0-16)
    const all_errors = [_]StakeError{
        .NoCreditsToRedeem,
        .LockupInForce,
        .AlreadyDeactivated,
        .TooSoonToRedelegate,
        .InsufficientStake,
        .MergeTransientStake,
        .MergeMismatch,
        .CustodianMissing,
        .CustodianSignatureMissing,
        .InsufficientReferenceVotes,
        .VoteAddressMismatch,
        .MinimumDelinquentEpochsForDeactivationNotMet,
        .InsufficientDelegation,
        .RedelegateTransientOrInactiveStake,
        .RedelegateToSameVoteAccount,
        .RedelegatedStakeMustFullyActivateBeforeDeactivationIsPermitted,
        .EpochRewardsActive,
    };

    // Verify each variant roundtrips correctly
    for (all_errors, 0..) |err, expected_code| {
        const code = err.toCode();
        try std.testing.expectEqual(@as(u32, @intCast(expected_code)), code);

        const recovered = StakeError.fromCode(code);
        try std.testing.expect(recovered != null);
        try std.testing.expectEqual(err, recovered.?);
    }

    // Verify total count matches (17 variants)
    try std.testing.expectEqual(@as(usize, 17), all_errors.len);

    // Verify codes outside range return null
    try std.testing.expect(StakeError.fromCode(17) == null);
    try std.testing.expect(StakeError.fromCode(100) == null);
    try std.testing.expect(StakeError.fromCode(0xFFFFFFFF) == null);
}
