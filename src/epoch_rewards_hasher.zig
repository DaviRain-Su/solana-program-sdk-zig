//! Zig implementation of Solana SDK's epoch-rewards-hasher module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-rewards-hasher/src/lib.rs
//!
//! This module provides a deterministic, unbiased hash-based partitioning mechanism
//! for distributing epoch rewards across multiple partitions in Solana.
//!
//! Key features:
//! - SipHasher13: Fast, cryptographically-weak hash function for non-adversarial partitioning
//! - Seeded Hashing: Each hasher is initialized with a seed for deterministic distribution
//! - Unbiased Distribution: Uses 128-bit arithmetic to avoid modulo bias

const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;
const Hash = @import("hash.zig").Hash;

/// SipHash-1-3 implementation (same parameters as Rust's SipHasher13)
/// Using Zig's standard library SipHash with c_rounds=1, d_rounds=3
const SipHash13 = std.hash.SipHash64(1, 3);

/// Epoch rewards hasher for deterministic partition assignment.
///
/// Uses SipHash-1-3 keyed on a seed (typically epoch-specific) to map
/// addresses to partitions in an unbiased manner.
///
/// Rust equivalent: `solana_epoch_rewards_hasher::EpochRewardsHasher`
pub const EpochRewardsHasher = struct {
    /// Number of partitions
    partitions: usize,
    /// The seed bytes for hashing (used as SipHash key, first 16 bytes)
    sip_key: [16]u8,

    const Self = @This();

    /// Create a new EpochRewardsHasher with the given number of partitions and seed.
    ///
    /// The seed is typically derived from the epoch's parent blockhash or similar
    /// epoch-specific data to ensure deterministic but varying distributions.
    ///
    /// # Arguments
    /// * `partitions` - Number of partitions to distribute addresses across
    /// * `seed` - Hash value used as the seed for the hasher
    ///
    /// # Returns
    /// A new EpochRewardsHasher instance
    ///
    /// Rust equivalent: `EpochRewardsHasher::new`
    pub fn new(partitions: usize, seed: *const Hash) Self {
        // Use first 16 bytes of seed as SipHash key
        var sip_key: [16]u8 = undefined;
        @memcpy(&sip_key, seed.bytes[0..16]);
        return .{
            .partitions = partitions,
            .sip_key = sip_key,
        };
    }

    /// Hash an address to determine its partition index.
    ///
    /// Returns a value in the range [0, partitions) indicating which partition
    /// the address belongs to. The distribution is unbiased.
    ///
    /// # Arguments
    /// * `address` - The public key/address to hash
    ///
    /// # Returns
    /// Partition index (0..partitions)
    ///
    /// Rust equivalent: `EpochRewardsHasher::hash_address_to_partition`
    pub fn hashAddressToPartition(self: Self, address: *const PublicKey) usize {
        // Hash the address bytes using SipHash-1-3 with the seed-derived key
        const hash64 = SipHash13.toInt(&address.bytes, &self.sip_key);
        return hashToPartition(hash64, self.partitions);
    }
};

/// Compute the partition index by modulo the hash to number of partitions without bias.
///
/// Uses the formula: (hash * partitions) / (u64::MAX + 1)
///
/// This avoids modulo bias by using 128-bit arithmetic to ensure uniform distribution
/// even when the number of partitions doesn't evenly divide the hash space.
///
/// Rust equivalent: `hash_to_partition`
pub fn hashToPartition(hash: u64, partitions: usize) usize {
    // (partitions * hash) / (u64::MAX + 1)
    // Using 128-bit arithmetic to avoid overflow
    const partitions_u128: u128 = @intCast(partitions);
    const hash_u128: u128 = @intCast(hash);
    const max_plus_one: u128 = @as(u128, std.math.maxInt(u64)) + 1;

    const result = (partitions_u128 *| hash_u128) / max_plus_one;
    return @intCast(result);
}

/// Helper function to get the range of hash values for a given partition.
/// Used for testing to verify partition boundaries.
///
/// Returns the inclusive range [start, end] of hash values that map to the partition.
fn getEqualPartitionRange(partition: usize, partitions: usize) struct { start: u64, end: u64 } {
    const max_inclusive: u128 = std.math.maxInt(u64);
    const max_plus_1: u128 = max_inclusive + 1;
    const partition_u128: u128 = @intCast(partition);
    const partitions_u128: u128 = @intCast(partitions);

    var start: u128 = max_plus_1 * partition_u128 / partitions_u128;

    // Adjust start if partitions don't evenly divide
    if (partition > 0) {
        const check = start * partitions_u128 / max_plus_1;
        if (check == partition_u128 - 1) {
            start += 1;
        }
    }

    var end_inclusive: u128 = start + max_plus_1 / partitions_u128 - 1;

    if (partition < partitions -| 1) {
        const next = end_inclusive + 1;
        const check = next * partitions_u128 / max_plus_1;
        if (check == partition_u128) {
            end_inclusive += 1;
        }
    } else {
        end_inclusive = max_inclusive;
    }

    return .{
        .start = @intCast(start),
        .end = @intCast(end_inclusive),
    };
}

// ============================================================================
// Tests
// ============================================================================

// Rust test: test_get_equal_partition_range
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-rewards-hasher/src/lib.rs#L47
test "epoch_rewards_hasher: get equal partition range" {
    // Show how 2 equal partition ranges are 0..=(max/2), (max/2+1)..=max
    const range0 = getEqualPartitionRange(0, 2);
    try std.testing.expectEqual(@as(u64, 0), range0.start);
    try std.testing.expectEqual(std.math.maxInt(u64) / 2, range0.end);

    const range1 = getEqualPartitionRange(1, 2);
    try std.testing.expectEqual(std.math.maxInt(u64) / 2 + 1, range1.start);
    try std.testing.expectEqual(std.math.maxInt(u64), range1.end);
}

// Rust test: test_hash_to_partitions
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-rewards-hasher/src/lib.rs#L59
test "epoch_rewards_hasher: hash to partitions" {
    const partitions: usize = 16;

    try std.testing.expectEqual(@as(usize, 0), hashToPartition(0, partitions));
    try std.testing.expectEqual(@as(usize, 0), hashToPartition(std.math.maxInt(u64) / 16, partitions));
    try std.testing.expectEqual(@as(usize, 1), hashToPartition(std.math.maxInt(u64) / 16 + 1, partitions));
    try std.testing.expectEqual(@as(usize, 1), hashToPartition(std.math.maxInt(u64) / 16 * 2, partitions));
    try std.testing.expectEqual(@as(usize, 1), hashToPartition(std.math.maxInt(u64) / 16 * 2 + 1, partitions));
    try std.testing.expectEqual(partitions - 1, hashToPartition(std.math.maxInt(u64) - 1, partitions));
    try std.testing.expectEqual(partitions - 1, hashToPartition(std.math.maxInt(u64), partitions));
}

// Helper for test_hash_to_partitions_equal_ranges
fn testPartitions(partition: usize, partitions: usize) !void {
    const p = @min(partition, partitions - 1);
    const range = getEqualPartitionRange(p, partitions);

    // Beginning and end of this partition
    try std.testing.expectEqual(p, hashToPartition(range.start, partitions));
    try std.testing.expectEqual(p, hashToPartition(range.end, partitions));

    if (p < partitions - 1) {
        // First index in next partition
        try std.testing.expectEqual(p + 1, hashToPartition(range.end + 1, partitions));
    } else {
        try std.testing.expectEqual(std.math.maxInt(u64), range.end);
    }

    if (p > 0) {
        // Last index in previous partition
        try std.testing.expectEqual(p - 1, hashToPartition(range.start - 1, partitions));
    } else {
        try std.testing.expectEqual(@as(u64, 0), range.start);
    }
}

// Rust test: test_hash_to_partitions_equal_ranges
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-rewards-hasher/src/lib.rs#L97
test "epoch_rewards_hasher: hash to partitions equal ranges" {
    // Test evenly divisible partitions
    const even_partitions = [_]usize{ 2, 4, 8, 16, 4096 };
    for (even_partitions) |partitions| {
        try std.testing.expectEqual(@as(usize, 0), hashToPartition(0, partitions));

        const test_indices = [_]usize{ 0, 1, 2, partitions - 1 };
        for (test_indices) |partition| {
            if (partition < partitions) {
                try testPartitions(partition, partitions);
            }
        }

        // Verify all partitions have equal size
        const range0 = getEqualPartitionRange(0, partitions);
        const expected_size = range0.end - range0.start;

        var p: usize = 1;
        while (p < partitions) : (p += 1) {
            const this_range = getEqualPartitionRange(p, partitions);
            const this_size = this_range.end - this_range.start;
            try std.testing.expectEqual(expected_size, this_size);
        }
    }

    // Test non-evenly divisible partitions
    const odd_partitions = [_]usize{ 3, 19, 1019, 4095 };
    for (odd_partitions) |partitions| {
        const test_indices = [_]usize{ 0, 1, 2, partitions - 1 };
        for (test_indices) |partition| {
            if (partition < partitions) {
                try testPartitions(partition, partitions);
            }
        }

        // Size is same or differs by at most 1
        const max_plus_1: u128 = @as(u128, std.math.maxInt(u64)) + 1;
        const expected_len: u64 = @intCast(max_plus_1 / @as(u128, partitions));

        var p: usize = 0;
        while (p < partitions) : (p += 1) {
            const this_range = getEqualPartitionRange(p, partitions);
            const len = this_range.end - this_range.start;
            // Size is same or 1 less
            try std.testing.expect(len == expected_len or len + 1 == expected_len);
        }
    }
}

// Rust test: test_hasher_copy
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-rewards-hasher/src/lib.rs#L160
test "epoch_rewards_hasher: hasher copy" {
    // Create a unique seed
    var seed = Hash.default();
    seed.bytes[0] = 0x42;
    seed.bytes[1] = 0x43;

    const partitions: usize = 10;
    const hasher = EpochRewardsHasher.new(partitions, &seed);

    // Create a unique public key
    var pk = PublicKey.default();
    pk.bytes[0] = 0xAB;
    pk.bytes[1] = 0xCD;

    // Hash the same address twice - should get same result
    const b1 = hasher.hashAddressToPartition(&pk);
    const b2 = hasher.hashAddressToPartition(&pk);
    try std.testing.expectEqual(b1, b2);

    // Verify the partition is in valid range
    try std.testing.expect(b1 < partitions);
}

test "epoch_rewards_hasher: basic functionality" {
    var seed = Hash.default();
    seed.bytes[0] = 1;

    const hasher = EpochRewardsHasher.new(100, &seed);

    var pk = PublicKey.default();
    pk.bytes[0] = 1;

    const partition = hasher.hashAddressToPartition(&pk);

    // Partition should be in valid range
    try std.testing.expect(partition < 100);
}

test "epoch_rewards_hasher: different seeds produce different partitions" {
    var seed1 = Hash.default();
    seed1.bytes[0] = 1;

    var seed2 = Hash.default();
    seed2.bytes[0] = 2;

    const hasher1 = EpochRewardsHasher.new(1000, &seed1);
    const hasher2 = EpochRewardsHasher.new(1000, &seed2);

    var pk = PublicKey.default();
    pk.bytes[0] = 42;

    const p1 = hasher1.hashAddressToPartition(&pk);
    const p2 = hasher2.hashAddressToPartition(&pk);

    // Different seeds should (likely) produce different partitions
    // With 1000 partitions, probability of collision is ~0.1%
    // This test may rarely fail due to chance collision, but that's acceptable
    try std.testing.expect(p1 != p2);
}
