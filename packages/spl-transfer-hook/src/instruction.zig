//! SPL Transfer Hook instruction builders and parsers.

const std = @import("std");
const sol = @import("solana_program_sdk");

const Pubkey = sol.Pubkey;
const AccountMeta = sol.cpi.AccountMeta;
const Instruction = sol.cpi.Instruction;
const ProgramError = sol.ProgramError;

pub const NAMESPACE = "spl-transfer-hook-interface";
pub const EXECUTE_DISCRIMINATOR = sol.discriminator.computeWithNamespace(NAMESPACE ++ ":", "execute");

pub const Spec = struct {
    accounts_len: usize,
    data_len: usize,
};

pub const execute_spec: Spec = .{
    .accounts_len = 4,
    .data_len = 16,
};

pub const execute_with_extra_account_metas_prefix_len: usize = 5;

pub const ExecuteMetas = [execute_spec.accounts_len]AccountMeta;
pub const ExecuteData = [execute_spec.data_len]u8;

pub const Execute = struct {
    amount: u64,
};

pub const TransferHookInstruction = union(enum) {
    execute: Execute,

    pub fn unpack(input: []const u8) ProgramError!TransferHookInstruction {
        if (input.len != execute_spec.data_len) return ProgramError.InvalidInstructionData;

        var discriminator: [sol.DISCRIMINATOR_LEN]u8 = undefined;
        @memcpy(&discriminator, input[0..sol.DISCRIMINATOR_LEN]);
        if (!sol.discriminator.eq(&discriminator, &EXECUTE_DISCRIMINATOR)) {
            return ProgramError.InvalidInstructionData;
        }

        const amount = sol.instruction.tryReadUnaligned(
            u64,
            input,
            sol.DISCRIMINATOR_LEN,
        ) orelse return ProgramError.InvalidInstructionData;
        return .{ .execute = .{ .amount = amount } };
    }
};

pub const ExecuteWithExtraAccountMetasError = error{
    InvalidAccountMetaSliceLength,
};

pub inline fn executeAccountMetasLenWithExtraAccountMetas(extra_accounts_len: usize) usize {
    return execute_with_extra_account_metas_prefix_len + extra_accounts_len;
}

fn encodeExecuteData(amount: u64) ExecuteData {
    var data: ExecuteData = undefined;
    @memcpy(data[0..sol.DISCRIMINATOR_LEN], &EXECUTE_DISCRIMINATOR);
    std.mem.writeInt(u64, data[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u64)], amount, .little);
    return data;
}

pub fn execute(
    program_id: *const Pubkey,
    source_pubkey: *const Pubkey,
    mint_pubkey: *const Pubkey,
    destination_pubkey: *const Pubkey,
    authority_pubkey: *const Pubkey,
    amount: u64,
    metas: *ExecuteMetas,
    data: *ExecuteData,
) Instruction {
    metas.* = .{
        AccountMeta.readonly(source_pubkey),
        AccountMeta.readonly(mint_pubkey),
        AccountMeta.readonly(destination_pubkey),
        AccountMeta.readonly(authority_pubkey),
    };
    data.* = encodeExecuteData(amount);
    return Instruction.init(program_id, metas, data);
}

pub fn executeWithExtraAccountMetas(
    program_id: *const Pubkey,
    source_pubkey: *const Pubkey,
    mint_pubkey: *const Pubkey,
    destination_pubkey: *const Pubkey,
    authority_pubkey: *const Pubkey,
    validate_state_pubkey: *const Pubkey,
    additional_accounts: []const AccountMeta,
    amount: u64,
    metas: []AccountMeta,
    data: *ExecuteData,
) ExecuteWithExtraAccountMetasError!Instruction {
    const expected_len = executeAccountMetasLenWithExtraAccountMetas(additional_accounts.len);
    if (metas.len != expected_len) return error.InvalidAccountMetaSliceLength;

    metas[0] = AccountMeta.readonly(source_pubkey);
    metas[1] = AccountMeta.readonly(mint_pubkey);
    metas[2] = AccountMeta.readonly(destination_pubkey);
    metas[3] = AccountMeta.readonly(authority_pubkey);
    metas[4] = AccountMeta.readonly(validate_state_pubkey);
    for (additional_accounts, 0..) |account_meta, i| {
        metas[execute_with_extra_account_metas_prefix_len + i] = account_meta;
    }

    data.* = encodeExecuteData(amount);
    return Instruction.init(program_id, metas, data);
}

fn expectMeta(
    actual: AccountMeta,
    expected_key: *const Pubkey,
    expected_writable: u8,
    expected_signer: u8,
) !void {
    try std.testing.expectEqual(expected_key, actual.pubkey);
    try std.testing.expectEqual(expected_writable, actual.is_writable);
    try std.testing.expectEqual(expected_signer, actual.is_signer);
}

test "Execute spec and discriminator are canonical" {
    try std.testing.expectEqual(@as(usize, 4), execute_spec.accounts_len);
    try std.testing.expectEqual(@as(usize, 16), execute_spec.data_len);
    try std.testing.expectEqual(@as(usize, 5), execute_with_extra_account_metas_prefix_len);
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 105, 37, 101, 197, 75, 251, 102, 26 },
        &EXECUTE_DISCRIMINATOR,
    );
}

test "Execute builder emits exact 16-byte discriminator + LE amount payload" {
    const program_id: Pubkey = .{0x01} ** 32;
    const source: Pubkey = .{0x11} ** 32;
    const mint: Pubkey = .{0x22} ** 32;
    const destination: Pubkey = .{0x33} ** 32;
    const authority: Pubkey = .{0x44} ** 32;

    const cases = [_]struct {
        amount: u64,
        expected: [16]u8,
    }{
        .{
            .amount = 0,
            .expected = .{ 105, 37, 101, 197, 75, 251, 102, 26, 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        .{
            .amount = 1,
            .expected = .{ 105, 37, 101, 197, 75, 251, 102, 26, 1, 0, 0, 0, 0, 0, 0, 0 },
        },
        .{
            .amount = 111_111_111,
            .expected = .{ 105, 37, 101, 197, 75, 251, 102, 26, 199, 107, 159, 6, 0, 0, 0, 0 },
        },
        .{
            .amount = std.math.maxInt(u64),
            .expected = .{ 105, 37, 101, 197, 75, 251, 102, 26, 255, 255, 255, 255, 255, 255, 255, 255 },
        },
    };

    inline for (cases) |case| {
        var metas: ExecuteMetas = undefined;
        var data: ExecuteData = undefined;
        const ix = execute(
            &program_id,
            &source,
            &mint,
            &destination,
            &authority,
            case.amount,
            &metas,
            &data,
        );

        try std.testing.expectEqual(@as(usize, 16), ix.data.len);
        try std.testing.expectEqual(@intFromPtr(&data[0]), @intFromPtr(ix.data.ptr));
        try std.testing.expectEqualSlices(u8, &case.expected, ix.data);

        const parsed = try TransferHookInstruction.unpack(ix.data);
        try std.testing.expectEqual(TransferHookInstruction{ .execute = .{ .amount = case.amount } }, parsed);
    }
}

test "Execute parser rejects short unknown truncated and overlong payloads" {
    inline for (0..8) |len| {
        const short = [_]u8{0} ** len;
        try std.testing.expectError(sol.ProgramError.InvalidInstructionData, TransferHookInstruction.unpack(&short));
    }

    try std.testing.expectError(
        sol.ProgramError.InvalidInstructionData,
        TransferHookInstruction.unpack(&[_]u8{0} ** 16),
    );
    try std.testing.expectError(
        sol.ProgramError.InvalidInstructionData,
        TransferHookInstruction.unpack(&[_]u8{0xff} ** 16),
    );

    const valid = [_]u8{ 105, 37, 101, 197, 75, 251, 102, 26, 42, 0, 0, 0, 0, 0, 0, 0 };

    var mutated = valid;
    mutated[7] ^= 1;
    try std.testing.expectError(sol.ProgramError.InvalidInstructionData, TransferHookInstruction.unpack(&mutated));
    try std.testing.expectError(sol.ProgramError.InvalidInstructionData, TransferHookInstruction.unpack(valid[0..15]));

    var overlong: [17]u8 = undefined;
    @memcpy(overlong[0..16], &valid);
    overlong[16] = 0xaa;
    try std.testing.expectError(sol.ProgramError.InvalidInstructionData, TransferHookInstruction.unpack(&overlong));
}

test "Execute builder emits canonical base accounts and caller-owned scratch" {
    const program_id: Pubkey = .{0x55} ** 32;
    const source: Pubkey = .{0x66} ** 32;
    const mint: Pubkey = .{0x77} ** 32;
    const destination: Pubkey = .{0x88} ** 32;
    const authority: Pubkey = .{0x99} ** 32;

    var metas: ExecuteMetas = undefined;
    var data: ExecuteData = undefined;
    const ix = execute(
        &program_id,
        &source,
        &mint,
        &destination,
        &authority,
        9,
        &metas,
        &data,
    );

    try std.testing.expectEqual(&program_id, ix.program_id);
    try std.testing.expectEqual(@as(usize, 4), ix.accounts.len);
    try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix.accounts.ptr));
    try expectMeta(ix.accounts[0], &source, 0, 0);
    try expectMeta(ix.accounts[1], &mint, 0, 0);
    try expectMeta(ix.accounts[2], &destination, 0, 0);
    try expectMeta(ix.accounts[3], &authority, 0, 0);
}

test "Execute with validation and extra metas preserves canonical ordering and flags" {
    const program_id: Pubkey = .{0xa1} ** 32;
    const source: Pubkey = .{0xb2} ** 32;
    const mint: Pubkey = .{0xc3} ** 32;
    const destination: Pubkey = .{0xd4} ** 32;
    const authority: Pubkey = .{0xe5} ** 32;
    const validation: Pubkey = .{0xf6} ** 32;
    const extra_a: Pubkey = .{0x10} ** 32;
    const extra_b: Pubkey = .{0x20} ** 32;
    const extra_c: Pubkey = .{0x30} ** 32;

    const extra_accounts = [_]AccountMeta{
        AccountMeta.writable(&extra_a),
        AccountMeta.signer(&extra_b),
        AccountMeta.signerWritable(&extra_c),
    };

    var metas: [execute_with_extra_account_metas_prefix_len + extra_accounts.len]AccountMeta = undefined;
    var data: ExecuteData = undefined;
    const ix = try executeWithExtraAccountMetas(
        &program_id,
        &source,
        &mint,
        &destination,
        &authority,
        &validation,
        &extra_accounts,
        123,
        metas[0..],
        &data,
    );

    try std.testing.expectEqual(&program_id, ix.program_id);
    try std.testing.expectEqual(@as(usize, 8), ix.accounts.len);
    try std.testing.expectEqual(@intFromPtr(&metas[0]), @intFromPtr(ix.accounts.ptr));
    try expectMeta(ix.accounts[0], &source, 0, 0);
    try expectMeta(ix.accounts[1], &mint, 0, 0);
    try expectMeta(ix.accounts[2], &destination, 0, 0);
    try expectMeta(ix.accounts[3], &authority, 0, 0);
    try expectMeta(ix.accounts[4], &validation, 0, 0);
    try expectMeta(ix.accounts[5], &extra_a, 1, 0);
    try expectMeta(ix.accounts[6], &extra_b, 0, 1);
    try expectMeta(ix.accounts[7], &extra_c, 1, 1);
}

test "Execute APIs stay caller-buffer-backed and allocator-free" {
    const execute_info = @typeInfo(@TypeOf(execute)).@"fn";
    try std.testing.expectEqual(@as(usize, 8), execute_info.params.len);
    try std.testing.expect(execute_info.params[0].type.? == *const Pubkey);
    try std.testing.expect(execute_info.params[1].type.? == *const Pubkey);
    try std.testing.expect(execute_info.params[2].type.? == *const Pubkey);
    try std.testing.expect(execute_info.params[3].type.? == *const Pubkey);
    try std.testing.expect(execute_info.params[4].type.? == *const Pubkey);
    try std.testing.expect(execute_info.params[5].type.? == u64);
    try std.testing.expect(execute_info.params[6].type.? == *ExecuteMetas);
    try std.testing.expect(execute_info.params[7].type.? == *ExecuteData);

    const with_extra_info = @typeInfo(@TypeOf(executeWithExtraAccountMetas)).@"fn";
    try std.testing.expectEqual(@as(usize, 10), with_extra_info.params.len);
    try std.testing.expect(with_extra_info.params[0].type.? == *const Pubkey);
    try std.testing.expect(with_extra_info.params[1].type.? == *const Pubkey);
    try std.testing.expect(with_extra_info.params[2].type.? == *const Pubkey);
    try std.testing.expect(with_extra_info.params[3].type.? == *const Pubkey);
    try std.testing.expect(with_extra_info.params[4].type.? == *const Pubkey);
    try std.testing.expect(with_extra_info.params[5].type.? == *const Pubkey);
    try std.testing.expect(with_extra_info.params[6].type.? == []const AccountMeta);
    try std.testing.expect(with_extra_info.params[7].type.? == u64);
    try std.testing.expect(with_extra_info.params[8].type.? == []AccountMeta);
    try std.testing.expect(with_extra_info.params[9].type.? == *ExecuteData);
}
