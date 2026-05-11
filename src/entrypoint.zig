//! Solana program entrypoint — InstructionContext (Pinocchio-style)
//!
//! Single entrypoint design: on-demand account parsing via InstructionContext.
//! Accounts returned as `AccountInfo` (8-byte pointer wrapper).
//!
//! Matches Pinocchio `lazy_program_entrypoint!` exactly.

const std = @import("std");
const account = @import("account.zig");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");

const Account = account.Account;
const AccountInfo = account.AccountInfo;
const MaybeAccount = account.MaybeAccount;
const Pubkey = pubkey.Pubkey;
const ProgramResult = program_error.ProgramResult;
const SUCCESS = program_error.SUCCESS;

pub const HEAP_START_ADDRESS: u64 = 0x300000000;
pub const HEAP_LENGTH: usize = 32 * 1024;

const MAX_PERMITTED_DATA_INCREASE: usize = account.MAX_PERMITTED_DATA_INCREASE;

inline fn alignPointer(ptr: usize) usize {
    return (ptr + 7) & ~@as(usize, 7);
}

// =========================================================================
// InstructionContext — on-demand input parsing (Pinocchio-style)
//
// Only 16 bytes on the stack (buffer pointer + remaining count).
// `next_account()` returns `AccountInfo` (8 bytes).
// =========================================================================

pub const InstructionContext = struct {
    buffer: [*]u8,
    remaining: u64,

    /// Create from raw input pointer.
    pub inline fn init(input: [*]u8) InstructionContext {
        const num_accounts: u64 = @as(*const u64, @ptrCast(@alignCast(input))).*;
        return .{
            .buffer = input + @sizeOf(u64),
            .remaining = num_accounts,
        };
    }

    /// Number of remaining unparsed accounts.
    pub inline fn remainingAccounts(self: InstructionContext) u64 {
        return self.remaining;
    }

    /// Parse the next account. Returns null if none remaining.
    pub fn nextAccount(self: *InstructionContext) ?AccountInfo {
        if (self.remaining == 0) return null;
        self.remaining -= 1;
        return self.nextAccountUnchecked();
    }

    /// Parse the next account — no bounds check.
    /// Caller must ensure there are remaining accounts.
    pub inline fn nextAccountUnchecked(self: *InstructionContext) AccountInfo {
        const account_ptr: *account.Account = @ptrCast(@alignCast(self.buffer));
        const data_len: usize = @intCast(account_ptr.data_len);
        self.buffer += @sizeOf(u64) + (@sizeOf(Account) - @sizeOf(u64)) + data_len + MAX_PERMITTED_DATA_INCREASE;
        self.buffer = @ptrFromInt(alignPointer(@intFromPtr(self.buffer)));
        self.buffer += @sizeOf(u64);
        return .{ .raw = account_ptr };
    }

    /// Skip accounts without parsing.
    pub fn skipAccounts(self: *InstructionContext, count: u64) void {
        var i: u64 = 0;
        while (i < count and self.remaining > 0) : (i += 1) {
            const account_ptr: *account.Account = @ptrCast(@alignCast(self.buffer));
            self.buffer += @sizeOf(u64);
            const data_len: usize = @intCast(account_ptr.data_len);
            self.buffer += @sizeOf(Account) - @sizeOf(u64) + data_len + MAX_PERMITTED_DATA_INCREASE;
            self.buffer = @ptrFromInt(alignPointer(@intFromPtr(self.buffer)));
            self.buffer += @sizeOf(u64);
            self.remaining -= 1;
        }
    }

    /// Get instruction data. Call after all accounts are consumed.
    pub inline fn instructionData(self: *InstructionContext) []const u8 {
        const data_len: usize = @intCast(@as(*const u64, @ptrCast(@alignCast(self.buffer))).*);
        self.buffer += @sizeOf(u64);
        return self.buffer[0..data_len];
    }

    /// Get program ID. Call after instruction_data().
    pub inline fn programId(self: *InstructionContext) *const Pubkey {
        const data_len: usize = @intCast(@as(*const u64, @ptrCast(@alignCast(self.buffer))).*);
        self.buffer += @sizeOf(u64) + data_len;
        return @ptrCast(@alignCast(self.buffer));
    }
};

// =========================================================================
// Entrypoint helpers
// =========================================================================

/// Branch prediction hint: unlikely branch.
pub inline fn unlikely(b: bool) bool {
    if (b) {
        @branchHint(.cold);
        return true;
    }
    return false;
}

/// Branch prediction hint: likely branch.
pub inline fn likely(b: bool) bool {
    if (!b) {
        @branchHint(.cold);
        return false;
    }
    return true;
}

// =========================================================================
// lazyEntrypoint — the ONLY entrypoint macro (Pinocchio: lazy_program_entrypoint!)
//
/// Usage:
/// ```zig
/// fn process(ctx: *sol.entrypoint.InstructionContext) sol.ProgramResult {
///     const source = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;
///     const dest = ctx.nextAccount() orelse return error.NotEnoughAccountKeys;
///     const ix_data = ctx.instructionData();
///     // ...
/// }
///
/// export fn entrypoint(input: [*]u8) u64 {
///     return sol.entrypoint.lazyEntrypoint(process)(input);
/// }
/// ```
pub fn lazyEntrypoint(
    comptime process: *const fn (*InstructionContext) ProgramResult,
) fn ([*]u8) callconv(.c) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.c) u64 {
            var context = InstructionContext.init(input);
            process(&context) catch |err| {
                return program_error.errorToU64(err);
            };
            return SUCCESS;
        }
    }.entry;
}

/// Raw entrypoint — returns u64 directly, no error union overhead.
/// Use for maximum performance when you don't need ProgramResult.
pub fn lazyEntrypointRaw(
    comptime process: *const fn (*InstructionContext) u64,
) fn ([*]u8) callconv(.c) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.c) u64 {
            var context = InstructionContext.init(input);
            return process(&context);
        }
    }.entry;
}

// =========================================================================
// Tests
// =========================================================================

fn makePubkey(v: u8) Pubkey {
    var pk: Pubkey = undefined;
    @memset(&pk, v);
    return pk;
}

test "entrypoint: InstructionContext size is 16 bytes" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(InstructionContext));
}

test "entrypoint: AccountInfo size is 8 bytes" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(AccountInfo));
}

test "entrypoint: parse accounts and instruction data" {
    var input align(8) = [_]u8{0} ** 32768;
    var ptr: [*]u8 = &input;

    // num_accounts = 2
    std.mem.writeInt(u64, ptr[0..8], 2, .little);
    ptr += 8;

    // Account 0
    const acc0: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(1),
        .owner = makePubkey(2),
        .lamports = 1000,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc0));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    // Account 1
    const acc1: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(3),
        .owner = makePubkey(2),
        .lamports = 500,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc1));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    // instruction data
    std.mem.writeInt(u64, ptr[0..8], 4, .little);
    ptr += 8;
    @memcpy(ptr[0..4], "test");

    var ctx = InstructionContext.init(&input);

    try std.testing.expectEqual(@as(u64, 2), ctx.remainingAccounts());

    const a0 = ctx.nextAccount().?;
    try std.testing.expect(a0.isSigner());
    try std.testing.expect(a0.isWritable());
    try std.testing.expectEqual(@as(u64, 1000), a0.lamports());
    try std.testing.expect(pubkey.pubkeyEq(a0.key(), &makePubkey(1)));

    const a1 = ctx.nextAccount().?;
    try std.testing.expect(!a1.isSigner());
    try std.testing.expectEqual(@as(u64, 500), a1.lamports());
    try std.testing.expect(pubkey.pubkeyEq(a1.key(), &makePubkey(3)));

    try std.testing.expectEqual(@as(u64, 0), ctx.remainingAccounts());
    try std.testing.expect(ctx.nextAccount() == null);

    const ix_data = ctx.instructionData();
    try std.testing.expectEqualStrings("test", ix_data);
}
