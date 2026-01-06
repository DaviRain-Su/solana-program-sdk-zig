//! Zig implementation of Solana SDK's epoch info types
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-info/src/lib.rs
//!
//! Information about the current epoch as returned by the `getEpochInfo` RPC method.

const std = @import("std");

/// Information about the current epoch.
///
/// As returned by the `getEpochInfo` RPC method.
///
/// Rust equivalent: `solana_epoch_info::EpochInfo`
/// Source: https://github.com/anza-xyz/solana-sdk/blob/master/epoch-info/src/lib.rs
pub const EpochInfo = struct {
    /// The current epoch
    epoch: u64,

    /// The current slot, relative to the start of the current epoch
    slot_index: u64,

    /// The number of slots in this epoch
    slots_in_epoch: u64,

    /// The absolute current slot
    absolute_slot: u64,

    /// The current block height
    block_height: u64,

    /// Total number of transactions processed without error since genesis
    transaction_count: ?u64,

    /// Create a new EpochInfo
    pub fn init(
        epoch: u64,
        slot_index: u64,
        slots_in_epoch: u64,
        absolute_slot: u64,
        block_height: u64,
        transaction_count: ?u64,
    ) EpochInfo {
        return .{
            .epoch = epoch,
            .slot_index = slot_index,
            .slots_in_epoch = slots_in_epoch,
            .absolute_slot = absolute_slot,
            .block_height = block_height,
            .transaction_count = transaction_count,
        };
    }

    /// Get the first slot of this epoch
    pub fn getFirstSlotInEpoch(self: EpochInfo) u64 {
        return self.absolute_slot - self.slot_index;
    }

    /// Get the last slot of this epoch
    pub fn getLastSlotInEpoch(self: EpochInfo) u64 {
        return self.getFirstSlotInEpoch() + self.slots_in_epoch - 1;
    }

    /// Get the remaining slots in this epoch
    pub fn getRemainingSlots(self: EpochInfo) u64 {
        return self.slots_in_epoch - self.slot_index - 1;
    }

    /// Get the progress through the current epoch (0.0 to 1.0)
    pub fn getEpochProgress(self: EpochInfo) f64 {
        if (self.slots_in_epoch == 0) return 0.0;
        return @as(f64, @floatFromInt(self.slot_index)) / @as(f64, @floatFromInt(self.slots_in_epoch));
    }

    /// Check if this is the first slot in the epoch
    pub fn isFirstSlotInEpoch(self: EpochInfo) bool {
        return self.slot_index == 0;
    }

    /// Check if this is the last slot in the epoch
    pub fn isLastSlotInEpoch(self: EpochInfo) bool {
        return self.slot_index == self.slots_in_epoch - 1;
    }

    /// Format for JSON output (camelCase field names as per Solana RPC)
    pub fn jsonStringify(self: EpochInfo, writer: anytype) !void {
        // Can use native zig json std
        try writer.writeAll("{");
        try std.fmt.format(writer, "\"epoch\":{d},", .{self.epoch});
        try std.fmt.format(writer, "\"slotIndex\":{d},", .{self.slot_index});
        try std.fmt.format(writer, "\"slotsInEpoch\":{d},", .{self.slots_in_epoch});
        try std.fmt.format(writer, "\"absoluteSlot\":{d},", .{self.absolute_slot});
        try std.fmt.format(writer, "\"blockHeight\":{d},", .{self.block_height});
        if (self.transaction_count) |count| {
            try std.fmt.format(writer, "\"transactionCount\":{d}", .{count});
        } else {
            try writer.writeAll("\"transactionCount\":null");
        }
        try writer.writeAll("}");
    }
};

// ============================================================================
// Tests
// ============================================================================

test "epoch_info: basic creation" {
    const info = EpochInfo.init(
        100, // epoch
        500, // slot_index
        432000, // slots_in_epoch (typical mainnet value)
        43200500, // absolute_slot
        35000000, // block_height
        1000000000, // transaction_count
    );

    try std.testing.expectEqual(@as(u64, 100), info.epoch);
    try std.testing.expectEqual(@as(u64, 500), info.slot_index);
    try std.testing.expectEqual(@as(u64, 432000), info.slots_in_epoch);
    try std.testing.expectEqual(@as(u64, 43200500), info.absolute_slot);
    try std.testing.expectEqual(@as(u64, 35000000), info.block_height);
    try std.testing.expectEqual(@as(?u64, 1000000000), info.transaction_count);
}

test "epoch_info: with null transaction_count" {
    const info = EpochInfo.init(0, 0, 432000, 0, 0, null);

    try std.testing.expect(info.transaction_count == null);
}

test "epoch_info: getFirstSlotInEpoch" {
    const info = EpochInfo.init(5, 1000, 432000, 2161000, 1500000, null);

    // absolute_slot - slot_index = 2161000 - 1000 = 2160000
    try std.testing.expectEqual(@as(u64, 2160000), info.getFirstSlotInEpoch());
}

test "epoch_info: getLastSlotInEpoch" {
    const info = EpochInfo.init(5, 1000, 432000, 2161000, 1500000, null);

    // first_slot + slots_in_epoch - 1 = 2160000 + 432000 - 1 = 2591999
    try std.testing.expectEqual(@as(u64, 2591999), info.getLastSlotInEpoch());
}

test "epoch_info: getRemainingSlots" {
    const info = EpochInfo.init(5, 1000, 432000, 2161000, 1500000, null);

    // slots_in_epoch - slot_index - 1 = 432000 - 1000 - 1 = 430999
    try std.testing.expectEqual(@as(u64, 430999), info.getRemainingSlots());
}

test "epoch_info: getEpochProgress" {
    const info = EpochInfo.init(5, 216000, 432000, 2376000, 2000000, null);

    // slot_index / slots_in_epoch = 216000 / 432000 = 0.5
    const progress = info.getEpochProgress();
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), progress, 0.001);
}

test "epoch_info: getEpochProgress zero slots" {
    const info = EpochInfo.init(0, 0, 0, 0, 0, null);

    try std.testing.expectEqual(@as(f64, 0.0), info.getEpochProgress());
}

test "epoch_info: isFirstSlotInEpoch" {
    const first = EpochInfo.init(5, 0, 432000, 2160000, 1500000, null);
    try std.testing.expect(first.isFirstSlotInEpoch());

    const middle = EpochInfo.init(5, 1000, 432000, 2161000, 1500500, null);
    try std.testing.expect(!middle.isFirstSlotInEpoch());
}

test "epoch_info: isLastSlotInEpoch" {
    const last = EpochInfo.init(5, 431999, 432000, 2591999, 2000000, null);
    try std.testing.expect(last.isLastSlotInEpoch());

    const middle = EpochInfo.init(5, 1000, 432000, 2161000, 1500500, null);
    try std.testing.expect(!middle.isLastSlotInEpoch());
}

test "epoch_info: jsonStringify" {
    const info = EpochInfo.init(100, 500, 432000, 43200500, 35000000, 1000000000);

    var buffer: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try info.jsonStringify(fbs.writer());

    const result = fbs.getWritten();
    try std.testing.expectEqualStrings(
        "{\"epoch\":100,\"slotIndex\":500,\"slotsInEpoch\":432000,\"absoluteSlot\":43200500,\"blockHeight\":35000000,\"transactionCount\":1000000000}",
        result,
    );
}

test "epoch_info: jsonStringify with null transaction_count" {
    const info = EpochInfo.init(0, 0, 432000, 0, 0, null);

    var buffer: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try info.jsonStringify(fbs.writer());

    const result = fbs.getWritten();
    try std.testing.expectEqualStrings(
        "{\"epoch\":0,\"slotIndex\":0,\"slotsInEpoch\":432000,\"absoluteSlot\":0,\"blockHeight\":0,\"transactionCount\":null}",
        result,
    );
}
