//! Solana program entrypoint — InstructionContext (Pinocchio-style)
//!
//! Single entrypoint design: on-demand account parsing via InstructionContext.
//! Accounts returned as `AccountInfo` (8-byte pointer wrapper).
//!
//! Matches Pinocchio `lazy_program_entrypoint!` exactly.

const std = @import("std");
const account = @import("account/root.zig");
const account_cursor = @import("account_cursor.zig");
const pubkey = @import("pubkey.zig");
const program_error = @import("program_error.zig");
const error_code = @import("error_code.zig");
const instruction_mod = @import("instruction.zig");

const Account = account.Account;
const AccountInfo = account.AccountInfo;
const AccountCursor = account_cursor.AccountCursor;
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

inline fn validateExpectedAccount(
    acc: AccountInfo,
    comptime name: []const u8,
    comptime exp: AccountExpectation,
) ProgramError!void {
    if (comptime exp.signer and exp.writable) {
        const flags_ptr: *align(1) const u16 = @ptrCast(&acc.raw.is_signer);
        if (flags_ptr.* != 0x0101) {
            if (!acc.isSigner()) {
                return program_error.fail(
                    @src(),
                    "parse:" ++ name ++ ":not_signer",
                    error.MissingRequiredSignature,
                );
            }
            return program_error.fail(
                @src(),
                "parse:" ++ name ++ ":not_writable",
                error.ImmutableAccount,
            );
        }
    } else {
        if (comptime exp.signer) {
            if (!acc.isSigner()) {
                return program_error.fail(
                    @src(),
                    "parse:" ++ name ++ ":not_signer",
                    error.MissingRequiredSignature,
                );
            }
        }
        if (comptime exp.writable) {
            if (!acc.isWritable()) {
                return program_error.fail(
                    @src(),
                    "parse:" ++ name ++ ":not_writable",
                    error.ImmutableAccount,
                );
            }
        }
    }

    if (comptime exp.executable) {
        if (!acc.executable()) {
            return program_error.fail(
                @src(),
                "parse:" ++ name ++ ":not_executable",
                error.InvalidAccountData,
            );
        }
    }
    if (comptime exp.owner != null) {
        const expected_owner = exp.owner.?;
        if (!acc.isOwnedByComptime(expected_owner)) {
            return program_error.fail(
                @src(),
                "parse:" ++ name ++ ":wrong_owner",
                error.IncorrectProgramId,
            );
        }
    }
    if (comptime exp.key != null) {
        const expected_key = exp.key.?;
        if (!pubkey.pubkeyEqComptime(acc.key(), expected_key)) {
            return program_error.fail(
                @src(),
                "parse:" ++ name ++ ":key_mismatch",
                error.InvalidArgument,
            );
        }
    }
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

    inline fn nextResolvedAccount(
        self: *InstructionContext,
        comptime seen_len: usize,
        seen: *const [seen_len]AccountInfo,
    ) ProgramError!AccountInfo {
        if (self.remaining == 0) return error.NotEnoughAccountKeys;
        self.remaining -= 1;
        return self.nextResolvedAccountUnchecked(seen_len, seen);
    }

    inline fn nextResolvedAccountUnchecked(
        self: *InstructionContext,
        comptime seen_len: usize,
        seen: *const [seen_len]AccountInfo,
    ) AccountInfo {
        const account_ptr: *account.Account = @ptrCast(@alignCast(self.buffer));

        if (account_ptr.borrow_state == account.NON_DUP_MARKER) {
            const acc: AccountInfo = .{ .raw = account_ptr };
            const data_len: usize = @intCast(account_ptr.data_len);
            self.buffer += @sizeOf(u64) + (@sizeOf(Account) - @sizeOf(u64)) + data_len + MAX_PERMITTED_DATA_INCREASE;
            self.buffer = @ptrFromInt(alignPointer(@intFromPtr(self.buffer)));
            self.buffer += @sizeOf(u64);
            return acc;
        }

        const idx = account_ptr.borrow_state;
        self.buffer += @sizeOf(u64);
        return seen[idx];
    }

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

    /// Create an `AccountCursor` over the remaining serialized account
    /// slots. Use this on a fresh context for the full instruction
    /// account list, or after fixed parsing when duplicate references
    /// cannot target accounts outside the remaining range.
    pub inline fn accountCursor(self: *const InstructionContext) ProgramError!AccountCursor {
        return AccountCursor.initRemaining(self.buffer, self.remaining, &.{});
    }

    /// Create an `AccountCursor` over the remaining account range while
    /// seeding already-parsed earlier accounts. This lets duplicate
    /// markers in the remaining range resolve back to fixed accounts
    /// that were consumed before the cursor was created.
    pub inline fn accountCursorWithPrefix(
        self: *const InstructionContext,
        prefix: []const AccountInfo,
    ) ProgramError!AccountCursor {
        return AccountCursor.initRemaining(self.buffer, self.remaining, prefix);
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
        if (self.remaining > 0) {
            return program_error.fail(
                @src(),
                "ctx:accounts_not_consumed",
                error.InvalidInstructionData,
            );
        }
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
        if (self.remaining > 0) {
            return program_error.fail(
                @src(),
                "ctx:accounts_not_consumed",
                error.InvalidInstructionData,
            );
        }
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
        const ptr: *align(1) const T = @ptrCast(@alignCast(self.buffer + @sizeOf(u64) + offset));
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
        const ptr: *align(1) const T = @ptrCast(@alignCast(self.buffer + @sizeOf(u64)));
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

    /// Require at least `min_len` bytes of ix-data.
    ///
    /// Useful for fixed-layout dispatchers that want one explicit bounds
    /// check up front, then raw `readIx*` loads for the hot path.
    pub inline fn requireIxDataLen(
        self: *const InstructionContext,
        comptime min_len: usize,
    ) ProgramError!void {
        if (unlikely(self.remaining > 0)) {
            return program_error.fail(
                @src(),
                "ctx:accounts_not_consumed",
                error.InvalidInstructionData,
            );
        }
        return self.requireIxDataLenUnchecked(min_len);
    }

    /// Same as `requireIxDataLen`, but skips the `remaining == 0` check.
    pub inline fn requireIxDataLenUnchecked(
        self: *const InstructionContext,
        comptime min_len: usize,
    ) ProgramError!void {
        const data_len: usize = @intCast(@as(*const u64, @ptrCast(@alignCast(self.buffer))).*);
        if (unlikely(data_len < min_len)) {
            return error.InvalidInstructionData;
        }
    }

    /// Bind an extern-struct instruction-data view in one step.
    ///
    /// Compared to `try instructionData()` + `IxDataReader(T).bind(...)`,
    /// this folds the "accounts consumed" and "buffer large enough" checks
    /// into a single helper while still returning the same zero-copy typed view.
    pub inline fn bindIxData(
        self: *const InstructionContext,
        comptime T: type,
    ) ProgramError!instruction_mod.IxDataReader(T) {
        try self.requireIxDataLen(@sizeOf(T));
        return self.bindIxDataUnchecked(T);
    }

    /// Same as `bindIxData`, but skips the `remaining == 0` check.
    /// Caller asserts the buffer is already positioned at ix-data.
    pub inline fn bindIxDataUnchecked(
        self: *const InstructionContext,
        comptime T: type,
    ) ProgramError!instruction_mod.IxDataReader(T) {
        try self.requireIxDataLenUnchecked(@sizeOf(T));
        const bytes = self.buffer[@sizeOf(u64) .. @sizeOf(u64) + @sizeOf(T)];
        return instruction_mod.IxDataReader(T).bindUnchecked(bytes);
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
        if (self.remaining < names.len) return error.NotEnoughAccountKeys;
        self.remaining -= @intCast(names.len);

        const T = ParsedAccounts(names);
        var out: T = undefined;
        // Dup-aware: walk the slot list with a single upfront account-count
        // check, then resolve duplicates against the already-seen accounts.
        var seen: [names.len]AccountInfo = undefined;
        inline for (names, 0..) |name, i| {
            const acc = self.nextResolvedAccountUnchecked(names.len, &seen);
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
        if (self.remaining < spec.len) return error.NotEnoughAccountKeys;
        self.remaining -= @intCast(spec.len);

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

            const acc = self.nextResolvedAccountUnchecked(spec.len, &seen);
            seen[i] = acc;

            try validateExpectedAccount(acc, name, exp);
            @field(out, name) = acc;
        }
        return out;
    }

    /// Like `parseAccountsWith`, but skips duplicate-account
    /// resolution entirely. Use this when the account roles are
    /// structurally unique yet you still want comptime-validated
    /// signer/writable/owner/key checks.
    ///
    /// This is the validated fast path: it keeps the same expectation
    /// checks as `parseAccountsWith`, but walks the input with
    /// `nextAccountUnchecked()` instead of the dup-aware
    /// `nextAccountMaybe()` tagged union.
    ///
    /// Prefer this over `parseAccountsUnchecked` + ad-hoc checks when:
    ///   - account roles are unique by construction, and
    ///   - you want the SDK to keep emitting the canonical failure
    ///     variants (`MissingRequiredSignature`, `ImmutableAccount`,
    ///     `IncorrectProgramId`, ...).
    ///
    /// If duplicate accounts are possible and semantically valid for
    /// the instruction, use the safe `parseAccountsWith` instead.
    pub inline fn parseAccountsWithUnchecked(
        self: *InstructionContext,
        comptime spec: anytype,
    ) ProgramError!ParsedAccountsWith(spec) {
        if (self.remaining < spec.len) return error.NotEnoughAccountKeys;
        self.remaining -= @intCast(spec.len);

        const T = ParsedAccountsWith(spec);
        var out: T = undefined;
        inline for (spec) |entry| {
            const name = entry[0];
            const exp: AccountExpectation = entry[1];
            const acc = self.nextAccountUnchecked();

            try validateExpectedAccount(acc, name, exp);
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
    /// Expected owner program ID (comptime constant). Comptime
    /// compare uses 4 u64-immediate cmps — no rodata lookup.
    owner: ?Pubkey = null,
    /// Expected pubkey (comptime constant). Useful for asserting an
    /// account is exactly a well-known sysvar / system program /
    /// pre-derived PDA. Same comptime-immediate compare as `owner`.
    key: ?Pubkey = null,
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

// =========================================================================
// programEntrypoint — eager-parse entrypoint (ergonomic alternative)
//
// Pre-parses a comptime-known account count and instruction data into
// a flat array, then hands everything to user `process` in one call.
//
// Performance: **measurably tied with lazyEntrypoint** under
// ReleaseFast. The benchmark `program_entry_1` vs `program_entry_lazy_1`
// shows a 1-CU difference (in either direction depending on the body).
// LLVM aggressively optimizes the lazy path so there's no real
// throughput win here — pick this entrypoint for **ergonomic
// reasons** (positional `accounts[0]` access, no InstructionContext
// indirection, account count enforced at the entrypoint level so
// per-handler bounds checks are unnecessary), not for CU savings.
//
// Trade-offs vs. lazyEntrypoint:
//   + Account count enforced at the entry boundary — handlers can
//     index `accounts[i]` without bounds checks.
//   + No `try ctx.parseAccountsUnchecked(...)` boilerplate at the
//     top of `process`.
//   + Cleaner signature: `(accounts, data, program_id)`.
//   - Requires the account count to be known at compile time. For
//     dispatch patterns where account count varies between
//     instructions, use `lazyEntrypoint` and `parseAccountsUnchecked`.
//
// All accounts MUST be non-duplicate slots (i.e. distinct positions
// in the transaction). If your program may receive duplicate accounts,
// use lazyEntrypoint + `nextAccountMaybe`.
// =========================================================================

/// Parse exactly `account_count` non-duplicate accounts plus the
/// instruction data and program id, then call
/// `process(accounts, data, program_id)`.
///
/// CU cost is essentially identical to `lazyEntrypoint` +
/// `parseAccountsUnchecked` — choose based on style preference, not
/// performance. (Measured 1-CU swing in the
/// `benchmark_program_entry_*` micro-benches.)
///
/// Usage:
/// ```zig
/// fn process(
///     accounts: *const [3]sol.AccountInfo,
///     data: []const u8,
///     _: *const sol.Pubkey,
/// ) sol.ProgramResult {
///     try accounts[0].expectSigner();
///     // ...
/// }
///
/// export fn entrypoint(input: [*]u8) u64 {
///     return sol.entrypoint.programEntrypoint(3, process)(input);
/// }
/// ```
///
/// Returns `error.NotEnoughAccountKeys` if the runtime serialized
/// fewer accounts than `account_count`. Programs whose account count
/// differs across instructions should use `lazyEntrypoint` instead.
pub fn programEntrypoint(
    comptime account_count: usize,
    comptime process: *const fn (
        accounts: *const [account_count]AccountInfo,
        data: []const u8,
        program_id: *const Pubkey,
    ) ProgramResult,
) fn ([*]u8) callconv(.c) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.c) u64 {
            // First 8 bytes: num_accounts (u64 LE).
            const num_accounts: u64 = @as(*const u64, @ptrCast(@alignCast(input))).*;
            if (num_accounts < account_count) {
                return program_error.errorToU64(error.NotEnoughAccountKeys);
            }

            var accounts: [account_count]AccountInfo = undefined;
            var buf: [*]u8 = input + @sizeOf(u64);

            // Unrolled at comptime — the loop body is straight-line BPF
            // assembly with `i` baked into the array store index.
            inline for (0..account_count) |i| {
                const account_ptr: *Account = @ptrCast(@alignCast(buf));
                const data_len: usize = @intCast(account_ptr.data_len);
                buf += @sizeOf(u64) + (@sizeOf(Account) - @sizeOf(u64)) + data_len + MAX_PERMITTED_DATA_INCREASE;
                buf = @ptrFromInt(alignPointer(@intFromPtr(buf)));
                buf += @sizeOf(u64);
                accounts[i] = .{ .raw = account_ptr };
            }

            // After `account_count` accounts the buffer points at the
            // instruction-data length prefix.
            const data_len: usize = @intCast(@as(*const u64, @ptrCast(@alignCast(buf))).*);
            const data: []const u8 = buf[@sizeOf(u64) .. @sizeOf(u64) + data_len];
            const program_id: *const Pubkey = @ptrCast(@alignCast(buf + @sizeOf(u64) + data_len));

            process(&accounts, data, program_id) catch |err| {
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

/// `lazyEntrypoint` variant for handlers that return `ErrCode.Error!void`.
///
/// Use this when you have an `ErrorCode(MyEnum)` and want to preserve
/// the custom u32 discriminator on the wire while keeping `try`
/// ergonomics:
///
/// ```zig
/// const VaultErr = sol.ErrorCode(enum(u32) { Unauthorized = 6000, Overflow });
///
/// fn process(ctx: *InstructionContext) VaultErr.Error!void {
///     try sol.system.transfer(...);                       // ProgramError
///     if (bad) return VaultErr.toError(.Unauthorized);    // custom code
/// }
///
/// export fn entrypoint(input: [*]u8) u64 {
///     return sol.entrypoint.lazyEntrypointTyped(VaultErr, process)(input);
/// }
/// ```
///
/// Why not mutable globals: the SBPFv2 loader rejects `.bss` /
/// `.data`, so we can't stash a `u32` discriminator alongside a
/// generic `error.Custom`. Instead `ErrorCode(E)` synthesises a
/// unique error name per enum variant; the entrypoint's `catch`
/// dispatches on the name to recover the `u32` code.
///
/// Cost: zero CU on the happy path. The error-path dispatch is an
/// `inline for` over the variants (cold).
pub fn lazyEntrypointTyped(
    comptime ErrCode: type,
    comptime process: *const fn (*InstructionContext) ErrCode.Error!void,
) fn ([*]u8) callconv(.c) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.c) u64 {
            var context = InstructionContext.init(input);
            process(&context) catch |err| return ErrCode.catchToU64(err);
            return SUCCESS;
        }
    }.entry;
}

/// `programEntrypoint` variant for handlers that return `ErrCode.Error!void`.
/// See `lazyEntrypointTyped` for the rationale.
pub fn programEntrypointTyped(
    comptime account_count: usize,
    comptime ErrCode: type,
    comptime process: *const fn (
        accounts: *const [account_count]AccountInfo,
        data: []const u8,
        program_id: *const Pubkey,
    ) ErrCode.Error!void,
) fn ([*]u8) callconv(.c) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.c) u64 {
            const num_accounts: u64 = @as(*const u64, @ptrCast(@alignCast(input))).*;
            if (num_accounts < account_count) {
                return program_error.errorToU64(error.NotEnoughAccountKeys);
            }

            var accounts: [account_count]AccountInfo = undefined;
            var buf: [*]u8 = input + @sizeOf(u64);

            inline for (0..account_count) |i| {
                const account_ptr: *Account = @ptrCast(@alignCast(buf));
                const data_len: usize = @intCast(account_ptr.data_len);
                buf += @sizeOf(u64) + (@sizeOf(Account) - @sizeOf(u64)) + data_len + MAX_PERMITTED_DATA_INCREASE;
                buf = @ptrFromInt(alignPointer(@intFromPtr(buf)));
                buf += @sizeOf(u64);
                accounts[i] = .{ .raw = account_ptr };
            }

            const data_len: usize = @intCast(@as(*const u64, @ptrCast(@alignCast(buf))).*);
            const data: []const u8 = buf[@sizeOf(u64) .. @sizeOf(u64) + data_len];
            const program_id: *const Pubkey = @ptrCast(@alignCast(buf + @sizeOf(u64) + data_len));

            process(&accounts, data, program_id) catch |err| return ErrCode.catchToU64(err);
            return SUCCESS;
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

test "entrypoint: ErrorCode catch path emits correct wire codes" {
    const Demo = enum(u32) { First = 6000, Second = 6042 };
    const DemoErr = error_code.ErrorCode(Demo, error{ First, Second });

    try std.testing.expectEqual(@as(u64, 6042), DemoErr.catchToU64(error.Second));
    try std.testing.expectEqual(@as(u64, 6000), DemoErr.catchToU64(error.First));
    try std.testing.expectEqual(
        program_error.errorToU64(error.InvalidArgument),
        DemoErr.catchToU64(error.InvalidArgument),
    );
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

test "entrypoint: parseAccountsWith — key match passes" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 0, makePubkey(3), 0, 0);

    var ctx = InstructionContext.init(&input);
    // acc0.key = makePubkey(1) per buildTwoAccountInput.
    const accs = try ctx.parseAccountsWith(.{
        .{ "from", AccountExpectation{ .key = comptime makePubkey(1) } },
        .{ "to", AccountExpectation{} },
    });
    _ = accs;
}

test "entrypoint: parseAccountsWith — key mismatch fails" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 0, makePubkey(3), 0, 0);

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.InvalidArgument,
        ctx.parseAccountsWith(.{
            .{ "from", AccountExpectation{ .key = comptime makePubkey(99) } },
            .{ "to", AccountExpectation{} },
        }),
    );
}

test "entrypoint: requireIxDataLen validates minimum ix-data length" {
    var input align(8) = [_]u8{0} ** 128;
    std.mem.writeInt(u64, input[0..8], 0, .little); // num_accounts
    std.mem.writeInt(u64, input[8..16], 12, .little); // ix_data_len

    var ctx = InstructionContext.init(&input);
    try ctx.requireIxDataLen(12);
    try std.testing.expectError(error.InvalidInstructionData, ctx.requireIxDataLen(13));
}

test "entrypoint: requireIxDataLen rejects unconsumed accounts" {
    var input align(8) = [_]u8{0} ** 128;
    std.mem.writeInt(u64, input[0..8], 1, .little); // num_accounts
    std.mem.writeInt(u64, input[8..16], 12, .little); // ix_data_len

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(error.InvalidInstructionData, ctx.requireIxDataLen(12));
}

test "entrypoint: bindIxData returns typed ix reader" {
    var input align(8) = [_]u8{0} ** 128;
    std.mem.writeInt(u64, input[0..8], 0, .little); // num_accounts
    std.mem.writeInt(u64, input[8..16], 16, .little); // ix_data_len
    std.mem.writeInt(u32, input[16..20], 7, .little);
    std.mem.writeInt(u64, input[20..28], 42, .little);

    const Args = extern struct {
        tag: u32 align(1),
        amount: u64 align(1),
    };

    var ctx = InstructionContext.init(&input);
    const args = try ctx.bindIxData(Args);
    try std.testing.expectEqual(@as(u32, 7), args.get(.tag));
    try std.testing.expectEqual(@as(u64, 42), args.get(.amount));

    std.mem.writeInt(u64, input[8..16], 4, .little);
    var short_ctx = InstructionContext.init(&input);
    try std.testing.expectError(error.InvalidInstructionData, short_ctx.bindIxData(Args));
}

test "entrypoint: bindIxData rejects unconsumed accounts" {
    var input align(8) = [_]u8{0} ** 128;
    std.mem.writeInt(u64, input[0..8], 1, .little); // num_accounts
    std.mem.writeInt(u64, input[8..16], 16, .little); // ix_data_len

    const Args = extern struct {
        tag: u32 align(1),
        amount: u64 align(1),
    };

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(error.InvalidInstructionData, ctx.bindIxData(Args));
}

test "entrypoint: parseAccountsWithUnchecked — happy path" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 1, 1, makePubkey(99), 0, 1);

    var ctx = InstructionContext.init(&input);
    const accs = try ctx.parseAccountsWithUnchecked(.{
        .{ "from", AccountExpectation{ .signer = true, .writable = true } },
        .{ "to", AccountExpectation{ .writable = true } },
    });
    try std.testing.expect(accs.from.isSigner());
    try std.testing.expect(accs.to.isWritable());
    try std.testing.expectEqual(@as(u64, 0), ctx.remaining);
    const ix = try ctx.instructionData();
    try std.testing.expectEqual(@as(usize, 0), ix.len);
}

test "entrypoint: parseAccountsWithUnchecked errors when too few accounts" {
    var input align(8) = [_]u8{0} ** 256;
    std.mem.writeInt(u64, input[0..8], 0, .little);
    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.NotEnoughAccountKeys,
        ctx.parseAccountsWithUnchecked(.{
            .{ "a", AccountExpectation{} },
            .{ "b", AccountExpectation{} },
        }),
    );
}

test "entrypoint: parseAccountsWithUnchecked — missing signer" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 1, makePubkey(99), 0, 1);

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.MissingRequiredSignature,
        ctx.parseAccountsWithUnchecked(.{
            .{ "from", AccountExpectation{ .signer = true } },
            .{ "to", AccountExpectation{} },
        }),
    );
}

test "entrypoint: parseAccountsWithUnchecked — not writable" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 1, 0, makePubkey(99), 0, 1);

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.ImmutableAccount,
        ctx.parseAccountsWithUnchecked(.{
            .{ "from", AccountExpectation{ .writable = true } },
            .{ "to", AccountExpectation{} },
        }),
    );
}

test "entrypoint: parseAccountsWithUnchecked — wrong owner" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 0, makePubkey(1), 0, 0);

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.IncorrectProgramId,
        ctx.parseAccountsWithUnchecked(.{
            .{ "from", AccountExpectation{ .owner = comptime makePubkey(99) } },
            .{ "to", AccountExpectation{} },
        }),
    );
}

test "entrypoint: parseAccountsWithUnchecked — key mismatch fails" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 0, 0, makePubkey(3), 0, 0);

    var ctx = InstructionContext.init(&input);
    try std.testing.expectError(
        error.InvalidArgument,
        ctx.parseAccountsWithUnchecked(.{
            .{ "from", AccountExpectation{ .key = comptime makePubkey(99) } },
            .{ "to", AccountExpectation{} },
        }),
    );
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

fn buildInputWithNonAdjacentDup(buf: *[32768]u8) void {
    @memset(buf, 0);
    var ptr: [*]u8 = buf;

    std.mem.writeInt(u64, ptr[0..8], 4, .little);
    ptr += 8;

    const acc0: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 1,
        .is_writable = 1,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(0x11),
        .owner = makePubkey(0x21),
        .lamports = 11,
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
        .key = makePubkey(0x12),
        .owner = makePubkey(0x22),
        .lamports = 22,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc1));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    ptr[0] = 0;
    ptr += 8;

    const acc3: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(0x13),
        .owner = makePubkey(0x23),
        .lamports = 33,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc3));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

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

// =========================================================================
// AccountCursor tests
// =========================================================================

test "entrypoint: accountCursor supports full and remaining sources" {
    var input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&input);

    var full_ctx = InstructionContext.init(&input);
    var full_cursor = try full_ctx.accountCursor();
    try std.testing.expectEqual(@as(usize, 0), full_cursor.nextIndex());
    try std.testing.expectEqual(@as(u64, 3), full_cursor.remainingAccounts());

    const first = try full_cursor.takeOne();
    try std.testing.expectEqual(@as(u64, 777), first.lamports());
    try std.testing.expectEqual(@as(usize, 1), full_cursor.nextIndex());

    const full_peek = try full_cursor.peek();
    try std.testing.expectEqual(@intFromPtr(first.raw), @intFromPtr(full_peek.raw));
    try std.testing.expectEqual(@as(u64, 2), full_cursor.remainingAccounts());

    var remaining_ctx = InstructionContext.init(&input);
    const fixed = try remaining_ctx.parseAccounts(.{"authority"});
    var remaining_cursor = try remaining_ctx.accountCursorWithPrefix(&.{fixed.authority});
    try std.testing.expectEqual(@as(usize, 1), remaining_cursor.nextIndex());
    try std.testing.expectEqual(@as(u64, 2), remaining_cursor.remainingAccounts());

    const remaining_peek = try remaining_cursor.peek();
    try std.testing.expectEqual(
        @intFromPtr(fixed.authority.raw),
        @intFromPtr(remaining_peek.raw),
    );

    const window = try remaining_cursor.takeWindow(2);
    try std.testing.expectEqual(@as(usize, 2), window.len());
    try std.testing.expectEqual(@intFromPtr(fixed.authority.raw), @intFromPtr(window.at(0).raw));
    try std.testing.expectEqual(@as(u64, 333), window.at(1).lamports());
    try std.testing.expectEqual(@as(u64, 0), remaining_cursor.remainingAccounts());
}

test "entrypoint: accountCursor takeOne peek and skip are all-or-nothing" {
    var input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&input, 1, 1, makePubkey(9), 0, 1);

    var ctx = InstructionContext.init(&input);
    var cursor = try ctx.accountCursor();

    const first = try cursor.takeOne();
    try std.testing.expectEqual(@as(u8, 1), first.key()[0]);
    try std.testing.expectEqual(@as(u64, 1), cursor.remainingAccounts());

    const peek_a = try cursor.peek();
    const peek_b = try cursor.peek();
    const peek_c = try cursor.peek();
    try std.testing.expectEqual(@intFromPtr(peek_a.raw), @intFromPtr(peek_b.raw));
    try std.testing.expectEqual(@intFromPtr(peek_a.raw), @intFromPtr(peek_c.raw));
    try std.testing.expectEqual(@as(u64, 1), cursor.remainingAccounts());

    try std.testing.expectError(error.NotEnoughAccountKeys, cursor.skip(2));
    try std.testing.expectEqual(@as(u64, 1), cursor.remainingAccounts());

    const second = try cursor.takeOne();
    try std.testing.expectEqual(@intFromPtr(peek_a.raw), @intFromPtr(second.raw));
    try std.testing.expectEqual(@as(u64, 0), cursor.remainingAccounts());
    try std.testing.expectError(error.NotEnoughAccountKeys, cursor.takeOne());
    try std.testing.expectError(error.NotEnoughAccountKeys, cursor.peek());
}

test "entrypoint: accountCursor windows stay ordered and stable after parent advances" {
    var input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&input);

    var ctx = InstructionContext.init(&input);
    var cursor = try ctx.accountCursor();

    const empty = try cursor.takeWindow(0);
    try std.testing.expectEqual(@as(usize, 0), empty.len());
    try std.testing.expectEqual(@as(u64, 3), cursor.remainingAccounts());

    const window = try cursor.takeWindow(2);
    try std.testing.expectEqual(@as(usize, 2), window.len());
    try std.testing.expectEqual(@as(u64, 777), window.at(0).lamports());
    try std.testing.expectEqual(@as(u64, 777), window.at(1).lamports());

    const tail = try cursor.takeOne();
    try std.testing.expectEqual(@as(u64, 333), tail.lamports());
    try std.testing.expectEqual(@as(usize, 2), window.len());
    try std.testing.expectEqual(@as(u64, 777), window.at(0).lamports());
    try std.testing.expectEqual(@as(u64, 777), window.at(1).lamports());

    var count: usize = 0;
    var sum: u64 = 0;
    var it = window.iterator();
    while (it.next()) |acc| {
        count += 1;
        sum += acc.lamports();
    }
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(@as(u64, 1_554), sum);
}

test "entrypoint: accountCursor duplicate policies and assume-unique path behave as specified" {
    var dup_input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&dup_input);

    var dup_ctx = InstructionContext.init(&dup_input);
    var dup_cursor = try dup_ctx.accountCursor();
    try std.testing.expectError(
        error.InvalidArgument,
        dup_cursor.takeWindowWithPolicy(2, .reject),
    );
    try std.testing.expectEqual(@as(u64, 3), dup_cursor.remainingAccounts());
    try std.testing.expectEqual(@as(u64, 777), (try dup_cursor.takeOne()).lamports());

    var unique_input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&unique_input, 1, 1, makePubkey(9), 0, 1);

    var safe_ctx = InstructionContext.init(&unique_input);
    var safe_cursor = try safe_ctx.accountCursor();
    const safe_window = try safe_cursor.takeWindow(2);

    var unique_ctx = InstructionContext.init(&unique_input);
    var unique_cursor = try unique_ctx.accountCursor();
    const unique_window = try unique_cursor.takeWindowAssumeUnique(2);

    try std.testing.expectEqual(@as(usize, safe_window.len()), unique_window.len());
    inline for (0..2) |i| {
        try std.testing.expectEqual(
            @intFromPtr(safe_window.at(i).raw),
            @intFromPtr(unique_window.at(i).raw),
        );
    }
    try std.testing.expectEqual(safe_cursor.nextIndex(), unique_cursor.nextIndex());
    try std.testing.expectEqual(safe_cursor.remainingAccounts(), unique_cursor.remainingAccounts());
}

test "entrypoint: accountCursor safe skip and reject duplicate windows stay aligned" {
    var adjacent_input: [32768]u8 align(8) = undefined;
    buildInputWithDup(&adjacent_input);

    var adjacent_ctx = InstructionContext.init(&adjacent_input);
    var adjacent_cursor = try adjacent_ctx.accountCursor();
    try adjacent_cursor.skip(2);
    try std.testing.expectEqual(@as(u64, 1), adjacent_cursor.remainingAccounts());
    try std.testing.expectEqual(@as(u64, 333), (try adjacent_cursor.takeOne()).lamports());

    var spaced_input: [32768]u8 align(8) = undefined;
    buildInputWithNonAdjacentDup(&spaced_input);

    var reject_ctx = InstructionContext.init(&spaced_input);
    var reject_cursor = try reject_ctx.accountCursor();
    try std.testing.expectError(
        error.InvalidArgument,
        reject_cursor.takeWindowWithPolicy(3, .reject),
    );
    try std.testing.expectEqual(@as(u64, 4), reject_cursor.remainingAccounts());

    var allow_ctx = InstructionContext.init(&spaced_input);
    var allow_cursor = try allow_ctx.accountCursor();
    const allow_window = try allow_cursor.takeWindow(3);
    try std.testing.expectEqual(@as(usize, 3), allow_window.len());
    try std.testing.expectEqual(@intFromPtr(allow_window.at(0).raw), @intFromPtr(allow_window.at(2).raw));
    try std.testing.expectEqual(@as(u64, 1), allow_cursor.remainingAccounts());
    try std.testing.expectEqual(@as(u64, 33), (try allow_cursor.takeOne()).lamports());
}

test "entrypoint: accountCursor validation maps canonical errors and rolls back" {
    var signer_input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&signer_input, 0, 1, makePubkey(9), 1, 1);
    var signer_ctx = InstructionContext.init(&signer_input);
    var signer_cursor = try signer_ctx.accountCursor();
    try std.testing.expectError(
        error.MissingRequiredSignature,
        signer_cursor.takeWindowValidated(1, .allow, .{ .writable = true, .signer = true }),
    );
    try std.testing.expectEqual(@as(u64, 2), signer_cursor.remainingAccounts());
    try std.testing.expectEqual(@as(u8, 1), (try signer_cursor.takeOne()).key()[0]);

    var writable_input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&writable_input, 1, 0, makePubkey(9), 1, 1);
    var writable_ctx = InstructionContext.init(&writable_input);
    var writable_cursor = try writable_ctx.accountCursor();
    try std.testing.expectError(
        error.ImmutableAccount,
        writable_cursor.takeWindowValidated(1, .allow, .{ .signer = true, .writable = true }),
    );

    var executable_input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&executable_input, 1, 1, makePubkey(9), 1, 1);
    var executable_ctx = InstructionContext.init(&executable_input);
    var executable_cursor = try executable_ctx.accountCursor();
    try std.testing.expectError(
        error.InvalidAccountData,
        executable_cursor.takeWindowValidated(1, .allow, .{ .executable = true }),
    );

    var owner_input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&owner_input, 1, 1, makePubkey(9), 1, 1);
    var owner_ctx = InstructionContext.init(&owner_input);
    var owner_cursor = try owner_ctx.accountCursor();
    try std.testing.expectError(
        error.IncorrectProgramId,
        owner_cursor.takeWindowValidated(1, .allow, .{ .owner = comptime makePubkey(77) }),
    );

    var key_input: [32768]u8 align(8) = undefined;
    buildTwoAccountInput(&key_input, 1, 1, makePubkey(9), 1, 1);
    var key_ctx = InstructionContext.init(&key_input);
    var key_cursor = try key_ctx.accountCursor();
    try std.testing.expectError(
        error.InvalidArgument,
        key_cursor.takeWindowValidated(1, .allow, .{ .key = comptime makePubkey(77) }),
    );
}

// =========================================================================
// programEntrypoint tests
// =========================================================================
//
// We exercise programEntrypoint directly by constructing a serialized
// input buffer (same shape the runtime hands the BPF program) and
// calling the closure it returns. Since we're on the host, the test
// runs in plain native code — there's no BPF runtime emulation here.

// A scratch buffer for the test process function to record what it saw.
var test_observed_count: usize = 0;
var test_observed_lamports: [4]u64 = .{ 0, 0, 0, 0 };
var test_observed_data: [16]u8 = .{0} ** 16;
var test_observed_data_len: usize = 0;

fn testProcess2(
    accounts: *const [2]AccountInfo,
    data: []const u8,
    _: *const Pubkey,
) ProgramResult {
    test_observed_count = 2;
    test_observed_lamports[0] = accounts[0].lamports();
    test_observed_lamports[1] = accounts[1].lamports();
    test_observed_data_len = data.len;
    @memcpy(test_observed_data[0..data.len], data);
    return;
}

test "entrypoint: programEntrypoint parses 2 accounts + ix data" {
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
        .key = makePubkey(1),
        .owner = makePubkey(2),
        .lamports = 12345,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc0));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    const acc1: Account = .{
        .borrow_state = account.NON_DUP_MARKER,
        .is_signer = 0,
        .is_writable = 0,
        .is_executable = 0,
        ._padding = .{0} ** 4,
        .key = makePubkey(3),
        .owner = makePubkey(2),
        .lamports = 67890,
        .data_len = 0,
    };
    @memcpy(ptr[0..@sizeOf(Account)], std.mem.asBytes(&acc1));
    ptr += @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE + 8;

    // instruction data: "hello" (5 bytes)
    std.mem.writeInt(u64, ptr[0..8], 5, .little);
    ptr += 8;
    @memcpy(ptr[0..5], "hello");
    ptr += 5;
    // program id (just zeros; we don't inspect it)
    ptr += @sizeOf(Pubkey);

    test_observed_count = 0;
    test_observed_data_len = 0;

    const entry = programEntrypoint(2, testProcess2);
    const result = entry(&input);

    try std.testing.expectEqual(SUCCESS, result);
    try std.testing.expectEqual(@as(usize, 2), test_observed_count);
    try std.testing.expectEqual(@as(u64, 12345), test_observed_lamports[0]);
    try std.testing.expectEqual(@as(u64, 67890), test_observed_lamports[1]);
    try std.testing.expectEqualStrings("hello", test_observed_data[0..test_observed_data_len]);
}

fn testProcess3Noop(
    _: *const [3]AccountInfo,
    _: []const u8,
    _: *const Pubkey,
) ProgramResult {
    return;
}

test "entrypoint: programEntrypoint errors on too-few accounts" {
    var input align(8) = [_]u8{0} ** 32768;
    // num_accounts = 1, but we request 3
    std.mem.writeInt(u64, input[0..8], 1, .little);
    const entry = programEntrypoint(3, testProcess3Noop);
    const result = entry(&input);
    // NotEnoughAccountKeys
    try std.testing.expect(result != SUCCESS);
}
