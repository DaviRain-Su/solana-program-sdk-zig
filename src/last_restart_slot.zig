//! Zig implementation of Solana SDK's last-restart-slot module
//!
//! Rust source: https://github.com/anza-xyz/solana-sdk/blob/master/last-restart-slot/src/lib.rs
//!
//! This module provides access to the LastRestartSlot sysvar, which contains
//! the slot number of the last network restart. This information is used to
//! determine the recovery point after a validator restart.
//!
//! The LastRestartSlot sysvar contains a single u64 value representing the
//! slot number when the network last restarted.

const std = @import("std");

/// The LastRestartSlot sysvar data
///
/// This contains the slot number of the last network restart.
pub const LastRestartSlot = struct {
    /// The slot number when the network last restarted
    last_restart_slot: u64,

    /// Parse LastRestartSlot from account data
    ///
    /// # Arguments
    /// * `data` - The raw account data (must be at least 8 bytes)
    ///
    /// # Returns
    /// Parsed LastRestartSlot struct
    ///
    /// # Errors
    /// Returns error if data is too small or invalid
    pub fn parse(data: []const u8) !LastRestartSlot {
        if (data.len < SIZE) {
            return error.InvalidAccountData;
        }

        const slot = std.mem.readInt(u64, data[0..8], .little);
        return LastRestartSlot{
            .last_restart_slot = slot,
        };
    }

    /// Get the slot number
    pub fn getSlot(self: LastRestartSlot) u64 {
        return self.last_restart_slot;
    }

    /// The size of LastRestartSlot data in bytes
    pub const SIZE: usize = 8;
};

// ============================================================================
// Tests
// ============================================================================

test "LastRestartSlot: parse valid data" {
    var data: [8]u8 = undefined;
    std.mem.writeInt(u64, &data, 123456789, .little);

    const result = try LastRestartSlot.parse(&data);
    try std.testing.expectEqual(@as(u64, 123456789), result.getSlot());
}

test "LastRestartSlot: parse invalid data (too small)" {
    const data = [_]u8{ 1, 2, 3 }; // Only 3 bytes

    const result = LastRestartSlot.parse(&data);
    try std.testing.expectError(error.InvalidAccountData, result);
}

test "LastRestartSlot: size constant" {
    try std.testing.expectEqual(@as(usize, 8), LastRestartSlot.SIZE);
}

test "LastRestartSlot: round trip" {
    const original = LastRestartSlot{ .last_restart_slot = 987654321 };

    // In a real scenario, this would be serialized to account data
    // and then parsed back. For testing, we'll simulate this.

    var buffer: [8]u8 = undefined;
    std.mem.writeInt(u64, &buffer, original.getSlot(), .little);

    const parsed = try LastRestartSlot.parse(&buffer);
    try std.testing.expectEqual(original.getSlot(), parsed.getSlot());
}
