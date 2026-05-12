//! Instructions sysvar — introspect the currently-executing transaction.
//!
//! Solana exposes the entire transaction's serialized instructions through
//! the `Sysvar1nstructions1111111111111111111111111` account. Reading it
//! lets a program:
//!
//!   - Detect that a specific instruction (e.g. an ed25519 / secp256k1
//!     verification) was included earlier in the same transaction.
//!   - Enforce that a particular instruction MUST appear before / after
//!     ours (sandwich defence, pre-checks).
//!   - Read its own position in the transaction (`current_index`).
//!
//! Unlike Clock / Rent / EpochSchedule, the instructions sysvar has **no**
//! `sol_get_*_sysvar` syscall — the caller must pass the sysvar account
//! into the instruction's account list, and we parse its raw bytes.
//!
//! Wire format (matches `solana-program::sysvar::instructions`):
//! ```
//! [0..2)      u16 LE   num_instructions = N
//! [2..2+2N)   u16 LE[] instruction_offset[i] — start of instruction i
//! ... instructions packed back-to-back ...
//! [len-2..)   u16 LE   current_instruction_index
//! ```
//!
//! Each instruction at `offset[i]`:
//! ```
//! [+0..2)            u16 LE   num_accounts = K
//! repeat K times:
//!   [+0..1)          u8       meta_byte  (bit 0 = is_signer, bit 1 = is_writable)
//!   [+1..33)         [32]u8   pubkey
//! [+33K+2..33K+34)   [32]u8   program_id
//! [+33K+34..33K+36)  u16 LE   data_len = D
//! [+33K+36..)        [D]u8    data
//! ```
//!
//! All multi-byte fields are unaligned little-endian.
//!
//! Cost: O(K + D) byte reads per `loadInstructionAt` (no syscall —
//! just walks the buffer). For programs that already need the sysvar
//! account in their input, the marginal cost is just the parsing.

const std = @import("std");
const pubkey = @import("pubkey.zig");
const account_mod = @import("account.zig");
const program_error = @import("program_error.zig");
const sysvar = @import("sysvar.zig");

const Pubkey = pubkey.Pubkey;
const AccountInfo = account_mod.AccountInfo;
const ProgramError = program_error.ProgramError;

/// Re-export the sysvar ID for convenience.
pub const ID = sysvar.INSTRUCTIONS_ID;

/// View into one instruction parsed from the sysvar.
///
/// Fields point into the sysvar account's data buffer — no copies.
/// `programId()`, `accounts()`, `data()` each fold to a single
/// pointer + bounds compute.
pub const IntrospectedInstruction = struct {
    /// Raw bytes covering exactly this one instruction (`[num_accounts:u16]
    /// [account_metas][program_id][data_len:u16][data]`).
    bytes: []const u8,

    /// Number of `AccountMeta` entries in this instruction.
    pub inline fn numAccounts(self: IntrospectedInstruction) u16 {
        return readU16LE(self.bytes, 0);
    }

    /// Read the i-th account meta.
    pub inline fn account(
        self: IntrospectedInstruction,
        i: usize,
    ) IntrospectedAccountMeta {
        const off = 2 + i * (1 + 32);
        return .{
            .meta_byte = self.bytes[off],
            .pubkey = @ptrCast(self.bytes[off + 1 ..][0..32]),
        };
    }

    /// Iterate the account metas. Returns a slice-like view.
    pub fn accounts(self: IntrospectedInstruction) AccountIterator {
        return .{ .ix = self, .i = 0 };
    }

    /// Pointer to the instruction's program id (32 bytes).
    pub fn programId(self: IntrospectedInstruction) *const Pubkey {
        const k = self.numAccounts();
        const off = 2 + @as(usize, k) * (1 + 32);
        return @ptrCast(self.bytes[off..][0..32]);
    }

    /// Raw instruction data bytes.
    pub fn data(self: IntrospectedInstruction) []const u8 {
        const k = self.numAccounts();
        const off = 2 + @as(usize, k) * (1 + 32) + 32;
        const data_len = readU16LE(self.bytes, off);
        return self.bytes[off + 2 ..][0..data_len];
    }
};

/// A single account-meta entry inside an introspected instruction.
pub const IntrospectedAccountMeta = struct {
    /// Raw meta byte: `bit 0` = is_signer, `bit 1` = is_writable.
    meta_byte: u8,
    /// Pointer to the 32-byte pubkey inside the sysvar buffer.
    pubkey: *const Pubkey,

    pub inline fn isSigner(self: IntrospectedAccountMeta) bool {
        return (self.meta_byte & 0b01) != 0;
    }
    pub inline fn isWritable(self: IntrospectedAccountMeta) bool {
        return (self.meta_byte & 0b10) != 0;
    }
};

/// Lazy iterator over an introspected instruction's account metas.
pub const AccountIterator = struct {
    ix: IntrospectedInstruction,
    i: usize,

    pub fn next(self: *AccountIterator) ?IntrospectedAccountMeta {
        if (self.i >= self.ix.numAccounts()) return null;
        const m = self.ix.account(self.i);
        self.i += 1;
        return m;
    }
};

// =============================================================================
// Public API — mirrors solana-program's `sysvar::instructions` free funcs
// =============================================================================

/// Load the index of the currently-executing instruction within the
/// transaction. The instructions sysvar stores this in its trailing
/// 2 bytes.
///
/// Returns `UnsupportedSysvar` if `info` is not the canonical sysvar
/// account. Mirrors `solana_program::sysvar::instructions::load_current_index_checked`.
pub fn loadCurrentIndexChecked(info: AccountInfo) ProgramError!u16 {
    if (!pubkey.pubkeyEqComptime(info.key(), ID)) {
        return error.UnsupportedSysvar;
    }
    const buf = info.data();
    if (buf.len < 2) return error.InvalidAccountData;
    return readU16LE(buf, buf.len - 2);
}

/// Load the instruction at absolute index `idx` within the
/// transaction. Returns an `IntrospectedInstruction` whose
/// internal pointers reference the sysvar account's data.
///
/// Mirrors `solana_program::sysvar::instructions::load_instruction_at_checked`.
pub fn loadInstructionAtChecked(
    idx: u16,
    info: AccountInfo,
) ProgramError!IntrospectedInstruction {
    if (!pubkey.pubkeyEqComptime(info.key(), ID)) {
        return error.UnsupportedSysvar;
    }
    return deserialize(idx, info.data());
}

/// Load an instruction by **relative** offset from the current
/// instruction. `0` is the current instruction; `-1` is the previous
/// one; `+1` is the next one. Returns `InvalidArgument` on under/overflow.
///
/// Mirrors `solana_program::sysvar::instructions::get_instruction_relative`.
pub fn getInstructionRelative(
    relative: i64,
    info: AccountInfo,
) ProgramError!IntrospectedInstruction {
    const current = try loadCurrentIndexChecked(info);
    const target_i64 = @as(i64, @intCast(current)) + relative;
    if (target_i64 < 0) {
        return program_error.fail("sysvar_ix:relative_underflow", error.InvalidArgument);
    }
    const target: u16 = @intCast(target_i64);
    return deserialize(target, info.data());
}

// =============================================================================
// Internal — wire-format reader
// =============================================================================

fn readU16LE(buf: []const u8, off: usize) u16 {
    // Bounds-check elided when callers verified earlier — common case
    // since the sysvar buffer is non-empty + length-prefixed.
    return std.mem.readInt(u16, buf[off..][0..2], .little);
}

fn deserialize(idx: u16, data: []const u8) ProgramError!IntrospectedInstruction {
    if (data.len < 2) return error.InvalidAccountData;
    const num_instructions = readU16LE(data, 0);
    if (idx >= num_instructions) {
        return program_error.fail("sysvar_ix:index_out_of_range", error.InvalidArgument);
    }

    // Read the offset of instruction `idx` from the table at byte 2.
    const offset_table = 2 + @as(usize, idx) * 2;
    if (offset_table + 2 > data.len) return error.InvalidAccountData;
    const ix_start = readU16LE(data, offset_table);
    if (ix_start + 2 > data.len) return error.InvalidAccountData;

    // Walk the instruction to find its total size so we can hand back
    // a tight slice.
    var cursor: usize = ix_start;
    const num_accounts = readU16LE(data, cursor);
    cursor += 2;
    // Each account meta = 1 (meta_byte) + 32 (pubkey).
    cursor += @as(usize, num_accounts) * (1 + 32);
    if (cursor + 32 > data.len) return error.InvalidAccountData; // program_id
    cursor += 32;
    if (cursor + 2 > data.len) return error.InvalidAccountData;
    const data_len = readU16LE(data, cursor);
    cursor += 2;
    if (cursor + data_len > data.len) return error.InvalidAccountData;
    const ix_end = cursor + data_len;

    return .{ .bytes = data[ix_start..ix_end] };
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

/// Build a synthetic instructions-sysvar payload for unit tests.
/// Mirrors the Rust `construct_instructions_data` exactly.
fn buildSysvarPayload(
    comptime instructions: []const TestInstruction,
    current_index: u16,
) []u8 {
    const allocator = std.testing.allocator;
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    // num_instructions
    buf.appendSlice(std.mem.asBytes(&@as(u16, @intCast(instructions.len)))) catch unreachable;
    // offset table (filled in below)
    for (instructions) |_| {
        buf.appendSlice(&[_]u8{ 0, 0 }) catch unreachable;
    }

    for (instructions, 0..) |ix, i| {
        const start: u16 = @intCast(buf.items.len);
        const table_offset = 2 + i * 2;
        @memcpy(buf.items[table_offset..][0..2], std.mem.asBytes(&start));

        buf.appendSlice(std.mem.asBytes(&@as(u16, @intCast(ix.accounts.len)))) catch unreachable;
        for (ix.accounts) |a| {
            const flags: u8 =
                (if (a.is_signer) @as(u8, 0b01) else 0) |
                (if (a.is_writable) @as(u8, 0b10) else 0);
            buf.append(flags) catch unreachable;
            buf.appendSlice(&a.pubkey) catch unreachable;
        }
        buf.appendSlice(&ix.program_id) catch unreachable;
        buf.appendSlice(std.mem.asBytes(&@as(u16, @intCast(ix.data.len)))) catch unreachable;
        buf.appendSlice(ix.data) catch unreachable;
    }

    // current index trailer
    buf.appendSlice(std.mem.asBytes(&current_index)) catch unreachable;

    return buf.toOwnedSlice() catch unreachable;
}

const TestAccount = struct {
    pubkey: Pubkey,
    is_signer: bool,
    is_writable: bool,
};
const TestInstruction = struct {
    program_id: Pubkey,
    accounts: []const TestAccount,
    data: []const u8,
};

test "sysvar_instructions: deserialize single instruction round-trip" {
    const pid = [_]u8{0x11} ** 32;
    const k1 = [_]u8{0x22} ** 32;
    const ixs = [_]TestInstruction{
        .{
            .program_id = pid,
            .accounts = &.{
                .{ .pubkey = k1, .is_signer = true, .is_writable = false },
            },
            .data = &.{ 0xde, 0xad, 0xbe, 0xef },
        },
    };
    const buf = buildSysvarPayload(&ixs, 0);
    defer std.testing.allocator.free(buf);

    const parsed = try deserialize(0, buf);
    try testing.expectEqual(@as(u16, 1), parsed.numAccounts());

    const meta = parsed.account(0);
    try testing.expect(meta.isSigner());
    try testing.expect(!meta.isWritable());
    try testing.expectEqualSlices(u8, &k1, meta.pubkey);

    try testing.expectEqualSlices(u8, &pid, parsed.programId());
    try testing.expectEqualSlices(u8, &.{ 0xde, 0xad, 0xbe, 0xef }, parsed.data());
}

test "sysvar_instructions: deserialize index out of bounds → InvalidArgument" {
    const pid = [_]u8{0x33} ** 32;
    const ixs = [_]TestInstruction{
        .{ .program_id = pid, .accounts = &.{}, .data = &.{} },
    };
    const buf = buildSysvarPayload(&ixs, 0);
    defer std.testing.allocator.free(buf);

    try testing.expectError(error.InvalidArgument, deserialize(1, buf));
}

test "sysvar_instructions: multi-instruction layout" {
    const pid_a = [_]u8{0xa1} ** 32;
    const pid_b = [_]u8{0xb2} ** 32;
    const acc = [_]u8{0xcc} ** 32;
    const ixs = [_]TestInstruction{
        .{
            .program_id = pid_a,
            .accounts = &.{.{ .pubkey = acc, .is_signer = false, .is_writable = true }},
            .data = &.{ 0x01, 0x02 },
        },
        .{
            .program_id = pid_b,
            .accounts = &.{},
            .data = &.{ 0xff, 0xee, 0xdd },
        },
    };
    const buf = buildSysvarPayload(&ixs, 1);
    defer std.testing.allocator.free(buf);

    const second = try deserialize(1, buf);
    try testing.expectEqualSlices(u8, &pid_b, second.programId());
    try testing.expectEqual(@as(u16, 0), second.numAccounts());
    try testing.expectEqualSlices(u8, &.{ 0xff, 0xee, 0xdd }, second.data());

    const first = try deserialize(0, buf);
    try testing.expectEqualSlices(u8, &pid_a, first.programId());
    var it = first.accounts();
    const m = it.next().?;
    try testing.expect(!m.isSigner());
    try testing.expect(m.isWritable());
}

test "sysvar_instructions: current index trailer" {
    const pid = [_]u8{0x99} ** 32;
    const ixs = [_]TestInstruction{
        .{ .program_id = pid, .accounts = &.{}, .data = &.{} },
        .{ .program_id = pid, .accounts = &.{}, .data = &.{} },
        .{ .program_id = pid, .accounts = &.{}, .data = &.{} },
    };
    const buf = buildSysvarPayload(&ixs, 2);
    defer std.testing.allocator.free(buf);

    // Read trailer directly — `loadCurrentIndexChecked` would also
    // verify the account key, which we can't synthesise without a
    // full AccountInfo here.
    const idx = readU16LE(buf, buf.len - 2);
    try testing.expectEqual(@as(u16, 2), idx);
}
