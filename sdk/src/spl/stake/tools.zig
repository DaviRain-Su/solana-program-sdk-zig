//! Zig implementation of Solana Stake program tools/utilities
//!
//! Rust source: https://github.com/solana-program/stake/blob/master/interface/src/tools.rs
//!
//! This module provides utility functions for stake program operations:
//! - Checking vote account eligibility for deactivate_delinquent
//! - Verifying reference vote account has acceptable activity

const std = @import("std");

// Import MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION from state
const state = @import("state.zig");
pub const MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION = state.MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION;

// ============================================================================
// Functions
// ============================================================================

/// Check if the provided epoch_credits demonstrate active voting over the previous
/// MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION epochs.
///
/// The reference vote account must have voted in exactly the last N consecutive epochs
/// (where N = MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION), with no gaps.
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/tools.rs#L47-L65
///
/// # Arguments
/// * `epoch_credits` - Slice of (epoch, credits, prev_credits) tuples from vote account
/// * `current_epoch` - The current epoch
///
/// # Returns
/// * `true` if the vote account has acceptable voting activity
/// * `false` if the vote account lacks sufficient voting activity
pub fn acceptableReferenceEpochCredits(epoch_credits: []const EpochCredits, current_epoch: u64) bool {
    // Need at least MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION entries
    if (epoch_credits.len < MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION) {
        return false;
    }

    // Get the index of the first entry in the last N entries
    const epoch_index = epoch_credits.len - MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION;

    // Iterate in reverse through the last N entries, checking that they form
    // a consecutive sequence ending at current_epoch
    var epoch = current_epoch;

    // Iterate in reverse order through the slice
    var i: usize = epoch_credits.len;
    while (i > epoch_index) {
        i -= 1;
        const vote_epoch = epoch_credits[i].epoch;
        if (vote_epoch != epoch) {
            return false;
        }
        epoch = epoch -| 1;
    }

    return true;
}

/// Check if the provided epoch_credits demonstrate delinquency over the previous
/// MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION epochs.
///
/// A vote account is eligible for deactivate_delinquent if its last vote was
/// at or before (current_epoch - MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION).
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/tools.rs#L67-L81
///
/// # Arguments
/// * `epoch_credits` - Slice of (epoch, credits, prev_credits) tuples from vote account
/// * `current_epoch` - The current epoch
///
/// # Returns
/// * `true` if the vote account is delinquent (eligible for deactivate_delinquent)
/// * `false` if the vote account has been voting recently
pub fn eligibleForDeactivateDelinquent(epoch_credits: []const EpochCredits, current_epoch: u64) bool {
    // If no credits at all, it's definitely delinquent
    if (epoch_credits.len == 0) {
        return true;
    }

    // Check the last entry
    const last_credits = epoch_credits[epoch_credits.len - 1];

    // Calculate the minimum epoch threshold
    // If current_epoch < MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION, checked_sub would underflow
    if (current_epoch < MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION) {
        return false;
    }
    const minimum_epoch = current_epoch - MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION;

    // Delinquent if last vote was at or before the minimum epoch
    // Rust: *epoch <= minimum_epoch
    return last_credits.epoch <= minimum_epoch;
}

// ============================================================================
// Types
// ============================================================================

/// Epoch credits tuple (epoch, credits, prev_credits)
///
/// This matches the format stored in vote accounts:
/// - epoch: The epoch number
/// - credits: Total credits earned by end of epoch
/// - prev_credits: Credits at start of epoch
pub const EpochCredits = struct {
    epoch: u64,
    credits: u64,
    prev_credits: u64,
};

// ============================================================================
// Tests
// ============================================================================

test "MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION constant" {
    try std.testing.expectEqual(@as(usize, 5), MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION);
}

// Rust test: test_acceptable_reference_epoch_credits
// Source: https://github.com/solana-program/stake/blob/master/interface/src/tools.rs#L88-L118
test "acceptableReferenceEpochCredits: basic cases" {
    // Empty credits - not acceptable
    {
        const credits = [_]EpochCredits{};
        try std.testing.expect(!acceptableReferenceEpochCredits(&credits, 0));
    }

    // 4 entries (epochs 0,1,2,3) - not acceptable (need 5)
    {
        const credits = [_]EpochCredits{
            .{ .epoch = 0, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 1, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 2, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 3, .credits = 42, .prev_credits = 42 },
        };
        try std.testing.expect(!acceptableReferenceEpochCredits(&credits, 3));
    }

    // 5 entries (epochs 0,1,2,3,4) at current_epoch=3 - not acceptable (doesn't end at current)
    {
        const credits = [_]EpochCredits{
            .{ .epoch = 0, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 1, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 2, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 3, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 4, .credits = 42, .prev_credits = 42 },
        };
        try std.testing.expect(!acceptableReferenceEpochCredits(&credits, 3));
        // At current_epoch=4, it should be acceptable
        try std.testing.expect(acceptableReferenceEpochCredits(&credits, 4));
    }

    // 5 entries (epochs 1,2,3,4,5) at current_epoch=5 - acceptable
    {
        const credits = [_]EpochCredits{
            .{ .epoch = 1, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 2, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 3, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 4, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 5, .credits = 42, .prev_credits = 42 },
        };
        try std.testing.expect(acceptableReferenceEpochCredits(&credits, 5));
    }

    // 5 entries with a gap (epochs 0,2,3,4,5) at current_epoch=5 - not acceptable
    {
        const credits = [_]EpochCredits{
            .{ .epoch = 0, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 2, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 3, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 4, .credits = 42, .prev_credits = 42 },
            .{ .epoch = 5, .credits = 42, .prev_credits = 42 },
        };
        try std.testing.expect(!acceptableReferenceEpochCredits(&credits, 5));
    }
}

// Rust test: test_eligible_for_deactivate_delinquent
// Source: https://github.com/solana-program/stake/blob/master/interface/src/tools.rs#L120-L147
test "eligibleForDeactivateDelinquent: basic cases" {
    // Empty credits - eligible (delinquent)
    {
        const credits = [_]EpochCredits{};
        try std.testing.expect(eligibleForDeactivateDelinquent(&credits, 42));
    }

    // Last vote at epoch 0, current_epoch=0 - not eligible
    {
        const credits = [_]EpochCredits{
            .{ .epoch = 0, .credits = 42, .prev_credits = 42 },
        };
        try std.testing.expect(!eligibleForDeactivateDelinquent(&credits, 0));
    }

    // Last vote at epoch 0, current_epoch = N-1 - not eligible (within threshold)
    {
        const credits = [_]EpochCredits{
            .{ .epoch = 0, .credits = 42, .prev_credits = 42 },
        };
        try std.testing.expect(!eligibleForDeactivateDelinquent(
            &credits,
            MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION - 1,
        ));
        // At current_epoch = N, it should be eligible (0 <= 5-5 = 0)
        try std.testing.expect(eligibleForDeactivateDelinquent(
            &credits,
            MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION,
        ));
    }

    // Last vote at epoch 100, test thresholds
    {
        const credits = [_]EpochCredits{
            .{ .epoch = 100, .credits = 42, .prev_credits = 42 },
        };
        // current_epoch = 104 (100 + N - 1) - not eligible
        try std.testing.expect(!eligibleForDeactivateDelinquent(
            &credits,
            100 + MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION - 1,
        ));
        // current_epoch = 105 (100 + N) - eligible (100 <= 105-5 = 100)
        try std.testing.expect(eligibleForDeactivateDelinquent(
            &credits,
            100 + MINIMUM_DELINQUENT_EPOCHS_FOR_DEACTIVATION,
        ));
    }
}
