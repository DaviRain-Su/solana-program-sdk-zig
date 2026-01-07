//! Zig implementation of Solana Stake History types
//!
//! Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs
//!
//! This module provides types for tracking stake activation/deactivation history:
//! - StakeHistoryEntry: Stake amounts for a single epoch
//! - StakeHistory: Collection of stake history entries
//! - StakeHistoryGetEntry: Trait for looking up history entries

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Maximum number of entries in StakeHistory
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L9
pub const MAX_ENTRIES: usize = 512;

// ============================================================================
// StakeHistoryEntry
// ============================================================================

/// A single entry in the stake history, recording the stake amounts for an epoch.
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L14-L21
///
/// Layout (24 bytes):
/// - bytes[0..8]: effective (u64, little-endian)
/// - bytes[8..16]: activating (u64, little-endian)
/// - bytes[16..24]: deactivating (u64, little-endian)
pub const StakeHistoryEntry = struct {
    /// Effective stake at this epoch
    effective: u64,
    /// Sum of all stake being activated during this epoch
    activating: u64,
    /// Sum of all stake being deactivated during this epoch
    deactivating: u64,

    /// Size in bytes
    pub const SIZE: usize = 24;

    /// Default entry (all zeros)
    pub const DEFAULT: StakeHistoryEntry = .{
        .effective = 0,
        .activating = 0,
        .deactivating = 0,
    };

    /// Create entry with effective stake only
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L23-L29
    pub fn withEffective(effective: u64) StakeHistoryEntry {
        return .{
            .effective = effective,
            .activating = 0,
            .deactivating = 0,
        };
    }

    /// Create entry with effective and activating stake
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L31-L37
    pub fn withEffectiveAndActivating(effective: u64, activating: u64) StakeHistoryEntry {
        return .{
            .effective = effective,
            .activating = activating,
            .deactivating = 0,
        };
    }

    /// Create entry with deactivating stake only
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L39-L45
    pub fn withDeactivating(deactivating: u64) StakeHistoryEntry {
        return .{
            .effective = 0,
            .activating = 0,
            .deactivating = deactivating,
        };
    }

    /// Add two entries together
    ///
    /// Rust source: impl Add for StakeHistoryEntry
    pub fn add(self: StakeHistoryEntry, other: StakeHistoryEntry) StakeHistoryEntry {
        return .{
            .effective = self.effective +| other.effective,
            .activating = self.activating +| other.activating,
            .deactivating = self.deactivating +| other.deactivating,
        };
    }

    /// Check if entry is empty (all zeros)
    pub fn isEmpty(self: StakeHistoryEntry) bool {
        return self.effective == 0 and self.activating == 0 and self.deactivating == 0;
    }

    /// Unpack from bytes
    pub fn unpack(data: []const u8) !StakeHistoryEntry {
        if (data.len < SIZE) return error.InvalidAccountData;
        return .{
            .effective = std.mem.readInt(u64, data[0..8], .little),
            .activating = std.mem.readInt(u64, data[8..16], .little),
            .deactivating = std.mem.readInt(u64, data[16..24], .little),
        };
    }

    /// Pack into bytes
    ///
    /// Returns error.InvalidAccountData if dest buffer is too small.
    pub fn pack(self: StakeHistoryEntry, dest: []u8) !void {
        if (dest.len < SIZE) return error.InvalidAccountData;
        std.mem.writeInt(u64, dest[0..8], self.effective, .little);
        std.mem.writeInt(u64, dest[8..16], self.activating, .little);
        std.mem.writeInt(u64, dest[16..24], self.deactivating, .little);
    }
};

// ============================================================================
// StakeHistoryGetEntry Trait
// ============================================================================

/// Interface for types that can provide stake history entries by epoch.
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L74-L76
///
/// This is used to abstract over StakeHistory (full collection) vs
/// StakeHistorySysvar (syscall-based access).
pub fn StakeHistoryGetEntry(comptime T: type) type {
    return struct {
        /// Get the stake history entry for a given epoch.
        /// Returns null if the epoch is not found.
        pub fn getEntry(self: T, epoch: u64) ?StakeHistoryEntry {
            return self.get(epoch);
        }
    };
}

// ============================================================================
// StakeHistory
// ============================================================================

/// A collection of stake history entries, indexed by epoch.
///
/// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L47-L72
///
/// The history is stored as a vector of (epoch, entry) pairs, sorted by epoch
/// in descending order (most recent first). The maximum size is MAX_ENTRIES.
pub const StakeHistory = struct {
    /// Entries stored as (epoch, entry) pairs, sorted by epoch descending
    entries: std.ArrayList(Entry),
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    /// Single entry tuple type
    pub const Entry = struct {
        epoch: u64,
        entry: StakeHistoryEntry,
    };

    /// Initialize empty stake history
    pub fn init(allocator: std.mem.Allocator) StakeHistory {
        return .{
            .entries = .{
                .items = &.{},
                .capacity = 0,
            },
            .allocator = allocator,
        };
    }

    /// Deinitialize and free memory
    pub fn deinit(self: *StakeHistory) void {
        self.entries.deinit(self.allocator);
    }

    /// Get entry for a specific epoch
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L52-L59
    pub fn get(self: StakeHistory, epoch: u64) ?StakeHistoryEntry {
        for (self.entries.items) |e| {
            if (e.epoch == epoch) {
                return e.entry;
            }
            // Entries are sorted descending, so if we've passed the epoch, stop
            if (e.epoch < epoch) {
                break;
            }
        }
        return null;
    }

    /// Add an entry for an epoch
    ///
    /// Rust source: https://github.com/solana-program/stake/blob/master/interface/src/stake_history.rs#L61-L71
    ///
    /// If an entry for this epoch already exists, it is replaced.
    /// Entries are kept sorted by epoch in descending order.
    /// The oldest entries are removed if the history exceeds MAX_ENTRIES.
    pub fn addEntry(self: *StakeHistory, epoch: u64, entry: StakeHistoryEntry) !void {
        // Find insertion point (sorted descending by epoch)
        var insert_idx: usize = 0;
        for (self.entries.items, 0..) |e, i| {
            if (e.epoch == epoch) {
                // Replace existing entry
                self.entries.items[i].entry = entry;
                return;
            }
            if (e.epoch < epoch) {
                insert_idx = i;
                break;
            }
            insert_idx = i + 1;
        }

        // Insert at the correct position
        try self.entries.insert(self.allocator, insert_idx, .{ .epoch = epoch, .entry = entry });

        // Remove oldest entries if we exceed MAX_ENTRIES
        while (self.entries.items.len > MAX_ENTRIES) {
            _ = self.entries.pop();
        }
    }

    /// Get number of entries
    pub fn len(self: StakeHistory) usize {
        return self.entries.items.len;
    }

    /// Check if empty
    pub fn isEmpty(self: StakeHistory) bool {
        return self.entries.items.len == 0;
    }

    /// Get slice of all entries
    pub fn items(self: StakeHistory) []const Entry {
        return self.entries.items;
    }

    /// Size of a single serialized entry in bytes
    /// Each entry is: epoch (8 bytes) + StakeHistoryEntry (24 bytes) = 32 bytes
    pub const ENTRY_SIZE: usize = 8 + StakeHistoryEntry.SIZE;

    /// Unpack StakeHistory from bincode-serialized bytes
    ///
    /// Format:
    /// - bytes[0..8]: length (u64, little-endian)
    /// - bytes[8..]: array of (epoch: u64, entry: StakeHistoryEntry) pairs
    ///
    /// Each entry is 32 bytes (8 + 24).
    pub fn unpack(allocator: std.mem.Allocator, data: []const u8) !StakeHistory {
        if (data.len < 8) return error.InvalidAccountData;

        const count = std.mem.readInt(u64, data[0..8], .little);
        if (count > MAX_ENTRIES) return error.InvalidAccountData;

        const expected_size = 8 + count * ENTRY_SIZE;
        if (data.len < expected_size) return error.InvalidAccountData;

        var history = StakeHistory.init(allocator);
        errdefer history.deinit();

        var offset: usize = 8;
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            const epoch = std.mem.readInt(u64, data[offset..][0..8], .little);
            const entry = try StakeHistoryEntry.unpack(data[offset + 8 ..][0..StakeHistoryEntry.SIZE]);
            try history.addEntry(epoch, entry);
            offset += ENTRY_SIZE;
        }

        return history;
    }

    /// Pack StakeHistory into bincode-serialized bytes
    ///
    /// Returns the number of bytes written, or error if buffer is too small.
    pub fn pack(self: StakeHistory, dest: []u8) !usize {
        const count = self.entries.items.len;
        const needed_size = 8 + count * ENTRY_SIZE;
        if (dest.len < needed_size) return error.InvalidAccountData;

        // Write length
        std.mem.writeInt(u64, dest[0..8], @intCast(count), .little);

        // Write entries
        var offset: usize = 8;
        for (self.entries.items) |e| {
            std.mem.writeInt(u64, dest[offset..][0..8], e.epoch, .little);
            try e.entry.pack(dest[offset + 8 ..][0..StakeHistoryEntry.SIZE]);
            offset += ENTRY_SIZE;
        }

        return needed_size;
    }

    /// Calculate the size needed to serialize this history
    pub fn packedSize(self: StakeHistory) usize {
        return 8 + self.entries.items.len * ENTRY_SIZE;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StakeHistoryEntry: SIZE constant" {
    try std.testing.expectEqual(@as(usize, 24), StakeHistoryEntry.SIZE);
}

test "StakeHistoryEntry: DEFAULT is empty" {
    const entry = StakeHistoryEntry.DEFAULT;
    try std.testing.expect(entry.isEmpty());
    try std.testing.expectEqual(@as(u64, 0), entry.effective);
    try std.testing.expectEqual(@as(u64, 0), entry.activating);
    try std.testing.expectEqual(@as(u64, 0), entry.deactivating);
}

test "StakeHistoryEntry: withEffective" {
    const entry = StakeHistoryEntry.withEffective(1000);
    try std.testing.expectEqual(@as(u64, 1000), entry.effective);
    try std.testing.expectEqual(@as(u64, 0), entry.activating);
    try std.testing.expectEqual(@as(u64, 0), entry.deactivating);
}

test "StakeHistoryEntry: withEffectiveAndActivating" {
    const entry = StakeHistoryEntry.withEffectiveAndActivating(1000, 500);
    try std.testing.expectEqual(@as(u64, 1000), entry.effective);
    try std.testing.expectEqual(@as(u64, 500), entry.activating);
    try std.testing.expectEqual(@as(u64, 0), entry.deactivating);
}

test "StakeHistoryEntry: withDeactivating" {
    const entry = StakeHistoryEntry.withDeactivating(750);
    try std.testing.expectEqual(@as(u64, 0), entry.effective);
    try std.testing.expectEqual(@as(u64, 0), entry.activating);
    try std.testing.expectEqual(@as(u64, 750), entry.deactivating);
}

test "StakeHistoryEntry: add" {
    const a = StakeHistoryEntry{
        .effective = 100,
        .activating = 50,
        .deactivating = 25,
    };
    const b = StakeHistoryEntry{
        .effective = 200,
        .activating = 75,
        .deactivating = 30,
    };
    const result = a.add(b);
    try std.testing.expectEqual(@as(u64, 300), result.effective);
    try std.testing.expectEqual(@as(u64, 125), result.activating);
    try std.testing.expectEqual(@as(u64, 55), result.deactivating);
}

test "StakeHistoryEntry: pack and unpack roundtrip" {
    const entry = StakeHistoryEntry{
        .effective = 1_000_000_000,
        .activating = 500_000_000,
        .deactivating = 250_000_000,
    };

    var buffer: [StakeHistoryEntry.SIZE]u8 = undefined;
    try entry.pack(&buffer);

    const unpacked = try StakeHistoryEntry.unpack(&buffer);
    try std.testing.expectEqual(entry.effective, unpacked.effective);
    try std.testing.expectEqual(entry.activating, unpacked.activating);
    try std.testing.expectEqual(entry.deactivating, unpacked.deactivating);
}

test "StakeHistory: basic operations" {
    var history = StakeHistory.init(std.testing.allocator);
    defer history.deinit();

    try std.testing.expect(history.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), history.len());

    // Add entries
    try history.addEntry(100, StakeHistoryEntry.withEffective(1000));
    try history.addEntry(101, StakeHistoryEntry.withEffective(2000));
    try history.addEntry(102, StakeHistoryEntry.withEffective(3000));

    try std.testing.expectEqual(@as(usize, 3), history.len());
    try std.testing.expect(!history.isEmpty());

    // Get entries
    const e100 = history.get(100);
    try std.testing.expect(e100 != null);
    try std.testing.expectEqual(@as(u64, 1000), e100.?.effective);

    const e101 = history.get(101);
    try std.testing.expect(e101 != null);
    try std.testing.expectEqual(@as(u64, 2000), e101.?.effective);

    const e102 = history.get(102);
    try std.testing.expect(e102 != null);
    try std.testing.expectEqual(@as(u64, 3000), e102.?.effective);

    // Non-existent epoch
    try std.testing.expect(history.get(99) == null);
    try std.testing.expect(history.get(103) == null);
}

test "StakeHistory: replace existing entry" {
    var history = StakeHistory.init(std.testing.allocator);
    defer history.deinit();

    try history.addEntry(100, StakeHistoryEntry.withEffective(1000));
    try std.testing.expectEqual(@as(u64, 1000), history.get(100).?.effective);

    // Replace entry
    try history.addEntry(100, StakeHistoryEntry.withEffective(9999));
    try std.testing.expectEqual(@as(usize, 1), history.len());
    try std.testing.expectEqual(@as(u64, 9999), history.get(100).?.effective);
}

test "StakeHistory: sorted descending by epoch" {
    var history = StakeHistory.init(std.testing.allocator);
    defer history.deinit();

    // Add out of order
    try history.addEntry(50, StakeHistoryEntry.withEffective(500));
    try history.addEntry(100, StakeHistoryEntry.withEffective(1000));
    try history.addEntry(75, StakeHistoryEntry.withEffective(750));

    // Verify sorted descending
    const entries = history.items();
    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expectEqual(@as(u64, 100), entries[0].epoch);
    try std.testing.expectEqual(@as(u64, 75), entries[1].epoch);
    try std.testing.expectEqual(@as(u64, 50), entries[2].epoch);
}

test "MAX_ENTRIES constant" {
    try std.testing.expectEqual(@as(usize, 512), MAX_ENTRIES);
}

test "StakeHistory: pack and unpack roundtrip" {
    var history = StakeHistory.init(std.testing.allocator);
    defer history.deinit();

    // Add some entries
    try history.addEntry(100, StakeHistoryEntry{
        .effective = 1_000_000_000,
        .activating = 500_000_000,
        .deactivating = 250_000_000,
    });
    try history.addEntry(101, StakeHistoryEntry{
        .effective = 2_000_000_000,
        .activating = 0,
        .deactivating = 100_000_000,
    });
    try history.addEntry(102, StakeHistoryEntry.withEffective(3_000_000_000));

    // Pack
    var buffer: [1024]u8 = undefined;
    const written = try history.pack(&buffer);
    try std.testing.expect(written > 0);
    try std.testing.expectEqual(history.packedSize(), written);

    // Unpack
    var unpacked = try StakeHistory.unpack(std.testing.allocator, buffer[0..written]);
    defer unpacked.deinit();

    // Verify
    try std.testing.expectEqual(history.len(), unpacked.len());

    const e100 = unpacked.get(100);
    try std.testing.expect(e100 != null);
    try std.testing.expectEqual(@as(u64, 1_000_000_000), e100.?.effective);
    try std.testing.expectEqual(@as(u64, 500_000_000), e100.?.activating);
    try std.testing.expectEqual(@as(u64, 250_000_000), e100.?.deactivating);

    const e101 = unpacked.get(101);
    try std.testing.expect(e101 != null);
    try std.testing.expectEqual(@as(u64, 2_000_000_000), e101.?.effective);
    try std.testing.expectEqual(@as(u64, 0), e101.?.activating);
    try std.testing.expectEqual(@as(u64, 100_000_000), e101.?.deactivating);

    const e102 = unpacked.get(102);
    try std.testing.expect(e102 != null);
    try std.testing.expectEqual(@as(u64, 3_000_000_000), e102.?.effective);
}

// ============================================================================
// Pack Error Tests
// ============================================================================

test "StakeHistoryEntry: pack rejects buffer too small" {
    const entry = StakeHistoryEntry{
        .effective = 1_000_000_000,
        .activating = 500_000_000,
        .deactivating = 250_000_000,
    };
    var small_buffer: [StakeHistoryEntry.SIZE - 1]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, entry.pack(&small_buffer));
}

test "StakeHistory: pack rejects buffer too small" {
    var history = StakeHistory.init(std.testing.allocator);
    defer history.deinit();

    try history.addEntry(100, StakeHistoryEntry.withEffective(1_000_000_000));
    try history.addEntry(101, StakeHistoryEntry.withEffective(2_000_000_000));

    // Buffer too small for the data
    var small_buffer: [10]u8 = undefined;
    try std.testing.expectError(error.InvalidAccountData, history.pack(&small_buffer));
}
