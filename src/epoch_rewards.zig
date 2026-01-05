//! Zig implementation of Solana SDK's epoch-rewards module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-rewards/src/lib.rs
//!
//! This module provides access to the EpochRewards sysvar, which contains
//! information about epoch reward distribution including total rewards,
//! distribution status, and partitioning information.
//!
//! The EpochRewards sysvar tracks the distribution of staking rewards
//! across epochs and provides transparency into the reward allocation process.

const std = @import("std");

/// The EpochRewards sysvar data
///
/// This contains information about epoch reward distribution.
pub const EpochRewards = struct {
    /// The starting block height of the rewards distribution
    distribution_starting_block_height: u64,

    /// The number of partitions for reward distribution
    num_partitions: u64,

    /// The parent blockhash for the rewards
    parent_blockhash: [32]u8,

    /// The total number of reward points
    total_points: u64,

    /// The total rewards available for distribution (in lamports)
    total_rewards: u64,

    /// The amount of rewards already distributed (in lamports)
    distributed_rewards: u64,

    /// Whether rewards are currently active for distribution
    active: bool,

    /// Parse EpochRewards from account data
    ///
    /// # Arguments
    /// * `data` - The raw account data (must be at least 77 bytes)
    ///
    /// # Returns
    /// Parsed EpochRewards struct
    ///
    /// # Errors
    /// Returns error if data is too small or invalid
    pub fn parse(data: []const u8) !EpochRewards {
        if (data.len < SIZE) {
            return error.InvalidAccountData;
        }

        var offset: usize = 0;

        const distribution_starting_block_height = std.mem.readInt(u64, data[offset..][0..8], .little);
        offset += 8;

        const num_partitions = std.mem.readInt(u64, data[offset..][0..8], .little);
        offset += 8;

        var parent_blockhash: [32]u8 = undefined;
        @memcpy(&parent_blockhash, data[offset..][0..32]);
        offset += 32;

        const total_points = std.mem.readInt(u64, data[offset..][0..8], .little);
        offset += 8;

        const total_rewards = std.mem.readInt(u64, data[offset..][0..8], .little);
        offset += 8;

        const distributed_rewards = std.mem.readInt(u64, data[offset..][0..8], .little);
        offset += 8;

        const active = data[offset] != 0;

        return EpochRewards{
            .distribution_starting_block_height = distribution_starting_block_height,
            .num_partitions = num_partitions,
            .parent_blockhash = parent_blockhash,
            .total_points = total_points,
            .total_rewards = total_rewards,
            .distributed_rewards = distributed_rewards,
            .active = active,
        };
    }

    /// Get the distribution starting block height
    pub fn getDistributionStartingBlockHeight(self: EpochRewards) u64 {
        return self.distribution_starting_block_height;
    }

    /// Get the number of partitions
    pub fn getNumPartitions(self: EpochRewards) u64 {
        return self.num_partitions;
    }

    /// Get the parent blockhash
    pub fn getParentBlockhash(self: EpochRewards) [32]u8 {
        return self.parent_blockhash;
    }

    /// Get the total points
    pub fn getTotalPoints(self: EpochRewards) u64 {
        return self.total_points;
    }

    /// Get the total rewards
    pub fn getTotalRewards(self: EpochRewards) u64 {
        return self.total_rewards;
    }

    /// Get the distributed rewards
    pub fn getDistributedRewards(self: EpochRewards) u64 {
        return self.distributed_rewards;
    }

    /// Check if rewards are active
    pub fn isActive(self: EpochRewards) bool {
        return self.active;
    }

    /// Calculate remaining rewards
    pub fn getRemainingRewards(self: EpochRewards) u64 {
        if (self.total_rewards >= self.distributed_rewards) {
            return self.total_rewards - self.distributed_rewards;
        }
        return 0;
    }

    /// The size of EpochRewards data in bytes
    pub const SIZE: usize = 77;
};

// ============================================================================
// Tests
// ============================================================================

test "EpochRewards: parse valid data" {
    var data: [77]u8 = undefined;

    // Fill with test data
    std.mem.writeInt(u64, data[0..8], 1000000, .little); // distribution_starting_block_height
    std.mem.writeInt(u64, data[8..16], 10, .little); // num_partitions
    @memset(data[16..48], 0xAA); // parent_blockhash
    std.mem.writeInt(u64, data[48..56], 1000000, .little); // total_points
    std.mem.writeInt(u64, data[56..64], 5000000000, .little); // total_rewards
    std.mem.writeInt(u64, data[64..72], 2000000000, .little); // distributed_rewards
    data[72] = 1; // active

    const result = try EpochRewards.parse(&data);

    try std.testing.expectEqual(@as(u64, 1000000), result.getDistributionStartingBlockHeight());
    try std.testing.expectEqual(@as(u64, 10), result.getNumPartitions());
    try std.testing.expectEqualSlices(u8, &([_]u8{0xAA} ** 32), &result.getParentBlockhash());
    try std.testing.expectEqual(@as(u64, 1000000), result.getTotalPoints());
    try std.testing.expectEqual(@as(u64, 5000000000), result.getTotalRewards());
    try std.testing.expectEqual(@as(u64, 2000000000), result.getDistributedRewards());
    try std.testing.expect(result.isActive());
}

test "EpochRewards: parse invalid data (too small)" {
    const data = [_]u8{ 1, 2, 3 }; // Only 3 bytes

    const result = EpochRewards.parse(&data);
    try std.testing.expectError(error.InvalidAccountData, result);
}

test "EpochRewards: size constant" {
    try std.testing.expectEqual(@as(usize, 77), EpochRewards.SIZE);
}

test "EpochRewards: remaining rewards calculation" {
    const rewards = EpochRewards{
        .distribution_starting_block_height = 0,
        .num_partitions = 0,
        .parent_blockhash = [_]u8{0} ** 32,
        .total_points = 0,
        .total_rewards = 1000,
        .distributed_rewards = 300,
        .active = true,
    };

    try std.testing.expectEqual(@as(u64, 700), rewards.getRemainingRewards());
}

test "EpochRewards: remaining rewards with overflow protection" {
    const rewards = EpochRewards{
        .distribution_starting_block_height = 0,
        .num_partitions = 0,
        .parent_blockhash = [_]u8{0} ** 32,
        .total_points = 0,
        .total_rewards = 100,
        .distributed_rewards = 200, // More than total
        .active = true,
    };

    try std.testing.expectEqual(@as(u64, 0), rewards.getRemainingRewards());
}

test "EpochRewards: round trip serialization" {
    const original = EpochRewards{
        .distribution_starting_block_height = 123456789,
        .num_partitions = 42,
        .parent_blockhash = [_]u8{0xBB} ** 32,
        .total_points = 987654321,
        .total_rewards = 10000000000,
        .distributed_rewards = 5000000000,
        .active = true,
    };

    // Serialize (simulate writing to account data)
    var buffer: [77]u8 = undefined;
    var offset: usize = 0;

    std.mem.writeInt(u64, buffer[offset..][0..8], original.distribution_starting_block_height, .little);
    offset += 8;
    std.mem.writeInt(u64, buffer[offset..][0..8], original.num_partitions, .little);
    offset += 8;
    @memcpy(buffer[offset..][0..32], &original.parent_blockhash);
    offset += 32;
    std.mem.writeInt(u64, buffer[offset..][0..8], original.total_points, .little);
    offset += 8;
    std.mem.writeInt(u64, buffer[offset..][0..8], original.total_rewards, .little);
    offset += 8;
    std.mem.writeInt(u64, buffer[offset..][0..8], original.distributed_rewards, .little);
    offset += 8;
    buffer[offset] = if (original.active) 1 else 0;

    // Parse back
    const parsed = try EpochRewards.parse(&buffer);

    // Verify all fields match
    try std.testing.expectEqual(original.distribution_starting_block_height, parsed.distribution_starting_block_height);
    try std.testing.expectEqual(original.num_partitions, parsed.num_partitions);
    try std.testing.expectEqualSlices(u8, &original.parent_blockhash, &parsed.parent_blockhash);
    try std.testing.expectEqual(original.total_points, parsed.total_points);
    try std.testing.expectEqual(original.total_rewards, parsed.total_rewards);
    try std.testing.expectEqual(original.distributed_rewards, parsed.distributed_rewards);
    try std.testing.expectEqual(original.active, parsed.active);
}
