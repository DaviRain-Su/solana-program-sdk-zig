//! System Program CPI wrappers
//!
//! High-level Zig API for common System Program operations.
//!
//! ⚠️ WARNING (Zig 0.16 BPF): Always use stack copies for Program IDs.
//! Module-scope const arrays may be placed at invalid low addresses.

const std = @import("std");
const pubkey = @import("pubkey.zig");
const account_mod = @import("account.zig");
const cpi = @import("cpi.zig");
const program_error = @import("program_error.zig");

const Pubkey = pubkey.Pubkey;
const AccountInfo = account_mod.AccountInfo;
const ProgramResult = program_error.ProgramResult;

/// System Program ID (all zeros)
/// Use getSystemProgramId() to obtain a valid stack copy
pub const SYSTEM_PROGRAM_ID: Pubkey = .{0} ** 32;

/// Write the System Program ID into the provided output buffer
pub fn getSystemProgramId(out: *Pubkey) void {
    out.* = .{0} ** 32;
}

/// Create a new account via System Program CPI
///
/// Accounts:
/// - `from`: signer, writable — pays for the new account
/// - `to`: writable — the account to be created
pub fn createAccount(
    from: AccountInfo,
    to: AccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
) ProgramResult {
    var system_program_id: Pubkey = undefined;
    getSystemProgramId(&system_program_id);

    var ix_data: [52]u8 = undefined;
    @memset(&ix_data, 0);

    // instruction index = 0 (CreateAccount, u32 LE)
    std.mem.writeInt(u32, ix_data[0..4], 0, .little);
    // lamports (u64 LE)
    std.mem.writeInt(u64, ix_data[4..12], lamports, .little);
    // space (u64 LE)
    std.mem.writeInt(u64, ix_data[12..20], space, .little);
    // owner (Pubkey, 32 bytes)
    @memcpy(ix_data[20..52], owner[0..32]);

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = true, .is_signer = true },
        .{ .pubkey = to.key(), .is_writable = true, .is_signer = true },
    };

    const instruction = cpi.Instruction{
        .program_id = &system_program_id,
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invoke(&instruction, &[_]AccountInfo{ from, to });
}

/// Create a new account with PDA signing
pub fn createAccountSigned(
    from: AccountInfo,
    to: AccountInfo,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
    signers_seeds: []const []const u8,
) ProgramResult {
    var system_program_id: Pubkey = undefined;
    getSystemProgramId(&system_program_id);

    var ix_data: [52]u8 = undefined;
    @memset(&ix_data, 0);

    std.mem.writeInt(u32, ix_data[0..4], 0, .little);
    std.mem.writeInt(u64, ix_data[4..12], lamports, .little);
    std.mem.writeInt(u64, ix_data[12..20], space, .little);
    @memcpy(ix_data[20..52], owner[0..32]);

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = true, .is_signer = true },
        .{ .pubkey = to.key(), .is_writable = true, .is_signer = true },
    };

    const instruction = cpi.Instruction{
        .program_id = &system_program_id,
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invokeSigned(&instruction, &[_]AccountInfo{ from, to }, signers_seeds);
}

/// Transfer lamports via System Program CPI
///
/// Accounts:
/// - `from`: signer, writable — source of lamports
/// - `to`: writable — destination for lamports
pub fn transfer(
    from: AccountInfo,
    to: AccountInfo,
    lamports: u64,
) ProgramResult {
    var system_program_id: Pubkey = undefined;
    getSystemProgramId(&system_program_id);

    var ix_data: [12]u8 = undefined;

    // instruction index = 2 (Transfer, u32 LE)
    std.mem.writeInt(u32, ix_data[0..4], 2, .little);
    // amount (u64 LE)
    std.mem.writeInt(u64, ix_data[4..12], lamports, .little);

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = true, .is_signer = true },
        .{ .pubkey = to.key(), .is_writable = true, .is_signer = false },
    };

    const instruction = cpi.Instruction{
        .program_id = &system_program_id,
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invoke(&instruction, &[_]AccountInfo{ from, to });
}

/// Assign a new owner to an account
pub fn assign(
    account: AccountInfo,
    owner: *const Pubkey,
) ProgramResult {
    var system_program_id: Pubkey = undefined;
    getSystemProgramId(&system_program_id);

    var ix_data: [36]u8 = undefined;
    @memset(&ix_data, 0);

    // instruction index = 1 (Assign, u32 LE)
    std.mem.writeInt(u32, ix_data[0..4], 1, .little);
    // owner (Pubkey, 32 bytes)
    @memcpy(ix_data[4..36], owner[0..32]);

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = account.key(), .is_writable = true, .is_signer = true },
    };

    const instruction = cpi.Instruction{
        .program_id = &system_program_id,
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invoke(&instruction, &[_]AccountInfo{account});
}

/// Allocate space in an account
pub fn allocate(
    account: AccountInfo,
    space: u64,
) ProgramResult {
    var system_program_id: Pubkey = undefined;
    getSystemProgramId(&system_program_id);

    var ix_data: [12]u8 = undefined;
    @memset(&ix_data, 0);

    // instruction index = 8 (Allocate, u32 LE)
    std.mem.writeInt(u32, ix_data[0..4], 8, .little);
    // space (u64 LE)
    std.mem.writeInt(u64, ix_data[4..12], space, .little);

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = account.key(), .is_writable = true, .is_signer = true },
    };

    const instruction = cpi.Instruction{
        .program_id = &system_program_id,
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invoke(&instruction, &[_]AccountInfo{account});
}

/// Reallocate space in an account
pub fn realloc(
    account: AccountInfo,
    new_space: u64,
    zero_init: bool,
) ProgramResult {
    var system_program_id: Pubkey = undefined;
    getSystemProgramId(&system_program_id);

    var ix_data: [13]u8 = undefined;
    @memset(&ix_data, 0);

    // instruction index = 11 (ReAlloc, u32 LE)
    std.mem.writeInt(u32, ix_data[0..4], 11, .little);
    // new_space (u64 LE)
    std.mem.writeInt(u64, ix_data[4..12], new_space, .little);
    // zero_init (u8)
    ix_data[12] = if (zero_init) 1 else 0;

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = account.key(), .is_writable = true, .is_signer = true },
    };

    const instruction = cpi.Instruction{
        .program_id = &system_program_id,
        .accounts = &account_metas,
        .data = &ix_data,
    };

    try cpi.invoke(&instruction, &[_]AccountInfo{account});
}

/// Create account with seed
pub fn createAccountWithSeed(
    from: AccountInfo,
    to: AccountInfo,
    base: *const Pubkey,
    seed: []const u8,
    lamports: u64,
    space: u64,
    owner: *const Pubkey,
) ProgramResult {
    var system_program_id: Pubkey = undefined;
    getSystemProgramId(&system_program_id);

    var ix_data: [84]u8 = undefined;
    @memset(&ix_data, 0);

    // instruction index = 3 (CreateAccountWithSeed, u32 LE)
    std.mem.writeInt(u32, ix_data[0..4], 3, .little);
    // base (Pubkey, 32 bytes)
    @memcpy(ix_data[4..36], base[0..32]);
    // seed_len (u64 LE)
    std.mem.writeInt(u64, ix_data[36..44], seed.len, .little);
    // seed (variable length)
    @memcpy(ix_data[44..44 + seed.len], seed);
    // lamports (u64 LE)
    const lamports_offset = 44 + seed.len;
    std.mem.writeInt(u64, ix_data[lamports_offset..][0..8], lamports, .little);
    // space (u64 LE)
    std.mem.writeInt(u64, ix_data[lamports_offset + 8..][0..8], space, .little);
    // owner (Pubkey, 32 bytes)
    @memcpy(ix_data[lamports_offset + 16..][0..32], owner[0..32]);

    const account_metas = [_]cpi.AccountMeta{
        .{ .pubkey = from.key(), .is_writable = true, .is_signer = true },
        .{ .pubkey = to.key(), .is_writable = true, .is_signer = false },
    };

    const instruction = cpi.Instruction{
        .program_id = &system_program_id,
        .accounts = &account_metas,
        .data = ix_data[0 .. 44 + seed.len + 16 + 32],
    };

    try cpi.invoke(&instruction, &[_]AccountInfo{ from, to });
}

// =============================================================================
// Tests
// =============================================================================

test "system: getSystemProgramId" {
    var id: Pubkey = undefined;
    getSystemProgramId(&id);
    const expected: Pubkey = .{0} ** 32;
    try std.testing.expectEqual(expected, id);
}

test "system: instruction data format" {
    var ix_data: [52]u8 = undefined;
    @memset(&ix_data, 0);
    std.mem.writeInt(u32, ix_data[0..4], 0, .little);
    std.mem.writeInt(u64, ix_data[4..12], 500, .little);
    std.mem.writeInt(u64, ix_data[12..20], 128, .little);
    const owner: Pubkey = .{3} ** 32;
    @memcpy(ix_data[20..52], &owner);

    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 500), std.mem.readInt(u64, ix_data[4..12], .little));
    try std.testing.expectEqual(@as(u64, 128), std.mem.readInt(u64, ix_data[12..20], .little));
    try std.testing.expectEqual(owner, ix_data[20..52].*);
}

test "system: transfer instruction data" {
    var ix_data: [12]u8 = undefined;
    std.mem.writeInt(u32, ix_data[0..4], 2, .little);
    std.mem.writeInt(u64, ix_data[4..12], 100, .little);

    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, ix_data[0..4], .little));
    try std.testing.expectEqual(@as(u64, 100), std.mem.readInt(u64, ix_data[4..12], .little));
}
