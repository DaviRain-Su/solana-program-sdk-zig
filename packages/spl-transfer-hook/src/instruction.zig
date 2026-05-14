//! SPL Transfer Hook instruction builders and parsers.

const std = @import("std");
const sol = @import("solana_program_sdk");
const codec = @import("solana_codec");
const meta = @import("meta.zig");

const Pubkey = sol.Pubkey;
const AccountMeta = sol.cpi.AccountMeta;
const Instruction = sol.cpi.Instruction;
const ProgramError = sol.ProgramError;
const ExtraAccountMeta = meta.ExtraAccountMeta;
const ExtraAccountMetaSlice = meta.ExtraAccountMetaSlice;

pub const NAMESPACE = "spl-transfer-hook-interface";
pub const EXECUTE_DISCRIMINATOR = sol.discriminator.computeWithNamespace(NAMESPACE ++ ":", "execute");
pub const INITIALIZE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR = sol.discriminator.computeWithNamespace(
    NAMESPACE ++ ":",
    "initialize-extra-account-metas",
);
pub const UPDATE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR = sol.discriminator.computeWithNamespace(
    NAMESPACE ++ ":",
    "update-extra-account-metas",
);

pub const Spec = struct {
    accounts_len: usize,
    data_len: usize,
};

pub const execute_spec: Spec = .{
    .accounts_len = 4,
    .data_len = 16,
};
pub const initialize_extra_account_meta_list_accounts_len: usize = 4;
pub const update_extra_account_meta_list_accounts_len: usize = 3;
pub const extra_account_meta_list_header_len: usize = sol.DISCRIMINATOR_LEN + @sizeOf(u32);
pub const execute_with_extra_account_metas_prefix_len: usize = 5;

pub const ExecuteMetas = [execute_spec.accounts_len]AccountMeta;
pub const ExecuteData = [execute_spec.data_len]u8;
pub const InitializeExtraAccountMetaListMetas = [initialize_extra_account_meta_list_accounts_len]AccountMeta;
pub const UpdateExtraAccountMetaListMetas = [update_extra_account_meta_list_accounts_len]AccountMeta;

pub const Execute = struct {
    amount: u64,
};

pub const ExtraAccountMetaList = struct {
    extra_account_metas: ExtraAccountMetaSlice,
};

pub const TransferHookInstruction = union(enum) {
    execute: Execute,
    initialize_extra_account_meta_list: ExtraAccountMetaList,
    update_extra_account_meta_list: ExtraAccountMetaList,

    pub fn unpack(input: []const u8) ProgramError!TransferHookInstruction {
        if (input.len < sol.DISCRIMINATOR_LEN) return ProgramError.InvalidInstructionData;

        const discriminator = input[0..sol.DISCRIMINATOR_LEN];
        const payload = input[sol.DISCRIMINATOR_LEN..];

        if (std.mem.eql(u8, discriminator, &EXECUTE_DISCRIMINATOR)) {
            if (input.len != execute_spec.data_len) return ProgramError.InvalidInstructionData;

            const amount = sol.instruction.tryReadUnaligned(
                u64,
                input,
                sol.DISCRIMINATOR_LEN,
            ) orelse return ProgramError.InvalidInstructionData;
            return .{ .execute = .{ .amount = amount } };
        }

        if (std.mem.eql(u8, discriminator, &INITIALIZE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR)) {
            return .{
                .initialize_extra_account_meta_list = .{
                    .extra_account_metas = try unpackExtraAccountMetaList(payload),
                },
            };
        }

        if (std.mem.eql(u8, discriminator, &UPDATE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR)) {
            return .{
                .update_extra_account_meta_list = .{
                    .extra_account_metas = try unpackExtraAccountMetaList(payload),
                },
            };
        }

        return ProgramError.InvalidInstructionData;
    }
};

pub const ExecuteWithExtraAccountMetasError = error{
    InvalidAccountMetaSliceLength,
};

pub const ExtraAccountMetaListBuilderError = error{
    InvalidInstructionDataSliceLength,
    TooManyExtraAccountMetas,
};

pub inline fn executeAccountMetasLenWithExtraAccountMetas(extra_accounts_len: usize) usize {
    return execute_with_extra_account_metas_prefix_len + extra_accounts_len;
}

pub inline fn extraAccountMetaListDataLen(extra_account_metas_len: usize) usize {
    return extra_account_meta_list_header_len + (extra_account_metas_len * meta.EXTRA_ACCOUNT_META_LEN);
}

fn encodeExecuteData(amount: u64) ExecuteData {
    var data: ExecuteData = undefined;
    @memcpy(data[0..sol.DISCRIMINATOR_LEN], &EXECUTE_DISCRIMINATOR);
    std.mem.writeInt(u64, data[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u64)], amount, .little);
    return data;
}

fn unpackExtraAccountMetaList(payload: []const u8) ProgramError!ExtraAccountMetaSlice {
    if (payload.len < @sizeOf(u32)) return ProgramError.InvalidInstructionData;

    const count = (codec.readBorshU32(payload) catch return ProgramError.InvalidInstructionData).value;
    const records = payload[@sizeOf(u32)..];
    const expected_records_len = std.math.mul(usize, @as(usize, count), meta.EXTRA_ACCOUNT_META_LEN) catch return ProgramError.InvalidInstructionData;
    if (records.len != expected_records_len) return ProgramError.InvalidInstructionData;

    return ExtraAccountMetaSlice.init(records);
}

fn encodeExtraAccountMetaListData(
    discriminator: *const [sol.DISCRIMINATOR_LEN]u8,
    extra_account_metas: []const ExtraAccountMeta,
    data: []u8,
) ExtraAccountMetaListBuilderError!void {
    if (extra_account_metas.len > std.math.maxInt(u32)) return error.TooManyExtraAccountMetas;

    const expected_len = extraAccountMetaListDataLen(extra_account_metas.len);
    if (data.len != expected_len) return error.InvalidInstructionDataSliceLength;

    @memcpy(data[0..sol.DISCRIMINATOR_LEN], discriminator);
    _ = codec.writeBorshU32(data[sol.DISCRIMINATOR_LEN..], @intCast(extra_account_metas.len)) catch unreachable;

    var cursor: usize = extra_account_meta_list_header_len;
    for (extra_account_metas) |extra_account_meta| {
        extra_account_meta.write(data[cursor..][0..meta.EXTRA_ACCOUNT_META_LEN]);
        cursor += meta.EXTRA_ACCOUNT_META_LEN;
    }
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

pub fn initializeExtraAccountMetaList(
    program_id: *const Pubkey,
    extra_account_metas_pubkey: *const Pubkey,
    mint_pubkey: *const Pubkey,
    authority_pubkey: *const Pubkey,
    extra_account_metas: []const ExtraAccountMeta,
    metas: *InitializeExtraAccountMetaListMetas,
    data: []u8,
) ExtraAccountMetaListBuilderError!Instruction {
    metas.* = .{
        AccountMeta.writable(extra_account_metas_pubkey),
        AccountMeta.readonly(mint_pubkey),
        AccountMeta.signer(authority_pubkey),
        AccountMeta.readonly(&sol.system_program_id),
    };
    try encodeExtraAccountMetaListData(
        &INITIALIZE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR,
        extra_account_metas,
        data,
    );
    return Instruction.init(program_id, metas, data);
}

pub fn updateExtraAccountMetaList(
    program_id: *const Pubkey,
    extra_account_metas_pubkey: *const Pubkey,
    mint_pubkey: *const Pubkey,
    authority_pubkey: *const Pubkey,
    extra_account_metas: []const ExtraAccountMeta,
    metas: *UpdateExtraAccountMetaListMetas,
    data: []u8,
) ExtraAccountMetaListBuilderError!Instruction {
    metas.* = .{
        AccountMeta.writable(extra_account_metas_pubkey),
        AccountMeta.readonly(mint_pubkey),
        AccountMeta.signer(authority_pubkey),
    };
    try encodeExtraAccountMetaListData(
        &UPDATE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR,
        extra_account_metas,
        data,
    );
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

fn expectExtraAccountMeta(actual: ExtraAccountMeta, expected: ExtraAccountMeta) !void {
    try std.testing.expectEqual(expected.discriminator, actual.discriminator);
    try std.testing.expectEqualSlices(u8, &expected.address_config, &actual.address_config);
    try std.testing.expectEqual(expected.is_signer, actual.is_signer);
    try std.testing.expectEqual(expected.is_writable, actual.is_writable);
}

fn expectFixtureMeta(actual: AccountMeta, expected: anytype) !void {
    try std.testing.expectEqualSlices(u8, &expected.pubkey, actual.pubkey[0..]);
    try std.testing.expectEqual(expected.is_writable, actual.is_writable);
    try std.testing.expectEqual(expected.is_signer, actual.is_signer);
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

test "Initialize and update discriminators and account lengths are canonical" {
    try std.testing.expectEqual(@as(usize, 4), initialize_extra_account_meta_list_accounts_len);
    try std.testing.expectEqual(@as(usize, 3), update_extra_account_meta_list_accounts_len);
    try std.testing.expectEqual(@as(usize, 12), extraAccountMetaListDataLen(0));
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 43, 34, 13, 49, 167, 88, 235, 235 },
        &INITIALIZE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR,
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 157, 105, 42, 146, 102, 85, 241, 174 },
        &UPDATE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR,
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

test "Initialize/update builders and parser round-trip raw extra-account-meta payloads" {
    const program_id: Pubkey = .{0x11} ** 32;
    const validation: Pubkey = .{0x22} ** 32;
    const mint: Pubkey = .{0x33} ** 32;
    const authority: Pubkey = .{0x44} ** 32;
    const extra_a: Pubkey = .{0x55} ** 32;
    const extra_b: Pubkey = .{0x66} ** 32;

    const extra_account_metas = [_]ExtraAccountMeta{
        ExtraAccountMeta.fixed(&extra_a, false, true),
        ExtraAccountMeta.fixed(&extra_b, true, false),
    };

    var initialize_metas: InitializeExtraAccountMetaListMetas = undefined;
    var initialize_data: [extraAccountMetaListDataLen(extra_account_metas.len)]u8 = undefined;
    const initialize_ix = try initializeExtraAccountMetaList(
        &program_id,
        &validation,
        &mint,
        &authority,
        &extra_account_metas,
        &initialize_metas,
        initialize_data[0..],
    );

    try std.testing.expectEqual(&program_id, initialize_ix.program_id);
    try std.testing.expectEqual(@as(usize, 4), initialize_ix.accounts.len);
    try expectMeta(initialize_ix.accounts[0], &validation, 1, 0);
    try expectMeta(initialize_ix.accounts[1], &mint, 0, 0);
    try expectMeta(initialize_ix.accounts[2], &authority, 0, 1);
    try expectMeta(initialize_ix.accounts[3], &sol.system_program_id, 0, 0);

    const initialize_parsed = try TransferHookInstruction.unpack(initialize_ix.data);
    switch (initialize_parsed) {
        .initialize_extra_account_meta_list => |parsed| {
            try std.testing.expectEqual(extra_account_metas.len, parsed.extra_account_metas.len());
            try expectExtraAccountMeta(extra_account_metas[0], try parsed.extra_account_metas.get(0));
            try expectExtraAccountMeta(extra_account_metas[1], try parsed.extra_account_metas.get(1));
        },
        else => return error.TestUnexpectedResult,
    }

    var update_metas: UpdateExtraAccountMetaListMetas = undefined;
    var update_data: [extraAccountMetaListDataLen(extra_account_metas.len)]u8 = undefined;
    const update_ix = try updateExtraAccountMetaList(
        &program_id,
        &validation,
        &mint,
        &authority,
        &extra_account_metas,
        &update_metas,
        update_data[0..],
    );

    try std.testing.expectEqual(&program_id, update_ix.program_id);
    try std.testing.expectEqual(@as(usize, 3), update_ix.accounts.len);
    try expectMeta(update_ix.accounts[0], &validation, 1, 0);
    try expectMeta(update_ix.accounts[1], &mint, 0, 0);
    try expectMeta(update_ix.accounts[2], &authority, 0, 1);

    const update_parsed = try TransferHookInstruction.unpack(update_ix.data);
    switch (update_parsed) {
        .update_extra_account_meta_list => |parsed| {
            try std.testing.expectEqual(extra_account_metas.len, parsed.extra_account_metas.len());
            try expectExtraAccountMeta(extra_account_metas[0], try parsed.extra_account_metas.get(0));
            try expectExtraAccountMeta(extra_account_metas[1], try parsed.extra_account_metas.get(1));
        },
        else => return error.TestUnexpectedResult,
    }
}

test "Initialize/update parser rejects truncated and mismatched extra-account-meta payloads" {
    const empty_init = [_]u8{ 43, 34, 13, 49, 167, 88, 235, 235, 0, 0, 0, 0 };
    _ = try TransferHookInstruction.unpack(&empty_init);

    const short_count = [_]u8{ 43, 34, 13, 49, 167, 88, 235, 235, 1, 0, 0 };
    try std.testing.expectError(ProgramError.InvalidInstructionData, TransferHookInstruction.unpack(&short_count));

    var missing_record = [_]u8{0} ** (extra_account_meta_list_header_len + meta.EXTRA_ACCOUNT_META_LEN - 1);
    @memcpy(missing_record[0..sol.DISCRIMINATOR_LEN], &INITIALIZE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR);
    std.mem.writeInt(u32, missing_record[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u32)], 1, .little);
    try std.testing.expectError(ProgramError.InvalidInstructionData, TransferHookInstruction.unpack(&missing_record));

    var trailing_bytes = [_]u8{0} ** (extra_account_meta_list_header_len + meta.EXTRA_ACCOUNT_META_LEN + 1);
    @memcpy(trailing_bytes[0..sol.DISCRIMINATOR_LEN], &UPDATE_EXTRA_ACCOUNT_META_LIST_DISCRIMINATOR);
    std.mem.writeInt(u32, trailing_bytes[sol.DISCRIMINATOR_LEN..][0..@sizeOf(u32)], 1, .little);
    try std.testing.expectError(ProgramError.InvalidInstructionData, TransferHookInstruction.unpack(&trailing_bytes));
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

test "Official Rust parity fixture matches Execute, Initialize, and Update builders" {
    const parity_fixture = @import("parity_fixture.zig");
    const fixture = try parity_fixture.load(std.testing.allocator);
    defer fixture.deinit();

    const input = fixture.value.inputs;
    const program_id: Pubkey = input.program_id;
    const source: Pubkey = input.source;
    const mint: Pubkey = input.mint;
    const destination: Pubkey = input.destination;
    const authority: Pubkey = input.authority;
    const validation: Pubkey = input.validation;

    const extra_account_metas = try std.testing.allocator.alloc(ExtraAccountMeta, input.extra_account_metas.len);
    defer std.testing.allocator.free(extra_account_metas);
    for (input.extra_account_metas, 0..) |fixture_meta, i| {
        const pubkey: Pubkey = fixture_meta.pubkey;
        extra_account_metas[i] = ExtraAccountMeta.fixed(
            &pubkey,
            fixture_meta.is_signer != 0,
            fixture_meta.is_writable != 0,
        );
    }

    var execute_metas: ExecuteMetas = undefined;
    var execute_data: ExecuteData = undefined;
    const execute_ix = execute(
        &program_id,
        &source,
        &mint,
        &destination,
        &authority,
        input.amount,
        &execute_metas,
        &execute_data,
    );
    try std.testing.expectEqualSlices(u8, &fixture.value.execute.program_id, execute_ix.program_id[0..]);
    try std.testing.expectEqualSlices(u8, fixture.value.execute.data, execute_ix.data);
    try std.testing.expectEqual(fixture.value.execute.accounts.len, execute_ix.accounts.len);
    for (fixture.value.execute.accounts, 0..) |expected_meta, i| {
        try expectFixtureMeta(execute_ix.accounts[i], expected_meta);
    }

    var initialize_metas: InitializeExtraAccountMetaListMetas = undefined;
    const initialize_data = try std.testing.allocator.alloc(u8, extraAccountMetaListDataLen(extra_account_metas.len));
    defer std.testing.allocator.free(initialize_data);
    const initialize_ix = try initializeExtraAccountMetaList(
        &program_id,
        &validation,
        &mint,
        &authority,
        extra_account_metas,
        &initialize_metas,
        initialize_data,
    );
    try std.testing.expectEqualSlices(u8, &fixture.value.initialize.program_id, initialize_ix.program_id[0..]);
    try std.testing.expectEqualSlices(u8, fixture.value.initialize.data, initialize_ix.data);
    try std.testing.expectEqual(fixture.value.initialize.accounts.len, initialize_ix.accounts.len);
    for (fixture.value.initialize.accounts, 0..) |expected_meta, i| {
        try expectFixtureMeta(initialize_ix.accounts[i], expected_meta);
    }

    var update_metas: UpdateExtraAccountMetaListMetas = undefined;
    const update_data = try std.testing.allocator.alloc(u8, extraAccountMetaListDataLen(extra_account_metas.len));
    defer std.testing.allocator.free(update_data);
    const update_ix = try updateExtraAccountMetaList(
        &program_id,
        &validation,
        &mint,
        &authority,
        extra_account_metas,
        &update_metas,
        update_data,
    );
    try std.testing.expectEqualSlices(u8, &fixture.value.update.program_id, update_ix.program_id[0..]);
    try std.testing.expectEqualSlices(u8, fixture.value.update.data, update_ix.data);
    try std.testing.expectEqual(fixture.value.update.accounts.len, update_ix.accounts.len);
    for (fixture.value.update.accounts, 0..) |expected_meta, i| {
        try expectFixtureMeta(update_ix.accounts[i], expected_meta);
    }
}
