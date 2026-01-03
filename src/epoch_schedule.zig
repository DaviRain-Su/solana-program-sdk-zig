//! Zig implementation of Solana SDK's epoch schedule sysvar
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-schedule/src/lib.rs
//!
//! This module provides the EpochSchedule sysvar which contains epoch timing
//! configuration and methods for calculating epoch boundaries.

const std = @import("std");
const bpf = @import("bpf.zig");
const log = @import("log.zig");
const PublicKey = @import("public_key.zig").PublicKey;

/// Minimum slots per epoch during the warmup period
pub const MINIMUM_SLOTS_PER_EPOCH: u64 = 32;

/// Default target slots per epoch (approximately 2 days at 400ms/slot)
pub const DEFAULT_SLOTS_PER_EPOCH: u64 = 432_000;

/// Default leader schedule slot offset
pub const DEFAULT_LEADER_SCHEDULE_SLOT_OFFSET: u64 = DEFAULT_SLOTS_PER_EPOCH;

/// Epoch schedule configuration
///
/// Rust equivalent: `solana_epoch_schedule::EpochSchedule`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-schedule/src/lib.rs
pub const EpochSchedule = extern struct {
    pub const id = PublicKey.comptimeFromBase58("SysvarEpochSchewordu1e11111111111111111111");

    /// The maximum number of slots in each epoch
    slots_per_epoch: u64,

    /// The number of slots before beginning of an epoch to calculate
    /// the leader schedule for that epoch
    leader_schedule_slot_offset: u64,

    /// Whether epochs start short and grow
    warmup: bool,

    /// The first epoch with `slots_per_epoch` slots
    first_normal_epoch: u64,

    /// The first slot of `first_normal_epoch`
    first_normal_slot: u64,

    /// Create a new EpochSchedule with custom settings
    pub fn init(slots_per_epoch: u64, leader_schedule_slot_offset: u64, warmup: bool) EpochSchedule {
        var schedule = EpochSchedule{
            .slots_per_epoch = slots_per_epoch,
            .leader_schedule_slot_offset = leader_schedule_slot_offset,
            .warmup = warmup,
            .first_normal_epoch = 0,
            .first_normal_slot = 0,
        };

        if (warmup) {
            const result = schedule.getFirstNormalEpochAndSlot();
            schedule.first_normal_epoch = result[0];
            schedule.first_normal_slot = result[1];
        }

        return schedule;
    }

    /// Create a new EpochSchedule without warmup
    pub fn withoutWarmup() EpochSchedule {
        return EpochSchedule{
            .slots_per_epoch = DEFAULT_SLOTS_PER_EPOCH,
            .leader_schedule_slot_offset = DEFAULT_LEADER_SCHEDULE_SLOT_OFFSET,
            .warmup = false,
            .first_normal_epoch = 0,
            .first_normal_slot = 0,
        };
    }

    /// Create a custom EpochSchedule
    pub fn custom(slots_per_epoch: u64, leader_schedule_slot_offset: u64, warmup: bool) EpochSchedule {
        return init(slots_per_epoch, leader_schedule_slot_offset, warmup);
    }

    /// Calculate the first normal epoch and slot based on warmup configuration
    fn getFirstNormalEpochAndSlot(self: EpochSchedule) struct { u64, u64 } {
        var epoch: u64 = 0;
        var slot: u64 = 0;
        var slots_in_epoch = MINIMUM_SLOTS_PER_EPOCH;

        while (slots_in_epoch < self.slots_per_epoch) {
            slot += slots_in_epoch;
            slots_in_epoch *= 2;
            epoch += 1;
        }

        return .{ epoch, slot };
    }

    /// Get the epoch for the given slot
    pub fn getEpoch(self: EpochSchedule, slot: u64) u64 {
        return self.getEpochAndSlotIndex(slot)[0];
    }

    /// Get both the epoch and slot index within that epoch
    pub fn getEpochAndSlotIndex(self: EpochSchedule, slot: u64) struct { u64, u64 } {
        if (slot < self.first_normal_slot) {
            // We're in the warmup period
            var epoch: u64 = 0;
            var slots_in_epoch = MINIMUM_SLOTS_PER_EPOCH;
            var epoch_start: u64 = 0;

            while (epoch_start + slots_in_epoch <= slot) {
                epoch_start += slots_in_epoch;
                slots_in_epoch *= 2;
                epoch += 1;
            }

            return .{ epoch, slot - epoch_start };
        } else {
            // Normal epoch calculation
            const normal_slot_index = slot - self.first_normal_slot;
            const normal_epoch_index = normal_slot_index / self.slots_per_epoch;
            const epoch = self.first_normal_epoch + normal_epoch_index;
            const slot_index = normal_slot_index % self.slots_per_epoch;
            return .{ epoch, slot_index };
        }
    }

    /// Get the first slot in the given epoch
    pub fn getFirstSlotInEpoch(self: EpochSchedule, epoch: u64) u64 {
        if (epoch <= self.first_normal_epoch) {
            return self.getFirstSlotInEpochWarmup(epoch);
        } else {
            return self.first_normal_slot + (epoch - self.first_normal_epoch) * self.slots_per_epoch;
        }
    }

    /// Calculate first slot during warmup period
    fn getFirstSlotInEpochWarmup(self: EpochSchedule, epoch: u64) u64 {
        _ = self;
        if (epoch == 0) return 0;

        // During warmup, epoch N has 2^N * MINIMUM_SLOTS_PER_EPOCH slots
        // First slot of epoch N = sum of slots in epochs 0..N-1
        // = MINIMUM_SLOTS_PER_EPOCH * (2^N - 1)
        const exponent = @min(epoch, 63); // Prevent overflow
        const slots_before = MINIMUM_SLOTS_PER_EPOCH * ((@as(u64, 1) << @intCast(exponent)) - 1);
        return slots_before;
    }

    /// Get the last slot in the given epoch
    pub fn getLastSlotInEpoch(self: EpochSchedule, epoch: u64) u64 {
        return self.getFirstSlotInEpoch(epoch) + self.getSlotsInEpoch(epoch) - 1;
    }

    /// Get the number of slots in the given epoch
    pub fn getSlotsInEpoch(self: EpochSchedule, epoch: u64) u64 {
        if (!self.warmup or epoch >= self.first_normal_epoch) {
            return self.slots_per_epoch;
        }

        // During warmup, epoch N has 2^N * MINIMUM_SLOTS_PER_EPOCH slots
        const exponent = @min(epoch, 63); // Prevent overflow
        return MINIMUM_SLOTS_PER_EPOCH << @intCast(exponent);
    }

    /// Get the leader schedule epoch for the given slot
    pub fn getLeaderScheduleEpoch(self: EpochSchedule, slot: u64) u64 {
        if (slot < self.first_normal_slot) {
            // During warmup, leader schedule epoch is same as slot's epoch
            return self.getEpoch(slot);
        }

        // Calculate which epoch's leader schedule would include this slot
        const new_slots_since_first_normal_slot = slot - self.first_normal_slot;
        const new_first_normal_leader_schedule_slot = self.first_normal_slot + self.leader_schedule_slot_offset;

        if (slot < new_first_normal_leader_schedule_slot) {
            return self.getEpoch(slot);
        }

        const new_epochs_since_first_normal_leader_schedule =
            (slot - new_first_normal_leader_schedule_slot) / self.slots_per_epoch;
        _ = new_slots_since_first_normal_slot;
        return self.first_normal_epoch + new_epochs_since_first_normal_leader_schedule;
    }

    /// Get the EpochSchedule sysvar from the runtime
    pub fn get() !EpochSchedule {
        var schedule: EpochSchedule = undefined;
        if (bpf.is_bpf_program) {
            const Syscall = struct {
                extern fn sol_get_epoch_schedule_sysvar(ptr: *EpochSchedule) callconv(.c) u64;
            };
            const result = Syscall.sol_get_epoch_schedule_sysvar(&schedule);
            if (result != 0) {
                log.print("failed to get epoch schedule sysvar: error code {d}", .{result});
                return error.Unexpected;
            }
        } else {
            log.log("cannot get epoch schedule in non-bpf context");
            return error.Unexpected;
        }
        return schedule;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "epoch_schedule: without warmup basic" {
    const schedule = EpochSchedule.withoutWarmup();

    try std.testing.expect(!schedule.warmup);
    try std.testing.expectEqual(@as(u64, DEFAULT_SLOTS_PER_EPOCH), schedule.slots_per_epoch);
    try std.testing.expectEqual(@as(u64, 0), schedule.first_normal_epoch);
    try std.testing.expectEqual(@as(u64, 0), schedule.first_normal_slot);
}

test "epoch_schedule: get epoch without warmup" {
    const schedule = EpochSchedule.withoutWarmup();

    // Slot 0 is epoch 0
    try std.testing.expectEqual(@as(u64, 0), schedule.getEpoch(0));

    // Slot slots_per_epoch - 1 is still epoch 0
    try std.testing.expectEqual(@as(u64, 0), schedule.getEpoch(schedule.slots_per_epoch - 1));

    // Slot slots_per_epoch is epoch 1
    try std.testing.expectEqual(@as(u64, 1), schedule.getEpoch(schedule.slots_per_epoch));

    // Test epoch 5
    try std.testing.expectEqual(@as(u64, 5), schedule.getEpoch(schedule.slots_per_epoch * 5));
}

test "epoch_schedule: get epoch and slot index" {
    const schedule = EpochSchedule.withoutWarmup();

    // Slot 0
    const result0 = schedule.getEpochAndSlotIndex(0);
    try std.testing.expectEqual(@as(u64, 0), result0[0]); // epoch
    try std.testing.expectEqual(@as(u64, 0), result0[1]); // slot index

    // Slot 100
    const result100 = schedule.getEpochAndSlotIndex(100);
    try std.testing.expectEqual(@as(u64, 0), result100[0]); // epoch
    try std.testing.expectEqual(@as(u64, 100), result100[1]); // slot index

    // Slot slots_per_epoch + 50
    const result_epoch1 = schedule.getEpochAndSlotIndex(schedule.slots_per_epoch + 50);
    try std.testing.expectEqual(@as(u64, 1), result_epoch1[0]); // epoch
    try std.testing.expectEqual(@as(u64, 50), result_epoch1[1]); // slot index
}

test "epoch_schedule: get first and last slot in epoch" {
    const schedule = EpochSchedule.withoutWarmup();

    // Epoch 0
    try std.testing.expectEqual(@as(u64, 0), schedule.getFirstSlotInEpoch(0));
    try std.testing.expectEqual(schedule.slots_per_epoch - 1, schedule.getLastSlotInEpoch(0));

    // Epoch 1
    try std.testing.expectEqual(schedule.slots_per_epoch, schedule.getFirstSlotInEpoch(1));
    try std.testing.expectEqual(schedule.slots_per_epoch * 2 - 1, schedule.getLastSlotInEpoch(1));

    // Epoch 5
    try std.testing.expectEqual(schedule.slots_per_epoch * 5, schedule.getFirstSlotInEpoch(5));
    try std.testing.expectEqual(schedule.slots_per_epoch * 6 - 1, schedule.getLastSlotInEpoch(5));
}

test "epoch_schedule: get slots in epoch without warmup" {
    const schedule = EpochSchedule.withoutWarmup();

    // All epochs have the same number of slots without warmup
    try std.testing.expectEqual(schedule.slots_per_epoch, schedule.getSlotsInEpoch(0));
    try std.testing.expectEqual(schedule.slots_per_epoch, schedule.getSlotsInEpoch(1));
    try std.testing.expectEqual(schedule.slots_per_epoch, schedule.getSlotsInEpoch(100));
}

test "epoch_schedule: warmup slots progression" {
    // Create schedule with warmup (target 256 slots per epoch)
    const schedule = EpochSchedule.init(256, 256, true);

    try std.testing.expect(schedule.warmup);

    // During warmup:
    // Epoch 0: 32 slots (MINIMUM_SLOTS_PER_EPOCH)
    // Epoch 1: 64 slots
    // Epoch 2: 128 slots
    // Epoch 3+: 256 slots (normal)

    try std.testing.expectEqual(@as(u64, 32), schedule.getSlotsInEpoch(0));
    try std.testing.expectEqual(@as(u64, 64), schedule.getSlotsInEpoch(1));
    try std.testing.expectEqual(@as(u64, 128), schedule.getSlotsInEpoch(2));
    try std.testing.expectEqual(@as(u64, 256), schedule.getSlotsInEpoch(3));
    try std.testing.expectEqual(@as(u64, 256), schedule.getSlotsInEpoch(10));
}

test "epoch_schedule: first normal epoch calculation" {
    // Target 256 slots per epoch with warmup
    const schedule = EpochSchedule.init(256, 256, true);

    // Warmup: 32 -> 64 -> 128 -> 256
    // So first_normal_epoch should be 3
    // first_normal_slot = 32 + 64 + 128 = 224
    try std.testing.expectEqual(@as(u64, 3), schedule.first_normal_epoch);
    try std.testing.expectEqual(@as(u64, 224), schedule.first_normal_slot);
}

test "epoch_schedule: get epoch with warmup" {
    const schedule = EpochSchedule.init(256, 256, true);

    // Epoch 0: slots 0-31
    try std.testing.expectEqual(@as(u64, 0), schedule.getEpoch(0));
    try std.testing.expectEqual(@as(u64, 0), schedule.getEpoch(31));

    // Epoch 1: slots 32-95
    try std.testing.expectEqual(@as(u64, 1), schedule.getEpoch(32));
    try std.testing.expectEqual(@as(u64, 1), schedule.getEpoch(95));

    // Epoch 2: slots 96-223
    try std.testing.expectEqual(@as(u64, 2), schedule.getEpoch(96));
    try std.testing.expectEqual(@as(u64, 2), schedule.getEpoch(223));

    // Epoch 3 (first normal): slots 224-479
    try std.testing.expectEqual(@as(u64, 3), schedule.getEpoch(224));
    try std.testing.expectEqual(@as(u64, 3), schedule.getEpoch(479));

    // Epoch 4: slots 480-735
    try std.testing.expectEqual(@as(u64, 4), schedule.getEpoch(480));
}
