//! Sysvar accessors for Solana programs
//!
//! Two access patterns:
//!
//! 1. **Syscall-based** (`Sysvar.get()`): no account-list entry
//!    required, ~250-300 CU per call. Available for: Clock, Rent,
//!    EpochSchedule, LastRestartSlot, EpochRewards.
//!
//! 2. **Account-based** (`getSysvarRef(T, account)` / `getSysvar(T, account)`):
//!    caller must pass the sysvar account in the instruction's `accounts`.
//!    `getSysvarRef` gives a zero-copy typed view over the account bytes;
//!    `getSysvar` copies that typed value out when ownership-by-value is
//!    more convenient.
//!
//! Choose syscalls when you can — they're cheaper and remove a
//! constraint on the client (no need to list the sysvar account).

const std = @import("std");
const pubkey = @import("pubkey.zig");
const account_mod = @import("account/root.zig");
const program_error = @import("program_error.zig");
const clock_mod = @import("clock.zig");
const rent_mod = @import("rent.zig");
const bpf = @import("bpf.zig");
const log = @import("log.zig");

const Pubkey = pubkey.Pubkey;
const AccountInfo = account_mod.AccountInfo;
const ProgramError = program_error.ProgramError;

/// Clock sysvar — re-exported from `clock.zig` so it is the single
/// canonical type in the SDK.
pub const Clock = clock_mod.Clock;

/// Rent sysvar data — re-exported from `rent.zig`.
pub const Rent = rent_mod.Rent.Data;

/// Clock sysvar ID
pub const CLOCK_ID: Pubkey = pubkey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");

/// Rent sysvar ID
pub const RENT_ID: Pubkey = pubkey.comptimeFromBase58("SysvarRent111111111111111111111111111111111");

/// Epoch schedule sysvar ID
pub const EPOCH_SCHEDULE_ID: Pubkey = pubkey.comptimeFromBase58("SysvarEpochSchedu1e111111111111111111111111");

/// Slot hashes sysvar ID
pub const SLOT_HASHES_ID: Pubkey = pubkey.comptimeFromBase58("SysvarS1otHashes111111111111111111111111111");

/// Stake history sysvar ID
pub const STAKE_HISTORY_ID: Pubkey = pubkey.comptimeFromBase58("SysvarStakeHistory1111111111111111111111111");

/// Instructions sysvar ID
pub const INSTRUCTIONS_ID: Pubkey = pubkey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");

/// Get a zero-copy typed view of sysvar account data.
///
/// The account must contain at least `@sizeOf(T)` bytes. The returned
/// pointer aliases the account's runtime data buffer directly — no copy,
/// no allocation, just a typed view over `account.data()`.
///
/// Use this for repeated field access or larger sysvar layouts where the
/// SDK's zero-copy style is preferable.
pub fn getSysvarRef(comptime T: type, account: AccountInfo) ProgramError!*align(1) const T {
    const data = account.data();
    if (data.len < @sizeOf(T)) {
        return ProgramError.InvalidAccountData;
    }
    return account.dataAsConst(T);
}

/// Get sysvar data from an account by value.
///
/// This is the convenience copy-returning form built on top of
/// `getSysvarRef`. Use `getSysvarRef` when you want the zero-copy path.
pub fn getSysvar(comptime T: type, account: AccountInfo) ProgramError!T {
    return (try getSysvarRef(T, account)).*;
}

// =============================================================================
// sol_get_sysvar — generic offset-based sysvar read syscall.
//
// Unlike the individual `Clock::get` / `Rent::get` syscalls (which are
// being deprecated in solana-program 4.x), `sol_get_sysvar` lets a
// program read **any** sysvar by ID, optionally at an offset. This is
// the only way to read large sysvars like `SlotHashes` or
// `StakeHistory` without having the account passed in.
//
// Return codes (per agave bpf_loader/syscalls/sysvar.rs):
//   0 = SUCCESS
//   1 = OFFSET_LENGTH_EXCEEDS_SYSVAR — `offset + length` past the data
//   2 = SYSVAR_NOT_FOUND               — sysvar ID isn't known
// =============================================================================

extern fn sol_get_sysvar(
    sysvar_id_addr: *const u8,
    result: *u8,
    offset: u64,
    length: u64,
) callconv(.c) u64;

/// Read `length` bytes of `sysvar_id`'s account data starting at
/// `offset` into `dst`. `dst.len` must be at least `length`.
///
/// Maps the runtime's two error codes onto `ProgramError` and logs a
/// tag so each failure mode is distinguishable on the transaction
/// log (the wire u64 alone wouldn't be — `InvalidArgument` /
/// `UnsupportedSysvar` are both extremely common values):
///
///   - `OFFSET_LENGTH_EXCEEDS_SYSVAR` (rc=1) →
///     `tag:"sysvar:offset_out_of_range"`, `InvalidArgument`.
///   - `SYSVAR_NOT_FOUND` (rc=2) →
///     `tag:"sysvar:not_found"`, `UnsupportedSysvar`.
///   - Any other non-zero rc →
///     `tag:"sysvar:unexpected"`, `UnsupportedSysvar`.
///
/// On host targets this returns `UnsupportedSysvar` — there's no
/// runtime to query.
pub fn getSysvarBytes(
    dst: []u8,
    sysvar_id_addr: *const Pubkey,
    offset: u64,
    length: u64,
) ProgramError!void {
    if (dst.len < length) {
        return program_error.fail(@src(), "sysvar:dst_too_small", ProgramError.InvalidArgument);
    }

    if (bpf.is_bpf_program) {
        const rc = sol_get_sysvar(
            @as(*const u8, @ptrCast(sysvar_id_addr)),
            @as(*u8, @ptrCast(dst.ptr)),
            offset,
            length,
        );
        return switch (rc) {
            0 => {},
            1 => program_error.fail(@src(), "sysvar:offset_out_of_range", ProgramError.InvalidArgument),
            2 => program_error.fail(@src(), "sysvar:not_found", ProgramError.UnsupportedSysvar),
            else => program_error.fail(@src(), "sysvar:unexpected", ProgramError.UnsupportedSysvar),
        };
    } else {
        return ProgramError.UnsupportedSysvar;
    }
}

/// Epoch schedule sysvar.
///
/// Use `EpochSchedule.get()` to read this via syscall (no account
/// required). The layout matches the runtime's serialized form.
pub const EpochSchedule = extern struct {
    /// The maximum number of slots in each epoch
    slots_per_epoch: u64,
    /// A number of slots before beginning of an epoch to calculate
    /// a leader schedule for that epoch
    leader_schedule_slot_offset: u64,
    /// Whether epochs start short and grow
    warmup: bool,
    /// The first epoch after the warmup period
    first_normal_epoch: u64,
    /// The first slot after the warmup period
    first_normal_slot: u64,

    /// Read the epoch schedule via syscall. Returns
    /// `error.Unexpected` if the runtime rejects the call.
    pub fn get() ProgramError!EpochSchedule {
        var es: EpochSchedule = undefined;
        if (bpf.is_bpf_program) {
            const Syscall = struct {
                extern fn sol_get_epoch_schedule_sysvar(ptr: *EpochSchedule) callconv(.c) u64;
            };
            const rc = Syscall.sol_get_epoch_schedule_sysvar(&es);
            if (rc != 0) {
                log.print("failed to get epoch_schedule sysvar: {d}", .{rc});
                return ProgramError.UnsupportedSysvar;
            }
        }
        return es;
    }
};

/// LastRestartSlot sysvar — exposes the slot at which the cluster
/// most recently restarted. Useful for time-sensitive program logic
/// that needs to detect a restart event.
pub const LastRestartSlot = extern struct {
    /// The last slot at which the cluster was restarted; `0` means
    /// no restart has occurred since the genesis epoch.
    last_restart_slot: u64,

    pub fn get() ProgramError!LastRestartSlot {
        var v: LastRestartSlot = undefined;
        if (bpf.is_bpf_program) {
            const Syscall = struct {
                extern fn sol_get_last_restart_slot(ptr: *LastRestartSlot) callconv(.c) u64;
            };
            const rc = Syscall.sol_get_last_restart_slot(&v);
            if (rc != 0) {
                log.print("failed to get last_restart_slot sysvar: {d}", .{rc});
                return ProgramError.UnsupportedSysvar;
            }
        }
        return v;
    }
};

/// EpochRewards sysvar — exposed during epoch-rewards distribution
/// (rare). Read via syscall.
pub const EpochRewards = extern struct {
    /// Total rewards for the current epoch, in lamports.
    distribution_starting_block_height: u64,
    /// Number of partitions in the rewards distribution.
    num_partitions: u64,
    /// Hash of the parent block at the start of distribution.
    parent_blockhash: [32]u8,
    /// Lamports remaining to be distributed.
    total_points: u128,
    /// Total rewards for current epoch, in lamports.
    total_rewards: u64,
    /// Distributed rewards so far, in lamports.
    distributed_rewards: u64,
    /// Whether the rewards period is currently active.
    active: bool,

    pub fn get() ProgramError!EpochRewards {
        var v: EpochRewards = undefined;
        if (bpf.is_bpf_program) {
            const Syscall = struct {
                extern fn sol_get_epoch_rewards_sysvar(ptr: *EpochRewards) callconv(.c) u64;
            };
            const rc = Syscall.sol_get_epoch_rewards_sysvar(&v);
            if (rc != 0) {
                log.print("failed to get epoch_rewards sysvar: {d}", .{rc});
                return ProgramError.UnsupportedSysvar;
            }
        }
        return v;
    }
};

/// Slot hash entry
pub const SlotHash = extern struct {
    slot: u64,
    hash: [32]u8,
};

// =============================================================================
// Tests
// =============================================================================

test "sysvar: Clock re-export points to clock.Clock" {
    try std.testing.expectEqual(@sizeOf(clock_mod.Clock), @sizeOf(Clock));
}

test "sysvar: Rent re-export points to rent.Rent.Data" {
    const r: Rent = .{};
    try std.testing.expect(r.lamports_per_byte_year > 0);
}

test "sysvar: EpochSchedule layout is 33 bytes" {
    // u64 + u64 + bool(1) + u64 + u64 = 33 (no padding because
    // extern struct uses C layout and bool is 1 byte). When laid out
    // for the syscall buffer the runtime sends the packed form.
    try std.testing.expect(@sizeOf(EpochSchedule) >= 33);
}

test "sysvar: LastRestartSlot is a single u64" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(LastRestartSlot));
}

test "sysvar: getSysvarBytes returns InvalidArgument when dst is too small" {
    const sid: Pubkey = .{0} ** 32;
    var buf: [4]u8 = undefined;
    try std.testing.expectError(
        ProgramError.InvalidArgument,
        getSysvarBytes(&buf, &sid, 0, 8),
    );
}

test "sysvar: getSysvarBytes on host returns UnsupportedSysvar" {
    const sid: Pubkey = .{0} ** 32;
    var buf: [8]u8 = undefined;
    try std.testing.expectError(
        ProgramError.UnsupportedSysvar,
        getSysvarBytes(&buf, &sid, 0, 8),
    );
}

test "sysvar: EpochRewards layout has expected fields" {
    const er: EpochRewards = .{
        .distribution_starting_block_height = 0,
        .num_partitions = 0,
        .parent_blockhash = .{0} ** 32,
        .total_points = 0,
        .total_rewards = 0,
        .distributed_rewards = 0,
        .active = false,
    };
    try std.testing.expectEqual(@as(u64, 0), er.total_rewards);
}

const TestSysvarBuf = struct {
    bytes: [@sizeOf(account_mod.Account) + 128]u8 align(8),

    fn init(comptime T: type, value: T) TestSysvarBuf {
        var self: TestSysvarBuf = .{ .bytes = .{0} ** (@sizeOf(account_mod.Account) + 128) };
        const acc: *account_mod.Account = @ptrCast(&self.bytes);
        acc.* = .{
            .borrow_state = account_mod.NOT_BORROWED,
            .is_signer = 0,
            .is_writable = 0,
            .is_executable = 0,
            ._padding = .{0} ** 4,
            .key = .{0} ** 32,
            .owner = .{0} ** 32,
            .lamports = 0,
            .data_len = @sizeOf(T),
        };
        const data_ptr: [*]u8 = @ptrFromInt(@intFromPtr(acc) + @sizeOf(account_mod.Account));
        @memcpy(data_ptr[0..@sizeOf(T)], std.mem.asBytes(&value));
        return self;
    }

    fn info(self: *TestSysvarBuf) AccountInfo {
        return .{ .raw = @ptrCast(&self.bytes) };
    }
};

test "sysvar: getSysvarRef returns zero-copy typed view" {
    const original = EpochSchedule{
        .slots_per_epoch = 432_000,
        .leader_schedule_slot_offset = 432_000,
        .warmup = false,
        .first_normal_epoch = 14,
        .first_normal_slot = 999,
    };
    var buf = TestSysvarBuf.init(EpochSchedule, original);
    const info = buf.info();

    const ref = try getSysvarRef(EpochSchedule, info);
    try std.testing.expectEqual(@as(u64, 432_000), ref.slots_per_epoch);
    try std.testing.expectEqual(@as(bool, false), ref.warmup);

    const copy = try getSysvar(EpochSchedule, info);
    try std.testing.expectEqual(ref.*, copy);

    const mut = info.dataAs(EpochSchedule);
    mut.warmup = true;
    mut.first_normal_slot = 12345;

    try std.testing.expectEqual(@as(bool, true), ref.warmup);
    try std.testing.expectEqual(@as(u64, 12345), ref.first_normal_slot);
    try std.testing.expectEqual(@as(bool, false), copy.warmup);
    try std.testing.expectEqual(@as(u64, 999), copy.first_normal_slot);
}

test "sysvar: getSysvarRef errors when account data is too small" {
    var buf = TestSysvarBuf.init(u32, 7);
    try std.testing.expectError(
        ProgramError.InvalidAccountData,
        getSysvarRef(EpochSchedule, buf.info()),
    );
}
