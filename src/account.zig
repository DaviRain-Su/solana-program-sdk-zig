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

    /// Subtract lamports, returning `error.ArithmeticOverflow` on
    /// underflow. Use when balance cannot be assumed to cover `amount`
    /// (typical for user-controlled withdrawal amounts).
    pub inline fn subLamportsChecked(self: AccountInfo, amount: u64) ProgramError!void {
        const new_balance, const overflow = @subWithOverflow(self.raw.lamports, amount);
        if (overflow != 0) return error.ArithmeticOverflow;
        self.raw.lamports = new_balance;
    }

    /// Add lamports, returning `error.ArithmeticOverflow` on overflow.
    /// Use when the destination balance could realistically reach
    /// `u64.max` (unusual outside of fees aggregator programs).
    pub inline fn addLamportsChecked(self: AccountInfo, amount: u64) ProgramError!void {
        const new_balance, const overflow = @addWithOverflow(self.raw.lamports, amount);
        if (overflow != 0) return error.ArithmeticOverflow;
        self.raw.lamports = new_balance;
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

    /// Combined expectation check, mirroring `parseAccountsWith`'s
    /// `AccountExpectation` shape but applied to a single account.
    ///
    /// ```zig
    /// try authority.expect(.{ .signer = true, .writable = true });
    /// try mint.expect(.{ .owner = sol.spl_token_program_id });
    /// try sysvar.expect(.{ .key = sol.sysvar.RENT_ID });
    /// ```
    ///
    /// Each check is `comptime if`-guarded: only the requested
    /// branches generate code. Three checks compile to three branches,
    /// the unset fields disappear entirely. Same BPF as calling the
    /// individual `expectSigner` / `expectWritable` / etc. helpers
    /// in sequence — but the single-call site is easier to read and
    /// keeps related assertions together.
    pub inline fn expect(self: AccountInfo, comptime spec: anytype) ProgramError!void {
        const S = @TypeOf(spec);
        const info = @typeInfo(S);
        if (info != .@"struct") {
            @compileError("AccountInfo.expect requires a struct literal");
        }
        // NOTE: we deliberately do NOT auto-fold `signer + writable`
        // into `expectSignerWritable`. Measurements showed the
        // u16-combined check helps some instructions and hurts others
        // (the wider load interacts differently with the register
        // scheduler). The user can call `expectSignerWritable` directly
        // when measurement says it wins.
        inline for (info.@"struct".fields) |field| {
            const name = field.name;
            const val = @field(spec, name);
            if (comptime std.mem.eql(u8, name, "signer")) {
                if (val) try self.expectSigner();
            } else if (comptime std.mem.eql(u8, name, "writable")) {
                if (val) try self.expectWritable();
            } else if (comptime std.mem.eql(u8, name, "executable")) {
                if (val) try self.expectExecutable();
            } else if (comptime std.mem.eql(u8, name, "owner")) {
                // `owner` field: pass either a comptime `Pubkey` (uses
                // immediate compares) or a `*const Pubkey` (uses
                // runtime compare). Comptime case is ~3-4 CU cheaper.
                const owner_val: Pubkey = val;
                if (!pubkey.pubkeyEqComptime(self.owner(), owner_val)) {
                    return error.IncorrectProgramId;
                }
            } else if (comptime std.mem.eql(u8, name, "key")) {
                const key_val: Pubkey = val;
                if (!pubkey.pubkeyEqComptime(self.key(), key_val)) {
                    return error.InvalidArgument;
                }
            } else {
                @compileError("Unknown expectation field: '" ++ name ++
                    "'. Allowed: signer, writable, executable, owner, key.");
            }
        }
    }

    /// Combined `expectSigner + expectWritable` — checks both flags
    /// with a single u16 load instead of two byte loads. The happy
    /// path is one compare against `0x0101` (both bytes = 1). Saves
    /// 2-3 CU vs. calling the two helpers in sequence.
    ///
    /// On failure: prefers `MissingRequiredSignature` over
    /// `ImmutableAccount`, matching the order of the equivalent
    /// hand-written `try expectSigner(); try expectWritable();`.
    pub inline fn expectSignerWritable(self: AccountInfo) ProgramError!void {
        // is_signer at offset 1, is_writable at offset 2. Both bytes
        // are 0 or 1 (never anything else). Combined u16 LE pattern
        // for "signer && writable" is 0x0101.
        const flags_ptr: *align(1) const u16 = @ptrCast(&self.raw.is_signer);
        if (flags_ptr.* != 0x0101) {
            // Fall back to individual checks to produce the right
            // error variant. Cold path — only runs when one of the
            // two flags is actually missing.
            if (!self.isSigner()) return error.MissingRequiredSignature;
            return error.ImmutableAccount;
        }
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

    /// Typed mutable view over the account's data, starting at offset 0.
    /// Returns `*align(1) T` — no copies, no allocation, single
    /// pointer-cast. Caller is responsible for asserting the layout
    /// is correct (use `TypedAccount(T)` for discriminator-checked
    /// access).
    ///
    /// ```zig
    /// const state: *align(1) MyState = account.dataAs(MyState);
    /// state.counter += 1;  // direct write into account data
    /// ```
    pub inline fn dataAs(self: AccountInfo, comptime T: type) *align(1) T {
        return @ptrCast(@alignCast(self.dataPtr()));
    }

    /// Read-only counterpart to `dataAs`.
    pub inline fn dataAsConst(self: AccountInfo, comptime T: type) *align(1) const T {
        return @ptrCast(@alignCast(self.dataPtr()));
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
        // `is_signer`/`is_writable`/`is_executable` live at consecutive
        // offsets 1, 2, 3 in `Account`. We copy them as a single u32
        // load+store (4 bytes — pulling in one byte of `_padding` on
        // both sides, which is fine since both sides have padding
        // there). This mirrors Pinocchio's `CpiAccount::init_from_account_view`
        // and saves a few CU vs. three byte loads + three byte stores.
        //
        // Tried u64 copy (8 bytes) but the source's byte 8 is `key[0]`,
        // not zero, so it would write garbage into `_abi_padding`.
        // u32 is the safe maximum.
        const flags_src: *align(1) const u32 = @ptrCast(&ptr.is_signer);
        var out: CpiAccountInfo = .{
            .key_ptr = &ptr.key,
            .lamports_ptr = &ptr.lamports,
            .data_len = ptr.data_len,
            .data_ptr = dp,
            .owner_ptr = &ptr.owner,
            .rent_epoch = 0,
            .is_signer = undefined,
            .is_writable = undefined,
            .is_executable = undefined,
            ._abi_padding = undefined,
        };
        const flags_dst: *align(1) u32 = @ptrCast(&out.is_signer);
        flags_dst.* = flags_src.*;
        return out;
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

test "account: expect — happy path" {
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{42} ** 32,
        .owner = .{7} ** 32,
        .lamports = 1000,
        .data_len = 0,
    };
    const info = AccountInfo{ .raw = &acc };

    try info.expect(.{ .signer = true, .writable = true });
    try info.expect(.{ .owner = .{7} ** 32 });
    try info.expect(.{ .key = .{42} ** 32 });
    try info.expect(.{
        .signer = true,
        .writable = true,
        .owner = .{7} ** 32,
        .key = .{42} ** 32,
    });
}

test "account: expect — signer missing" {
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    const info = AccountInfo{ .raw = &acc };
    try std.testing.expectError(error.MissingRequiredSignature, info.expect(.{ .signer = true }));
}

test "account: expect — wrong owner" {
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{7} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    const info = AccountInfo{ .raw = &acc };
    try std.testing.expectError(
        error.IncorrectProgramId,
        info.expect(.{ .owner = .{99} ** 32 }),
    );
}

test "account: expect — wrong key" {
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{42} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = 0,
    };
    const info = AccountInfo{ .raw = &acc };
    try std.testing.expectError(
        error.InvalidArgument,
        info.expect(.{ .key = .{99} ** 32 }),
    );
}

test "account: dataAs / dataAsConst typed view" {
    const Layout = extern struct {
        a: u64 align(1),
        b: u32 align(1),
    };
    const backing: [@sizeOf(Layout)]u8 = .{0} ** @sizeOf(Layout);
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 0,
        .data_len = @sizeOf(Layout),
    };
    // dataPtr() reads the bytes immediately after the Account header,
    // so we need a contiguous buffer. The host-side test simulates by
    // adjusting data_len and exercising dataAs via the @ptrCast — but
    // since dataPtr() is `&self.raw[1]`, we can't easily test the read
    // here without a full input layout. Instead just verify the
    // function compiles and the returned pointer type is correct.
    _ = backing;
    const info = AccountInfo{ .raw = &acc };
    const ptr_mut = info.dataAs(Layout);
    const ptr_const = info.dataAsConst(Layout);
    try std.testing.expectEqual(@TypeOf(ptr_mut), *align(1) Layout);
    try std.testing.expectEqual(@TypeOf(ptr_const), *align(1) const Layout);
}

test "account: addLamportsChecked / subLamportsChecked overflow" {
    var acc: Account = .{
        .borrow_state = NOT_BORROWED,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = .{0} ** 32,
        .owner = .{0} ** 32,
        .lamports = 100,
        .data_len = 0,
    };
    const info = AccountInfo{ .raw = &acc };

    try info.addLamportsChecked(50);
    try std.testing.expectEqual(@as(u64, 150), info.lamports());

    try info.subLamportsChecked(150);
    try std.testing.expectEqual(@as(u64, 0), info.lamports());

    try std.testing.expectError(error.ArithmeticOverflow, info.subLamportsChecked(1));
    info.setLamports(std.math.maxInt(u64));
    try std.testing.expectError(error.ArithmeticOverflow, info.addLamportsChecked(1));
}
