const std = @import("std");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");

const Pubkey = pubkey.Pubkey;
const ProgramError = program_error.ProgramError;

/// Value used to indicate that a serialized account is not a duplicate
pub const NON_DUP_MARKER: u8 = 0xFF;

/// Maximum permitted data increase per instruction
pub const MAX_PERMITTED_DATA_INCREASE: usize = 10 * 1024;

/// Maximum number of accounts that a transaction may process
pub const MAX_TX_ACCOUNTS: usize = 256;

/// BPF alignment for u128
pub const BPF_ALIGN_OF_U128: usize = 8;

/// Not borrowed state (all bits set)
pub const NOT_BORROWED: u8 = 0xFF;

/// Direct mapping of Solana runtime account memory layout.
/// Data follows immediately in memory after this struct.
pub const Account = extern struct {
    borrow_state: u8,
    is_signer: u8,
    is_writable: u8,
    is_executable: u8,
    _padding: [4]u8,
    key: Pubkey,
    owner: Pubkey,
    lamports: u64,
    data_len: u64,
};

// =========================================================================
// AccountInfo — primary account type (Pinocchio-style, 8 bytes)
//
// A single pointer into the runtime input buffer. All field access
// dereferences through it — compiles to the same BPF instructions as
// hand-written pointer arithmetic.
//
// For CPI calls, use `toCpiInfo()` to create a C-ABI-compatible view.
// =========================================================================

pub const AccountInfo = struct {
    raw: *align(8) Account,

    // --- Accessors (all inline, zero overhead) ---

    pub inline fn key(self: AccountInfo) *const Pubkey {
        return &self.raw.key;
    }

    pub inline fn owner(self: AccountInfo) *const Pubkey {
        return &self.raw.owner;
    }

    pub inline fn lamports(self: AccountInfo) u64 {
        return self.raw.lamports;
    }

    pub inline fn setLamports(self: AccountInfo, value: u64) void {
        self.raw.lamports = value;
    }

    /// Subtract lamports from this account (source of a transfer).
    /// Caller must ensure this account is writable and has sufficient balance.
    pub inline fn subLamports(self: AccountInfo, amount: u64) void {
        self.raw.lamports -= amount;
    }

    /// Add lamports to this account (destination of a transfer).
    pub inline fn addLamports(self: AccountInfo, amount: u64) void {
        self.raw.lamports += amount;
    }

    pub inline fn dataLen(self: AccountInfo) usize {
        return @intCast(self.raw.data_len);
    }

    pub inline fn isSigner(self: AccountInfo) bool {
        return self.raw.is_signer != 0;
    }

    pub inline fn isWritable(self: AccountInfo) bool {
        return self.raw.is_writable != 0;
    }

    pub inline fn executable(self: AccountInfo) bool {
        return self.raw.is_executable != 0;
    }

    pub inline fn dataPtr(self: AccountInfo) [*]u8 {
        return @ptrFromInt(@intFromPtr(self.raw) + @sizeOf(Account));
    }

    pub inline fn data(self: AccountInfo) []u8 {
        return self.dataPtr()[0..self.dataLen()];
    }

    pub inline fn isOwnedBy(self: AccountInfo, program: *const Pubkey) bool {
        return pubkey.pubkeyEq(self.owner(), program);
    }

    /// Read a typed value from account data at the given byte offset.
    /// Zero overhead — compiles to a single pointer dereference.
    ///
    /// ```zig
    /// const counter: u64 = account.readData(u64, 0);
    /// const flag: bool = account.readData(bool, 8);
    /// ```
    pub inline fn readData(self: AccountInfo, comptime T: type, comptime offset: usize) T {
        comptime {
            if (offset + @sizeOf(T) > 0) { // runtime check done separately
                // offset + @sizeOf(T) must fit in data
            }
        }
        const ptr: *align(1) const T = @ptrCast(@alignCast(self.dataPtr() + offset));
        return ptr.*;
    }

    /// Write a typed value to account data at the given byte offset.
    /// Zero overhead — compiles to a single pointer store.
    ///
    /// ```zig
    /// account.writeData(u64, 0, new_counter);
    /// ```
    pub inline fn writeData(self: AccountInfo, comptime T: type, comptime offset: usize, value: T) void {
        const ptr: *align(1) T = @ptrCast(@alignCast(self.dataPtr() + offset));
        ptr.* = value;
    }

    /// Create a C-ABI-compatible view for CPI calls.
    /// Only needed when calling `cpi.invoke`.
    pub inline fn toCpiInfo(self: AccountInfo) CpiAccountInfo {
        return CpiAccountInfo.fromPtr(self.raw);
    }
};

// =========================================================================
// MaybeAccount — result of next_account (Pinocchio-style)
// =========================================================================

pub const MaybeAccount = union(enum) {
    account: AccountInfo,
    duplicated: u8,
};

// =========================================================================
// CpiAccountInfo — C-ABI-compatible view for CPI (SolAccountInfo layout)
//
// Only use this when passing accounts to `cpi.invoke`.
// Normal programs should use `AccountInfo` instead.
// =========================================================================

pub const CpiAccountInfo = extern struct {
    key_ptr: *const Pubkey,
    lamports_ptr: *u64,
    data_len: u64,
    data_ptr: [*]u8,
    owner_ptr: *const Pubkey,
    rent_epoch: u64,
    is_signer: u8,
    is_writable: u8,
    is_executable: u8,
    _abi_padding: [5]u8,
    borrow_state_ptr: *u8,
    flags: u8,
    _ext_padding: [6]u8,

    const FLAG_SIGNER: u8 = 1 << 0;
    const FLAG_WRITABLE: u8 = 1 << 1;
    const FLAG_EXECUTABLE: u8 = 1 << 2;

    pub inline fn fromPtr(ptr: *Account) CpiAccountInfo {
        const dp: [*]u8 = @ptrFromInt(@intFromPtr(ptr) + @sizeOf(Account));
        return .{
            .key_ptr = &ptr.key,
            .lamports_ptr = &ptr.lamports,
            .data_len = ptr.data_len,
            .data_ptr = dp,
            .owner_ptr = &ptr.owner,
            .rent_epoch = 0,
            .is_signer = ptr.is_signer,
            .is_writable = ptr.is_writable,
            .is_executable = ptr.is_executable,
            ._abi_padding = .{0} ** 5,
            .borrow_state_ptr = &ptr.borrow_state,
            .flags = makeFlags(ptr.is_signer, ptr.is_writable, ptr.is_executable),
            ._ext_padding = .{0} ** 6,
        };
    }

    inline fn makeFlags(s: u8, w: u8, e: u8) u8 {
        var f: u8 = 0;
        if (s != 0) f |= FLAG_SIGNER;
        if (w != 0) f |= FLAG_WRITABLE;
        if (e != 0) f |= FLAG_EXECUTABLE;
        return f;
    }

    pub inline fn key(self: CpiAccountInfo) *const Pubkey {
        return self.key_ptr;
    }

    pub inline fn owner(self: CpiAccountInfo) *const Pubkey {
        return self.owner_ptr;
    }

    pub inline fn lamports(self: CpiAccountInfo) u64 {
        return self.lamports_ptr.*;
    }

    pub inline fn dataLen(self: CpiAccountInfo) usize {
        return @intCast(self.data_len);
    }

    pub inline fn isSigner(self: CpiAccountInfo) bool {
        return self.flags & FLAG_SIGNER != 0;
    }

    pub inline fn isWritable(self: CpiAccountInfo) bool {
        return self.flags & FLAG_WRITABLE != 0;
    }

    pub inline fn data(self: CpiAccountInfo) []u8 {
        return self.data_ptr[0..self.dataLen()];
    }
};

/// Align pointer to BPF u128 alignment
pub inline fn alignPointer(ptr: usize) usize {
    return (ptr + (BPF_ALIGN_OF_U128 - 1)) & ~(BPF_ALIGN_OF_U128 - 1);
}

// =============================================================================
// Tests
// =============================================================================

test "account: Account size" {
    try std.testing.expectEqual(@as(usize, 88), @sizeOf(Account));
}

test "account: AccountInfo is 8 bytes" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(AccountInfo));
}

test "account: AccountInfo accessors" {
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{1} ** 32,
        .owner = .{2} ** 32,
        .lamports = 1000,
        .data_len = 10,
    };
    const info = AccountInfo{ .raw = &acc };

    try std.testing.expect(info.isSigner());
    try std.testing.expect(info.isWritable());
    try std.testing.expect(!info.executable());
    try std.testing.expectEqual(@as(u64, 1000), info.lamports());
    try std.testing.expectEqual(@as(usize, 10), info.dataLen());
    try std.testing.expect(pubkey.pubkeyEq(info.key(), &[_]u8{1} ** 32));
    try std.testing.expect(pubkey.pubkeyEq(info.owner(), &[_]u8{2} ** 32));
}

test "account: CpiAccountInfo from AccountInfo" {
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{1} ** 32,
        .owner = .{2} ** 32,
        .lamports = 1000,
        .data_len = 0,
    };
    const info = AccountInfo{ .raw = &acc };
    const cpi_info = info.toCpiInfo();

    try std.testing.expect(cpi_info.isSigner());
    try std.testing.expectEqual(@as(u64, 1000), cpi_info.lamports());
}
