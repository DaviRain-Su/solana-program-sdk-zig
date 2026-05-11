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

    /// Compare this account's owner against a compile-time-known
    /// program id. Generates four `u64`-immediate compares — no second
    /// load and no rodata reference to the expected pubkey.
    ///
    /// ```zig
    /// const MY_PROGRAM_ID = sol.pubkey.comptimeFromBase58("...");
    /// if (!account.isOwnedByComptime(MY_PROGRAM_ID)) {
    ///     return error.IncorrectProgramId;
    /// }
    /// ```
    pub inline fn isOwnedByComptime(self: AccountInfo, comptime program: Pubkey) bool {
        return pubkey.pubkeyEqComptime(self.owner(), program);
    }

    /// Like `isOwnedByComptime`, but returns
    /// `error.IncorrectProgramId` when the owner doesn't match.
    pub inline fn assertOwnerComptime(self: AccountInfo, comptime program: Pubkey) ProgramError!void {
        if (!pubkey.pubkeyEqComptime(self.owner(), program)) {
            return error.IncorrectProgramId;
        }
    }

    /// Compare this account's key against a compile-time-known pubkey.
    pub inline fn keyEqComptime(self: AccountInfo, comptime expected: Pubkey) bool {
        return pubkey.pubkeyEqComptime(self.key(), expected);
    }

    /// Return `error.MissingRequiredSignature` if this account did not
    /// sign the transaction.
    pub inline fn expectSigner(self: AccountInfo) ProgramError!void {
        if (!self.isSigner()) return error.MissingRequiredSignature;
    }

    /// Return `error.ImmutableAccount` if this account is not writable.
    pub inline fn expectWritable(self: AccountInfo) ProgramError!void {
        if (!self.isWritable()) return error.ImmutableAccount;
    }

    /// Return `error.InvalidAccountData` if this account is not executable.
    /// Useful for sanity-checking that an "executable" account passed
    /// into the program really is a program account.
    pub inline fn expectExecutable(self: AccountInfo) ProgramError!void {
        if (!self.executable()) return error.InvalidAccountData;
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
//
// When the Solana runtime serializes an instruction whose account list
// includes the same key more than once, occurrences after the first
// are encoded as an 8-byte "duplicate" record whose first byte holds
// the original account's index (instead of `NON_DUP_MARKER`).
//
// The lazy entrypoint's dup-aware iterators return `MaybeAccount` so
// callers can distinguish:
//   - `.account`: a non-duplicate `AccountInfo` pointing into the
//     input buffer
//   - `.duplicated`: the index of the original (earlier) account that
//     this slot duplicates — caller resolves the mapping
// =========================================================================

pub const MaybeAccount = union(enum) {
    account: AccountInfo,
    duplicated: u8,

    /// Extract the wrapped `AccountInfo`, panicking if this slot is a
    /// duplicate. Use this when you've structurally proven (or
    /// validated upstream) that duplicates can't occur.
    pub inline fn assumeAccount(self: MaybeAccount) AccountInfo {
        return switch (self) {
            .account => |a| a,
            .duplicated => @panic("MaybeAccount.assumeAccount called on duplicated account"),
        };
    }
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
        };
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
        return self.is_signer != 0;
    }

    pub inline fn isWritable(self: CpiAccountInfo) bool {
        return self.is_writable != 0;
    }

    pub inline fn data(self: CpiAccountInfo) []u8 {
        return self.data_ptr[0..self.dataLen()];
    }
};

comptime {
    // SolAccountInfo C ABI is 56 bytes; the syscall reads accounts at this stride.
    std.debug.assert(@sizeOf(CpiAccountInfo) == 56);
}

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
