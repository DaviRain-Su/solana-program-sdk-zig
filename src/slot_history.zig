//! Zig implementation of Solana SDK's slot history sysvar
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/slot-history/src/lib.rs
//!
//! This module provides the SlotHistory sysvar which tracks which slots have been
//! processed by the validator. It uses a bitvector to efficiently store the presence
//! of slots over a rolling window of approximately 5 days (1M slots).

const std = @import("std");
const bpf = @import("bpf.zig");
const log = @import("log.zig");
const PublicKey = @import("public_key.zig").PublicKey;

/// Maximum number of slots to track in history (approximately 5 days at 400ms/slot)
pub const MAX_ENTRIES: u64 = 1024 * 1024;

/// Number of u64 words needed to store MAX_ENTRIES bits
const BITVEC_WORDS: usize = MAX_ENTRIES / 64;

/// Result of checking if a slot exists in history
///
/// Rust equivalent: `solana_slot_history::Check`
pub const Check = enum {
    /// Slot is in the future (after newest)
    future,
    /// Slot is too old (before oldest tracked slot)
    too_old,
    /// Slot was found in history (was processed)
    found,
    /// Slot was not found in history (was skipped)
    not_found,
};

/// Slot history bitvector
///
/// Tracks which slots have been processed over a rolling window.
/// Uses a circular buffer of bits to efficiently track slot presence.
///
/// Rust equivalent: `solana_slot_history::SlotHistory`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/slot-history/src/lib.rs
pub const SlotHistory = struct {
    pub const id = PublicKey.comptimeFromBase58("SysvarS1otHistory11111111111111111111111111");
    pub const SIZE = @sizeOf(SlotHistory);

    /// Bitvector storing slot presence
    bits: [BITVEC_WORDS]u64,

    /// The next slot that will be added
    next_slot: u64,

    /// Create a new empty SlotHistory
    pub fn init() SlotHistory {
        return SlotHistory{
            .bits = [_]u64{0} ** BITVEC_WORDS,
            .next_slot = 0,
        };
    }

    /// Add a slot to the history
    ///
    /// This marks the slot as processed and updates the bitvector.
    /// Old slots beyond MAX_ENTRIES are automatically cleared.
    pub fn add(self: *SlotHistory, slot: u64) void {
        // If slot is before our window, ignore it
        if (slot < self.next_slot and self.next_slot - slot >= MAX_ENTRIES) {
            return;
        }

        // Clear bits for slots between next_slot and the new slot
        if (slot >= self.next_slot) {
            var s = self.next_slot;
            while (s <= slot) : (s += 1) {
                self.clearBit(s);
            }
            self.next_slot = slot + 1;
        }

        // Set the bit for this slot
        self.setBit(slot);
    }

    /// Check if a slot exists in history
    pub fn check(self: *const SlotHistory, slot: u64) Check {
        if (slot >= self.next_slot) {
            return .future;
        }

        if (slot < self.oldest()) {
            return .too_old;
        }

        if (self.getBit(slot)) {
            return .found;
        } else {
            return .not_found;
        }
    }

    /// Get the oldest slot that can be tracked
    pub fn oldest(self: *const SlotHistory) u64 {
        if (self.next_slot <= MAX_ENTRIES) {
            return 0;
        }
        return self.next_slot - MAX_ENTRIES;
    }

    /// Get the newest slot in history (last added slot)
    pub fn newest(self: *const SlotHistory) u64 {
        if (self.next_slot == 0) {
            return 0;
        }
        return self.next_slot - 1;
    }

    /// Check if a slot contains data (was processed)
    pub fn contains(self: *const SlotHistory, slot: u64) bool {
        return self.check(slot) == .found;
    }

    // Internal bit manipulation functions

    fn setBit(self: *SlotHistory, slot: u64) void {
        const index = slot % MAX_ENTRIES;
        const word_idx = index / 64;
        const bit_idx: u6 = @intCast(index % 64);
        self.bits[word_idx] |= (@as(u64, 1) << bit_idx);
    }

    fn clearBit(self: *SlotHistory, slot: u64) void {
        const index = slot % MAX_ENTRIES;
        const word_idx = index / 64;
        const bit_idx: u6 = @intCast(index % 64);
        self.bits[word_idx] &= ~(@as(u64, 1) << bit_idx);
    }

    fn getBit(self: *const SlotHistory, slot: u64) bool {
        const index = slot % MAX_ENTRIES;
        const word_idx = index / 64;
        const bit_idx: u6 = @intCast(index % 64);
        return (self.bits[word_idx] & (@as(u64, 1) << bit_idx)) != 0;
    }
};

// ============================================================================
// Tests
// ============================================================================

// Rust test: slot_history_test1
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/slot-history/src/lib.rs#L104
test "slot_history: basic add and check" {
    var history = SlotHistory.init();

    // Initially empty
    try std.testing.expectEqual(Check.future, history.check(0));
    try std.testing.expectEqual(@as(u64, 0), history.oldest());
    try std.testing.expectEqual(@as(u64, 0), history.newest());

    // Add slot 0
    history.add(0);
    try std.testing.expectEqual(Check.found, history.check(0));
    try std.testing.expectEqual(Check.future, history.check(1));
    try std.testing.expectEqual(@as(u64, 0), history.oldest());
    try std.testing.expectEqual(@as(u64, 0), history.newest());

    // Add slot 1
    history.add(1);
    try std.testing.expectEqual(Check.found, history.check(0));
    try std.testing.expectEqual(Check.found, history.check(1));
    try std.testing.expectEqual(Check.future, history.check(2));
    try std.testing.expectEqual(@as(u64, 1), history.newest());
}

// Rust test: slot_history_test_wrap
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/slot-history/src/lib.rs#L143
test "slot_history: wrap around at MAX_ENTRIES" {
    var history = SlotHistory.init();

    // Add slot 0
    history.add(0);
    try std.testing.expectEqual(Check.found, history.check(0));

    // Jump to MAX_ENTRIES - 1 (skip many slots)
    history.add(MAX_ENTRIES - 1);
    try std.testing.expectEqual(Check.found, history.check(0));
    try std.testing.expectEqual(Check.not_found, history.check(1)); // skipped
    try std.testing.expectEqual(Check.found, history.check(MAX_ENTRIES - 1));
    try std.testing.expectEqual(@as(u64, 0), history.oldest());

    // Add MAX_ENTRIES to cause wrap
    history.add(MAX_ENTRIES);
    try std.testing.expectEqual(Check.too_old, history.check(0)); // now too old
    try std.testing.expectEqual(Check.found, history.check(MAX_ENTRIES - 1));
    try std.testing.expectEqual(Check.found, history.check(MAX_ENTRIES));
    try std.testing.expectEqual(@as(u64, 1), history.oldest());
}

// Rust test: slot_history_test_same_index
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/slot-history/src/lib.rs#L167
test "slot_history: slots with same index" {
    var history = SlotHistory.init();

    // Add slot 0 and slot MAX_ENTRIES (same bit index)
    history.add(0);
    try std.testing.expectEqual(Check.found, history.check(0));

    history.add(MAX_ENTRIES);
    // Slot 0 should now be too old since we added slot MAX_ENTRIES
    try std.testing.expectEqual(Check.too_old, history.check(0));
    try std.testing.expectEqual(Check.found, history.check(MAX_ENTRIES));
}

// Rust test: test_older_slot
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/slot-history/src/lib.rs#L184
test "slot_history: add older slot than current" {
    var history = SlotHistory.init();

    // Add slot 10 first
    history.add(10);
    try std.testing.expectEqual(@as(u64, 10), history.newest());

    // Adding an older slot should still work
    history.add(5);
    try std.testing.expectEqual(Check.found, history.check(5));
    try std.testing.expectEqual(Check.found, history.check(10));
    // Newest should still be 10
    try std.testing.expectEqual(@as(u64, 10), history.newest());
}

// Rust test: test_oldest
// Source: https://github.com/anza-xyz/solana-sdk/blob/master/slot-history/src/lib.rs#L197
test "slot_history: oldest calculation" {
    var history = SlotHistory.init();

    // Initially oldest is 0
    try std.testing.expectEqual(@as(u64, 0), history.oldest());

    // Add some slots
    history.add(100);
    try std.testing.expectEqual(@as(u64, 0), history.oldest());

    // Jump past MAX_ENTRIES
    history.add(MAX_ENTRIES + 100);
    try std.testing.expectEqual(@as(u64, 101), history.oldest());
}

test "slot_history: contains convenience method" {
    var history = SlotHistory.init();

    history.add(0);
    history.add(2);
    // Skip slot 1

    try std.testing.expect(history.contains(0));
    try std.testing.expect(!history.contains(1)); // skipped
    try std.testing.expect(history.contains(2));
    try std.testing.expect(!history.contains(3)); // future
}

test "slot_history: future slot check" {
    var history = SlotHistory.init();

    history.add(5);

    try std.testing.expectEqual(Check.future, history.check(6));
    try std.testing.expectEqual(Check.future, history.check(100));
    try std.testing.expectEqual(Check.future, history.check(MAX_ENTRIES + 1000));
}

test "slot_history: skipped slots" {
    var history = SlotHistory.init();

    // Add non-consecutive slots
    history.add(0);
    history.add(5);
    history.add(10);

    try std.testing.expectEqual(Check.found, history.check(0));
    try std.testing.expectEqual(Check.not_found, history.check(1));
    try std.testing.expectEqual(Check.not_found, history.check(2));
    try std.testing.expectEqual(Check.not_found, history.check(3));
    try std.testing.expectEqual(Check.not_found, history.check(4));
    try std.testing.expectEqual(Check.found, history.check(5));
    try std.testing.expectEqual(Check.not_found, history.check(6));
    try std.testing.expectEqual(Check.found, history.check(10));
}
