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
const ProgramError = program_error.ProgramError;
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

    // ---------------------------------------------------------------------
    // next_account — non-dup fast path
    //
    // `nextAccount` / `nextAccountUnchecked` assume the slot is NOT a
    // duplicate (i.e. `borrow_state == NON_DUP_MARKER`). They step the
    // buffer past the full account header + data + padding.
    //
    // If the runtime ever serializes a duplicate slot, these will
    // misalign the buffer for subsequent reads. Programs that know
    // their callers may pass duplicates should use the `Maybe` variants
    // below.
    // ---------------------------------------------------------------------

    /// Parse the next account. Returns null if none remaining.
    ///
    /// Assumes the slot is not a duplicated-account marker. For
    /// duplicate-aware iteration use `nextAccountMaybe`.
    pub fn nextAccount(self: *InstructionContext) ?AccountInfo {
        if (self.remaining == 0) return null;
        self.remaining -= 1;
        return self.nextAccountUnchecked();
    }

    /// Parse the next account — no bounds check, no dup check.
    /// Caller must ensure there are remaining accounts AND that the
    /// slot is not a duplicate marker.
    pub inline fn nextAccountUnchecked(self: *InstructionContext) AccountInfo {
        const account_ptr: *account.Account = @ptrCast(@alignCast(self.buffer));
        const data_len: usize = @intCast(account_ptr.data_len);
        self.buffer += @sizeOf(u64) + (@sizeOf(Account) - @sizeOf(u64)) + data_len + MAX_PERMITTED_DATA_INCREASE;
        self.buffer = @ptrFromInt(alignPointer(@intFromPtr(self.buffer)));
        self.buffer += @sizeOf(u64);
        return .{ .raw = account_ptr };
    }

    // ---------------------------------------------------------------------
    // next_account_maybe — dup-aware (matches Pinocchio `next_account`)
    //
    // Returns `MaybeAccount`, distinguishing between a freshly serialized
    // account and a duplicate slot that references an earlier account by
    // index. Buffer is advanced by the correct stride either way:
    //
    //   - non-dup:   8-byte rent_epoch + STATIC_ACCOUNT_DATA + data_len +
    //                MAX_PERMITTED_DATA_INCREASE + 8-byte alignment pad
    //   - dup:       8 bytes (1-byte index + 7 bytes padding)
    //
    // This is the only safe iteration mode for programs whose callers
    // may pass the same account in more than one slot.
    // ---------------------------------------------------------------------

    /// Dup-aware next-account. Returns `error.NotEnoughAccountKeys`
    /// when no accounts remain; otherwise returns `MaybeAccount`
    /// which the caller pattern-matches:
    ///
    /// ```zig
    /// switch (try ctx.nextAccountMaybe()) {
    ///     .account => |acc| { ... },
    ///     .duplicated => |idx| { /* same as earlier accounts[idx] */ },
    /// }
    /// ```
    pub fn nextAccountMaybe(self: *InstructionContext) ProgramError!MaybeAccount {
        if (self.remaining == 0) return error.NotEnoughAccountKeys;
        self.remaining -= 1;
        return self.nextAccountMaybeUnchecked();
    }

    /// Dup-aware next-account — no bounds check.
    /// Caller must ensure `remainingAccounts() > 0`.
    pub inline fn nextAccountMaybeUnchecked(self: *InstructionContext) MaybeAccount {
        const account_ptr: *account.Account = @ptrCast(@alignCast(self.buffer));

        if (account_ptr.borrow_state == account.NON_DUP_MARKER) {
            // Non-duplicate: advance past header (which includes the leading
            // 8-byte rent_epoch padding embedded by the runtime) + data +
            // MAX_PERMITTED_DATA_INCREASE + alignment.
            const data_len: usize = @intCast(account_ptr.data_len);
            self.buffer += @sizeOf(u64) + (@sizeOf(Account) - @sizeOf(u64)) + data_len + MAX_PERMITTED_DATA_INCREASE;
            self.buffer = @ptrFromInt(alignPointer(@intFromPtr(self.buffer)));
            self.buffer += @sizeOf(u64);
            return .{ .account = .{ .raw = account_ptr } };
        } else {
            // Duplicate slot: 1-byte index + 7 bytes padding = 8 bytes total.
            const idx = account_ptr.borrow_state;
            self.buffer += @sizeOf(u64);
            return .{ .duplicated = idx };
        }
    }

    /// Skip accounts without parsing. Dup-aware: dup slots advance by
    /// 8 bytes, non-dup slots advance by the full account stride.
    pub fn skipAccounts(self: *InstructionContext, count: u64) void {
        var i: u64 = 0;
        while (i < count and self.remaining > 0) : (i += 1) {
            _ = self.nextAccountMaybeUnchecked();
            self.remaining -= 1;
        }
    }

    /// Get instruction data. Returns an error if there are still
    /// unparsed accounts; this is the safe variant matching Pinocchio's
    /// `instruction_data`.
    ///
    /// Does NOT advance the buffer — safe to call multiple times, and
    /// safe to interleave with `programId()`. Use `instructionDataUnchecked`
    /// when you've consumed accounts via `nextAccountUnchecked` (which
    /// leaves `remaining` unchanged).
    pub inline fn instructionData(self: *const InstructionContext) ProgramError![]const u8 {
        if (self.remaining > 0) return error.InvalidInstructionData;
        return self.instructionDataUnchecked();
    }

    /// Get instruction data without checking the remaining-accounts
    /// counter. Does not advance the buffer.
    ///
    /// Mirrors Pinocchio's `instruction_data_unchecked`.
    pub inline fn instructionDataUnchecked(self: *const InstructionContext) []const u8 {
        const data_len: usize = @intCast(@as(*const u64, @ptrCast(@alignCast(self.buffer))).*);
        return self.buffer[@sizeOf(u64) .. @sizeOf(u64) + data_len];
    }

    /// Get program ID. Returns an error if accounts are still unparsed.
    /// Mirrors Pinocchio's `program_id`. Does NOT advance the buffer.
    pub inline fn programId(self: *const InstructionContext) ProgramError!*const Pubkey {
        if (self.remaining > 0) return error.InvalidInstructionData;
        return self.programIdUnchecked();
    }

    /// Get program ID without checks. Does not advance the buffer.
    /// Skips past the instruction-data length prefix and contents to
    /// find the program-id at the end of the input layout.
    pub inline fn programIdUnchecked(self: *const InstructionContext) *const Pubkey {
        const data_len: usize = @intCast(@as(*const u64, @ptrCast(@alignCast(self.buffer))).*);
        return @ptrCast(@alignCast(self.buffer + @sizeOf(u64) + data_len));
    }

    // =====================================================================
    // Comptime typed deserialization — no more manual pointer casting
    // =====================================================================

    /// Read a typed value from instruction data at the given byte offset.
    /// Zero overhead — compiles to a single aligned pointer dereference.
    ///
    /// ```zig
    /// const amount = ctx.readIx(u64, 0);
    /// const index = ctx.readIx(u32, 8);
    /// ```
    pub inline fn readIx(self: *InstructionContext, comptime T: type, comptime offset: usize) T {
        const data = self.instructionDataUnchecked();
        const ptr: *align(1) const T = @ptrCast(@alignCast(data.ptr + offset));
        return ptr.*;
    }

    /// Read instruction data as a packed struct, starting at byte 0.
    /// Returns a comptime-typed value — no manual deserialization needed.
    ///
    /// ```zig
    /// const TransferIx = packed struct { amount: u64 };
    /// const ix = ctx.unpackIx(TransferIx);
    /// // ix.amount is a plain u64
    /// ```
    pub inline fn unpackIx(self: *InstructionContext, comptime T: type) T {
        const data = self.instructionDataUnchecked();
        const ptr: *align(1) const T = @ptrCast(@alignCast(data.ptr));
        return ptr.*;
    }

    /// Read instruction data as a discriminated enum union.
    /// First reads the discriminant (default: u32 at offset 0), then returns
    /// the tagged union value. Comptime — no runtime dispatch overhead.
    ///
    /// ```zig
    /// const MyInstruction = enum(u32) {
    ///     transfer,
    ///     burn,
    /// };
    /// const tag = ctx.readIxTag(MyInstruction);
    /// switch (tag) {
    ///     .transfer => { ... },
    ///     .burn => { ... },
    /// }
    /// ```
    pub inline fn readIxTag(self: *InstructionContext, comptime Tag: type) Tag {
        comptime {
            if (@typeInfo(Tag) != .@"enum") {
                @compileError("readIxTag requires an enum type");
            }
        }
        const TagInt = comptime blk: {
            break :blk @typeInfo(Tag).@"enum".tag_type;
        };
        const raw = self.readIx(TagInt, 0);
        return @enumFromInt(raw);
    }

    /// Parse a fixed set of accounts into a named struct.
    ///
    /// `names` is a comptime tuple of `[]const u8` field names. The
    /// returned struct has one `AccountInfo` field per name, in order.
    /// Returns `error.NotEnoughAccountKeys` if `ctx.remainingAccounts()`
    /// is smaller than `names.len`.
    ///
    /// ```zig
    /// const accs = try ctx.parseAccounts(.{ "from", "to", "system_program" });
    /// // accs.from, accs.to, accs.system_program are AccountInfo
    /// try sol.system.transfer(accs.from, accs.to, accs.system_program, 100);
    /// ```
    ///
    /// Zero runtime overhead vs. hand-written `nextAccount() orelse …`:
    /// the loop is fully unrolled at compile time.
    pub inline fn parseAccounts(
        self: *InstructionContext,
        comptime names: anytype,
    ) ProgramError!ParsedAccounts(names) {
        const T = ParsedAccounts(names);
        var out: T = undefined;
        // Dup-aware: walk the slot list with `nextAccountMaybe`,
        // resolving duplicates back to the corresponding earlier
        // AccountInfo via a small parallel array.
        var seen: [names.len]AccountInfo = undefined;
        inline for (names, 0..) |name, i| {
            const slot = try self.nextAccountMaybe();
            const acc = switch (slot) {
                .account => |a| a,
                .duplicated => |idx| seen[idx],
            };
            seen[i] = acc;
            @field(out, name) = acc;
        }
        return out;
    }

    /// Like `parseAccounts`, but skips the dup-aware tagged-union
    /// machinery entirely. Caller asserts (structurally or by upstream
    /// validation) that no two slots reference the same account.
    ///
    /// On BPF this is **~70 CU cheaper** for a 2-account parse compared
    /// to the safe `parseAccounts` — the unsafe path collapses to a
    /// straight stride-advance per slot, no `MaybeAccount` switch, no
    /// `seen[]` parallel array.
    ///
    /// Use only when:
    ///   - the program logically can't be passed the same account
    ///     twice (e.g. fixed roles like `mint`/`vault`/`recipient`), or
    ///   - the caller's transaction-builder guarantees uniqueness
    ///     (e.g. derived PDAs that are distinct by construction).
    ///
    /// If your program accepts arbitrary user-supplied account lists
    /// where dups are possible AND meaningful (token transfers,
    /// multisig signers), use the safe `parseAccounts` instead.
    pub inline fn parseAccountsUnchecked(
        self: *InstructionContext,
        comptime names: anytype,
    ) ProgramError!ParsedAccounts(names) {
        if (self.remaining < names.len) return error.NotEnoughAccountKeys;
        self.remaining -= @intCast(names.len);

        const T = ParsedAccounts(names);
        var out: T = undefined;
        inline for (names) |name| {
            @field(out, name) = self.nextAccountUnchecked();
        }
        return out;
    }

    /// Like `parseAccounts`, but with comptime-declared per-account
    /// expectations. Each entry is `.{ name, AccountExpectation{...} }`.
    /// The expectation fields:
    ///   - `signer`:     if `true`, fail with `MissingRequiredSignature`
    ///                   when the account did not sign the transaction.
    ///   - `writable`:   if `true`, fail with `ImmutableAccount`.
    ///   - `executable`: if `true`, fail with `InvalidAccountData`
    ///                   when the account is not a program.
    ///   - `owner`:      optional comptime `Pubkey`; if set, fail with
    ///                   `IncorrectProgramId` unless the account is
    ///                   owned by exactly this program id. Uses
    ///                   `pubkeyEqComptime` so the expected key is
    ///                   folded into 4 u64 immediates.
    ///
    /// All checks are unrolled at compile time — the resulting BPF
    /// code is byte-identical to hand-written `if`s, but the SDK
    /// guarantees the correct error variant for each failure (no more
    /// stray "Custom program error" surprises).
    ///
    /// ```zig
    /// const accs = try ctx.parseAccountsWith(.{
    ///     .{ "from",           .{ .signer = true, .writable = true } },
    ///     .{ "to",             .{ .writable = true } },
    ///     .{ "system_program", .{ .owner = sol.native_loader_id } },
    /// });
    /// ```
    pub inline fn parseAccountsWith(
        self: *InstructionContext,
        comptime spec: anytype,
    ) ProgramError!ParsedAccountsWith(spec) {
        const T = ParsedAccountsWith(spec);
        var out: T = undefined;
        // Dup-aware: see parseAccounts. Duplicates are resolved against
        // earlier slots in this same parse call, then the resolved
        // AccountInfo is still subject to the per-slot expectation
        // checks (signer/writable/owner) — because a duplicate slot in
        // an instruction's account list still has its own copy of the
        // (is_signer, is_writable) flags on the original account, so
        // re-checking those is correct.
        var seen: [spec.len]AccountInfo = undefined;
        inline for (spec, 0..) |entry, i| {
            const name = entry[0];
            const exp: AccountExpectation = entry[1];

            const slot = try self.nextAccountMaybe();
            const acc = switch (slot) {
                .account => |a| a,
                .duplicated => |idx| seen[idx],
            };
            seen[i] = acc;

            if (exp.signer) try acc.expectSigner();
            if (exp.writable) try acc.expectWritable();
            if (exp.executable) try acc.expectExecutable();
            if (exp.owner) |expected_owner| {
                if (!acc.isOwnedByComptime(expected_owner)) {
                    return error.IncorrectProgramId;
                }
            }

            @field(out, name) = acc;
        }
        return out;
    }
};

/// Per-account validation rules for `parseAccountsWith`.
///
/// Optional fields default to "no check"; set them to `true` (or a
/// `Pubkey` value) to enforce them.
pub const AccountExpectation = struct {
    signer: bool = false,
    writable: bool = false,
    executable: bool = false,
    owner: ?Pubkey = null,
};

/// Generate a `ParsedAccounts`-shaped struct from a comptime spec
/// tuple of `.{ name, AccountExpectation }`. Each field has type
/// `AccountInfo`.
pub fn ParsedAccountsWith(comptime spec: anytype) type {
    var field_names: [spec.len][:0]const u8 = undefined;
    inline for (spec, 0..) |entry, i| {
        field_names[i] = entry[0] ++ "";
    }
    return @Struct(
        .auto,
        null,
        &field_names,
        &@as([spec.len]type, @splat(AccountInfo)),
        &@as(
            [spec.len]std.builtin.Type.StructField.Attributes,
            @splat(.{}),
        ),
    );
}

/// Generate a struct type from a tuple of field names. Each field is
/// of type `AccountInfo`. Used by `parseAccounts`.
///
/// Zig 0.16 replaced `@Type` with per-kind builtins; this uses
/// `@Struct(layout, backing_int, field_names, field_types, field_attrs)`.
/// See <https://ziglang.org/download/0.16.0/release-notes.html>.
pub fn ParsedAccounts(comptime names: anytype) type {
    var field_names: [names.len][:0]const u8 = undefined;
    inline for (names, 0..) |name, i| {
        field_names[i] = name ++ "";
    }
    return @Struct(
        .auto,
        null,
        &field_names,
        &@as([names.len]type, @splat(AccountInfo)),
        &@as(
            [names.len]std.builtin.Type.StructField.Attributes,
            @splat(.{}),
        ),
    );
}

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

    const ix_data = try ctx.instructionData();
    try std.testing.expectEqualStrings("test", ix_data);
}

test "entrypoint: parseAccounts builds named struct" {
    var input align(8) = [_]u8{0} ** 32768;
    var ptr: [*]u8 = &input;

    std.mem.writeInt(u64, ptr[0..8], 2, .little);
    ptr += 8;

    const acc0: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(7),
        .owner = makePubkey(8),
        .lamports = 100,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc0));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    const acc1: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(9),
        .owner = makePubkey(8),
        .lamports = 200,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc1));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    std.mem.writeInt(u64, ptr[0..8], 0, .little);

    var ctx = InstructionContext.init(&input);
    const accs = try ctx.parseAccounts(.{ "from", "to" });

    try std.testing.expectEqual(@as(u64, 100), accs.from.lamports());
    try std.testing.expectEqual(@as(u64, 200), accs.to.lamports());
    try std.testing.expect(accs.from.isSigner());
    try std.testing.expect(!accs.to.isSigner());
}

test "entrypoint: parseAccounts errors when too few accounts" {
    var input align(8) = [_]u8{0} ** 256;
    std.mem.writeInt(u64, input[0..8], 0, .little);
    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.NotEnoughAccountKeys,
        ctx.parseAccounts(.{"only_one"}),
    );
}

test "entrypoint: parseAccountsUnchecked — happy path advances remaining" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 1, 1, makePubkey(99), 0, 1);

    var ctx = InstructionContext.init(&input);
    const accs = try ctx.parseAccountsUnchecked(.{ "first", "second" });
    try std.testing.expectEqual(@as(u8, 1), accs.first.key()[0]);
    try std.testing.expectEqual(@as(u8, 2), accs.second.key()[0]);
    try std.testing.expectEqual(@as(u64, 0), ctx.remaining);
    // After consuming both slots, instructionData() must accept.
    const ix = try ctx.instructionData();
    try std.testing.expectEqual(@as(usize, 0), ix.len);
}

test "entrypoint: parseAccountsUnchecked errors when too few accounts" {
    var input align(8) = [_]u8{0} ** 256;
    std.mem.writeInt(u64, input[0..8], 0, .little);
    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.NotEnoughAccountKeys,
        ctx.parseAccountsUnchecked(.{ "a", "b" }),
    );
}

// Helper that builds an input buffer with two accounts whose
// signer/writable flags are set by the caller.
fn buildTwoAccountInput(
    buf: *[32768]u8,
    acc0_signer: u8,
    acc0_writable: u8,
    acc0_owner: Pubkey,
    acc1_signer: u8,
    acc1_writable: u8,
) void {
    @memset(buf, 0);
    var ptr: [*]u8 = buf;

    std.mem.writeInt(u64, ptr[0..8], 2, .little);
    ptr += 8;

    const acc0: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = acc0_signer,
        .is_writable = acc0_writable,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(1),
        .owner = acc0_owner,
        .lamports = 100,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc0));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    const acc1: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = acc1_signer,
        .is_writable = acc1_writable,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(2),
        .owner = makePubkey(3),
        .lamports = 100,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc1));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    std.mem.writeInt(u64, ptr[0..8], 0, .little);
}

test "entrypoint: parseAccountsWith — happy path" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 1, 1, makePubkey(99), 0, 1);

    var ctx = InstructionContext.init(&input);
    const accs = try ctx.parseAccountsWith(.{
        .{ "from", AccountExpectation{ .signer = true, .writable = true } },
        .{ "to", AccountExpectation{ .writable = true } },
    });
    try std.testing.expect(accs.from.isSigner());
    try std.testing.expect(accs.to.isWritable());
}

test "entrypoint: parseAccountsWith — missing signer" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 1, makePubkey(99), 0, 1); // acc0 not signing

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.MissingRequiredSignature,
        ctx.parseAccountsWith(.{
            .{ "from", AccountExpectation{ .signer = true } },
            .{ "to", AccountExpectation{} },
        }),
    );
}

test "entrypoint: parseAccountsWith — not writable" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 1, 0, makePubkey(99), 0, 1); // acc0 not writable

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.ImmutableAccount,
        ctx.parseAccountsWith(.{
            .{ "from", AccountExpectation{ .writable = true } },
            .{ "to", AccountExpectation{} },
        }),
    );
}

test "entrypoint: parseAccountsWith — wrong owner" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 0, makePubkey(1), 0, 0); // owner=1, not 99

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.IncorrectProgramId,
        ctx.parseAccountsWith(.{
            .{ "from", AccountExpectation{ .owner = comptime makePubkey(99) } },
            .{ "to", AccountExpectation{} },
        }),
    );
}

test "entrypoint: parseAccountsWith — owner match passes" {
    const expected_owner = comptime makePubkey(42);
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 0, expected_owner, 0, 0);

    var ctx = InstructionContext.init(&input);
    const accs = try ctx.parseAccountsWith(.{
        .{ "from", AccountExpectation{ .owner = comptime makePubkey(42) } },
        .{ "to", AccountExpectation{} },
    });
    _ = accs;
}

// =========================================================================
// Duplicate-account handling tests
//
// Build an input buffer where slot 1 is a duplicate of slot 0
// (encoded as 1 byte index = 0, then 7 bytes padding = 8 bytes total).
// =========================================================================

fn buildInputWithDup(buf: *[32768]u8) void {
    @memset(buf, 0);
    var ptr: [*]u8 = buf;

    // num_accounts = 3 (one real, one dup-of-0, one real)
    std.mem.writeInt(u64, ptr[0..8], 3, .little);
    ptr += 8;

    // slot 0: real account
    const acc0: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(0xAA),
        .owner = makePubkey(0xBB),
        .lamports = 777,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc0));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    // slot 1: duplicate marker pointing back to slot 0
    // (8 bytes: index byte + 7 zero pad)
    ptr[0] = 0; // dup-of index = 0
    ptr += 8;

    // slot 2: another real account
    const acc2: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(0xCC),
        .owner = makePubkey(0xDD),
        .lamports = 333,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc2));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    // instruction data: empty
    std.mem.writeInt(u64, ptr[0..8], 0, .little);
}

test "entrypoint: nextAccountMaybe handles dup marker" {
    var input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&input);

    var ctx = InstructionContext.init(&input);
    try std.testing.expectEqual(@as(u64, 3), ctx.remainingAccounts());

    const s0 = try ctx.nextAccountMaybe();
    switch (s0) {
        .account => |a| try std.testing.expectEqual(@as(u64, 777), a.lamports()),
        .duplicated => return error.TestUnexpectedDup,
    }

    const s1 = try ctx.nextAccountMaybe();
    switch (s1) {
        .account => return error.TestExpectedDup,
        .duplicated => |idx| try std.testing.expectEqual(@as(u8, 0), idx),
    }

    const s2 = try ctx.nextAccountMaybe();
    switch (s2) {
        .account => |a| try std.testing.expectEqual(@as(u64, 333), a.lamports()),
        .duplicated => return error.TestUnexpectedDup,
    }

    try std.testing.expectEqual(@as(u64, 0), ctx.remainingAccounts());
}

test "entrypoint: parseAccounts resolves dup back to original" {
    var input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&input);

    var ctx = InstructionContext.init(&input);
    const accs = try ctx.parseAccounts(.{ "owner", "owner_again", "other" });

    // owner and owner_again must refer to the same backing record.
    try std.testing.expectEqual(@intFromPtr(accs.owner.raw), @intFromPtr(accs.owner_again.raw));
    try std.testing.expectEqual(@as(u64, 777), accs.owner_again.lamports());
    try std.testing.expectEqual(@as(u64, 333), accs.other.lamports());
}

test "entrypoint: parseAccountsWith resolves dup and re-applies checks" {
    var input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&input);

    var ctx = InstructionContext.init(&input);
    const accs = try ctx.parseAccountsWith(.{
        .{ "owner", AccountExpectation{ .signer = true, .writable = true } },
        .{ "owner_again", AccountExpectation{ .signer = true, .writable = true } },
        .{ "other", AccountExpectation{} },
    });
    try std.testing.expectEqual(@intFromPtr(accs.owner.raw), @intFromPtr(accs.owner_again.raw));
    try std.testing.expect(accs.owner_again.isSigner());
}

test "entrypoint: skipAccounts is dup-aware" {
    var input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&input);

    var ctx = InstructionContext.init(&input);
    ctx.skipAccounts(2); // skip slot 0 (real) + slot 1 (dup)
    try std.testing.expectEqual(@as(u64, 1), ctx.remainingAccounts());

    const last = ctx.nextAccount().?;
    try std.testing.expectEqual(@as(u64, 333), last.lamports());
}
