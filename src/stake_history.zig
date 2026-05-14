//! `StakeHistory` sysvar accessor.
//!
//! Unlike Clock / Rent / EpochSchedule, the stake-history sysvar has
//! **no direct syscall**. Reading it requires the caller to pass the
//! sysvar account as part of the instruction's account list. We then
//! parse the account data zero-copy.
//!
//! ### Wire layout
//!
//! ```text
//! [0..8)        u64 LE   length (number of entries, ≤ 512)
//! [8..8+24N)    repeat N times:
//!   [+0..8)     u64 LE   epoch
//!   [+8..16)    u64 LE   effective
//!   [+16..24)   u64 LE   activating
//!   [+24..32)   u64 LE   deactivating
//! ```
//!
//! Wait — the canonical Rust layout actually packs `epoch` separately
//! from a `StakeHistoryEntry { effective, activating, deactivating }`
//! tuple, so the entry stride is 32 bytes (8 + 24). See
//! `solana_program::stake_history`.
//!
//! Entries are sorted by epoch in **descending** order (newest first)
//! and the runtime truncates to `MAX_ENTRIES = 512`.

const std = @import("std");
const account_mod = @import("account/root.zig");
const program_error = @import("program_error/root.zig");
const sysvar = @import("sysvar/root.zig");
const pubkey = @import("pubkey.zig");

const AccountInfo = account_mod.AccountInfo;
const ProgramError = program_error.ProgramError;
const Pubkey = pubkey.Pubkey;

/// Maximum number of entries the runtime keeps. After this, oldest
/// entries are truncated.
pub const MAX_ENTRIES: usize = 512;

/// On-chain stake-history entry. `repr(C)` matches the runtime's
/// serialized form exactly — `extern struct` in Zig gives the same
/// guarantees.
pub const Entry = extern struct {
    epoch: u64,
    effective: u64,
    activating: u64,
    deactivating: u64,

    pub fn isZero(self: Entry) bool {
        return self.effective == 0 and self.activating == 0 and self.deactivating == 0;
    }
};

/// Zero-copy view over the stake-history sysvar account.
pub const StakeHistory = struct {
    /// Pointer into the sysvar account's data buffer. Entries are
    /// laid out contiguously in epoch-descending order.
    entries: []align(1) const Entry,

    /// Re-export for symmetry with the Rust API.
    pub const ID = sysvar.STAKE_HISTORY_ID;

    /// Parse the sysvar account. Returns `UnsupportedSysvar` if the
    /// account isn't the canonical stake-history sysvar, or
    /// `InvalidAccountData` if the buffer is too short / its
    /// length-prefix is inconsistent.
    pub fn fromAccount(info: AccountInfo) ProgramError!StakeHistory {
        if (!pubkey.pubkeyEqComptime(info.key(), sysvar.STAKE_HISTORY_ID)) {
            return error.UnsupportedSysvar;
        }
        const buf = info.data();
        if (buf.len < 8) return error.InvalidAccountData;
        const n = std.mem.readInt(u64, buf[0..8], .little);
        if (n > MAX_ENTRIES) return error.InvalidAccountData;
        const total = 8 + n * @sizeOf(Entry);
        if (buf.len < total) return error.InvalidAccountData;

        const entries_ptr: [*]align(1) const Entry = @ptrCast(buf[8..].ptr);
        return .{ .entries = entries_ptr[0..@intCast(n)] };
    }

    /// Look up the entry for `epoch` via binary search. Returns
    /// `null` if the epoch isn't represented in history.
    ///
    /// History is stored newest-first, so we search descending. Both
    /// `O(log n)` and stable across runtime versions.
    pub fn get(self: StakeHistory, epoch: u64) ?Entry {
        if (self.entries.len == 0) return null;
        var lo: usize = 0;
        var hi: usize = self.entries.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const e = self.entries[mid].epoch;
            if (e == epoch) return self.entries[mid];
            // Descending order: epochs above `epoch` live to the left.
            if (e > epoch) lo = mid + 1 else hi = mid;
        }
        return null;
    }

    /// Convenience: the most recent (highest-epoch) entry, or `null`
    /// if the history is empty.
    pub fn latest(self: StakeHistory) ?Entry {
        if (self.entries.len == 0) return null;
        return self.entries[0];
    }
};

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "stake_history: Entry layout is 32 bytes" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(Entry));
    try testing.expectEqual(@as(usize, 0), @offsetOf(Entry, "epoch"));
    try testing.expectEqual(@as(usize, 8), @offsetOf(Entry, "effective"));
    try testing.expectEqual(@as(usize, 16), @offsetOf(Entry, "activating"));
    try testing.expectEqual(@as(usize, 24), @offsetOf(Entry, "deactivating"));
}

test "stake_history: get finds entries by binary search" {
    // Synthetic descending history: epochs 10, 7, 5, 2.
    const entries = [_]Entry{
        .{ .epoch = 10, .effective = 100, .activating = 0, .deactivating = 0 },
        .{ .epoch = 7, .effective = 70, .activating = 5, .deactivating = 0 },
        .{ .epoch = 5, .effective = 50, .activating = 0, .deactivating = 10 },
        .{ .epoch = 2, .effective = 20, .activating = 0, .deactivating = 0 },
    };
    const sh: StakeHistory = .{ .entries = &entries };

    try testing.expectEqual(@as(?Entry, entries[0]), sh.get(10));
    try testing.expectEqual(@as(?Entry, entries[1]), sh.get(7));
    try testing.expectEqual(@as(?Entry, entries[2]), sh.get(5));
    try testing.expectEqual(@as(?Entry, entries[3]), sh.get(2));
    try testing.expectEqual(@as(?Entry, null), sh.get(0));
    try testing.expectEqual(@as(?Entry, null), sh.get(3));
    try testing.expectEqual(@as(?Entry, null), sh.get(11));
}

test "stake_history: latest returns the highest-epoch entry" {
    const entries = [_]Entry{
        .{ .epoch = 100, .effective = 1, .activating = 0, .deactivating = 0 },
        .{ .epoch = 50, .effective = 2, .activating = 0, .deactivating = 0 },
    };
    const sh: StakeHistory = .{ .entries = &entries };
    try testing.expectEqual(@as(u64, 100), sh.latest().?.epoch);

    const empty: StakeHistory = .{ .entries = &.{} };
    try testing.expectEqual(@as(?Entry, null), empty.latest());
}
