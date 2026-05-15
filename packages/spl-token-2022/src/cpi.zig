//! Thin Token-2022 CPI helpers.
//!
//! `instruction.zig` owns the byte-level builders. This module keeps CPI
//! support generic: callers build any Token-2022 instruction with caller-owned
//! metas/data buffers, then pass the matching runtime accounts here.

const std = @import("std");
const sol = @import("solana_program_sdk");
const token_2022_instruction = @import("instruction.zig");

const Pubkey = sol.Pubkey;
const CpiAccountInfo = sol.CpiAccountInfo;
const AccountMeta = sol.cpi.AccountMeta;
const Instruction = sol.cpi.Instruction;
const Signer = sol.cpi.Signer;
const ProgramError = sol.ProgramError;
const ProgramResult = sol.ProgramResult;

pub const InvokeError = ProgramError;

pub fn invokeAccountsArray(comptime child_accounts_len: usize) type {
    return [child_accounts_len + 1]CpiAccountInfo;
}

pub fn invokeAccountsLen(ix: Instruction) ?usize {
    return std.math.add(usize, ix.accounts.len, 1) catch null;
}

pub inline fn instructionWithProgram(ix: Instruction, token_program: CpiAccountInfo) Instruction {
    return .{
        .program_id = token_program.key(),
        .accounts = ix.accounts,
        .data = ix.data,
    };
}

pub fn stageRuntimeAccounts(
    ix: Instruction,
    child_runtime_accounts: []const CpiAccountInfo,
    token_program: CpiAccountInfo,
    invoke_accounts_out: []CpiAccountInfo,
) InvokeError![]const CpiAccountInfo {
    if (child_runtime_accounts.len != ix.accounts.len) return error.InvalidArgument;
    if (invoke_accounts_out.len < child_runtime_accounts.len + 1) return error.InvalidArgument;
    try validateChildRuntimeAccounts(ix.accounts, child_runtime_accounts);

    @memcpy(invoke_accounts_out[0..child_runtime_accounts.len], child_runtime_accounts);
    invoke_accounts_out[child_runtime_accounts.len] = token_program;
    return invoke_accounts_out[0 .. child_runtime_accounts.len + 1];
}

pub fn validatePreparedRuntimeAccounts(
    ix: Instruction,
    invoke_accounts: []const CpiAccountInfo,
    token_program: CpiAccountInfo,
) ProgramResult {
    if (invoke_accounts.len != ix.accounts.len + 1) return error.InvalidArgument;
    try validateChildRuntimeAccounts(ix.accounts, invoke_accounts[0..ix.accounts.len]);
    if (!sol.pubkey.pubkeyEq(invoke_accounts[ix.accounts.len].key(), token_program.key())) {
        return error.InvalidArgument;
    }
}

pub fn invokeInstruction(
    token_program: CpiAccountInfo,
    ix: Instruction,
    child_runtime_accounts: []const CpiAccountInfo,
    invoke_accounts_out: []CpiAccountInfo,
) ProgramResult {
    const branded = instructionWithProgram(ix, token_program);
    const invoke_accounts = try stageRuntimeAccounts(branded, child_runtime_accounts, token_program, invoke_accounts_out);
    try sol.cpi.invokeRaw(&branded, invoke_accounts);
}

pub fn invokeInstructionSigned(
    token_program: CpiAccountInfo,
    ix: Instruction,
    child_runtime_accounts: []const CpiAccountInfo,
    invoke_accounts_out: []CpiAccountInfo,
    signers: []const Signer,
) ProgramResult {
    const branded = instructionWithProgram(ix, token_program);
    const invoke_accounts = try stageRuntimeAccounts(branded, child_runtime_accounts, token_program, invoke_accounts_out);
    try sol.cpi.invokeSignedRaw(&branded, invoke_accounts, signers);
}

pub inline fn invokeInstructionSignedSingle(
    token_program: CpiAccountInfo,
    ix: Instruction,
    child_runtime_accounts: []const CpiAccountInfo,
    invoke_accounts_out: []CpiAccountInfo,
    signer_seeds: anytype,
) ProgramResult {
    const branded = instructionWithProgram(ix, token_program);
    const invoke_accounts = try stageRuntimeAccounts(branded, child_runtime_accounts, token_program, invoke_accounts_out);
    try sol.cpi.invokeSignedSingle(&branded, invoke_accounts, signer_seeds);
}

pub fn invokePrepared(
    token_program: CpiAccountInfo,
    ix: Instruction,
    invoke_accounts: []const CpiAccountInfo,
) ProgramResult {
    const branded = instructionWithProgram(ix, token_program);
    try validatePreparedRuntimeAccounts(branded, invoke_accounts, token_program);
    try sol.cpi.invokeRaw(&branded, invoke_accounts);
}

pub fn invokePreparedSigned(
    token_program: CpiAccountInfo,
    ix: Instruction,
    invoke_accounts: []const CpiAccountInfo,
    signers: []const Signer,
) ProgramResult {
    const branded = instructionWithProgram(ix, token_program);
    try validatePreparedRuntimeAccounts(branded, invoke_accounts, token_program);
    try sol.cpi.invokeSignedRaw(&branded, invoke_accounts, signers);
}

pub inline fn invokePreparedSignedSingle(
    token_program: CpiAccountInfo,
    ix: Instruction,
    invoke_accounts: []const CpiAccountInfo,
    signer_seeds: anytype,
) ProgramResult {
    const branded = instructionWithProgram(ix, token_program);
    try validatePreparedRuntimeAccounts(branded, invoke_accounts, token_program);
    try sol.cpi.invokeSignedSingle(&branded, invoke_accounts, signer_seeds);
}

fn validateChildRuntimeAccounts(
    metas: []const AccountMeta,
    child_runtime_accounts: []const CpiAccountInfo,
) ProgramResult {
    if (child_runtime_accounts.len != metas.len) return error.InvalidArgument;
    for (metas, child_runtime_accounts) |meta, account| {
        if (!sol.pubkey.pubkeyEq(account.key(), meta.pubkey)) return error.InvalidArgument;
    }
}

const TestAccount = struct {
    key: Pubkey,
    lamports: u64 = 0,
    data: [1]u8 = .{0},
    owner: Pubkey = .{0} ** 32,

    fn cpi(self: *TestAccount) CpiAccountInfo {
        return .{
            .key_ptr = &self.key,
            .lamports_ptr = &self.lamports,
            .data_len = self.data.len,
            .data_ptr = self.data[0..].ptr,
            .owner_ptr = &self.owner,
            .rent_epoch = 0,
            .is_signer = 0,
            .is_writable = 0,
            .is_executable = 0,
            ._abi_padding = .{0} ** 5,
        };
    }
};

test "spl-token-2022 cpi: stages runtime accounts and rebrands program id" {
    var token_program: TestAccount = .{ .key = .{0x20} ** 32 };
    var source: TestAccount = .{ .key = .{0x21} ** 32 };
    var mint: TestAccount = .{ .key = .{0x22} ** 32 };
    var destination: TestAccount = .{ .key = .{0x23} ** 32 };
    var authority: TestAccount = .{ .key = .{0x24} ** 32 };

    var metas: token_2022_instruction.metasArray(token_2022_instruction.transfer_checked_spec) = undefined;
    var data: token_2022_instruction.dataArray(token_2022_instruction.transfer_checked_spec) = undefined;
    const ix = token_2022_instruction.transferChecked(
        &source.key,
        &mint.key,
        &destination.key,
        &authority.key,
        500,
        6,
        &metas,
        &data,
    );

    const branded = instructionWithProgram(ix, token_program.cpi());
    try std.testing.expectEqualSlices(u8, &token_program.key, branded.program_id);

    var invoke_accounts: invokeAccountsArray(token_2022_instruction.transfer_checked_spec.accounts_len) = undefined;
    const staged = try stageRuntimeAccounts(
        ix,
        &.{ source.cpi(), mint.cpi(), destination.cpi(), authority.cpi() },
        token_program.cpi(),
        &invoke_accounts,
    );
    try std.testing.expectEqual(@as(usize, 5), staged.len);
    try std.testing.expectEqualSlices(u8, &source.key, staged[0].key());
    try std.testing.expectEqualSlices(u8, &token_program.key, staged[4].key());
    try validatePreparedRuntimeAccounts(ix, staged, token_program.cpi());
}

test "spl-token-2022 cpi: rejects runtime account order mismatch" {
    var token_program: TestAccount = .{ .key = .{0x30} ** 32 };
    var source: TestAccount = .{ .key = .{0x31} ** 32 };
    var mint: TestAccount = .{ .key = .{0x32} ** 32 };
    var destination: TestAccount = .{ .key = .{0x33} ** 32 };
    var authority: TestAccount = .{ .key = .{0x34} ** 32 };

    var metas: token_2022_instruction.metasArray(token_2022_instruction.transfer_checked_spec) = undefined;
    var data: token_2022_instruction.dataArray(token_2022_instruction.transfer_checked_spec) = undefined;
    const ix = token_2022_instruction.transferChecked(
        &source.key,
        &mint.key,
        &destination.key,
        &authority.key,
        1,
        0,
        &metas,
        &data,
    );

    var invoke_accounts: invokeAccountsArray(token_2022_instruction.transfer_checked_spec.accounts_len) = undefined;
    try std.testing.expectError(
        error.InvalidArgument,
        stageRuntimeAccounts(
            ix,
            &.{ mint.cpi(), source.cpi(), destination.cpi(), authority.cpi() },
            token_program.cpi(),
            &invoke_accounts,
        ),
    );
}
